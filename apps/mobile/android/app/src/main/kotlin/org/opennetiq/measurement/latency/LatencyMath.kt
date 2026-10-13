package org.opennetiq.measurement.latency

import kotlin.math.abs
import kotlin.math.ceil

/** Statistics of one latency test (MEASUREMENT-METHODOLOGY.md §6, method `lat-1.0`). */
data class LatencyStats(
    val sent: Int,
    val received: Int,
    val minMs: Double?,
    val maxMs: Double?,
    val meanMs: Double?,
    val medianMs: Double?,
    val p95Ms: Double?,
    val jitterMs: Double?,
    val packetLossPct: Double?,
)

/**
 * KPI math for `lat-1.0`:
 * - min, max, mean, median and P95 (nearest rank) over received probes;
 * - jitter = mean |RTT(i) - RTT(i-1)| over pairs of consecutive probes that
 *   both succeeded (IPDV, RFC 3393 / ITU-T Y.1540);
 * - packet loss = (sent - received) / sent x 100.
 */
object LatencyMath {
    /** [rtts] in probe order; null = lost. */
    fun summarize(rtts: List<Double?>): LatencyStats {
        val sent = rtts.size
        val ok = rtts.filterNotNull()
        val sorted = ok.sorted()
        val diffs = rtts.zipWithNext().mapNotNull { (a, b) -> if (a != null && b != null) abs(b - a) else null }
        return LatencyStats(
            sent = sent,
            received = ok.size,
            minMs = sorted.firstOrNull(),
            maxMs = sorted.lastOrNull(),
            meanMs = if (ok.isEmpty()) null else ok.sum() / ok.size,
            medianMs = median(sorted),
            p95Ms = if (sorted.isEmpty()) null else percentile(sorted, 95.0),
            jitterMs = if (diffs.isEmpty()) null else diffs.sum() / diffs.size,
            packetLossPct = if (sent == 0) null else (sent - ok.size) * 100.0 / sent,
        )
    }

    fun percentile(sortedAscending: List<Double>, p: Double): Double {
        require(sortedAscending.isNotEmpty()) { "empty" }
        val rank = ceil(p / 100.0 * sortedAscending.size).toInt().coerceIn(1, sortedAscending.size)
        return sortedAscending[rank - 1]
    }

    private fun median(sorted: List<Double>): Double? {
        if (sorted.isEmpty()) return null
        val n = sorted.size
        return if (n % 2 == 1) sorted[n / 2] else (sorted[n / 2 - 1] + sorted[n / 2]) / 2
    }
}
