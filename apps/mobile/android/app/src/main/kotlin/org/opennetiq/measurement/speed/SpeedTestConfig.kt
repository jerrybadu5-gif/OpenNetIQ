package org.opennetiq.measurement.speed

import java.net.URI

/**
 * Test parameters (method `http-mc-1.0`, ADR-007). The server exposes
 * LibreSpeed-compatible endpoints relative to [baseUrl]:
 * `garbage.php?ckSize=N` (download, N MiB) and `empty.php` (upload sink).
 */
data class SpeedTestConfig(
    val baseUrl: String,
    val streams: Int = DEFAULT_STREAMS,
    val directionMs: Long = DEFAULT_DIRECTION_MS,
    val rampUpMs: Long = ThroughputMath.RAMP_UP_MS,
    val sampleMs: Long = ThroughputMath.SAMPLE_INTERVAL_MS,
    val downloadPath: String = "garbage.php",
    val uploadPath: String = "empty.php",
    val downloadChunkMiB: Int = 100,
    val uploadChunkBytes: Int = 16 * 1024 * 1024,
    val timeoutMs: Long = 5_000,
) {
    init {
        require(streams in 1..16) { "streams must be 1..16" }
        require(directionMs in 1_000..60_000) { "direction duration must be 1..60 s" }
        require(rampUpMs in 0 until directionMs) { "ramp-up must be shorter than the test" }
        require(sampleMs in 10..1_000) { "sample interval must be 10..1000 ms" }
    }

    private val base: URI = parseBase(baseUrl)

    val host: String
        get() = base.host

    val port: Int
        get() = if (base.port != -1) base.port else if (base.scheme == "https") 443 else 80

    fun downloadUrl(nonce: Long): String = "${base.resolve(downloadPath)}?ckSize=$downloadChunkMiB&r=$nonce"

    fun uploadUrl(nonce: Long): String = "${base.resolve(uploadPath)}?r=$nonce"

    companion object {
        const val METHOD = "http-mc-1.0"
        const val DEFAULT_STREAMS = 4
        const val DEFAULT_DIRECTION_MS = 12_000L // 2 s ramp-up + 10 s measured

        /** Normalises to an absolute http(s) URL ending in `/`. */
        fun parseBase(url: String): URI {
            val trimmed = url.trim()
            val uri = try {
                URI(if (trimmed.endsWith("/")) trimmed else "$trimmed/")
            } catch (e: Exception) {
                throw IllegalArgumentException("Invalid server URL")
            }
            require(uri.scheme == "http" || uri.scheme == "https") { "Server URL must start with http:// or https://" }
            require(!uri.host.isNullOrBlank()) { "Server URL has no host" }
            return uri
        }

        /** From the channel map (`server_url`, optional `streams`, `direction_ms`). */
        fun fromChannel(arguments: Any?): SpeedTestConfig {
            val map = arguments as? Map<*, *> ?: throw IllegalArgumentException("Missing arguments")
            val url = map["server_url"] as? String ?: throw IllegalArgumentException("Missing server_url")
            return SpeedTestConfig(
                baseUrl = url,
                streams = (map["streams"] as? Number)?.toInt() ?: DEFAULT_STREAMS,
                directionMs = (map["direction_ms"] as? Number)?.toLong() ?: DEFAULT_DIRECTION_MS,
            )
        }
    }
}
