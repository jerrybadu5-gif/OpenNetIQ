package org.opennetiq.measurement.qoe

import org.apache.commons.net.ftp.FTP
import org.apache.commons.net.ftp.FTPClient
import org.apache.commons.net.ftp.FTPReply
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.URI
import java.time.Duration
import kotlin.random.Random

/**
 * FTP throughput test (spec v3 M14, NICTA QoS Rule 2022 Schedule 2 G8,
 * methodology §6b). One passive-mode binary transfer per call against the
 * OpenNetIQ FTP server (`/download/{N}MB.bin`, `/upload/`).
 *
 * Mean data rate = bytes × 8 / transfer time, where transfer time runs from
 * the RETR/STOR command to the server's completion reply (the whole data
 * connection). Blocking: run off the main thread.
 */
class FtpProbe(
    private val clock: () -> Long = System::nanoTime,
    private val newClient: () -> FTPClient = ::FTPClient,
) {
    @Volatile private var client: FTPClient? = null
    @Volatile private var cancelled = false

    data class Target(val host: String, val port: Int, val basePath: String)

    fun cancel() {
        cancelled = true
        client?.let { c -> runCatching { c.abort() }; runCatching { c.disconnect() } }
    }

    /**
     * @param maxMs the transfer is cut off after this time (failed, with the
     *   bytes and rate so far)
     */
    fun run(
        url: String,
        user: String,
        password: String,
        upload: Boolean,
        sizeMib: Int,
        maxMs: Long,
    ): Map<String, Any?> {
        cancelled = false
        val base = mapOf<String, Any?>(
            "protocol" to "ftp",
            "direction" to if (upload) "upload" else "download",
        )
        val target = parse(url) ?: return base + ("error" to "Invalid FTP URL")
        if (sizeMib !in SIZES_MIB) return base + ("error" to "Size must be one of $SIZES_MIB MB")
        val c = newClient()
        client = c
        c.connectTimeout = CONNECT_TIMEOUT_MS
        c.defaultTimeout = CONNECT_TIMEOUT_MS
        c.setDataTimeout(Duration.ofMillis(DATA_TIMEOUT_MS))
        c.bufferSize = BUFFER
        val t0 = clock()
        var dnsMs: Double? = null
        var connectMs: Double? = null
        try {
            val address = InetAddress.getByName(target.host)
            dnsMs = ms(t0)
            val tc = clock()
            c.connect(address, target.port)
            connectMs = ms(tc)
            if (!FTPReply.isPositiveCompletion(c.replyCode)) return fail(c, base, dnsMs, connectMs, "Server refused connection")
            if (!c.login(user, password)) return fail(c, base, dnsMs, connectMs, "Login failed")
            c.enterLocalPassiveMode()
            if (!c.setFileType(FTP.BINARY_FILE_TYPE)) return fail(c, base, dnsMs, connectMs, "Binary mode refused")
            val expected = sizeMib * MIB
            val r = if (upload) {
                val name = "${target.basePath}upload/onq-${System.nanoTime()}-${Random.nextInt(1_000_000)}.bin"
                val out = c.storeFileStream(name) ?: return fail(c, base, dnsMs, connectMs, reply(c, "Upload refused"))
                transfer(c, maxMs, expected) { tStart -> write(out, expected, maxMs, tStart) }
                    .also { runCatching { c.deleteFile(name) } }
            } else {
                val path = "${target.basePath}download/${sizeMib}MB.bin"
                val input = c.retrieveFileStream(path) ?: return fail(c, base, dnsMs, connectMs, reply(c, "Download refused"))
                transfer(c, maxMs, expected) { tStart -> read(input, maxMs, tStart) }
            }
            return base + mapOf(
                "dns_ms" to dnsMs,
                "connect_ms" to connectMs,
                "ttfb_ms" to r.firstByteMs,
                "total_ms" to r.totalMs,
                "bytes" to r.bytes,
                "rate_mbps" to if (r.totalMs > 0 && r.bytes > 0) mbps(r.bytes, r.totalMs) else null,
                "error" to r.error,
            )
        } catch (e: IOException) {
            return base + mapOf(
                "dns_ms" to dnsMs,
                "connect_ms" to connectMs,
                "error" to if (cancelled) "cancelled" else (e.message ?: e.javaClass.simpleName),
            )
        } finally {
            runCatching { if (c.isConnected) { c.logout(); c.disconnect() } }
            client = null
        }
    }

    private data class Transfer(val bytes: Long, val totalMs: Double, val firstByteMs: Double?, val error: String?)

    private class Moved(val bytes: Long, val firstByteAt: Long?, val cutOff: Boolean)

    /** Runs [move] on the data connection and waits for the completion reply. */
    private fun transfer(c: FTPClient, maxMs: Long, expected: Long, move: (Long) -> Moved): Transfer {
        val tStart = clock()
        val moved = try {
            move(tStart)
        } catch (e: IOException) {
            val error = if (cancelled) "cancelled" else "Transfer interrupted: ${e.message ?: e.javaClass.simpleName}"
            return Transfer(0, ms(tStart), null, error)
        }
        if (moved.cutOff || cancelled) {
            runCatching { c.abort() }
            val error = if (cancelled) "cancelled" else "Cut off after ${maxMs / 1000} s"
            return Transfer(moved.bytes, ms(tStart), moved.firstByteAt?.let { (it - tStart) / 1e6 }, error)
        }
        val completed = c.completePendingCommand()
        val total = ms(tStart)
        val firstByte = moved.firstByteAt?.let { (it - tStart) / 1e6 }
        val error = when {
            !completed -> reply(c, "Transfer not confirmed")
            moved.bytes != expected -> "Incomplete: ${moved.bytes} of $expected bytes"
            else -> null
        }
        return Transfer(moved.bytes, total, firstByte, error)
    }

    private fun read(input: InputStream, maxMs: Long, tStart: Long): Moved {
        val buf = ByteArray(BUFFER)
        var bytes = 0L
        var first: Long? = null
        input.use {
            while (true) {
                if (cancelled || clock() - tStart > maxMs * 1_000_000) return Moved(bytes, first, cutOff = true)
                val n = it.read(buf)
                if (n < 0) break
                if (first == null && n > 0) first = clock()
                bytes += n
            }
        }
        return Moved(bytes, first, cutOff = false)
    }

    private fun write(out: OutputStream, size: Long, maxMs: Long, tStart: Long): Moved {
        val block = Random.nextBytes(BUFFER) // incompressible
        var bytes = 0L
        out.use {
            while (bytes < size) {
                if (cancelled || clock() - tStart > maxMs * 1_000_000) return Moved(bytes, tStart, cutOff = true)
                val n = minOf(BUFFER.toLong(), size - bytes).toInt()
                it.write(block, 0, n)
                bytes += n
            }
        }
        return Moved(bytes, tStart, cutOff = false)
    }

    private fun fail(c: FTPClient, base: Map<String, Any?>, dns: Double?, connect: Double?, error: String) =
        base + mapOf("dns_ms" to dns, "connect_ms" to connect, "error" to error).also { runCatching { c.disconnect() } }

    private fun reply(c: FTPClient, prefix: String): String {
        val text = c.replyString?.trim()?.takeIf { it.isNotEmpty() }
        return if (text == null) prefix else "$prefix (${text.take(120)})"
    }

    private fun ms(from: Long) = (clock() - from) / 1e6

    companion object {
        /** Files served by infra/test-server/ftp. */
        val SIZES_MIB = listOf(5, 10, 20, 50, 100)
        const val MIB = 1024L * 1024L
        private const val BUFFER = 256 * 1024
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val DATA_TIMEOUT_MS = 30_000L

        fun mbps(bytes: Long, ms: Double): Double = bytes * 8 / (ms / 1000) / 1e6

        /** `ftp://host[:port][/base/]`; base path always ends with `/`. */
        fun parse(url: String): Target? = try {
            val u = URI(url.trim())
            if (u.scheme?.lowercase() != "ftp" || u.host.isNullOrBlank() || u.userInfo != null) {
                null
            } else {
                val path = (u.path ?: "").let { if (it.endsWith("/")) it else "$it/" }
                Target(u.host, if (u.port == -1) 21 else u.port, if (path.startsWith("/")) path else "/$path")
            }
        } catch (e: IllegalArgumentException) {
            null
        } catch (e: java.net.URISyntaxException) {
            null
        }
    }
}
