package org.opennetiq.measurement.latency

import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.UnknownHostException
import java.util.Locale
import java.util.concurrent.TimeUnit

enum class LatencyProtocol(val wireValue: String) {
    ICMP("icmp"),
    TCP("tcp"),
    DNS("dns");

    companion object {
        fun fromWire(value: String): LatencyProtocol? =
            entries.firstOrNull { it.wireValue == value.lowercase(Locale.ROOT) }
    }
}

data class LatencyResult(
    val protocol: LatencyProtocol,
    val target: String,
    val rawRttsMs: List<Double?>,
    val statistics: LatencyStatistics,
) {
    val status: String
        get() = when {
            statistics.probesReceived == 0 -> "failed"
            statistics.probesReceived < statistics.probesSent -> "partial"
            else -> "ok"
        }
}

class LatencyEngine {
    fun measure(
        protocol: LatencyProtocol,
        target: String,
        port: Int = 443,
    ): LatencyResult {
        require(target.isNotBlank()) { "Target must not be empty" }
        require(port in 1..65535) { "Port must be between 1 and 65535" }
        val address = if (protocol == LatencyProtocol.DNS) null else
            try {
                InetAddress.getByName(target)
            } catch (_: UnknownHostException) {
                null
            }
        val rawRtts = mutableListOf<Double?>()

        repeat(PROBE_COUNT) { index ->
            val startedAt = System.nanoTime()
            val rtt = try {
                when (protocol) {
                    LatencyProtocol.ICMP -> address?.let { ping(it) }
                    LatencyProtocol.TCP -> address?.let { tcpConnect(it, port) }
                    LatencyProtocol.DNS -> dnsLookup(target)
                }
            } catch (_: Exception) {
                null
            }
            rawRtts.add(rtt)

            if (index < PROBE_COUNT - 1) {
                val remainingNanos = TimeUnit.MILLISECONDS.toNanos(PROBE_INTERVAL_MS) -
                    (System.nanoTime() - startedAt)
                if (remainingNanos > 0) {
                    TimeUnit.NANOSECONDS.sleep(remainingNanos)
                }
            }
        }

        return LatencyResult(protocol, target, rawRtts, LatencyStatistics.from(rawRtts))
    }

    private fun ping(address: InetAddress): Double? {
        val timeoutSeconds = (PROBE_TIMEOUT_MS + 999) / 1000
        val process = ProcessBuilder(
            "/system/bin/ping",
            "-n",
            "-c",
            "1",
            "-W",
            timeoutSeconds.toString(),
            "-s",
            "56",
            address.hostAddress,
        ).redirectErrorStream(true).start()

        try {
            if (!process.waitFor((PROBE_TIMEOUT_MS + 500).toLong(), TimeUnit.MILLISECONDS)) {
                process.destroyForcibly()
                return null
            }
            val output = process.inputStream.bufferedReader().use { it.readText() }
            if (process.exitValue() != 0) return null
            return PING_RTT.find(output)?.groupValues?.get(1)?.toDoubleOrNull()
        } finally {
            process.destroy()
        }
    }

    private fun tcpConnect(address: InetAddress, port: Int): Double? {
        Socket().use { socket ->
            val startedAt = System.nanoTime()
            socket.connect(InetSocketAddress(address, port), PROBE_TIMEOUT_MS)
            return (System.nanoTime() - startedAt) / 1_000_000.0
        }
    }

    private fun dnsLookup(host: String): Double? {
        val startedAt = System.nanoTime()
        InetAddress.getAllByName(host)
        return (System.nanoTime() - startedAt) / 1_000_000.0
    }

    companion object {
        const val PROBE_COUNT = 20
        const val PROBE_INTERVAL_MS = 200L
        const val PROBE_TIMEOUT_MS = 2_000
        private val PING_RTT = Regex("""time[=<]\s*([\d.]+)\s*ms""", RegexOption.IGNORE_CASE)
    }
}
