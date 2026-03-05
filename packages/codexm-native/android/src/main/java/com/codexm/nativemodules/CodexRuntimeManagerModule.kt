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
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.GZIPInputStream

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
    val stderrTail: StringBuilder,
  )

  private data class RuntimeExitInfo(
    val exitCode: Int?,
    val stderrTail: String,
    val updatedAtMs: Long,
  )

  private val ioExecutor = Executors.newCachedThreadPool()
  private val runtimes = ConcurrentHashMap<String, RuntimeProc>()
  private val runtimeExits = ConcurrentHashMap<String, RuntimeExitInfo>()

  private val stderrTailMaxChars = 8_000
  private val startupGraceMs = 250L

  override fun getName(): String = "CodexRuntimeManager"

  private fun chmodExecutable(path: String) {
    try {
      // 0755
      Os.chmod(path, 493)
    } catch (_: Throwable) {
      // best-effort
    }
  }

  private fun appendStderrTail(buf: StringBuilder, line: String) {
    synchronized(buf) {
      if (buf.isNotEmpty()) buf.append('\n')
      buf.append(line)
      if (buf.length > stderrTailMaxChars) {
        buf.delete(0, buf.length - stderrTailMaxChars)
      }
    }
  }

  private fun readStderrTail(buf: StringBuilder): String {
    return synchronized(buf) { buf.toString().trim() }
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

  private fun ensureExecWrapper(wrapper: File, target: File): Boolean {
    return try {
      wrapper.parentFile?.mkdirs()
      val targetPath = target.absolutePath.replace("\"", "\\\"")
      val script = "#!/system/bin/sh\nexec \"$targetPath\" \"$@\"\n"
      wrapper.writeText(script, Charsets.UTF_8)
      chmodExecutable(wrapper.absolutePath)
      wrapper.setExecutable(true, false)
      wrapper.setReadable(true, false)
      wrapper.setWritable(true, true)
      true
    } catch (_: Throwable) {
      false
    }
  }

  private fun ensureRuntimeHelper(outDir: File, helperName: String, target: File): Boolean {
    val helper = File(outDir, helperName)
    if (ensureSymlink(helper, target)) return true
    return ensureExecWrapper(helper, target)
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
      // Best-effort: some devices may block symlink creation. If possible, fall back to a hard
      // link which still points at the same inode (so exec permission is checked against the
      // nativeLibraryDir file label).
      try {
        Os.link(target.absolutePath, link.absolutePath)
        true
      } catch (_: Throwable) {
        // We intentionally avoid copying the binary into app data here because Android 10+
        // (targetSdk>=29) forbids exec() from app-private writable directories under SELinux W^X
        // restrictions.
        false
      }
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
    val codexExec = File(nativeDir, "libcodex_exec.so")
    val rg = File(nativeDir, "librg.so")
    if (!codex.exists()) return null
    if (!codexExec.exists()) return null
    if (!rg.exists()) return null

    // Create stable names in our own bin dir. Exec permission will be checked against the target
    // (apk native lib dir), not the symlink itself.
    val codexLink = File(outDir, "codex")
    val useSymlink = ensureSymlink(codexLink, codex)
    val codexExecReady = ensureRuntimeHelper(outDir, "codex-exec", codexExec)
    val rgReady = ensureRuntimeHelper(outDir, "rg", rg)

    if (!codexExecReady || !rgReady) {
      throw IllegalStateException(
        "Codex 运行时 helper 准备失败（无法创建 codex-exec/rg 入口）。\n" +
          "- nativeLibraryDir: $nativeDirPath\n" +
          "- outDir: ${outDir.absolutePath}\n" +
          "- codexExecReady: $codexExecReady\n" +
          "- rgReady: $rgReady"
      )
    }

    val execPath = if (useSymlink && codexLink.exists()) {
      codexLink.absolutePath
    } else {
      codex.absolutePath
    }

    return ResolvedExecutable(execPath, outDir, "nativeLibs")
  }

  private fun isVersionedSoName(name: String): Boolean {
    val i = name.indexOf(".so.")
    if (i < 0) return false
    val j = i + 4
    if (j >= name.length) return false
    val c = name[j]
    return c in '0'..'9'
  }

  private fun baseSoNameForVersioned(name: String): String? {
    val i = name.indexOf(".so.")
    if (i < 0) return null
    return name.substring(0, i + 3)
  }

  private fun bundledSoNameForVersionedNeeded(neededName: String): String? {
    // Avoid clobbering/overriding system libraries with the same basename (e.g. liblzma.so, libz.so).
    // We package Termux-provided deps under private names and create versioned aliases at runtime.
    if (neededName.startsWith("liblzma.so.")) return "libcodex_lzma.so"
    if (neededName.startsWith("libz.so.")) return "libcodex_z.so"
    return baseSoNameForVersioned(neededName)
  }

  private fun shouldPreflightNeededLib(name: String): Boolean {
    // Only check deps that are very unlikely to be provided by Android system images:
    // - versioned SONAMEs (e.g. libssl.so.3, liblzma.so.5)
    // - libc++_shared.so (should be bundled by the app when using c++_shared)
    if (name == "libc++_shared.so") return true
    return isVersionedSoName(name)
  }

  private fun readFully(channel: java.nio.channels.FileChannel, buf: ByteBuffer, pos: Long): Int {
    var total = 0
    while (buf.hasRemaining()) {
      val n = channel.read(buf, pos + total)
      if (n <= 0) break
      total += n
    }
    return total
  }

  private fun u16(v: Short): Int = v.toInt() and 0xffff
  private fun u32(v: Int): Long = v.toLong() and 0xffffffffL

  private data class ElfSegment(
    val type: Long,
    val offset: Long,
    val vaddr: Long,
    val filesz: Long,
    val memsz: Long,
  )

  private fun listNeededSharedLibraries(execFile: File): List<String> {
    if (!execFile.exists() || !execFile.isFile) return emptyList()
    return try {
      FileInputStream(execFile).use { fis ->
        val ch = fis.channel

        val header = ByteBuffer.allocate(64).order(ByteOrder.LITTLE_ENDIAN)
        val n0 = readFully(ch, header, 0L)
        if (n0 < 52) return emptyList()
        header.flip()

        // e_ident
        val magic0 = header.get(0)
        val magic1 = header.get(1)
        val magic2 = header.get(2)
        val magic3 = header.get(3)
        if (magic0.toInt() != 0x7f || magic1.toInt() != 'E'.code || magic2.toInt() != 'L'.code || magic3.toInt() != 'F'.code) {
          return emptyList()
        }
        val eiClass = header.get(4).toInt() and 0xff // 1=32, 2=64
        val eiData = header.get(5).toInt() and 0xff  // 1=little
        if (eiData != 1) return emptyList()

        val phoff: Long
        val phentsize: Int
        val phnum: Int
        val is64 = eiClass == 2

        if (is64) {
          phoff = header.getLong(32)
          phentsize = u16(header.getShort(54))
          phnum = u16(header.getShort(56))
        } else if (eiClass == 1) {
          phoff = u32(header.getInt(28))
          phentsize = u16(header.getShort(42))
          phnum = u16(header.getShort(44))
        } else {
          return emptyList()
        }

        if (phoff <= 0 || phentsize <= 0 || phnum <= 0) return emptyList()

        val segments = ArrayList<ElfSegment>(phnum)
        val phBuf = ByteBuffer.allocate(phentsize).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until phnum) {
          phBuf.clear()
          val pos = phoff + (i.toLong() * phentsize.toLong())
          val n = readFully(ch, phBuf, pos)
          if (n < phentsize) break
          phBuf.flip()
          if (is64) {
            val pType = u32(phBuf.getInt(0))
            val pOffset = phBuf.getLong(8)
            val pVaddr = phBuf.getLong(16)
            val pFilesz = phBuf.getLong(32)
            val pMemsz = phBuf.getLong(40)
            segments.add(ElfSegment(pType, pOffset, pVaddr, pFilesz, pMemsz))
          } else {
            val pType = u32(phBuf.getInt(0))
            val pOffset = u32(phBuf.getInt(4))
            val pVaddr = u32(phBuf.getInt(8))
            val pFilesz = u32(phBuf.getInt(16))
            val pMemsz = u32(phBuf.getInt(20))
            segments.add(ElfSegment(pType, pOffset, pVaddr, pFilesz, pMemsz))
          }
        }

        val ptDynamic = segments.firstOrNull { it.type == 2L } ?: return emptyList()
        val loadSegs = segments.filter { it.type == 1L }
        if (ptDynamic.filesz <= 0) return emptyList()

        val dynEntrySize = if (is64) 16 else 8
        val dynMax = 1024 * 1024
        val dynSize = kotlin.math.min(ptDynamic.filesz.toInt(), dynMax)
        if (dynSize < dynEntrySize) return emptyList()

        val dynBuf = ByteBuffer.allocate(dynSize).order(ByteOrder.LITTLE_ENDIAN)
        val nd = readFully(ch, dynBuf, ptDynamic.offset)
        if (nd < dynEntrySize) return emptyList()
        dynBuf.flip()

        var strtabVa: Long? = null
        var strsz: Long = 0
        val neededOffsets = ArrayList<Long>()

        var idx = 0
        while (idx + dynEntrySize <= dynBuf.limit()) {
          val tag: Long
          val value: Long
          if (is64) {
            tag = dynBuf.getLong(idx)
            value = dynBuf.getLong(idx + 8)
          } else {
            tag = u32(dynBuf.getInt(idx))
            value = u32(dynBuf.getInt(idx + 4))
          }
          if (tag == 0L) break // DT_NULL
          when (tag) {
            1L -> neededOffsets.add(value)  // DT_NEEDED
            5L -> strtabVa = value          // DT_STRTAB
            10L -> strsz = value            // DT_STRSZ
          }
          idx += dynEntrySize
        }

        if (neededOffsets.isEmpty()) return emptyList()
        val strVa = strtabVa ?: return emptyList()
        if (strsz <= 0) return emptyList()

        val strSeg = loadSegs.firstOrNull { seg ->
          strVa >= seg.vaddr && strVa < (seg.vaddr + seg.memsz)
        } ?: return emptyList()

        val strOffset = strSeg.offset + (strVa - strSeg.vaddr)
        val strMax = 8 * 1024 * 1024L
        val strToRead = kotlin.math.min(strsz, strMax).toInt()
        if (strToRead <= 0) return emptyList()

        val strBuf = ByteBuffer.allocate(strToRead)
        val ns = readFully(ch, strBuf, strOffset)
        if (ns <= 0) return emptyList()
        val strBytes = strBuf.array()

        fun readCString(off: Int): String? {
          if (off < 0 || off >= ns) return null
          var end = off
          while (end < ns && strBytes[end].toInt() != 0) end++
          if (end <= off) return null
          return try {
            String(strBytes, off, end - off, Charsets.UTF_8)
          } catch (_: Throwable) {
            null
          }
        }

        val out = LinkedHashSet<String>()
        for (off0 in neededOffsets) {
          val off = off0.toInt()
          readCString(off)?.let { out.add(it) }
        }
        out.toList()
      }
    } catch (_: Throwable) {
      emptyList()
    }
  }

  private fun findLibraryFile(name: String, dirs: List<File>): File? {
    for (d in dirs) {
      val f = File(d, name)
      if (f.exists()) return f
    }
    return null
  }

  private fun preflightLinkerDeps(execPath: String, binDir: File?, nativeLibDir: File?) {
    if (binDir == null || nativeLibDir == null) return
    if (!nativeLibDir.exists()) return

    val needed = listNeededSharedLibraries(File(execPath))
    if (needed.isEmpty()) return

    val searchDirs = listOf(binDir, nativeLibDir)
    val missing = ArrayList<String>()

    for (name in needed) {
      if (!shouldPreflightNeededLib(name)) continue
      if (findLibraryFile(name, searchDirs) != null) continue

      // Best-effort: if the binary needs a versioned SONAME like libfoo.so.1 but we only ship
      // libfoo.so (because jniLibs must end with ".so"), create an alias in our writable bin dir.
      if (isVersionedSoName(name)) {
        val base = bundledSoNameForVersionedNeeded(name)
        if (!base.isNullOrBlank()) {
          val baseFile = File(nativeLibDir, base)
          if (baseFile.exists()) {
            val link = File(binDir, name)
            val linked = ensureSymlink(link, baseFile)
            if (!linked) {
              // Some devices may block symlink/hardlink creation. As a last resort, copy the
              // shared library into our bin dir with the versioned filename.
              try {
                link.delete()
              } catch (_: Throwable) {
              }
              try {
                baseFile.copyTo(link, overwrite = true)
                chmodExecutable(link.absolutePath)
                link.setReadable(true, false)
                link.setWritable(true, true)
              } catch (_: Throwable) {
                // ignore
              }
            }
          }
        }
      }

      if (findLibraryFile(name, searchDirs) == null) missing.add(name)
    }

    if (missing.isNotEmpty()) {
      val bin = binDir.absolutePath
      val native = nativeLibDir.absolutePath
      throw IllegalStateException(
        "缺少共享库依赖（动态链接器无法解析）。\n" +
          "- execPath: $execPath\n" +
          "- missing: ${missing.joinToString(", ")}\n" +
          "- searched: $bin, $native\n"
      )
    }
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

  private fun missingNativeRuntimeFiles(nativeDir: File): List<String> {
    val required = listOf("libcodex.so", "libcodex_exec.so", "librg.so")
    return required.filter { name -> !File(nativeDir, name).exists() }
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

      val targetSdk = try {
        reactContext.applicationInfo?.targetSdkVersion ?: 0
      } catch (_: Throwable) {
        0
      }

      val nativeDirPath = reactContext.applicationInfo?.nativeLibraryDir ?: ""
      val missing = try {
        val dir = File(nativeDirPath)
        if (nativeDirPath.isNotBlank() && dir.exists()) missingNativeRuntimeFiles(dir) else emptyList()
      } catch (_: Throwable) {
        emptyList()
      }
      val nativeDirListing = try {
        val dir = File(nativeDirPath)
        if (!dir.exists()) "(missing)"
        else (dir.list()?.joinToString(", ") ?: "(empty)")
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
          "1) `android/gradle.properties` 设置 `expo.useLegacyPackaging=true`（确保 .so 提取到磁盘）\n" +
          "2) Manifest 设置 `android:extractNativeLibs=\"true\"`\n" +
          "3) APK 内包含 `lib/<abi>/libcodex.so`、`libcodex_exec.so`、`librg.so`\n"
      )
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
      runtimeExits.remove(runtimeId)

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
      val commandPreview = argv.joinToString(" ").let { if (it.length > 360) "${it.take(360)}..." else it }

      val pb = ProcessBuilder(argv)
      pb.directory(cwd)
      pb.redirectErrorStream(false)

      if (params.hasKey("env") && !params.isNull("env")) {
        val envMap = params.getMap("env")!!
        val it = envMap.keySetIterator()
        while (it.hasNextKey()) {
          val k = it.nextKey()
          val v = envMap.getString(k)
          if (v != null) pb.environment()[k] = v
        }
      }

      // Prepend our bin directory (contains symlinks or extracted helpers) to PATH so Codex can
      // locate codex-exec/rg. Also ensure /system/bin is present, because some Android app
      // environments may not set PATH by default (which breaks spawning /system/bin/sh).
      try {
        val env = pb.environment()
        val systemFallback = listOf("/system/bin", "/system/xbin", "/vendor/bin", "/system_ext/bin")
          .joinToString(File.pathSeparator)

        val binDir = resolved.binDir?.absolutePath
        if (!binDir.isNullOrBlank()) {
          val existingPath = env["PATH"]
          val basePath = if (existingPath.isNullOrBlank()) systemFallback else existingPath
          env["PATH"] = "${binDir}${File.pathSeparator}${basePath}"
        } else if (env["PATH"].isNullOrBlank()) {
          env["PATH"] = systemFallback
        }

        // When spawning prebuilt executables, the dynamic linker won't automatically search the
        // app's nativeLibraryDir for DT_NEEDED dependencies (e.g. libc++_shared.so). Make it
        // explicit.
        val nativeLibDir = reactContext.applicationInfo?.nativeLibraryDir
        if (!nativeLibDir.isNullOrBlank()) {
          val existingLd = env["LD_LIBRARY_PATH"]
          val parts = ArrayList<String>()
          val binDir = resolved.binDir?.absolutePath
          if (!binDir.isNullOrBlank()) parts.add(binDir)
          parts.add(nativeLibDir)
          if (!existingLd.isNullOrBlank()) {
            existingLd.split(File.pathSeparatorChar).filter { it.isNotBlank() }.forEach { parts.add(it) }
          }
          env["LD_LIBRARY_PATH"] = parts.distinct().joinToString(File.pathSeparator)
        }

        if (env["SHELL"].isNullOrBlank()) env["SHELL"] = "/system/bin/sh"
        if (env["TMPDIR"].isNullOrBlank()) env["TMPDIR"] = reactContext.cacheDir.absolutePath
      } catch (_: Throwable) {
        // ignore
      }

      // Preflight: check for "versioned" DT_NEEDED libs (e.g. libssl.so.3 / liblzma.so.5) which
      // Android system images typically do not provide. This helps surface missing runtime deps
      // earlier and (when possible) creates alias symlinks in our writable bin dir.
      try {
        val nativeLibDirPath = reactContext.applicationInfo?.nativeLibraryDir
        val nativeLibDir = if (!nativeLibDirPath.isNullOrBlank()) File(nativeLibDirPath) else null
        preflightLinkerDeps(execPath, resolved.binDir, nativeLibDir)
      } catch (e: Throwable) {
        throw IllegalStateException(
          "CodexRuntime 缺少依赖库，无法启动。\n" +
            "- runtimeId: $runtimeId\n" +
            "- source: ${resolved.source}\n" +
            "${e.message ?: ""}".trim(),
          e
        )
      }

      val proc = try {
        pb.start()
      } catch (e: Throwable) {
        val msg = e.message ?: ""
        if (msg.contains("error=13") || msg.contains("Permission denied", ignoreCase = true)) {
          val appData = reactContext.filesDir.absolutePath
          val nativeDir = reactContext.applicationInfo?.nativeLibraryDir ?: ""
          throw RuntimeException(
            "CodexRuntime 无法执行可执行文件（Permission denied）。\n" +
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
      val runtime = RuntimeProc(runtimeId, proc, stdin, alive, StringBuilder())
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
              appendStderrTail(runtime.stderrTail, line)
              emitLine(runtimeId, "stderr", line)
            }
          }
        } catch (e: Throwable) {
          val line = "stderr reader error: ${e.message}"
          appendStderrTail(runtime.stderrTail, line)
          emitLine(runtimeId, "stderr", line)
        }
      }

      ioExecutor.execute {
        var exitCode: Int? = null
        try {
          exitCode = proc.waitFor()
        } catch (_: Throwable) {
        } finally {
          alive.set(false)
          runtimes.remove(runtimeId)
          val tail = readStderrTail(runtime.stderrTail)
          recordRuntimeExit(runtimeId, exitCode, tail)
          val code = exitCode?.toString() ?: "unknown"
          emitLine(runtimeId, "stderr", "process exited (code=$code)")
        }
      }

      val exitedEarly = try {
        proc.waitFor(startupGraceMs, TimeUnit.MILLISECONDS)
      } catch (_: Throwable) {
        false
      }
      if (exitedEarly) {
        val exitCode = try {
          proc.exitValue()
        } catch (_: Throwable) {
          null
        }
        alive.set(false)
        runtimes.remove(runtimeId, runtime)
        try {
          stdin.close()
        } catch (_: Throwable) {
        }
        val tail = readStderrTail(runtime.stderrTail)
        recordRuntimeExit(runtimeId, exitCode, tail)
        throw IllegalStateException(
          buildStartupExitMessage(runtimeId, resolved.source, commandPreview, exitCode, tail)
        )
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
      val rt = runtimes[runtimeId]
      if (rt == null || !rt.alive.get()) {
        val last = runtimeExits[runtimeId]
        val lastSummary = if (last != null) "\n${formatRuntimeExit(last)}" else ""
        throw IllegalStateException("runtime not running: $runtimeId$lastSummary")
      }
      rt.stdin.write(line)
      rt.stdin.write("\n")
      rt.stdin.flush()
      promise.resolve(null)
    } catch (e: Throwable) {
      promise.reject("E_CODEX_RUNTIME_SEND", e.message, e)
    }
  }

  private fun tarString(buf: ByteArray, offset: Int, len: Int): String {
    var end = offset
    val max = offset + len
    while (end < max && buf[end].toInt() != 0) end++
    return String(buf, offset, end - offset, StandardCharsets.UTF_8)
  }

  private fun tarOctal(buf: ByteArray, offset: Int, len: Int): Long {
    val s = tarString(buf, offset, len).trim()
    if (s.isBlank()) return 0
    return try {
      s.toLong(8)
    } catch (_: Throwable) {
      0
    }
  }

  private fun readFully(input: java.io.InputStream, buf: ByteArray, len: Int): Int {
    var total = 0
    while (total < len) {
      val n = input.read(buf, total, len - total)
      if (n <= 0) break
      total += n
    }
    return total
  }

  private fun skipFully(input: java.io.InputStream, bytes: Long) {
    var remaining = bytes
    while (remaining > 0) {
      val skipped = try {
        input.skip(remaining)
      } catch (_: Throwable) {
        0
      }
      if (skipped > 0) {
        remaining -= skipped
        continue
      }
      val b = input.read()
      if (b == -1) break
      remaining -= 1
    }
  }

  @ReactMethod
  fun chmod(params: ReadableMap, promise: Promise) {
    try {
      val p0 = params.getString("path") ?: throw IllegalArgumentException("path is required")
      val p = uriToFilePath(p0)
      chmodExecutable(p)
      val f = File(p)
      f.setExecutable(true, false)
      f.setReadable(true, false)
      f.setWritable(true, true)
      promise.resolve(null)
    } catch (e: Throwable) {
      promise.reject("E_CHMOD", e.message, e)
    }
  }

  @ReactMethod
  fun extractTarGz(params: ReadableMap, promise: Promise) {
    try {
      val archive0 = params.getString("archivePath") ?: throw IllegalArgumentException("archivePath is required")
      val destDir0 = params.getString("destDir") ?: throw IllegalArgumentException("destDir is required")
      val archivePath = uriToFilePath(archive0)
      val destDirPath = uriToFilePath(destDir0)

      val destRoot = File(destDirPath).apply { mkdirs() }.canonicalFile
      val destRootPrefix = destRoot.absolutePath + File.separator

      val header = ByteArray(512)
      val buf = ByteArray(32 * 1024)

      FileInputStream(File(archivePath)).use { fis ->
        GZIPInputStream(BufferedInputStream(fis)).use { input ->
          while (true) {
            val n = readFully(input, header, 512)
            if (n == 0) break
            if (n < 512) throw IllegalStateException("invalid tar header: truncated")

            var allZero = true
            for (b in header) {
              if (b.toInt() != 0) {
                allZero = false
                break
              }
            }
            if (allZero) break

            val name = tarString(header, 0, 100).trim()
            val prefix = tarString(header, 345, 155).trim()
            val fullName = when {
              prefix.isNotBlank() && name.isNotBlank() -> "$prefix/$name"
              name.isNotBlank() -> name
              else -> ""
            }

            val size = tarOctal(header, 124, 12)
            val typeFlag = header[156].toInt().toChar()
            val normalized = fullName.replace('\\', '/')

            val padding = ((512 - (size % 512)) % 512)

            if (normalized.isBlank()) {
              skipFully(input, size + padding)
              continue
            }

            // Prevent path traversal.
            val out = File(destRoot, normalized).canonicalFile
            val outPath = out.absolutePath
            if (!(outPath == destRoot.absolutePath || outPath.startsWith(destRootPrefix))) {
              skipFully(input, size + padding)
              continue
            }

            val isDir = typeFlag == '5' || normalized.endsWith("/")
            if (isDir) {
              out.mkdirs()
              skipFully(input, size + padding)
              continue
            }

            // Regular file
            out.parentFile?.mkdirs()
            FileOutputStream(out).use { fos ->
              var remaining = size
              while (remaining > 0) {
                val toRead = kotlin.math.min(buf.size.toLong(), remaining).toInt()
                val r = input.read(buf, 0, toRead)
                if (r <= 0) throw IllegalStateException("invalid tar entry: truncated")
                fos.write(buf, 0, r)
                remaining -= r.toLong()
              }
            }
            skipFully(input, padding)
          }
        }
      }

      promise.resolve(null)
    } catch (e: Throwable) {
      promise.reject("E_TAR_GZ", e.message, e)
    }
  }
}
