package org.opennetiq.measurement.latency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LatencyStatisticsTest {
    @Test
    fun computesSummaryNearestRankP95AndLoss() {
        val statistics = LatencyStatistics.from(
            listOf(10.0, 20.0, null, 30.0, 40.0),
        )

        assertEquals(5, statistics.probesSent)
        assertEquals(4, statistics.probesReceived)
        assertEquals(10.0, statistics.minMs!!, 0.0)
        assertEquals(40.0, statistics.maxMs!!, 0.0)
        assertEquals(25.0, statistics.meanMs!!, 0.0)
        assertEquals(25.0, statistics.medianMs!!, 0.0)
        assertEquals(40.0, statistics.p95Ms!!, 0.0)
        assertEquals(10.0, statistics.jitterMs!!, 0.0)
        assertEquals(20.0, statistics.packetLossPct, 0.0)
    }

    @Test
    fun jitterOnlyUsesAdjacentSuccessfulProbes() {
        val statistics = LatencyStatistics.from(listOf(10.0, 14.0, null, 100.0, 106.0))

        assertEquals(5.0, statistics.jitterMs!!, 0.0)
    }

    @Test
    fun emptyAndSingleSampleHaveUnavailableStatistics() {
        val empty = LatencyStatistics.from(emptyList())
        assertNull(empty.minMs)
        assertNull(empty.meanMs)
        assertNull(empty.p95Ms)
        assertNull(empty.jitterMs)
        assertEquals(0.0, empty.packetLossPct, 0.0)

        val single = LatencyStatistics.from(listOf(12.0))
        assertNull(single.jitterMs)
        assertEquals(0.0, single.packetLossPct, 0.0)
    }
}
