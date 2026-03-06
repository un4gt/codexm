package com.codexm.nativemodules

import android.net.Uri
import android.system.Os
import java.io.File

internal object CodexRuntimeFs {
    fun chmodExecutable(path: String) {
        try {
            Os.chmod(path, 493)
        } catch (_: Throwable) {
        }
    }

    fun ensureRuntimeHelper(outDir: File, helperName: String, target: File): Boolean {
        val helper = File(outDir, helperName)
        if (ensureSymlink(helper, target)) {
            return true
        }
        return ensureExecWrapper(helper, target)
    }

    fun ensureSymlink(link: File, target: File): Boolean {
        return try {
            try {
                Os.lstat(link.absolutePath)
                link.delete()
            } catch (_: Throwable) {
            }
            Os.symlink(target.absolutePath, link.absolutePath)
            true
        } catch (_: Throwable) {
            try {
                Os.link(target.absolutePath, link.absolutePath)
                true
            } catch (_: Throwable) {
                false
            }
        }
    }

    fun uriToFilePath(uriOrPath: String): String {
        return try {
            val uri = Uri.parse(uriOrPath)
            if (uri.scheme == null) uriOrPath else (uri.path ?: uriOrPath)
        } catch (_: Throwable) {
            uriOrPath
        }
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
}
