package org.opennetiq.measurement.latency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.OutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.ServerSocket

class LatencyEngineTest {
    private fun config(port: Int, protocols: List<String>, probes: Int = 5) = LatencyConfig(
        host = "127.0.0.1",
        port = port,
        protocols = protocols,
        probes = probes,
        intervalMs = 200,
        timeoutMs = 500,
        dnsServer = "127.0.0.1",
    )

    private class Recorder : LatencyEngine.Listener {
        val protocols = mutableListOf<String>()
        val probes = mutableListOf<Triple<String, Int, Double?>>()

        override fun onProtocol(protocol: String) {
            protocols.add(protocol)
        }

        override fun onProbe(protocol: String, seq: Int, rttMs: Double?) {
            probes.add(Triple(protocol, seq, rttMs))
        }
    }

    @Test
    fun tcpConnectRttAgainstAListeningPort() {
        ServerSocket(0, 50, InetAddress.getByName("127.0.0.1")).use { server ->
            val acceptor = Thread {
                try {
                    while (true) server.accept().close()
                } catch (_: Exception) {
                }
            }.apply { isDaemon = true; start() }
            val recorder = Recorder()
            val result = LatencyEngine(config(server.localPort, listOf("tcp"))).run(recorder).single()
            assertEquals("tcp", result.protocol)
            assertEquals("ok", result.status)
            assertEquals(5, result.stats.received)
            assertEquals(0.0, result.stats.packetLossPct!!, 0.0)
            assertTrue(result.stats.medianMs!! >= 0)
            assertEquals(listOf("tcp"), recorder.protocols)
            assertEquals((1..5).toList(), recorder.probes.map { it.second })
            acceptor.interrupt()
        }
    }

    @Test
    fun closedPortLosesEveryProbe() {
        val port = ServerSocket(0).use { it.localPort } // now closed
        val result = LatencyEngine(config(port, listOf("tcp"), probes = 3)).run().single()
        assertEquals("failed", result.status)
        assertEquals(100.0, result.stats.packetLossPct!!, 0.0)
        assertEquals("no reply", result.error)
    }

    @Test
    fun probesAreSpacedByTheInterval() {
        ServerSocket(0, 50, InetAddress.getByName("127.0.0.1")).use { server ->
            Thread {
                try {
                    while (true) server.accept().close()
                } catch (_: Exception) {
                }
            }.apply { isDaemon = true; start() }
            val started = System.nanoTime()
            LatencyEngine(config(server.localPort, listOf("tcp"), probes = 5)).run()
            val tookMs = (System.nanoTime() - started) / 1_000_000
            assertTrue("took $tookMs ms", tookMs in 750..2_000) // 4 gaps of 200 ms
        }
    }

    @Test
    fun dnsRttAgainstALocalResolver() {
        DatagramSocket(0, InetAddress.getByName("127.0.0.1")).use { resolver ->
            Thread {
                val buf = ByteArray(512)
                try {
                    var n = 0
                    while (true) {
                        val p = DatagramPacket(buf, buf.size)
                        resolver.receive(p)
                        n++
                        if (n == 2) continue // drop the 2nd query: one lost probe
                        val reply = buf.copyOf(p.length).also { it[2] = (it[2].toInt() or 0x80).toByte() }
                        resolver.send(DatagramPacket(reply, reply.size, p.socketAddress))
                    }
                } catch (_: Exception) {
                }
            }.apply { isDaemon = true; start() }
            val engine = LatencyEngine(
                config(443, listOf("dns"), probes = 4).copy(host = "speed.example.org"),
                dnsPort = resolver.localPort,
            )
            val result = engine.run().single()
            assertEquals("dns", result.protocol)
            assertEquals(listOf(true, false, true, true), result.rtts.map { it != null })
            assertEquals(25.0, result.stats.packetLossPct!!, 0.0)
            assertEquals("speed.example.org via 127.0.0.1", result.target)
        }
    }

    @Test
    fun dnsWithoutResolverOrForIpTargetFails() {
        val noResolver = LatencyEngine(config(443, listOf("dns")).copy(host = "h.example", dnsServer = null)).run()
        assertEquals("no DNS resolver available", noResolver.single().error)
        val ip = LatencyEngine(config(443, listOf("dns"))).run().single()
        assertEquals("failed", ip.status)
        assertEquals("target is an IP address", ip.error)
    }

    private class FakeProcess(text: String) : Process() {
        private val input = ByteArrayInputStream(text.toByteArray())
        var destroyed = false

        override fun getOutputStream(): OutputStream = OutputStream.nullOutputStream()

        override fun getInputStream(): InputStream = input

        override fun getErrorStream(): InputStream = InputStream.nullInputStream()

        override fun waitFor(): Int = 0

        override fun exitValue(): Int = 0

        override fun destroy() {
            destroyed = true
        }
    }

    @Test
    fun icmpUsesThePingBinaryOutput() {
        var command: List<String> = emptyList()
        val process = FakeProcess(
            "64 bytes from 127.0.0.1: icmp_seq=1 ttl=64 time=0.05 ms\n" +
                "64 bytes from 127.0.0.1: icmp_seq=3 ttl=64 time=0.07 ms\n",
        )
        val recorder = Recorder()
        val result = LatencyEngine(
            config(443, listOf("icmp"), probes = 3),
            processStarter = { command = it; process },
        ).run(recorder).single()
        assertEquals("/system/bin/ping", command.first())
        assertEquals(listOf(0.05, null, 0.07), result.rtts)
        assertEquals("ok", result.status)
        assertTrue(process.destroyed)
        assertEquals(listOf(1, 3), recorder.probes.map { it.second })
    }

    @Test
    fun icmpFailureKeepsTheReason() {
        val result = LatencyEngine(
            config(443, listOf("icmp"), probes = 2),
            processStarter = { FakeProcess("ping: unknown host nope\n") },
        ).run().single()
        assertEquals("failed", result.status)
        assertEquals("ping: unknown host nope", result.error)
        val missing = LatencyEngine(
            config(443, listOf("icmp")),
            processStarter = { throw java.io.IOException("no such file") },
        ).run().single()
        assertTrue(missing.error!!.startsWith("ping unavailable"))
    }

    @Test
    fun cancelReturnsNothingPromptly() {
        val port = ServerSocket(0).use { it.localPort }
        val engine = LatencyEngine(config(port, listOf("tcp", "dns"), probes = 50))
        Thread {
            Thread.sleep(300)
            engine.cancel()
        }.start()
        val started = System.nanoTime()
        val results = engine.run()
        assertTrue(results.isEmpty())
        assertTrue((System.nanoTime() - started) / 1_000_000 < 2_000)
        assertTrue(engine.isCancelled)
        assertNull(null)
    }
}
