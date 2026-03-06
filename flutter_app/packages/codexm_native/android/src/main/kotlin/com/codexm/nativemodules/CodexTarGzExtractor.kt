package com.codexm.nativemodules

import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.GZIPInputStream

internal object CodexTarGzExtractor {
    fun extract(archivePath: String, destDir: String) {
        val destRoot = File(destDir).apply { mkdirs() }.canonicalFile
        val destRootPrefix = destRoot.absolutePath + File.separator
        val header = ByteArray(512)
        val buffer = ByteArray(32 * 1024)

        FileInputStream(File(archivePath)).use { fileInput ->
            GZIPInputStream(BufferedInputStream(fileInput)).use { input ->
                while (true) {
                    val read = readFully(input, header, 512)
                    if (read == 0) {
                        break
                    }
                    if (read < 512) {
                        throw IllegalStateException("invalid tar header: truncated")
                    }
                    if (header.all { value -> value.toInt() == 0 }) {
                        break
                    }

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
                    val padding = (512 - (size % 512)) % 512

                    if (normalized.isBlank()) {
                        skipFully(input, size + padding)
                        continue
                    }

                    val outputFile = File(destRoot, normalized).canonicalFile
                    val outputPath = outputFile.absolutePath
                    if (
                        outputPath != destRoot.absolutePath &&
                        !outputPath.startsWith(destRootPrefix)
                    ) {
                        skipFully(input, size + padding)
                        continue
                    }

                    val isDirectory = typeFlag == '5' || normalized.endsWith("/")
                    if (isDirectory) {
                        outputFile.mkdirs()
                        skipFully(input, size + padding)
                        continue
                    }

                    outputFile.parentFile?.mkdirs()
                    FileOutputStream(outputFile).use { output ->
                        var remaining = size
                        while (remaining > 0) {
                            val nextRead = kotlin.math.min(buffer.size.toLong(), remaining).toInt()
                            val chunk = input.read(buffer, 0, nextRead)
                            if (chunk <= 0) {
                                throw IllegalStateException("invalid tar entry: truncated")
                            }
                            output.write(buffer, 0, chunk)
                            remaining -= chunk.toLong()
                        }
                    }
                    skipFully(input, padding)
                }
            }
        }
    }

    private fun tarString(buffer: ByteArray, offset: Int, length: Int): String {
        var end = offset
        val max = offset + length
        while (end < max && buffer[end].toInt() != 0) {
            end++
        }
        return String(buffer, offset, end - offset, StandardCharsets.UTF_8)
    }

    private fun tarOctal(buffer: ByteArray, offset: Int, length: Int): Long {
        val value = tarString(buffer, offset, length).trim()
        if (value.isBlank()) {
            return 0
        }
        return try {
            value.toLong(8)
        } catch (_: Throwable) {
            0
        }
    }

    private fun readFully(input: java.io.InputStream, buffer: ByteArray, length: Int): Int {
        var total = 0
        while (total < length) {
            val read = input.read(buffer, total, length - total)
            if (read <= 0) {
                break
            }
            total += read
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
            if (input.read() == -1) {
                break
            }
            remaining -= 1
        }
    }
}
