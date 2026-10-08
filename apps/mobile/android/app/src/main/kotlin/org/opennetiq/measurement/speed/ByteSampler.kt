package org.opennetiq.measurement.speed

import java.util.concurrent.atomic.AtomicLong

/** Thread-safe byte counter cut into intervals by the sampling thread. */
class ByteSampler(startNs: Long) {
    private val total = AtomicLong(0)
    private var lastNs = startNs
    private var lastTotal = 0L
    private val intervals = ArrayList<ThroughputInterval>()

    fun add(bytes: Long) {
        total.addAndGet(bytes)
    }

    val totalBytes: Long
        get() = total.get()

    /** Closes the interval ending at [nowNs]; called by one thread only. */
    fun sample(nowNs: Long): ThroughputInterval {
        val current = total.get()
        val interval = ThroughputInterval(current - lastTotal, (nowNs - lastNs).coerceAtLeast(0))
        lastTotal = current
        lastNs = nowNs
        intervals.add(interval)
        return interval
    }

    fun intervals(): List<ThroughputInterval> = intervals.toList()
}
