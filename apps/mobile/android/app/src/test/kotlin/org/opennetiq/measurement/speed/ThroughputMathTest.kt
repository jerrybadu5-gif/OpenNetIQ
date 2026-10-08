package org.opennetiq.measurement.speed

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ThroughputMathTest {
    private val ms100 = 100_000_000L

    /** [mbps] rate over a 100 ms interval. */
    private fun interval(mbps: Double) = ThroughputInterval((mbps * 1e6 / 8 * 0.1).toLong(), ms100)

    @Test
    fun intervalRateIsSiMegabitsPerSecond() {
        assertEquals(80.0, ThroughputInterval(1_000_000, ms100).mbps, 1e-9)
        assertEquals(0.0, ThroughputInterval(1_000, 0).mbps, 1e-9)
    }

    @Test
    fun rampUpIsExcludedAndStatisticsUseTheRest() {
        val ramp = List(20) { interval(1.0) }
        val measured = List(80) { i -> interval((i + 1).toDouble()) } // 1..80 Mbps
        val stats = ThroughputMath.summarize(ramp + measured)!!
        assertEquals(80, stats.intervals)
        assertEquals(40.5, stats.meanMbps, 1e-3)
        assertEquals(40.0, stats.medianMbps, 1e-3)
        assertEquals(8.0, stats.p10Mbps, 1e-3)
        assertEquals(72.0, stats.p90Mbps, 1e-3)
        // Best 1 s window = last 10 intervals: mean of 71..80.
        assertEquals(75.5, stats.peakMbps, 1e-3)
        assertEquals((ramp + measured).sumOf { it.bytes }, stats.bytes)
    }

    @Test
    fun meanIsTimeWeighted() {
        val stats = ThroughputMath.summarize(
            listOf(ThroughputInterval(1_000_000, 100_000_000), ThroughputInterval(1_000_000, 300_000_000)),
            rampUpNs = 0,
        )!!
        assertEquals(40.0, stats.meanMbps, 1e-9) // 16 Mbit over 0.4 s
    }

    @Test
    fun nothingAfterRampUpGivesNoStatistics() {
        assertNull(ThroughputMath.summarize(List(20) { interval(5.0) }))
        assertNull(ThroughputMath.summarize(emptyList()))
    }

    @Test
    fun nearestRankPercentiles() {
        val v = listOf(10.0, 20.0, 30.0, 40.0, 50.0)
        assertEquals(10.0, ThroughputMath.percentile(v, 10.0), 0.0)
        assertEquals(30.0, ThroughputMath.percentile(v, 50.0), 0.0)
        assertEquals(50.0, ThroughputMath.percentile(v, 90.0), 0.0)
        assertEquals(10.0, ThroughputMath.percentile(v, 0.0), 0.0)
        assertEquals(50.0, ThroughputMath.percentile(v, 100.0), 0.0)
        assertEquals(7.0, ThroughputMath.percentile(listOf(7.0), 95.0), 0.0)
    }

    @Test
    fun peakOfShortTestIsTheWholeTest() {
        val short = List(5) { interval(10.0) }
        assertEquals(10.0, ThroughputMath.peak(short, 1_000_000_000), 1e-3)
    }

    @Test
    fun peakFindsTheBurst() {
        val list = List(10) { interval(10.0) } + List(10) { interval(100.0) } + List(10) { interval(10.0) }
        assertEquals(100.0, ThroughputMath.peak(list, 1_000_000_000), 1e-3)
    }

    @Test
    fun recentRateUsesTheLastSecond() {
        val list = List(10) { interval(100.0) } + List(10) { interval(20.0) }
        assertEquals(20.0, ThroughputMath.recentMbps(list), 1e-3)
        assertEquals(0.0, ThroughputMath.recentMbps(emptyList()), 0.0)
    }

    @Test
    fun samplerCutsIntervals() {
        val sampler = ByteSampler(0)
        sampler.add(500)
        sampler.add(500)
        val first = sampler.sample(100_000_000)
        sampler.add(250)
        val second = sampler.sample(150_000_000)
        assertEquals(ThroughputInterval(1000, 100_000_000), first)
        assertEquals(ThroughputInterval(250, 50_000_000), second)
        assertEquals(1250L, sampler.totalBytes)
        assertEquals(2, sampler.intervals().size)
    }

    @Test
    fun statusNeedsOneMegabytePerDirection() {
        fun stats(bytes: Long) = ThroughputStats(1.0, 1.0, 1.0, 1.0, 1.0, bytes, 1)
        assertEquals("ok", SpeedTestResult.statusOf(stats(2_000_000), stats(1_000_000)))
        assertEquals("partial", SpeedTestResult.statusOf(stats(2_000_000), stats(999_999)))
        assertEquals("partial", SpeedTestResult.statusOf(null, stats(5_000_000)))
        assertEquals("failed", SpeedTestResult.statusOf(null, null))
        assertTrue(SpeedTestEngine.median(listOf(3.0, 1.0, 2.0)) == 2.0)
        assertEquals(1.5, SpeedTestEngine.median(listOf(1.0, 2.0))!!, 1e-9)
        assertNull(SpeedTestEngine.median(emptyList()))
    }
}
