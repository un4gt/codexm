package com.codexm.nativemodules

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runtime start parameters for the Android Codex native bridge.
 */
data class RuntimeStartRequest(
    val runtimeId: String = "default",
    val cwdUri: String,
    val executablePath: String? = null,
    val assetPath: String? = null,
    val args: List<String> = emptyList(),
    val env: Map<String, String> = emptyMap(),
)

internal data class ResolvedExecutable(
    val execPath: String,
    val binDir: File?,
    val source: String,
)

internal data class RuntimeProc(
    val process: Process,
    val stdin: OutputStreamWriter,
    val alive: AtomicBoolean,
    val stderrTail: StringBuilder,
)

internal data class RuntimeExitInfo(
    val exitCode: Int?,
    val stderrTail: String,
    val updatedAtMs: Long,
)

/**
 * Runs the packaged Codex Android runtime and forwards stdout/stderr lines to Flutter.
 */
class CodexRuntimeManager(
    private val appContext: Context,
    private val onRuntimeLine: (Map<String, Any?>) -> Unit = {},
) {
    private val ioExecutor = Executors.newCachedThreadPool()
    private val runtimes = ConcurrentHashMap<String, RuntimeProc>()
    private val runtimeExits = ConcurrentHashMap<String, RuntimeExitInfo>()
    private val executableResolver = CodexRuntimeExecutableResolver(appContext)

    private val stderrTailMaxChars = 8_000
    private val startupGraceMs = 250L

    /**
     * Starts a runtime if it is not already alive and returns its runtime id.
     */
    fun start(request: RuntimeStartRequest): String {
        val runtimeId = request.runtimeId.ifBlank { "default" }
        val existing = runtimes[runtimeId]
        if (existing != null && existing.alive.get()) {
            return runtimeId
        }
        runtimeExits.remove(runtimeId)

        val cwdPath = CodexRuntimeFs.uriToFilePath(request.cwdUri)
        val cwd = File(cwdPath).apply { mkdirs() }
        val resolved = executableResolver.resolve(request)
        val execPath = resolved.execPath

        val argv = ArrayList<String>(request.args.size + 1).apply {
            add(execPath)
            addAll(request.args)
        }
        val commandPreview = argv.joinToString(" ").let { value ->
            if (value.length > 360) "${value.take(360)}..." else value
        }

        val processBuilder = ProcessBuilder(argv).apply {
            directory(cwd)
            redirectErrorStream(false)
        }
        configureEnvironment(processBuilder, resolved, request.env)
        preflightLinkerDeps(runtimeId, resolved, execPath)

        val process = startProcess(processBuilder, resolved)
        val stdin = OutputStreamWriter(process.outputStream, StandardCharsets.UTF_8)
        val alive = AtomicBoolean(true)
        val runtime = RuntimeProc(
            process = process,
            stdin = stdin,
            alive = alive,
            stderrTail = StringBuilder(),
        )
        runtimes[runtimeId] = runtime

        startReaders(runtimeId, runtime)
        watchExit(runtimeId, runtime)
        verifyNotExitedEarly(runtimeId, runtime, stdin, resolved, commandPreview)
        return runtimeId
    }

    /**
     * Stops a runtime by id. When no id is provided, stops the default runtime.
     */
    fun stop(runtimeId: String? = null) {
        val resolvedId = runtimeId?.ifBlank { "default" } ?: "default"
        val runtime = runtimes.remove(resolvedId) ?: return
        runtime.alive.set(false)
        try {
            runtime.stdin.close()
        } catch (_: Throwable) {
        }
        try {
            runtime.process.destroy()
            runtime.process.waitFor(500, TimeUnit.MILLISECONDS)
            if (runtime.process.isAlive) {
                runtime.process.destroyForcibly()
            }
        } catch (_: Throwable) {
        }
    }

    /**
     * Stops all active runtimes. Used when the Flutter engine is detached.
     */
    fun stopAll() {
        runtimes.keys.toList().forEach { runtimeId -> stop(runtimeId) }
    }

    /**
     * Sends a line into a running runtime stdin.
     */
    fun send(runtimeId: String, line: String) {
        val resolvedId = runtimeId.ifBlank { "default" }
        val runtime = runtimes[resolvedId]
        if (runtime == null || !runtime.alive.get()) {
            val last = runtimeExits[resolvedId]
            val lastSummary = if (last != null) "\n${formatRuntimeExit(last)}" else ""
            throw IllegalStateException("runtime not running: $resolvedId$lastSummary")
        }
        runtime.stdin.write(line)
        runtime.stdin.write("\n")
        runtime.stdin.flush()
    }

    /**
     * Marks a filesystem path executable for runtime helpers.
     */
    fun chmod(path: String) {
        val resolvedPath = CodexRuntimeFs.uriToFilePath(path)
        CodexRuntimeFs.chmodExecutable(resolvedPath)
        val file = File(resolvedPath)
        file.setExecutable(true, false)
        file.setReadable(true, false)
        file.setWritable(true, true)
    }

    /**
     * Extracts a `.tar.gz` archive into the destination directory.
     */
    fun extractTarGz(archivePath: String, destDir: String) {
        CodexTarGzExtractor.extract(
            archivePath = CodexRuntimeFs.uriToFilePath(archivePath),
            destDir = CodexRuntimeFs.uriToFilePath(destDir),
        )
    }

    private fun configureEnvironment(
        processBuilder: ProcessBuilder,
        resolved: ResolvedExecutable,
        extraEnv: Map<String, String>,
    ) {
        val env = processBuilder.environment()
        extraEnv.forEach { (key, value) ->
            env[key] = value
        }

        val systemFallback = listOf(
            "/system/bin",
            "/system/xbin",
            "/vendor/bin",
            "/system_ext/bin",
        ).joinToString(File.pathSeparator)

        val binDir = resolved.binDir?.absolutePath
        if (!binDir.isNullOrBlank()) {
            val existingPath = env["PATH"]
            val basePath = if (existingPath.isNullOrBlank()) systemFallback else existingPath
            env["PATH"] = "${binDir}${File.pathSeparator}${basePath}"
        } else if (env["PATH"].isNullOrBlank()) {
            env["PATH"] = systemFallback
        }

        val nativeLibDir = appContext.applicationInfo?.nativeLibraryDir
        if (!nativeLibDir.isNullOrBlank()) {
            val existingLd = env["LD_LIBRARY_PATH"]
            val parts = ArrayList<String>()
            if (!binDir.isNullOrBlank()) {
                parts.add(binDir)
            }
            parts.add(nativeLibDir)
            if (!existingLd.isNullOrBlank()) {
                existingLd.split(File.pathSeparatorChar)
                    .filter { value -> value.isNotBlank() }
                    .forEach(parts::add)
            }
            env["LD_LIBRARY_PATH"] = parts.distinct().joinToString(File.pathSeparator)
        }

        if (env["SHELL"].isNullOrBlank()) {
            env["SHELL"] = "/system/bin/sh"
        }
        if (env["TMPDIR"].isNullOrBlank()) {
            env["TMPDIR"] = appContext.cacheDir.absolutePath
        }
    }

    private fun preflightLinkerDeps(
        runtimeId: String,
        resolved: ResolvedExecutable,
        execPath: String,
    ) {
        try {
            val nativeLibDirPath = appContext.applicationInfo?.nativeLibraryDir
            val nativeLibDir = if (!nativeLibDirPath.isNullOrBlank()) {
                File(nativeLibDirPath)
            } else {
                null
            }
            CodexRuntimeLinker.preflight(execPath, resolved.binDir, nativeLibDir)
        } catch (error: Throwable) {
            throw IllegalStateException(
                "CodexRuntime 缺少依赖库，无法启动。\n" +
                    "- runtimeId: $runtimeId\n" +
                    "- source: ${resolved.source}\n" +
                    "${error.message ?: ""}".trim(),
                error,
            )
        }
    }

    private fun startProcess(
        processBuilder: ProcessBuilder,
        resolved: ResolvedExecutable,
    ): Process {
        return try {
            processBuilder.start()
        } catch (error: Throwable) {
            val message = error.message.orEmpty()
            if (
                message.contains("error=13") ||
                message.contains("Permission denied", ignoreCase = true)
            ) {
                throw RuntimeException(
                    "CodexRuntime 无法执行可执行文件（Permission denied）。\n" +
                        "- 已解析来源：${resolved.source}\n" +
                        "- filesDir: ${appContext.filesDir.absolutePath}\n" +
                        "- nativeLibraryDir: ${appContext.applicationInfo?.nativeLibraryDir.orEmpty()}\n" +
                        "\n" +
                        "Android >= 10 且 targetSdkVersion >= 29 时，SELinux 会阻止从应用私有可写目录直接执行 ELF。" +
                        " 当前 Flutter 插件方案必须从 nativeLibraryDir 运行 codex/codex-exec/rg，并在 filesDir 仅保留 symlink 或 wrapper。\n" +
                        "原始错误：$message",
                    error,
                )
            }
            throw error
        }
    }

    private fun startReaders(runtimeId: String, runtime: RuntimeProc) {
        ioExecutor.execute {
            try {
                BufferedReader(
                    InputStreamReader(runtime.process.inputStream, StandardCharsets.UTF_8),
                ).use { reader ->
                    while (runtime.alive.get()) {
                        val line = reader.readLine() ?: break
                        emitLine(runtimeId, "stdout", line)
                    }
                }
            } catch (error: Throwable) {
                emitLine(runtimeId, "stderr", "stdout reader error: ${error.message}")
            }
        }

        ioExecutor.execute {
            try {
                BufferedReader(
                    InputStreamReader(runtime.process.errorStream, StandardCharsets.UTF_8),
                ).use { reader ->
                    while (runtime.alive.get()) {
                        val line = reader.readLine() ?: break
                        appendStderrTail(runtime.stderrTail, line)
                        emitLine(runtimeId, "stderr", line)
                    }
                }
            } catch (error: Throwable) {
                val line = "stderr reader error: ${error.message}"
                appendStderrTail(runtime.stderrTail, line)
                emitLine(runtimeId, "stderr", line)
            }
        }
    }

    private fun watchExit(runtimeId: String, runtime: RuntimeProc) {
        ioExecutor.execute {
            var exitCode: Int? = null
            try {
                exitCode = runtime.process.waitFor()
            } catch (_: Throwable) {
            } finally {
                runtime.alive.set(false)
                runtimes.remove(runtimeId)
                val tail = readStderrTail(runtime.stderrTail)
                recordRuntimeExit(runtimeId, exitCode, tail)
                val code = exitCode?.toString() ?: "unknown"
                emitLine(runtimeId, "stderr", "process exited (code=$code)")
            }
        }
    }

    private fun verifyNotExitedEarly(
        runtimeId: String,
        runtime: RuntimeProc,
        stdin: OutputStreamWriter,
        resolved: ResolvedExecutable,
        commandPreview: String,
    ) {
        val exitedEarly = try {
            runtime.process.waitFor(startupGraceMs, TimeUnit.MILLISECONDS)
        } catch (_: Throwable) {
            false
        }
        if (!exitedEarly) {
            return
        }

        val exitCode = try {
            runtime.process.exitValue()
        } catch (_: Throwable) {
            null
        }
        runtime.alive.set(false)
        runtimes.remove(runtimeId, runtime)
        try {
            stdin.close()
        } catch (_: Throwable) {
        }
        val tail = readStderrTail(runtime.stderrTail)
        recordRuntimeExit(runtimeId, exitCode, tail)
        throw IllegalStateException(
            buildStartupExitMessage(
                runtimeId = runtimeId,
                source = resolved.source,
                commandPreview = commandPreview,
                exitCode = exitCode,
                stderrTail = tail,
            ),
        )
    }

    private fun emitLine(runtimeId: String, stream: String, line: String) {
        onRuntimeLine(
            mapOf(
                "runtimeId" to runtimeId,
                "stream" to stream,
                "line" to line,
            ),
        )
    }

    private fun appendStderrTail(buffer: StringBuilder, line: String) {
        synchronized(buffer) {
            if (buffer.isNotEmpty()) {
                buffer.append('\n')
            }
            buffer.append(line)
            if (buffer.length > stderrTailMaxChars) {
                buffer.delete(0, buffer.length - stderrTailMaxChars)
            }
        }
    }

    private fun readStderrTail(buffer: StringBuilder): String {
        return synchronized(buffer) { buffer.toString().trim() }
    }

    private fun recordRuntimeExit(runtimeId: String, exitCode: Int?, stderrTail: String) {
        runtimeExits[runtimeId] = RuntimeExitInfo(
            exitCode = exitCode,
            stderrTail = stderrTail,
            updatedAtMs = System.currentTimeMillis(),
        )
    }

    private fun formatRuntimeExit(info: RuntimeExitInfo): String {
        val code = info.exitCode?.toString() ?: "unknown"
        val tail = if (info.stderrTail.isBlank()) "<empty>" else info.stderrTail
        return "lastExitCode=$code at=${info.updatedAtMs}\nstderr:\n$tail"
    }

    private fun buildStartupExitMessage(
        runtimeId: String,
        source: String,
        commandPreview: String,
        exitCode: Int?,
        stderrTail: String,
    ): String {
        val code = exitCode?.toString() ?: "unknown"
        val tail = if (stderrTail.isBlank()) "<empty>" else stderrTail
        return "CodexRuntime 启动后立即退出。\n" +
            "- runtimeId: $runtimeId\n" +
            "- source: $source\n" +
            "- exitCode: $code\n" +
            "- command: $commandPreview\n" +
            "stderr:\n$tail"
    }
}
