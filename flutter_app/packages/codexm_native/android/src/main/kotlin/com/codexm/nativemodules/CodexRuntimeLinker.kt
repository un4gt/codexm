package com.codexm.nativemodules

import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal object CodexRuntimeLinker {
    fun preflight(execPath: String, binDir: File?, nativeLibDir: File?) {
        if (binDir == null || nativeLibDir == null || !nativeLibDir.exists()) {
            return
        }

        val needed = listNeededSharedLibraries(File(execPath))
        if (needed.isEmpty()) {
            return
        }

        val searchDirs = listOf(binDir, nativeLibDir)
        val missing = ArrayList<String>()
        for (name in needed) {
            if (!shouldPreflightNeededLib(name)) {
                continue
            }
            if (findLibraryFile(name, searchDirs) != null) {
                continue
            }

            if (isVersionedSoName(name)) {
                val base = bundledSoNameForVersionedNeeded(name)
                if (!base.isNullOrBlank()) {
                    val baseFile = File(nativeLibDir, base)
                    if (baseFile.exists()) {
                        val link = File(binDir, name)
                        val linked = CodexRuntimeFs.ensureSymlink(link, baseFile)
                        if (!linked) {
                            try {
                                link.delete()
                            } catch (_: Throwable) {
                            }
                            try {
                                baseFile.copyTo(link, overwrite = true)
                                CodexRuntimeFs.chmodExecutable(link.absolutePath)
                                link.setReadable(true, false)
                                link.setWritable(true, true)
                            } catch (_: Throwable) {
                            }
                        }
                    }
                }
            }

            if (findLibraryFile(name, searchDirs) == null) {
                missing.add(name)
            }
        }

        if (missing.isNotEmpty()) {
            throw IllegalStateException(
                "缺少共享库依赖（动态链接器无法解析）。\n" +
                    "- execPath: $execPath\n" +
                    "- missing: ${missing.joinToString(", ")}\n" +
                    "- searched: ${binDir.absolutePath}, ${nativeLibDir.absolutePath}\n",
            )
        }
    }

    private data class ElfSegment(
        val type: Long,
        val offset: Long,
        val vaddr: Long,
        val filesz: Long,
        val memsz: Long,
    )

    private fun isVersionedSoName(name: String): Boolean {
        val markerIndex = name.indexOf(".so.")
        if (markerIndex < 0) {
            return false
        }
        val versionIndex = markerIndex + 4
        if (versionIndex >= name.length) {
            return false
        }
        return name[versionIndex] in '0'..'9'
    }

    private fun baseSoNameForVersioned(name: String): String? {
        val markerIndex = name.indexOf(".so.")
        return if (markerIndex < 0) null else name.substring(0, markerIndex + 3)
    }

    private fun bundledSoNameForVersionedNeeded(neededName: String): String? {
        if (neededName.startsWith("liblzma.so.")) {
            return "libcodex_lzma.so"
        }
        if (neededName.startsWith("libz.so.")) {
            return "libcodex_z.so"
        }
        return baseSoNameForVersioned(neededName)
    }

    private fun shouldPreflightNeededLib(name: String): Boolean {
        return name == "libc++_shared.so" || isVersionedSoName(name)
    }

    private fun listNeededSharedLibraries(execFile: File): List<String> {
        if (!execFile.exists() || !execFile.isFile) {
            return emptyList()
        }
        return try {
            FileInputStream(execFile).use { input ->
                val channel = input.channel
                val header = ByteBuffer.allocate(64).order(ByteOrder.LITTLE_ENDIAN)
                val headerBytes = readFully(channel, header, 0L)
                if (headerBytes < 52) {
                    return emptyList()
                }
                header.flip()
                if (!isElfHeader(header)) {
                    return emptyList()
                }

                val eiClass = header.get(4).toInt() and 0xff
                val eiData = header.get(5).toInt() and 0xff
                if (eiData != 1) {
                    return emptyList()
                }

                val is64Bit = eiClass == 2
                val phoff: Long
                val phentsize: Int
                val phnum: Int
                when (eiClass) {
                    2 -> {
                        phoff = header.getLong(32)
                        phentsize = u16(header.getShort(54))
                        phnum = u16(header.getShort(56))
                    }

                    1 -> {
                        phoff = u32(header.getInt(28))
                        phentsize = u16(header.getShort(42))
                        phnum = u16(header.getShort(44))
                    }

                    else -> return emptyList()
                }
                if (phoff <= 0 || phentsize <= 0 || phnum <= 0) {
                    return emptyList()
                }

                val segments = readSegments(channel, phoff, phentsize, phnum, is64Bit)
                val dynamicSegment = segments.firstOrNull { segment -> segment.type == 2L }
                    ?: return emptyList()
                val loadSegments = segments.filter { segment -> segment.type == 1L }
                if (dynamicSegment.filesz <= 0) {
                    return emptyList()
                }

                val dynEntrySize = if (is64Bit) 16 else 8
                val dynSize = kotlin.math.min(dynamicSegment.filesz.toInt(), 1024 * 1024)
                if (dynSize < dynEntrySize) {
                    return emptyList()
                }

                val dynBuffer = ByteBuffer.allocate(dynSize).order(ByteOrder.LITTLE_ENDIAN)
                val dynamicBytes = readFully(channel, dynBuffer, dynamicSegment.offset)
                if (dynamicBytes < dynEntrySize) {
                    return emptyList()
                }
                dynBuffer.flip()

                var stringTableAddress: Long? = null
                var stringTableSize = 0L
                val neededOffsets = ArrayList<Long>()
                var index = 0
                while (index + dynEntrySize <= dynBuffer.limit()) {
                    val tag: Long
                    val value: Long
                    if (is64Bit) {
                        tag = dynBuffer.getLong(index)
                        value = dynBuffer.getLong(index + 8)
                    } else {
                        tag = u32(dynBuffer.getInt(index))
                        value = u32(dynBuffer.getInt(index + 4))
                    }
                    if (tag == 0L) {
                        break
                    }
                    when (tag) {
                        1L -> neededOffsets.add(value)
                        5L -> stringTableAddress = value
                        10L -> stringTableSize = value
                    }
                    index += dynEntrySize
                }

                val strVa = stringTableAddress ?: return emptyList()
                if (neededOffsets.isEmpty() || stringTableSize <= 0) {
                    return emptyList()
                }
                val strSegment = loadSegments.firstOrNull { segment ->
                    strVa >= segment.vaddr && strVa < (segment.vaddr + segment.memsz)
                } ?: return emptyList()

                val stringOffset = strSegment.offset + (strVa - strSegment.vaddr)
                val stringReadSize = kotlin.math.min(stringTableSize, 8 * 1024 * 1024L).toInt()
                if (stringReadSize <= 0) {
                    return emptyList()
                }

                val stringBuffer = ByteBuffer.allocate(stringReadSize)
                val stringBytesRead = readFully(channel, stringBuffer, stringOffset)
                if (stringBytesRead <= 0) {
                    return emptyList()
                }
                val stringBytes = stringBuffer.array()

                fun readCString(offset: Int): String? {
                    if (offset < 0 || offset >= stringBytesRead) {
                        return null
                    }
                    var end = offset
                    while (end < stringBytesRead && stringBytes[end].toInt() != 0) {
                        end++
                    }
                    if (end <= offset) {
                        return null
                    }
                    return try {
                        String(stringBytes, offset, end - offset, Charsets.UTF_8)
                    } catch (_: Throwable) {
                        null
                    }
                }

                val output = LinkedHashSet<String>()
                neededOffsets.forEach { offset ->
                    readCString(offset.toInt())?.let(output::add)
                }
                output.toList()
            }
        } catch (_: Throwable) {
            emptyList()
        }
    }

    private fun readSegments(
        channel: java.nio.channels.FileChannel,
        phoff: Long,
        phentsize: Int,
        phnum: Int,
        is64Bit: Boolean,
    ): List<ElfSegment> {
        val segments = ArrayList<ElfSegment>(phnum)
        val buffer = ByteBuffer.allocate(phentsize).order(ByteOrder.LITTLE_ENDIAN)
        for (index in 0 until phnum) {
            buffer.clear()
            val pos = phoff + (index.toLong() * phentsize.toLong())
            val read = readFully(channel, buffer, pos)
            if (read < phentsize) {
                break
            }
            buffer.flip()
            val segment = if (is64Bit) {
                ElfSegment(
                    type = u32(buffer.getInt(0)),
                    offset = buffer.getLong(8),
                    vaddr = buffer.getLong(16),
                    filesz = buffer.getLong(32),
                    memsz = buffer.getLong(40),
                )
            } else {
                ElfSegment(
                    type = u32(buffer.getInt(0)),
                    offset = u32(buffer.getInt(4)),
                    vaddr = u32(buffer.getInt(8)),
                    filesz = u32(buffer.getInt(16)),
                    memsz = u32(buffer.getInt(20)),
                )
            }
            segments.add(segment)
        }
        return segments
    }

    private fun isElfHeader(header: ByteBuffer): Boolean {
        return header.get(0).toInt() == 0x7f &&
            header.get(1).toInt() == 'E'.code &&
            header.get(2).toInt() == 'L'.code &&
            header.get(3).toInt() == 'F'.code
    }

    private fun findLibraryFile(name: String, dirs: List<File>): File? {
        dirs.forEach { dir ->
            val file = File(dir, name)
            if (file.exists()) {
                return file
            }
        }
        return null
    }

    private fun readFully(
        channel: java.nio.channels.FileChannel,
        buffer: ByteBuffer,
        pos: Long,
    ): Int {
        var total = 0
        while (buffer.hasRemaining()) {
            val read = channel.read(buffer, pos + total)
            if (read <= 0) {
                break
            }
            total += read
        }
        return total
    }

    private fun u16(value: Short): Int = value.toInt() and 0xffff

    private fun u32(value: Int): Long = value.toLong() and 0xffffffffL
}
