package org.opennetiq.measurement.speed

/** Outcome of one test; maps to a `speed_tests` row (DATA-DICTIONARY.md). */
data class SpeedTestResult(
    val status: String,
    val serverHost: String,
    val streams: Int,
    val dnsMs: Double?,
    val tcpConnectMs: Double?,
    val download: ThroughputStats?,
    val upload: ThroughputStats?,
    val error: String?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to "result",
        "status" to status,
        "method" to SpeedTestConfig.METHOD,
        "server_host" to serverHost,
        "streams" to streams,
        "dns_ms" to dnsMs,
        "tcp_connect_ms" to tcpConnectMs,
        "dl_mean_mbps" to download?.meanMbps,
        "dl_median_mbps" to download?.medianMbps,
        "dl_p10_mbps" to download?.p10Mbps,
        "dl_p90_mbps" to download?.p90Mbps,
        "dl_peak_mbps" to download?.peakMbps,
        "dl_bytes" to download?.bytes,
        "ul_mean_mbps" to upload?.meanMbps,
        "ul_median_mbps" to upload?.medianMbps,
        "ul_p10_mbps" to upload?.p10Mbps,
        "ul_p90_mbps" to upload?.p90Mbps,
        "ul_peak_mbps" to upload?.peakMbps,
        "ul_bytes" to upload?.bytes,
        "error" to error,
    )

    companion object {
        const val OK = "ok"
        const val PARTIAL = "partial"
        const val FAILED = "failed"
        const val CANCELLED = "cancelled"

        /** ok = both directions valid; partial = one; failed = none. */
        fun statusOf(download: ThroughputStats?, upload: ThroughputStats?): String {
            val valid = listOf(download, upload).count { it != null && it.bytes >= ThroughputMath.MIN_VALID_BYTES }
            return when (valid) {
                2 -> OK
                1 -> PARTIAL
                else -> FAILED
            }
        }
    }
}
