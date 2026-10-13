package org.opennetiq.measurement.latency

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LatencyMathTest {
    @Test
    fun statisticsOverReceivedProbes() {
        val s = LatencyMath.summarize(listOf(20.0, 30.0, null, 25.0, 40.0))
        assertEquals(5, s.sent)
        assertEquals(4, s.received)
        assertEquals(20.0, s.minMs!!, 1e-9)
        assertEquals(40.0, s.maxMs!!, 1e-9)
        assertEquals(28.75, s.meanMs!!, 1e-9)
        assertEquals(27.5, s.medianMs!!, 1e-9)
        assertEquals(40.0, s.p95Ms!!, 1e-9)
        assertEquals(20.0, s.packetLossPct!!, 1e-9)
    }

    @Test
    fun jitterUsesOnlyConsecutiveSuccessfulPairs() {
        // Pairs: (20,30)=10, (30,null) skip, (null,25) skip, (25,40)=15 -> 12.5
        val s = LatencyMath.summarize(listOf(20.0, 30.0, null, 25.0, 40.0))
        assertEquals(12.5, s.jitterMs!!, 1e-9)
        assertNull(LatencyMath.summarize(listOf(10.0, null, 12.0)).jitterMs)
    }

    @Test
    fun ipdvExample() {
        // RFC 3393-style: |12-10| + |11-12| + |15-11| = 7 over 3 pairs.
        assertEquals(7.0 / 3, LatencyMath.summarize(listOf(10.0, 12.0, 11.0, 15.0)).jitterMs!!, 1e-9)
    }

    @Test
    fun p95IsNearestRank() {
        val twenty = (1..20).map { it.toDouble() }
        assertEquals(19.0, LatencyMath.summarize(twenty).p95Ms!!, 1e-9)
        assertEquals(10.5, LatencyMath.summarize(twenty).medianMs!!, 1e-9)
        assertEquals(7.0, LatencyMath.percentile(listOf(7.0), 95.0), 0.0)
    }

    @Test
    fun allLostAndEmpty() {
        val lost = LatencyMath.summarize(listOf(null, null))
        assertEquals(0, lost.received)
        assertEquals(100.0, lost.packetLossPct!!, 1e-9)
        assertNull(lost.meanMs)
        assertNull(lost.p95Ms)
        val empty = LatencyMath.summarize(emptyList())
        assertNull(empty.packetLossPct)
    }

    @Test
    fun resultStatusRule() {
        assertEquals("ok", LatencyResult("tcp", "h", listOf(1.0, null), 2).status)
        assertEquals("partial", LatencyResult("tcp", "h", listOf(1.0), 2).status)
        assertEquals("failed", LatencyResult("tcp", "h", listOf(null, null), 2).status)
        val map = LatencyResult("icmp", "h", listOf(1.0, null), 2).toMap()
        assertEquals("lat-1.0", map["method"])
        assertEquals(listOf(1.0, null), map["raw_rtts_ms"])
        assertEquals(50.0, map["packet_loss_pct"])
    }
}
