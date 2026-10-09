package org.opennetiq.measurement.latency

/** Parameters of method `lat-1.0` (MEASUREMENT-METHODOLOGY.md §6). */
data class LatencyConfig(
    val host: String,
    val port: Int = 443,
    val protocols: List<String> = listOf(ICMP, TCP, DNS),
    val probes: Int = DEFAULT_PROBES,
    val intervalMs: Long = DEFAULT_INTERVAL_MS,
    val timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    val payloadBytes: Int = DEFAULT_PAYLOAD,
    /** Resolver for DNS probes; null skips DNS (reported as failed). */
    val dnsServer: String? = null,
) {
    init {
        require(host.isNotBlank() && HOST.matches(host)) { "Invalid host" }
        require(port in 1..65535) { "Invalid port" }
        require(protocols.isNotEmpty() && protocols.all { it in ALL }) { "Unknown protocol" }
        require(probes in 1..100) { "probes must be 1..100" }
        // Unprivileged ping refuses intervals below 200 ms.
        require(intervalMs in 200..5_000) { "interval must be 200..5000 ms" }
        require(timeoutMs in 100..10_000) { "timeout must be 100..10000 ms" }
        require(payloadBytes in 0..1_400) { "payload must be 0..1400 bytes" }
    }

    companion object {
        const val METHOD = "lat-1.0"
        const val ICMP = "icmp"
        const val TCP = "tcp"
        const val DNS = "dns"
        val ALL = listOf(ICMP, TCP, DNS)
        const val DEFAULT_PROBES = 20
        const val DEFAULT_INTERVAL_MS = 200L
        const val DEFAULT_TIMEOUT_MS = 2_000L
        const val DEFAULT_PAYLOAD = 56

        /** Hostname or IPv4/IPv6 literal, no scheme, path or shell metacharacters. */
        private val HOST = Regex("^[A-Za-z0-9.:\\-\\[\\]]{1,253}$")

        fun fromChannel(arguments: Any?, dnsServer: String?): LatencyConfig {
            val map = arguments as? Map<*, *> ?: throw IllegalArgumentException("Missing arguments")
            val host = map["host"] as? String ?: throw IllegalArgumentException("Missing host")
            val protocols = (map["protocols"] as? List<*>)?.map { it as? String ?: "" } ?: ALL
            return LatencyConfig(
                host = host.trim(),
                port = (map["port"] as? Number)?.toInt() ?: 443,
                protocols = protocols,
                probes = (map["probes"] as? Number)?.toInt() ?: DEFAULT_PROBES,
                intervalMs = (map["interval_ms"] as? Number)?.toLong() ?: DEFAULT_INTERVAL_MS,
                timeoutMs = (map["timeout_ms"] as? Number)?.toLong() ?: DEFAULT_TIMEOUT_MS,
                dnsServer = dnsServer,
            )
        }
    }
}
