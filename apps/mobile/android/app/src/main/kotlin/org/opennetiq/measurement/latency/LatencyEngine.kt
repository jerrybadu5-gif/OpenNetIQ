package org.opennetiq.measurement.latency

import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/**
 * Latency engine, method `lat-1.0` (MEASUREMENT-METHODOLOGY.md §6, issue #21).
 * ICMP via the system `ping` binary (no root), TCP connect RTT, DNS query RTT
 * to the device resolver. Plain JVM: tested locally against in-process
 * servers. [run] blocks; [cancel] is safe from any thread.
 */
class LatencyEngine(
    private val config: LatencyConfig,
    private val nanoTime: () -> Long = System::nanoTime,
    private val resolver: (String) -> InetAddress = { InetAddress.getByName(it) },
    private val processStarter: (List<String>) -> Process = { ProcessBuilder(it).redirectErrorStream(true).start() },
    private val pingBinary: String = DEFAULT_PING,
    private val dnsPort: Int = DNS_PORT,
) {
    interface Listener {
        fun onProtocol(protocol: String) {}

        fun onProbe(protocol: String, seq: Int, rttMs: Double?) {}
    }

    @Volatile
    private var cancelled = false

    @Volatile
    private var process: Process? = null
    private val stop = CountDownLatch(1)

    val isCancelled: Boolean
        get() = cancelled

    fun cancel() {
        cancelled = true
        stop.countDown()
        process?.destroy()
    }

    /** One result per configured protocol, in order; empty when cancelled. */
    fun run(listener: Listener = object : Listener {}): List<LatencyResult> {
        val results = ArrayList<LatencyResult>()
        for (protocol in config.protocols) {
            if (cancelled) return emptyList()
            listener.onProtocol(protocol)
            val result = when (protocol) {
                LatencyConfig.ICMP -> icmp(listener)
                LatencyConfig.TCP -> tcp(listener)
                else -> dns(listener)
            }
            if (cancelled) return emptyList()
            results.add(result)
        }
        return results
    }

    private fun icmp(listener: Listener): LatencyResult {
        val lines = ArrayList<String>()
        val p = try {
            processStarter(PingOutput.command(pingBinary, config))
        } catch (e: IOException) {
            return failed(LatencyConfig.ICMP, "ping unavailable: ${e.message}")
        }
        process = p
        try {
            p.inputStream.bufferedReader().useLines { seq ->
                for (line in seq) {
                    if (cancelled) break
                    lines.add(line)
                    val parsed = PingOutput.parse(listOf(line), config.probes)
                    parsed.withIndex().firstOrNull { it.value != null }?.let {
                        listener.onProbe(LatencyConfig.ICMP, it.index + 1, it.value)
                    }
                }
            }
            p.waitFor(config.timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: IOException) {
            if (!cancelled) return failed(LatencyConfig.ICMP, "ping: ${e.message}")
        } finally {
            p.destroy()
            process = null
        }
        val rtts = PingOutput.parse(lines, config.probes)
        val error = if (rtts.all { it == null }) {
            lines.lastOrNull { it.isNotBlank() }?.take(200) ?: "no reply"
        } else {
            null
        }
        return LatencyResult(LatencyConfig.ICMP, config.host, rtts, config.probes, error)
    }

    private fun tcp(listener: Listener): LatencyResult {
        val address = try {
            resolver(config.host)
        } catch (e: IOException) {
            return failed(LatencyConfig.TCP, "DNS: ${e.message}")
        }
        val target = InetSocketAddress(address, config.port)
        return probeLoop(LatencyConfig.TCP, listener) {
            Socket().use { socket ->
                socket.tcpNoDelay = true
                val start = nanoTime()
                socket.connect(target, config.timeoutMs.toInt())
                (nanoTime() - start) / 1e6
            }
        }
    }

    private fun dns(listener: Listener): LatencyResult {
        val server = config.dnsServer ?: return failed(LatencyConfig.DNS, "no DNS resolver available")
        if (IP_LITERAL.matches(config.host)) return failed(LatencyConfig.DNS, "target is an IP address")
        val resolverAddress = try {
            InetAddress.getByName(server)
        } catch (e: IOException) {
            return failed(LatencyConfig.DNS, "resolver: ${e.message}")
        }
        DatagramSocket().use { socket ->
            socket.connect(InetSocketAddress(resolverAddress, dnsPort))
            val buffer = ByteArray(1_500)
            return probeLoop(LatencyConfig.DNS, listener, target = "${config.host} via $server") {
                val id = Random.nextInt(0, 0x10000)
                val query = DnsQuery.build(id, config.host)
                val start = nanoTime()
                socket.send(DatagramPacket(query, query.size))
                val deadline = start + config.timeoutMs * 1_000_000
                while (true) {
                    val remainingMs = (deadline - nanoTime()) / 1_000_000
                    if (remainingMs <= 0) throw SocketTimeoutException()
                    socket.soTimeout = remainingMs.toInt().coerceAtLeast(1)
                    val packet = DatagramPacket(buffer, buffer.size)
                    socket.receive(packet)
                    if (DnsQuery.isResponseTo(buffer, packet.length, id)) break
                }
                (nanoTime() - start) / 1e6
            }
        }
    }

    /** Sends [config.probes] probes [config.intervalMs] apart; a failed probe is lost. */
    private fun probeLoop(
        protocol: String,
        listener: Listener,
        target: String = "${config.host}:${config.port}",
        probe: () -> Double,
    ): LatencyResult {
        val rtts = ArrayList<Double?>()
        var next = nanoTime()
        for (seq in 1..config.probes) {
            val wait = next - nanoTime()
            if (wait > 0 && stop.await(wait, TimeUnit.NANOSECONDS)) break
            if (cancelled) break
            next += config.intervalMs * 1_000_000
            val rtt = try {
                probe()
            } catch (e: IOException) {
                null
            }
            rtts.add(rtt)
            listener.onProbe(protocol, seq, rtt)
        }
        return LatencyResult(protocol, target, rtts, config.probes, if (rtts.all { it == null }) "no reply" else null)
    }

    private fun failed(protocol: String, error: String) =
        LatencyResult(protocol, config.host, emptyList(), config.probes, error)

    companion object {
        const val DEFAULT_PING = "/system/bin/ping"
        private const val DNS_PORT = 53
        private val IP_LITERAL = Regex("^[0-9.]+$|^\\[?[0-9a-fA-F:]+]?$")
    }
}
