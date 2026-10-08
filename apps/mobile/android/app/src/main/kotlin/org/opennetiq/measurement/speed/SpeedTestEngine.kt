package org.opennetiq.measurement.speed

import okhttp3.Call
import okhttp3.ConnectionPool
import okhttp3.Dns
import okhttp3.EventListener
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.RequestBody
import okio.BufferedSink
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.random.Random

/**
 * Multi-connection HTTP throughput engine, method `http-mc-1.0`
 * (MEASUREMENT-METHODOLOGY.md §5, issue #19). Plain JVM: no Android APIs, so
 * it runs in local unit tests against an in-process server.
 *
 * [run] blocks; call it from a worker thread. [cancel] is safe from any
 * thread at any time and makes [run] return [SpeedTestResult.CANCELLED]
 * promptly with every connection closed.
 */
class SpeedTestEngine(
    private val config: SpeedTestConfig,
    private val nanoTime: () -> Long = System::nanoTime,
    private val resolver: (String) -> List<InetAddress> = { InetAddress.getAllByName(it).toList() },
) {
    interface Listener {
        fun onPhase(phase: String) {}

        fun onProgress(phase: String, elapsedMs: Long, mbps: Double) {}
    }

    @Volatile
    private var cancelled = false
    private val calls: MutableSet<Call> = Collections.synchronizedSet(HashSet())
    private val connectTimesMs: MutableList<Double> = Collections.synchronizedList(ArrayList())
    private val stopLatch = CountDownLatch(1)

    fun cancel() {
        cancelled = true
        stopLatch.countDown()
        synchronized(calls) { calls.toList() }.forEach { it.cancel() }
    }

    fun run(listener: Listener = object : Listener {}): SpeedTestResult {
        listener.onPhase(PHASE_DNS)
        val dnsStart = nanoTime()
        val addresses = try {
            resolver(config.host)
        } catch (e: Exception) {
            return failed(null, "DNS: ${e.message ?: e.javaClass.simpleName}")
        }
        val dnsMs = (nanoTime() - dnsStart) / 1e6
        if (addresses.isEmpty()) return failed(dnsMs, "DNS: no address")
        if (cancelled) return cancelled(dnsMs)

        val client = buildClient(addresses)
        try {
            listener.onPhase(PHASE_DOWNLOAD)
            val download = measure(PHASE_DOWNLOAD, client, listener)
            if (cancelled) return cancelled(dnsMs)
            listener.onPhase(PHASE_UPLOAD)
            val upload = measure(PHASE_UPLOAD, client, listener)
            if (cancelled) return cancelled(dnsMs)
            val status = SpeedTestResult.statusOf(download.stats, upload.stats)
            val error = listOfNotNull(
                download.error?.let { "download: $it" },
                upload.error?.let { "upload: $it" },
            ).joinToString("; ").ifEmpty { null }
            return SpeedTestResult(
                status = status,
                serverHost = config.host,
                streams = config.streams,
                dnsMs = dnsMs,
                tcpConnectMs = median(connectTimesMs),
                download = download.stats,
                upload = upload.stats,
                error = if (status == SpeedTestResult.OK) null else error ?: "less than 1 MB transferred",
            )
        } finally {
            client.dispatcher.executorService.shutdownNow()
            client.connectionPool.evictAll()
        }
    }

    private class Direction(val stats: ThroughputStats?, val error: String?)

    /** Runs [config.streams] parallel transfers for [config.directionMs]. */
    private fun measure(phase: String, client: OkHttpClient, listener: Listener): Direction {
        val start = nanoTime()
        val sampler = ByteSampler(start)
        val deadline = start + config.directionMs * 1_000_000
        val firstError = AtomicReference<String?>(null)
        val workers = (0 until config.streams).map { stream ->
            Thread({ transferLoop(phase, client, sampler, deadline, stream, firstError) }, "onq-$phase-$stream")
                .apply { isDaemon = true; start() }
        }
        var next = start + config.sampleMs * 1_000_000
        while (!cancelled) {
            val now = nanoTime()
            if (now >= deadline) break
            val waitNs = minOf(next, deadline) - now
            if (waitNs > 0 && stopLatch.await(waitNs, TimeUnit.NANOSECONDS)) break
            val sampled = nanoTime()
            sampler.sample(minOf(sampled, deadline))
            listener.onProgress(phase, (sampled - start) / 1_000_000, ThroughputMath.recentMbps(sampler.intervals()))
            next += config.sampleMs * 1_000_000
            if (workers.none { it.isAlive }) break
        }
        stopCalls()
        workers.forEach { it.join(config.timeoutMs) }
        if (cancelled) return Direction(null, "cancelled")
        val rampUpNs = config.rampUpMs * 1_000_000
        val stats = ThroughputMath.summarize(sampler.intervals(), rampUpNs)
        return Direction(stats, if (stats == null) firstError.get() ?: "no data" else firstError.get())
    }

    private fun transferLoop(
        phase: String,
        client: OkHttpClient,
        sampler: ByteSampler,
        deadline: Long,
        stream: Int,
        firstError: AtomicReference<String?>,
    ) {
        var request = 0L
        while (!cancelled && nanoTime() < deadline) {
            val nonce = (stream.toLong() shl 32) or request++
            val call = client.newCall(
                if (phase == PHASE_DOWNLOAD) downloadRequest(nonce) else uploadRequest(nonce, sampler, deadline),
            )
            calls.add(call)
            try {
                call.execute().use { response ->
                    if (!response.isSuccessful) throw IOException("HTTP ${response.code}")
                    if (phase == PHASE_DOWNLOAD) {
                        val source = response.body.source()
                        val buffer = ByteArray(BUFFER_BYTES)
                        val input = source.inputStream()
                        while (!cancelled && nanoTime() < deadline) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            sampler.add(n.toLong())
                        }
                    }
                }
            } catch (e: IOException) {
                // Cancellation at the deadline is the normal end of a stream.
                if (!cancelled && nanoTime() < deadline) {
                    firstError.compareAndSet(null, e.message ?: e.javaClass.simpleName)
                    return
                }
            } finally {
                calls.remove(call)
            }
        }
    }

    private fun downloadRequest(nonce: Long): Request = Request.Builder()
        .url(config.downloadUrl(nonce))
        .header("Accept-Encoding", "identity")
        .header("Cache-Control", "no-cache")
        .get()
        .build()

    private fun uploadRequest(nonce: Long, sampler: ByteSampler, deadline: Long): Request = Request.Builder()
        .url(config.uploadUrl(nonce))
        .header("Cache-Control", "no-cache")
        .post(UploadBody(config.uploadChunkBytes.toLong(), sampler, deadline))
        .build()

    /** Incompressible payload; bytes are counted as they are handed to the socket. */
    private inner class UploadBody(
        private val length: Long,
        private val sampler: ByteSampler,
        private val deadline: Long,
    ) : RequestBody() {
        override fun contentType() = "application/octet-stream".toMediaType()

        override fun contentLength() = length

        override fun writeTo(sink: BufferedSink) {
            var remaining = length
            while (remaining > 0) {
                if (cancelled || nanoTime() >= deadline) throw IOException("stopped")
                val n = minOf(remaining, PAYLOAD.size.toLong()).toInt()
                sink.write(PAYLOAD, 0, n)
                sink.flush()
                sampler.add(n.toLong())
                remaining -= n
            }
        }
    }

    private fun stopCalls() {
        synchronized(calls) { calls.toList() }.forEach { it.cancel() }
    }

    private fun buildClient(addresses: List<InetAddress>): OkHttpClient = OkHttpClient.Builder()
        // One TCP connection per stream: HTTP/2 would multiplex onto one.
        .protocols(listOf(Protocol.HTTP_1_1))
        .connectionPool(ConnectionPool(config.streams, 1, TimeUnit.MINUTES))
        .dns(object : Dns {
            override fun lookup(hostname: String) = addresses
        })
        .connectTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
        .readTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
        .writeTimeout(config.timeoutMs, TimeUnit.MILLISECONDS)
        .retryOnConnectionFailure(false)
        .eventListenerFactory { ConnectTimer() }
        .build()

    /** TCP connect time: connectStart to TLS start (or connect end without TLS). */
    private inner class ConnectTimer : EventListener() {
        private var startNs = 0L
        private var recorded = false

        override fun connectStart(call: Call, inetSocketAddress: InetSocketAddress, proxy: Proxy) {
            startNs = nanoTime()
            recorded = false
        }

        override fun secureConnectStart(call: Call) = record()

        override fun connectEnd(call: Call, inetSocketAddress: InetSocketAddress, proxy: Proxy, protocol: Protocol?) =
            record()

        private fun record() {
            if (recorded || startNs == 0L) return
            recorded = true
            connectTimesMs.add((nanoTime() - startNs) / 1e6)
        }
    }

    private fun failed(dnsMs: Double?, error: String) = SpeedTestResult(
        status = SpeedTestResult.FAILED,
        serverHost = config.host,
        streams = config.streams,
        dnsMs = dnsMs,
        tcpConnectMs = null,
        download = null,
        upload = null,
        error = error,
    )

    private fun cancelled(dnsMs: Double?) = failed(dnsMs, "cancelled").copy(status = SpeedTestResult.CANCELLED)

    companion object {
        const val PHASE_DNS = "dns"
        const val PHASE_DOWNLOAD = "download"
        const val PHASE_UPLOAD = "upload"
        private const val BUFFER_BYTES = 64 * 1024
        private val PAYLOAD: ByteArray = Random(0x4F4E51).nextBytes(1024 * 1024)

        fun median(values: List<Double>): Double? {
            val sorted = synchronized(values) { values.sorted() }
            if (sorted.isEmpty()) return null
            val n = sorted.size
            return if (n % 2 == 1) sorted[n / 2] else (sorted[n / 2 - 1] + sorted[n / 2]) / 2
        }
    }
}
