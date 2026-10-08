package org.opennetiq.measurement.speed

import kotlin.math.ceil

/** Bytes moved during one sampling interval of measured length. */
data class ThroughputInterval(val bytes: Long, val durationNs: Long) {
    val mbps: Double
        get() = if (durationNs <= 0) 0.0 else bytes * 8.0 / 1e6 / (durationNs / 1e9)
}

/** Throughput statistics of one direction (MEASUREMENT-METHODOLOGY.md §5). */
data class ThroughputStats(
    val meanMbps: Double,
    val medianMbps: Double,
    val p10Mbps: Double,
    val p90Mbps: Double,
    val peakMbps: Double,
    /** All bytes transferred, ramp-up included. */
    val bytes: Long,
    /** Intervals used for the statistics (ramp-up excluded). */
    val intervals: Int,
)

/**
 * KPI math for method `http-mc-1.0`.
 * - Intervals starting before the ramp-up end are discarded (TCP slow start).
 * - mean = bytes / time over the measured window (time-weighted).
 * - median, P10, P90 = nearest-rank percentiles of per-interval rates.
 * - peak = highest rate over any 1 s window of consecutive intervals.
 * - Mbit/s are SI (10^6 bit/s), application-layer goodput.
 */
object ThroughputMath {
    const val SAMPLE_INTERVAL_MS = 100L
    const val RAMP_UP_MS = 2_000L
    const val PEAK_WINDOW_MS = 1_000L

    /** Below this a direction is invalid (methodology §5.6). */
    const val MIN_VALID_BYTES = 1_000_000L

    fun summarize(
        intervals: List<ThroughputInterval>,
        rampUpNs: Long = RAMP_UP_MS * 1_000_000,
        peakWindowNs: Long = PEAK_WINDOW_MS * 1_000_000,
    ): ThroughputStats? {
        val total = intervals.sumOf { it.bytes }
        var elapsed = 0L
        val measured = ArrayList<ThroughputInterval>()
        for (interval in intervals) {
            if (elapsed >= rampUpNs) measured.add(interval)
            elapsed += interval.durationNs
        }
        val measuredNs = measured.sumOf { it.durationNs }
        if (measured.isEmpty() || measuredNs <= 0) return null
        val rates = measured.map { it.mbps }.sorted()
        return ThroughputStats(
            meanMbps = ThroughputInterval(measured.sumOf { it.bytes }, measuredNs).mbps,
            medianMbps = percentile(rates, 50.0),
            p10Mbps = percentile(rates, 10.0),
            p90Mbps = percentile(rates, 90.0),
            peakMbps = peak(measured, peakWindowNs),
            bytes = total,
            intervals = measured.size,
        )
    }

    /** Nearest-rank percentile of an ascending list (same rule as latency P95). */
    fun percentile(sortedAscending: List<Double>, p: Double): Double {
        require(sortedAscending.isNotEmpty()) { "empty" }
        require(p in 0.0..100.0) { "p out of range" }
        val rank = ceil(p / 100.0 * sortedAscending.size).toInt().coerceIn(1, sortedAscending.size)
        return sortedAscending[rank - 1]
    }

    /** Highest rate over windows of consecutive intervals spanning >= [windowNs]. */
    fun peak(intervals: List<ThroughputInterval>, windowNs: Long): Double {
        var best = 0.0
        var start = 0
        var bytes = 0L
        var duration = 0L
        var reachedWindow = false
        for (end in intervals.indices) {
            bytes += intervals[end].bytes
            duration += intervals[end].durationNs
            while (duration - intervals[start].durationNs >= windowNs) {
                bytes -= intervals[start].bytes
                duration -= intervals[start].durationNs
                start++
            }
            if (duration >= windowNs) {
                reachedWindow = true
                best = maxOf(best, ThroughputInterval(bytes, duration).mbps)
            }
        }
        // Shorter tests than one window: the whole test is the only window.
        return if (reachedWindow) best else ThroughputInterval(bytes, duration).mbps
    }

    /** Rate over the last [windowNs] of intervals (live display). */
    fun recentMbps(intervals: List<ThroughputInterval>, windowNs: Long = PEAK_WINDOW_MS * 1_000_000): Double {
        var bytes = 0L
        var duration = 0L
        for (i in intervals.indices.reversed()) {
            bytes += intervals[i].bytes
            duration += intervals[i].durationNs
            if (duration >= windowNs) break
        }
        return ThroughputInterval(bytes, duration).mbps
    }
}
