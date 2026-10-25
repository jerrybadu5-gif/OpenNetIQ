package org.opennetiq.measurement.qoe

/**
 * Video QoE accumulator (issue #29), shared by direct-stream (ExoPlayer) and
 * web-page (HTML5 video) tests. Times are monotonic nanoseconds.
 *
 * - start delay: test start -> first playing
 * - rebuffer: playing -> buffering after first playback, until playing again
 * - played: time spent playing
 * - bitrate: time-weighted mean of the selected video format's bitrate
 */
class PlaybackStats(private val startNs: Long) {
    private var firstPlayingNs: Long? = null
    private var playingSinceNs: Long? = null
    private var bufferingSinceNs: Long? = null
    private var playedNs = 0L
    private var rebufferNs = 0L
    var rebufferCount = 0
        private set
    var error: String? = null
        private set
    private var maxHeight = 0
    private var formatSinceNs: Long? = null
    private var formatBitrate: Int? = null
    private var bitrateWeighted = 0.0
    private var bitrateTimeNs = 0L

    fun onPlaying(t: Long) {
        if (firstPlayingNs == null) firstPlayingNs = t
        bufferingSinceNs?.let { rebufferNs += t - it }
        bufferingSinceNs = null
        if (playingSinceNs == null) playingSinceNs = t
    }

    fun onBuffering(t: Long) {
        closePlaying(t)
        if (firstPlayingNs != null && bufferingSinceNs == null) {
            rebufferCount++
            bufferingSinceNs = t
        }
    }

    fun onFormat(t: Long, heightPx: Int?, bitrateBps: Int?) {
        closeFormat(t)
        if (heightPx != null && heightPx > maxHeight) maxHeight = heightPx
        formatBitrate = bitrateBps?.takeIf { it > 0 }
        formatSinceNs = t
    }

    fun onError(message: String) { if (error == null) error = message }

    private fun closePlaying(t: Long) {
        playingSinceNs?.let { playedNs += t - it }
        playingSinceNs = null
    }

    private fun closeFormat(t: Long) {
        val since = formatSinceNs ?: return
        val rate = formatBitrate ?: return
        bitrateWeighted += rate.toDouble() * (t - since)
        bitrateTimeNs += t - since
    }

    /** Freezes the stats at [t]; an open rebuffer counts until then. */
    fun finish(t: Long): Map<String, Any?> {
        closePlaying(t)
        closeFormat(t)
        bufferingSinceNs?.let { rebufferNs += t - it }
        bufferingSinceNs = null
        formatSinceNs = null
        val first = firstPlayingNs
        return mapOf(
            "start_delay_ms" to first?.let { (it - startNs) / 1e6 },
            "rebuffer_count" to rebufferCount,
            "rebuffer_ms" to rebufferNs / 1e6,
            "played_ms" to playedNs / 1e6,
            "total_ms" to (t - startNs) / 1e6,
            "bitrate_kbps" to if (bitrateTimeNs > 0) bitrateWeighted / bitrateTimeNs / 1000 else null,
            "resolution" to if (maxHeight > 0) "${maxHeight}p" else null,
            "error" to (error ?: if (first == null) "playback did not start" else null),
        )
    }
}
