package org.opennetiq.measurement.speed

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class SpeedTestConfigTest {
    @Test
    fun buildsLibreSpeedUrls() {
        val c = SpeedTestConfig("https://speed.example.org/backend")
        assertEquals("speed.example.org", c.host)
        assertEquals(443, c.port)
        assertEquals("https://speed.example.org/backend/garbage.php?ckSize=100&r=7", c.downloadUrl(7))
        assertEquals("https://speed.example.org/backend/empty.php?r=7", c.uploadUrl(7))
        assertEquals(8080, SpeedTestConfig("http://10.0.0.2:8080/").port)
        assertEquals(80, SpeedTestConfig("http://10.0.0.2").port)
    }

    @Test
    fun readsChannelArgumentsWithMethodDefaults() {
        val c = SpeedTestConfig.fromChannel(mapOf("server_url" to " http://10.0.0.2:8080/backend/ "))
        assertEquals(4, c.streams)
        assertEquals(12_000L, c.directionMs)
        assertEquals(2_000L, c.rampUpMs)
        assertEquals(100L, c.sampleMs)
        val custom = SpeedTestConfig.fromChannel(
            mapOf("server_url" to "http://h/", "streams" to 2, "direction_ms" to 5000),
        )
        assertEquals(2, custom.streams)
        assertEquals(5_000L, custom.directionMs)
    }

    @Test
    fun rejectsBadInput() {
        for (bad in listOf("ftp://h/", "not a url", "http:///nohost", "")) {
            try {
                SpeedTestConfig(bad)
                fail("accepted $bad")
            } catch (e: IllegalArgumentException) {
                assertTrue(e.message!!.isNotEmpty())
            }
        }
        for (args in listOf(null, mapOf("streams" to 4), mapOf("server_url" to "http://h/", "streams" to 0))) {
            try {
                SpeedTestConfig.fromChannel(args)
                fail("accepted $args")
            } catch (_: IllegalArgumentException) {
            }
        }
    }
}
