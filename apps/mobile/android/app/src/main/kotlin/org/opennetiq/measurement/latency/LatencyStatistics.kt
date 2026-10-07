package org.opennetiq.measurement.latency

import kotlin.math.ceil

data class LatencyStatistics(
    val probesSent: Int,
    val probesReceived: Int,
    val minMs: Double?,
    val maxMs: Double?,
    val meanMs: Double?,
    val medianMs: Double?,
    val p95Ms: Double?,
    val jitterMs: Double?,
    val packetLossPct: Double,
) {
    companion object {
        fun from(rawRttsMs: List<Double?>): LatencyStatistics {
            val samples = rawRttsMs.filterNotNull().filter { it.isFinite() && it >= 0.0 }.sorted()
            val received = samples.size
            val median = when {
                received == 0 -> null
                received % 2 == 1 -> samples[received / 2]
                else -> (samples[received / 2 - 1] + samples[received / 2]) / 2
            }
            var previous: Double? = null
            var differenceTotal = 0.0
            var differenceCount = 0
            rawRttsMs.forEach { rtt ->
                if (rtt == null || !rtt.isFinite() || rtt < 0.0) {
                    previous = null
                } else {
                    previous?.let {
                        differenceTotal += kotlin.math.abs(rtt - it)
                        differenceCount++
                    }
                    previous = rtt
                }
            }

            return LatencyStatistics(
                probesSent = rawRttsMs.size,
                probesReceived = received,
                minMs = samples.firstOrNull(),
                maxMs = samples.lastOrNull(),
                meanMs = samples.takeIf { it.isNotEmpty() }?.average(),
                medianMs = median,
                p95Ms = samples.takeIf { it.isNotEmpty() }?.let {
                    it[ceil(0.95 * it.size).toInt() - 1]
                },
                jitterMs = if (differenceCount == 0) null else differenceTotal / differenceCount,
                packetLossPct = if (rawRttsMs.isEmpty()) 0.0
                else (rawRttsMs.size - received) * 100.0 / rawRttsMs.size,
            )
        }
    }
}
