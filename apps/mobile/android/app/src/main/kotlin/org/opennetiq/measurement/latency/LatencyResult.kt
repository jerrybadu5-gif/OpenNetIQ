package org.opennetiq.measurement.latency

/** One protocol's outcome; maps to a `latency_tests` row (DATA-DICTIONARY.md). */
data class LatencyResult(
    val protocol: String,
    val target: String,
    val rtts: List<Double?>,
    val planned: Int,
    val error: String? = null,
) {
    val stats: LatencyStats = LatencyMath.summarize(rtts)

    /** ok = all probes sent and at least one answered; partial = cut short; failed = no answer. */
    val status: String
        get() = when {
            stats.received == 0 -> FAILED
            rtts.size < planned -> PARTIAL
            else -> OK
        }

    fun toMap(): Map<String, Any?> = mapOf(
        "type" to "result",
        "protocol" to protocol,
        "method" to LatencyConfig.METHOD,
        "target" to target,
        "probes_sent" to stats.sent,
        "probes_received" to stats.received,
        "min_ms" to stats.minMs,
        "max_ms" to stats.maxMs,
        "mean_ms" to stats.meanMs,
        "median_ms" to stats.medianMs,
        "p95_ms" to stats.p95Ms,
        "jitter_ms" to stats.jitterMs,
        "packet_loss_pct" to stats.packetLossPct,
        "raw_rtts_ms" to rtts,
        "status" to status,
        "error" to error,
    )

    companion object {
        const val OK = "ok"
        const val PARTIAL = "partial"
        const val FAILED = "failed"
    }
}
