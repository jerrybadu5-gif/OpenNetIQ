package org.opennetiq.measurement.latency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class PingAndDnsTest {
    private val output = """
        PING speed.example.org (203.0.113.5) 56(84) bytes of data.
        64 bytes from 203.0.113.5: icmp_seq=1 ttl=55 time=23.4 ms
        64 bytes from 203.0.113.5: icmp_seq=3 ttl=55 time=25.1 ms
        64 bytes from 203.0.113.5: icmp_seq=2 ttl=55 time=40.0 ms
        64 bytes from 203.0.113.5: icmp_seq=3 ttl=55 time=99 ms (DUP!)
        64 bytes from 203.0.113.5: icmp_req=5 ttl=55 time<1 ms

        --- speed.example.org ping statistics ---
        5 packets transmitted, 4 received, 20% packet loss, time 804ms
    """.trimIndent().lines()

    @Test
    fun parsesBySequenceWithLossReorderingAndDuplicates() {
        assertEquals(listOf(23.4, 40.0, 25.1, null, 1.0), PingOutput.parse(output, 5))
    }

    @Test
    fun ignoresOutOfRangeSequences() {
        assertEquals(listOf(23.4), PingOutput.parse(output, 1))
    }

    @Test
    fun buildsAnUnprivilegedPingCommand() {
        val cmd = PingOutput.command("/system/bin/ping", LatencyConfig(host = "speed.example.org"))
        assertEquals(
            listOf("/system/bin/ping", "-n", "-c", "20", "-i", "0.2", "-s", "56", "-W", "2", "-w", "7", "speed.example.org"),
            cmd,
        )
    }

    @Test
    fun configValidatesHostAndLimits() {
        for (bad in listOf("", "a b", "host;rm -rf", "http://h/", "\$(id)")) {
            try {
                LatencyConfig(host = bad)
                fail("accepted '$bad'")
            } catch (_: IllegalArgumentException) {
            }
        }
        for (make in listOf<() -> Unit>(
            { LatencyConfig(host = "h", intervalMs = 100) },
            { LatencyConfig(host = "h", probes = 0) },
            { LatencyConfig(host = "h", protocols = listOf("udp")) },
            { LatencyConfig(host = "h", port = 0) },
        )) {
            try {
                make()
                fail("accepted")
            } catch (_: IllegalArgumentException) {
            }
        }
        val c = LatencyConfig.fromChannel(mapOf("host" to " speed.example.org ", "port" to 8443), "10.0.0.1")
        assertEquals("speed.example.org", c.host)
        assertEquals(8443, c.port)
        assertEquals(listOf("icmp", "tcp", "dns"), c.protocols)
        assertEquals(20, c.probes)
        assertEquals("10.0.0.1", c.dnsServer)
    }

    @Test
    fun dnsQueryWireFormat() {
        val q = DnsQuery.build(0x1234, "a.bc")
        val expected = byteArrayOf(
            0x12, 0x34, 0x01, 0x00, 0, 1, 0, 0, 0, 0, 0, 0,
            1, 'a'.code.toByte(), 2, 'b'.code.toByte(), 'c'.code.toByte(), 0,
            0, 1, 0, 1,
        )
        assertTrue(expected.contentEquals(q))
        val response = q.copyOf().also { it[2] = (it[2].toInt() or 0x80).toByte() }
        assertTrue(DnsQuery.isResponseTo(response, response.size, 0x1234))
        assertFalse(DnsQuery.isResponseTo(q, q.size, 0x1234)) // query, not response
        assertFalse(DnsQuery.isResponseTo(response, response.size, 0x1235))
        assertFalse(DnsQuery.isResponseTo(response, 5, 0x1234))
    }
}
