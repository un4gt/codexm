package com.codexm.nativemodules

import android.content.Context
import android.os.Build
import java.io.File

internal class CodexRuntimeExecutableResolver(private val appContext: Context) {
    fun resolve(request: RuntimeStartRequest): ResolvedExecutable {
        request.executablePath
            ?.takeIf { value -> value.isNotBlank() }
            ?.let { executablePath ->
                val execPath = CodexRuntimeFs.uriToFilePath(executablePath)
                return ResolvedExecutable(
                    execPath = execPath,
                    binDir = File(execPath).parentFile,
                    source = "executablePath",
                )
            }

        request.assetPath
            ?.takeIf { value -> value.isNotBlank() }
            ?.let {
                tryResolveFromNativeLibs()?.let { resolved -> return resolved }

                val targetSdk = try {
                    appContext.applicationInfo?.targetSdkVersion ?: 0
                } catch (_: Throwable) {
                    0
                }
                val nativeDirPath = appContext.applicationInfo?.nativeLibraryDir.orEmpty()
                val missing = try {
                    val dir = File(nativeDirPath)
                    if (nativeDirPath.isNotBlank() && dir.exists()) {
                        missingNativeRuntimeFiles(dir)
                    } else {
                        emptyList()
                    }
                } catch (_: Throwable) {
                    emptyList()
                }
                val nativeDirListing = try {
                    val dir = File(nativeDirPath)
                    when {
                        !dir.exists() -> "(missing)"
                        else -> dir.list()?.joinToString(", ") ?: "(empty)"
                    }
                } catch (_: Throwable) {
                    "(unreadable)"
                }

                throw IllegalStateException(
                    "未能从 nativeLibraryDir 解析 Codex 运行时可执行文件。\n" +
                        "- targetSdkVersion: $targetSdk\n" +
                        "- nativeLibraryDir: $nativeDirPath\n" +
                        "- nativeLibraryDir contents: $nativeDirListing\n" +
                        (if (missing.isNotEmpty()) "- missing: ${missing.joinToString(", ")}\n" else "") +
                        "\n" +
                        "请确认：\n" +
                        "1) Flutter plugin 的 jniLibs 生成任务已产出 libcodex.so、libcodex_exec.so、librg.so\n" +
                        "2) Android 打包产物允许提取 native libraries 到磁盘\n" +
                        "3) APK/AAB 内包含 lib/<abi>/libcodex.so、libcodex_exec.so、librg.so\n",
                )
            }

        throw IllegalArgumentException("executablePath or assetPath is required")
    }

    @Suppress("unused")
    private fun ensureExecutableFromAssets(assetPath: String): File {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
        val resolvedAssetPath = assetPath.replace("{abi}", abi)
        val outDir = File(appContext.filesDir, "codexm/bin/$abi").apply { mkdirs() }
        CodexRuntimeFs.chmodExecutable(outDir.absolutePath)
        val name = resolvedAssetPath.substringAfterLast('/')
        val outFile = File(outDir, name)
        if (!outFile.exists()) {
            appContext.assets.open(resolvedAssetPath).use { input ->
                outFile.outputStream().use { output -> input.copyTo(output) }
            }
        }
        CodexRuntimeFs.chmodExecutable(outFile.absolutePath)
        outFile.setExecutable(true, false)
        outFile.setReadable(true, false)
        outFile.setWritable(true, true)
        return outFile
    }

    private fun tryResolveFromNativeLibs(): ResolvedExecutable? {
        val nativeDirPath = appContext.applicationInfo?.nativeLibraryDir ?: return null
        if (nativeDirPath.isBlank()) {
            return null
        }
        val nativeDir = File(nativeDirPath)
        if (!nativeDir.exists()) {
            return null
        }

        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
        val outDir = File(appContext.filesDir, "codexm/bin/$abi").apply { mkdirs() }
        CodexRuntimeFs.chmodExecutable(outDir.absolutePath)

        val codex = File(nativeDir, "libcodex.so")
        val codexExec = File(nativeDir, "libcodex_exec.so")
        val rg = File(nativeDir, "librg.so")
        if (!codex.exists() || !codexExec.exists() || !rg.exists()) {
            return null
        }

        val codexLink = File(outDir, "codex")
        val useSymlink = CodexRuntimeFs.ensureSymlink(codexLink, codex)
        val codexExecReady = CodexRuntimeFs.ensureRuntimeHelper(outDir, "codex-exec", codexExec)
        val rgReady = CodexRuntimeFs.ensureRuntimeHelper(outDir, "rg", rg)

        if (!codexExecReady || !rgReady) {
            throw IllegalStateException(
                "Codex 运行时 helper 准备失败（无法创建 codex-exec/rg 入口）。\n" +
                    "- nativeLibraryDir: $nativeDirPath\n" +
                    "- outDir: ${outDir.absolutePath}\n" +
                    "- codexExecReady: $codexExecReady\n" +
                    "- rgReady: $rgReady",
            )
        }

        val execPath = if (useSymlink && codexLink.exists()) {
            codexLink.absolutePath
        } else {
            codex.absolutePath
        }
        return ResolvedExecutable(execPath = execPath, binDir = outDir, source = "nativeLibs")
    }

    private fun missingNativeRuntimeFiles(nativeDir: File): List<String> {
        val required = listOf("libcodex.so", "libcodex_exec.so", "librg.so")
        return required.filter { name -> !File(nativeDir, name).exists() }
    }
}
