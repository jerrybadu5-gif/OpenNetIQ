package org.opennetiq.measurement.latency

/**
 * Parses `ping` output (Android toybox / iputils): one line per reply,
 * e.g. `64 bytes from 1.2.3.4: icmp_seq=3 ttl=55 time=23.4 ms`.
 * Replies are matched by sequence number, so loss and reordering are exact.
 */
object PingOutput {
    private val REPLY = Regex("icmp_[sr]eq=(\\d+).*?time[=<]([0-9.]+)\\s*ms")

    /** RTTs for sequence numbers 1..[count] (null = no reply). */
    fun parse(lines: List<String>, count: Int): List<Double?> {
        val rtts = arrayOfNulls<Double>(count)
        for (line in lines) {
            val m = REPLY.find(line) ?: continue
            val seq = m.groupValues[1].toInt()
            if (seq in 1..count && rtts[seq - 1] == null) {
                rtts[seq - 1] = m.groupValues[2].toDoubleOrNull()
            }
        }
        return rtts.toList()
    }

    /** Arguments for a single ping run of [config] (no shell involved). */
    fun command(binary: String, config: LatencyConfig): List<String> {
        val intervalS = "%.1f".format(java.util.Locale.ROOT, config.intervalMs / 1000.0)
        val timeoutS = maxOf(1L, (config.timeoutMs + 999) / 1000)
        val deadlineS = (config.probes * config.intervalMs + config.timeoutMs + 999) / 1000 + 1
        return listOf(
            binary,
            "-n",
            "-c", config.probes.toString(),
            "-i", intervalS,
            "-s", config.payloadBytes.toString(),
            "-W", timeoutS.toString(),
            "-w", deadlineS.toString(),
            config.host,
        )
    }
}
