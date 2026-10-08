package org.opennetiq.measurement.speed

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.UnknownHostException

class SpeedTestEngineTest {
    private fun config(url: String) = SpeedTestConfig(
        baseUrl = url,
        streams = 4,
        directionMs = 1_500,
        rampUpMs = 500,
        uploadChunkBytes = 4 * 1024 * 1024,
        timeoutMs = 2_000,
    )

    private class Recorder : SpeedTestEngine.Listener {
        val phases = mutableListOf<String>()
        val progress = mutableListOf<Pair<String, Double>>()

        override fun onPhase(phase: String) {
            phases.add(phase)
        }

        override fun onProgress(phase: String, elapsedMs: Long, mbps: Double) {
            progress.add(phase to mbps)
        }
    }

    @Test
    fun measuresBothDirectionsAgainstALocalServer() {
        LocalSpeedServer().use { server ->
            val recorder = Recorder()
            val result = SpeedTestEngine(config(server.baseUrl)).run(recorder)

            assertEquals("ok", result.status)
            assertNull(result.error)
            assertEquals("127.0.0.1", result.serverHost)
            assertEquals(4, result.streams)
            assertTrue(result.dnsMs!! >= 0)
            assertTrue(result.tcpConnectMs!! >= 0)
            val dl = result.download!!
            val ul = result.upload!!
            assertTrue(dl.bytes >= 1_000_000 && ul.bytes >= 1_000_000)
            assertTrue(dl.meanMbps > 1 && ul.meanMbps > 1)
            assertTrue(dl.p10Mbps <= dl.medianMbps && dl.medianMbps <= dl.p90Mbps)
            assertTrue(dl.peakMbps >= dl.medianMbps * 0.5)
            assertTrue(dl.intervals in 8..11) // 1 s measured at 100 ms
            assertTrue(server.uploadedBytes > 0)
            assertEquals(listOf("dns", "download", "upload"), recorder.phases)
            assertTrue(recorder.progress.any { it.first == "download" && it.second > 0 })
            assertTrue(recorder.progress.any { it.first == "upload" && it.second > 0 })
            assertEquals("result", result.toMap()["type"])
            assertEquals("http-mc-1.0", result.toMap()["method"])
        }
    }

    @Test
    fun cancelStopsPromptlyWithoutResult() {
        LocalSpeedServer().use { server ->
            val engine = SpeedTestEngine(config(server.baseUrl).copy(directionMs = 10_000))
            Thread {
                Thread.sleep(400)
                engine.cancel()
            }.start()
            val started = System.nanoTime()
            val result = engine.run()
            val tookMs = (System.nanoTime() - started) / 1_000_000
            assertEquals("cancelled", result.status)
            assertNull(result.download)
            assertTrue(tookMs < 3_000)
        }
    }

    @Test
    fun serverErrorsFailTheTestWithAReason() {
        LocalSpeedServer(failWith = 500).use { server ->
            val result = SpeedTestEngine(config(server.baseUrl)).run()
            assertEquals("failed", result.status)
            assertTrue(result.error!!.contains("HTTP 500"))
            assertNull(result.download)
        }
    }

    @Test
    fun dnsFailureIsReported() {
        val engine = SpeedTestEngine(
            config("http://speed.invalid/"),
            resolver = { throw UnknownHostException("speed.invalid") },
        )
        val result = engine.run()
        assertEquals("failed", result.status)
        assertTrue(result.error!!.startsWith("DNS"))
        assertNull(result.dnsMs)
    }

    @Test
    fun cancelBeforeRunReturnsCancelled() {
        val engine = SpeedTestEngine(config("http://127.0.0.1:9/"))
        engine.cancel()
        assertEquals("cancelled", engine.run().status)
    }
}
