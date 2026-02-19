package com.codexm.nativemodules

import android.net.Uri
import android.os.Build
import android.system.Os
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule.RCTDeviceEventEmitter
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class CodexRuntimeManagerModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private data class ResolvedExecutable(
    val execPath: String,
    val binDir: File?,
    val source: String,
  )

  private data class RuntimeProc(
    val id: String,
    val process: Process,
    val stdin: OutputStreamWriter,
    val alive: AtomicBoolean,
  )

  private val ioExecutor = Executors.newCachedThreadPool()
  private val runtimes = ConcurrentHashMap<String, RuntimeProc>()

  override fun getName(): String = "CodexRuntimeManager"

  private fun chmodExecutable(path: String) {
    try {
      // 0755
      Os.chmod(path, 493)
    } catch (_: Throwable) {
      // best-effort
    }
  }

  private fun ensureSymlink(link: File, target: File): Boolean {
    return try {
      try {
        // Use lstat so we can detect/remove broken symlinks as well.
        Os.lstat(link.absolutePath)
        link.delete()
      } catch (_: Throwable) {
        // doesn't exist
      }
      Os.symlink(target.absolutePath, link.absolutePath)
      true
    } catch (_: Throwable) {
      // best-effort: some devices may block symlink creation. We intentionally avoid copying the
      // binary into app data here because Android 10+ (targetSdk>=29) forbids exec() from
      // app-private writable directories under SELinux W^X restrictions.
      false
    }
  }

  private fun tryResolveFromNativeLibs(): ResolvedExecutable? {
    val nativeDirPath = reactContext.applicationInfo?.nativeLibraryDir ?: return null
    if (nativeDirPath.isBlank()) return null
    val nativeDir = File(nativeDirPath)
    if (!nativeDir.exists()) return null

    val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
    val outDir = File(reactContext.filesDir, "codexm/bin/$abi").apply { mkdirs() }
    chmodExecutable(outDir.absolutePath)

    val codex = File(nativeDir, "libcodex.so")
    if (!codex.exists()) return null

    // Create stable names in our own bin dir. Exec permission will be checked against the target
    // (apk native lib dir), not the symlink itself.
    val codexLink = File(outDir, "codex")
    val useSymlink = ensureSymlink(codexLink, codex)
    ensureSymlink(File(outDir, "codex-exec"), File(nativeDir, "libcodex_exec.so"))
    ensureSymlink(File(outDir, "rg"), File(nativeDir, "librg.so"))

    val execPath = if (useSymlink && codexLink.exists()) {
      codexLink.absolutePath
    } else {
      codex.absolutePath
    }

    return ResolvedExecutable(execPath, outDir, "nativeLibs")
  }

  private fun emitLine(runtimeId: String, stream: String, line: String) {
    val payload = Arguments.createMap().apply {
      putString("runtimeId", runtimeId)
      putString("stream", stream)
      putString("line", line)
    }
    reactContext.getJSModule(RCTDeviceEventEmitter::class.java).emit("CodexRuntimeLine", payload)
  }

  private fun uriToFilePath(uriOrPath: String): String {
    return try {
      val uri = Uri.parse(uriOrPath)
      if (uri.scheme == null) uriOrPath else (uri.path ?: uriOrPath)
    } catch (_: Throwable) {
      uriOrPath
    }
  }

  private fun ensureExecutableFromAssets(assetPath: String): File {
    val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
    val resolvedAssetPath = assetPath.replace("{abi}", abi)
    val outDir = File(reactContext.filesDir, "codexm/bin/$abi").apply { mkdirs() }
    chmodExecutable(outDir.absolutePath)
    val name = resolvedAssetPath.substringAfterLast('/')
    val outFile = File(outDir, name)
    if (!outFile.exists()) {
      reactContext.assets.open(resolvedAssetPath).use { input ->
        outFile.outputStream().use { output -> input.copyTo(output) }
      }
    }

    // Always ensure permissions (file may exist from a previous run without +x).
    chmodExecutable(outFile.absolutePath)
    outFile.setExecutable(true, false)
    outFile.setReadable(true, false)
    outFile.setWritable(true, true)
    return outFile
  }

  private fun resolveExecutable(params: ReadableMap): ResolvedExecutable {
    if (params.hasKey("executablePath") && !params.isNull("executablePath")) {
      val execPath = uriToFilePath(params.getString("executablePath")!!)
      return ResolvedExecutable(execPath, File(execPath).parentFile, "executablePath")
    }

    if (params.hasKey("assetPath") && !params.isNull("assetPath")) {
      // Android 10+ with targetSdk>=29 blocks exec() from app-private writable directories
      // (/data/data/<pkg>/files...) with SELinux "execute_no_trans". So we prefer running the
      // binaries from the APK native library directory (/data/app/.../lib/<abi>), which is allowed.
      tryResolveFromNativeLibs()?.let { return it }

      // On Android 10+ with targetSdk>=29, falling back to extracting the ELF into filesDir will
      // reliably fail with "Permission denied" (avc: denied { execute_no_trans }). If we couldn't
      // resolve extracted native libs, fail fast with actionable guidance instead of copying assets.
      val targetSdk = try {
        reactContext.applicationInfo?.targetSdkVersion ?: 0
      } catch (_: Throwable) {
        0
      }
      if (Build.VERSION.SDK_INT >= 29 && targetSdk >= 29) {
        val nativeDirPath = reactContext.applicationInfo?.nativeLibraryDir ?: ""
        val nativeDirListing = try {
          val dir = File(nativeDirPath)
          if (!dir.exists()) "(missing)"
          else (dir.list()?.joinToString(", ") ?: "(empty)")
        } catch (_: Throwable) {
          "(unreadable)"
        }
        throw IllegalStateException(
          "未能从 nativeLibraryDir 解析 codex 可执行文件（libcodex.so）。\n" +
            "- targetSdkVersion: $targetSdk\n" +
            "- nativeLibraryDir: $nativeDirPath\n" +
            "- nativeLibraryDir contents: $nativeDirListing\n" +
            "\n" +
            "这是 Android >= 10 / targetSdk >= 29 的已知限制：app 私有可写目录（filesDir）中的 ELF 无法 exec（avc: denied { execute_no_trans }）。\n" +
            "请确认：\n" +
            "1) `android/gradle.properties` 设置 `expo.useLegacyPackaging=true`（确保 .so 提取到磁盘）\n" +
            "2) Manifest 设置 `android:extractNativeLibs=\"true\"`\n" +
            "3) APK 内包含 `lib/<abi>/libcodex.so`、`libcodex_exec.so`、`librg.so`\n"
        )
      }

      val assetPathRaw = params.getString("assetPath")!!
      val execFile = ensureExecutableFromAssets(assetPathRaw)

      // Place helper executables next to the main binary and prepend that directory to PATH so
      // Codex can locate them (e.g. codex-exec, rg).
      try {
        val assetDir = assetPathRaw.substringBeforeLast('/', "")
        if (assetDir.isNotEmpty()) {
          ensureExecutableFromAssets("$assetDir/codex-exec")
          ensureExecutableFromAssets("$assetDir/rg")
        }
      } catch (_: Throwable) {
        // ignore: helper asset may be missing
      }

      return ResolvedExecutable(execFile.absolutePath, execFile.parentFile, "assets")
    }

    throw IllegalArgumentException("executablePath or assetPath is required")
  }

  @ReactMethod
  fun start(params: ReadableMap, promise: Promise) {
    try {
      val runtimeId = params.getString("runtimeId") ?: "default"
      val existing = runtimes[runtimeId]
      if (existing != null && existing.alive.get()) {
        promise.resolve(runtimeId)
        return
      }

      val cwdUri = params.getString("cwdUri") ?: throw IllegalArgumentException("cwdUri is required")
      val cwdPath = uriToFilePath(cwdUri)
      val cwd = File(cwdPath)
      cwd.mkdirs()

      val resolved = resolveExecutable(params)
      val execPath = resolved.execPath

      val argsArray = if (params.hasKey("args") && !params.isNull("args")) params.getArray("args") else null
      val argv = ArrayList<String>()
      argv.add(execPath)
      if (argsArray != null) {
        for (i in 0 until argsArray.size()) {
          val v = argsArray.getString(i)
          if (v != null) argv.add(v)
        }
      }

      val pb = ProcessBuilder(argv)
      pb.directory(cwd)
      pb.redirectErrorStream(false)

      // Prepend our bin directory (contains symlinks or extracted helpers) to PATH so Codex can
      // locate codex-exec/rg.
      try {
        val binDir = resolved.binDir?.absolutePath
        if (!binDir.isNullOrBlank()) {
          val existingPath = pb.environment()["PATH"]
          pb.environment()["PATH"] = if (existingPath.isNullOrBlank()) {
            binDir
          } else {
            "${binDir}${File.pathSeparator}${existingPath}"
          }
        }
      } catch (_: Throwable) {
        // ignore
      }

      if (params.hasKey("env") && !params.isNull("env")) {
        val envMap = params.getMap("env")!!
        val it = envMap.keySetIterator()
        while (it.hasNextKey()) {
          val k = it.nextKey()
          val v = envMap.getString(k)
          if (v != null) pb.environment()[k] = v
        }
      }

      val proc = try {
        pb.start()
      } catch (e: Throwable) {
        val msg = e.message ?: ""
        if (msg.contains("error=13") || msg.contains("Permission denied", ignoreCase = true)) {
          val appData = reactContext.filesDir.absolutePath
          val nativeDir = reactContext.applicationInfo?.nativeLibraryDir ?: ""
          throw RuntimeException(
            "无法执行 codex 可执行文件（Permission denied）。\n" +
              "- 已解析来源：${resolved.source}\n" +
              "- filesDir: $appData\n" +
              "- nativeLibraryDir: $nativeDir\n" +
              "\n" +
              "Android >= 10 且 targetSdkVersion >= 29 时，SELinux 会阻止 untrusted_app 从 app 私有可写目录（如 filesDir）执行 ELF（常见日志：`avc: denied { execute_no_trans } ... tcontext=app_data_file`），仅 chmod +x 不足以解决。\n" +
              "建议：把 codex/codex-exec/rg 作为 APK native libraries（jniLibs，文件名以 .so 结尾）打包并从 nativeLibraryDir 执行，然后在 filesDir 创建 symlink（codex/codex-exec/rg）供 PATH 查找。\n" +
              "原始错误：$msg",
            e
          )
        }
        throw e
      }
      val stdin = OutputStreamWriter(proc.outputStream, StandardCharsets.UTF_8)
      val alive = AtomicBoolean(true)
      val runtime = RuntimeProc(runtimeId, proc, stdin, alive)
      runtimes[runtimeId] = runtime

      ioExecutor.execute {
        try {
          BufferedReader(InputStreamReader(proc.inputStream, StandardCharsets.UTF_8)).use { br ->
            while (alive.get()) {
              val line = br.readLine() ?: break
              emitLine(runtimeId, "stdout", line)
            }
          }
        } catch (e: Throwable) {
          emitLine(runtimeId, "stderr", "stdout reader error: ${e.message}")
        }
      }

      ioExecutor.execute {
        try {
          BufferedReader(InputStreamReader(proc.errorStream, StandardCharsets.UTF_8)).use { br ->
            while (alive.get()) {
              val line = br.readLine() ?: break
              emitLine(runtimeId, "stderr", line)
            }
          }
        } catch (e: Throwable) {
          emitLine(runtimeId, "stderr", "stderr reader error: ${e.message}")
        }
      }

      ioExecutor.execute {
        try {
          proc.waitFor()
        } catch (_: Throwable) {
        } finally {
          alive.set(false)
          runtimes.remove(runtimeId)
          emitLine(runtimeId, "stderr", "process exited")
        }
      }

      promise.resolve(runtimeId)
    } catch (e: Throwable) {
      promise.reject("E_CODEX_RUNTIME_START", e.message, e)
    }
  }

  // React Native NativeEventEmitter requires these two methods to be present on the module.
  // We don't need to track listener counts here because we push process output only when a runtime is started.
  @ReactMethod
  fun addListener(eventName: String) {
    // no-op
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    // no-op
  }

  @ReactMethod
  fun stop(params: ReadableMap?, promise: Promise) {
    try {
      val runtimeId = params?.getString("runtimeId") ?: "default"
      val rt = runtimes.remove(runtimeId)
      if (rt != null) {
        rt.alive.set(false)
        try {
          rt.stdin.close()
        } catch (_: Throwable) {
        }
        try {
          rt.process.destroy()
          rt.process.waitFor(500, TimeUnit.MILLISECONDS)
          if (rt.process.isAlive) rt.process.destroyForcibly()
        } catch (_: Throwable) {
        }
      }
      promise.resolve(null)
    } catch (e: Throwable) {
      promise.reject("E_CODEX_RUNTIME_STOP", e.message, e)
    }
  }

  @ReactMethod
  fun send(params: ReadableMap, promise: Promise) {
    try {
      val runtimeId = params.getString("runtimeId") ?: "default"
      val line = params.getString("line") ?: ""
      val rt = runtimes[runtimeId] ?: throw IllegalStateException("runtime not running: $runtimeId")
      rt.stdin.write(line)
      rt.stdin.write("\n")
      rt.stdin.flush()
      promise.resolve(null)
    } catch (e: Throwable) {
      promise.reject("E_CODEX_RUNTIME_SEND", e.message, e)
    }
  }
}
