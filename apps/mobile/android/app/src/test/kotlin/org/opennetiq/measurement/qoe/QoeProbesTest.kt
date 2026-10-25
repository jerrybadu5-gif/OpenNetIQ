package org.opennetiq.measurement.qoe

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.opennetiq.measurement.speed.LocalSpeedServer

class HttpProbeTest {
    @Test
    fun `get times the phases and reads the body`() {
        LocalSpeedServer().use { server ->
            val t = HttpProbe().get("${server.baseUrl}garbage.php?ckSize=2")
            assertEquals(200, t.httpStatus)
            assertEquals(2L * 1024 * 1024, t.bytes)
            assertTrue(t.ok)
            assertNotNull(t.connectMs)
            assertNotNull(t.ttfbMs)
            assertTrue(t.totalMs!! >= t.ttfbMs!!)
            assertNull(t.tlsMs) // plain HTTP
            assertNull(t.error)
            assertEquals(200, t.toMap()["http_status"])
        }
    }

    @Test
    fun `post uploads the requested size`() {
        LocalSpeedServer().use { server ->
            val t = HttpProbe().post("${server.baseUrl}empty.php", 3L * 1024 * 1024)
            assertTrue(t.ok)
            assertEquals(3L * 1024 * 1024, t.bytes)
            assertEquals(3L * 1024 * 1024, server.uploadedBytes)
        }
    }

    @Test
    fun `http errors and unreachable hosts are reported`() {
        LocalSpeedServer(failWith = 503).use { server ->
            val t = HttpProbe().get("${server.baseUrl}garbage.php")
            assertEquals(503, t.httpStatus)
            assertEquals("HTTP 503", t.error)
            assertTrue(!t.ok)
        }
        val down = HttpProbe().get("http://127.0.0.1:1/", timeoutMs = 2000)
        assertNotNull(down.error)
        assertNull(down.httpStatus)
        assertEquals("invalid URL", HttpProbe().get("not a url").error)
        assertEquals("invalid URL", HttpProbe().post("ftp://x", 1).error)
    }

    @Test
    fun `rate in Mbit per second`() {
        assertEquals(8.0, HttpProbe.mbps(1_000_000, 1000.0)!!, 1e-9)
        assertNull(HttpProbe.mbps(0, 10.0))
        assertNull(HttpProbe.mbps(10, null))
    }
}

class NavigationTimingTest {
    @Test
    fun `parses WebView JSON`() {
        val t = NavigationTiming.parse(
            """{"dns":12.5,"connect":30,"tls":null,"ttfb":120.25,"dom":800,"load":1500.5,"bytes":45678}""",
        )!!
        assertEquals(12.5, t.dnsMs!!, 1e-9)
        assertEquals(30.0, t.connectMs!!, 1e-9)
        assertNull(t.tlsMs)
        assertEquals(1500.5, t.loadMs!!, 1e-9)
        assertEquals(45678L, t.transferBytes)
    }

    @Test
    fun `rejects non-objects and negative values`() {
        assertNull(NavigationTiming.parse(null))
        assertNull(NavigationTiming.parse("null"))
        val t = NavigationTiming.parse("""{"dns":-1,"load":5}""")!!
        assertNull(t.dnsMs)
        assertEquals(5.0, t.loadMs!!, 1e-9)
        assertTrue(NavigationTiming.SCRIPT.contains("getEntriesByType"))
    }
}

class PlaybackStatsTest {
    private val ms = 1_000_000L

    @Test
    fun `start delay, rebuffering, played time and bitrate`() {
        val s = PlaybackStats(0)
        s.onBuffering(100 * ms) // initial load: not a rebuffer
        s.onFormat(500 * ms, 480, 1_000_000)
        s.onPlaying(800 * ms)
        s.onBuffering(2_800 * ms)
        s.onFormat(3_000 * ms, 720, 3_000_000)
        s.onPlaying(3_300 * ms)
        s.onBuffering(4_000 * ms)
        val r = s.finish(4_500 * ms) // ends while rebuffering
        assertEquals(800.0, r["start_delay_ms"] as Double, 1e-6)
        assertEquals(2, r["rebuffer_count"])
        assertEquals(1000.0, r["rebuffer_ms"] as Double, 1e-6)
        assertEquals(2700.0, r["played_ms"] as Double, 1e-6)
        assertEquals(4500.0, r["total_ms"] as Double, 1e-6)
        assertEquals("720p", r["resolution"])
        // 2.5 s at 1 Mb/s, 1.5 s at 3 Mb/s -> 1750 kb/s
        assertEquals(1750.0, r["bitrate_kbps"] as Double, 1e-6)
        assertNull(r["error"])
    }

    @Test
    fun `no playback is an error, first error wins`() {
        val s = PlaybackStats(0)
        s.onError("ERROR_CODE_IO_NETWORK_CONNECTION_FAILED")
        s.onError("other")
        val r = s.finish(30_000 * ms)
        assertNull(r["start_delay_ms"])
        assertEquals("ERROR_CODE_IO_NETWORK_CONNECTION_FAILED", r["error"])
        assertNull(r["bitrate_kbps"])
        assertNull(r["resolution"])
        assertEquals("playback did not start", PlaybackStats(0).finish(1)["error"])
    }

    @Test
    fun `repeated playing events do not double count`() {
        val s = PlaybackStats(0)
        s.onPlaying(10 * ms)
        s.onPlaying(20 * ms)
        s.onFormat(10 * ms, null, null)
        val r = s.finish(110 * ms)
        assertEquals(100.0, r["played_ms"] as Double, 1e-6)
        assertEquals(0, r["rebuffer_count"])
    }
}
