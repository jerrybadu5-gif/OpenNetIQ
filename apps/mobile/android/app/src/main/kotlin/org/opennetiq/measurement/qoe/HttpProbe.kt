package org.opennetiq.measurement.qoe

import okhttp3.Call
import okhttp3.ConnectionPool
import okhttp3.EventListener
import okhttp3.Handshake
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.Response
import okio.BufferedSink
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/** Phase timings of one HTTP exchange (ms from call start), method `qoe-1.0`. */
data class HttpTiming(
    val dnsMs: Double? = null,
    val connectMs: Double? = null,
    val tlsMs: Double? = null,
    val ttfbMs: Double? = null,
    val totalMs: Double? = null,
    val httpStatus: Int? = null,
    val bytes: Long = 0,
    val error: String? = null,
) {
    val ok: Boolean get() = error == null && httpStatus != null && httpStatus in 200..399

    fun toMap(): Map<String, Any?> = mapOf(
        "dns_ms" to dnsMs,
        "connect_ms" to connectMs,
        "tls_ms" to tlsMs,
        "ttfb_ms" to ttfbMs,
        "total_ms" to totalMs,
        "http_status" to httpStatus,
        "bytes" to bytes,
        "error" to error,
    )
}

/** Records phase durations; every call gets a fresh listener. */
internal class TimingListener(private val clock: () -> Long) : EventListener() {
    var start = 0L
    var dns: Double? = null
    var connect: Double? = null
    var tls: Double? = null
    var ttfb: Double? = null
    private var dnsStart = 0L
    private var connectStart = 0L
    private var tlsStart = 0L

    private fun ms(from: Long) = (clock() - from) / 1e6

    override fun callStart(call: Call) { start = clock() }
    override fun dnsStart(call: Call, domainName: String) { dnsStart = clock() }
    override fun dnsEnd(call: Call, domainName: String, inetAddressList: List<InetAddress>) {
        dns = ms(dnsStart)
    }
    override fun connectStart(call: Call, inetSocketAddress: InetSocketAddress, proxy: Proxy) {
        connectStart = clock()
    }
    override fun secureConnectStart(call: Call) { tlsStart = clock() }
    override fun secureConnectEnd(call: Call, handshake: Handshake?) { tls = ms(tlsStart) }
    override fun connectEnd(
        call: Call,
        inetSocketAddress: InetSocketAddress,
        proxy: Proxy,
        protocol: Protocol?,
    ) {
        // TCP connect only: TLS is reported separately.
        connect = ms(connectStart) - (tls ?: 0.0)
    }
    override fun responseHeadersStart(call: Call) { if (ttfb == null) ttfb = ms(start) }
}

/**
 * Cold HTTP probes for app reachability and file transfer (issue #29).
 * No connection reuse or cache: every probe measures DNS, TCP and TLS as a
 * first visit would.
 */
class HttpProbe(
    private val clock: () -> Long = System::nanoTime,
    private val userAgent: String = "OpenNetIQ/qoe-1.0",
) {
    @Volatile private var current: Call? = null

    fun cancel() { current?.cancel() }

    private fun client(listener: TimingListener, timeoutMs: Long) = OkHttpClient.Builder()
        .connectionPool(ConnectionPool(0, 1, TimeUnit.SECONDS))
        .eventListener(listener)
        .callTimeout(timeoutMs, TimeUnit.MILLISECONDS)
        .followRedirects(true)
        .build()

    /** GET [url] and read the whole body. */
    fun get(url: String, timeoutMs: Long = 15_000): HttpTiming {
        val request = request(url) ?: return HttpTiming(error = "invalid URL")
        return exchange(request.build(), timeoutMs)
    }

    private fun request(url: String): Request.Builder? = try {
        Request.Builder().url(url).header("User-Agent", userAgent)
    } catch (e: IllegalArgumentException) {
        null
    }

    /** POST [bytes] of random data to [url] (upload sink). */
    fun post(url: String, bytes: Long, timeoutMs: Long = 60_000): HttpTiming {
        val body = object : RequestBody() {
            override fun contentType() = "application/octet-stream".toMediaType()
            override fun contentLength() = bytes
            override fun writeTo(sink: BufferedSink) {
                val chunk = Random.nextBytes(64 * 1024)
                var left = bytes
                while (left > 0) {
                    val n = minOf(left, chunk.size.toLong()).toInt()
                    sink.write(chunk, 0, n)
                    left -= n
                }
            }
        }
        val request = request(url) ?: return HttpTiming(error = "invalid URL")
        return exchange(request.post(body).build(), timeoutMs, uploaded = bytes)
    }

    private fun exchange(request: Request, timeoutMs: Long, uploaded: Long = 0): HttpTiming {
        val listener = TimingListener(clock)
        val call = client(listener, timeoutMs).newCall(request)
        current = call
        return try {
            call.execute().use { response -> read(response, listener, uploaded) }
        } catch (e: IOException) {
            HttpTiming(
                dnsMs = listener.dns,
                connectMs = listener.connect,
                tlsMs = listener.tls,
                ttfbMs = listener.ttfb,
                totalMs = if (listener.start == 0L) null else (clock() - listener.start) / 1e6,
                error = if (call.isCanceled()) "cancelled" else (e.message ?: e.javaClass.simpleName),
            )
        } finally {
            current = null
        }
    }

    private fun read(response: Response, listener: TimingListener, uploaded: Long): HttpTiming {
        var bytes = 0L
        val source = response.body.source()
        val buffer = okio.Buffer()
        while (true) {
            val n = source.read(buffer, 64 * 1024)
            if (n == -1L) break
            bytes += n
            buffer.clear()
        }
        return HttpTiming(
            dnsMs = listener.dns,
            connectMs = listener.connect,
            tlsMs = listener.tls,
            ttfbMs = listener.ttfb,
            totalMs = (clock() - listener.start) / 1e6,
            httpStatus = response.code,
            bytes = if (uploaded > 0) uploaded else bytes,
            error = if (response.code >= 400) "HTTP ${response.code}" else null,
        )
    }

    companion object {
        /** Effective rate in Mbit/s (SI). */
        fun mbps(bytes: Long, ms: Double?): Double? =
            if (ms == null || ms <= 0 || bytes <= 0) null else bytes * 8.0 / (ms * 1000.0)
    }
}
