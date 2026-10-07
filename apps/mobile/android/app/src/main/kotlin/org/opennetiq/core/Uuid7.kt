package org.opennetiq.core

import java.security.SecureRandom

/** RFC 9562 UUIDv7 generator, monotonic (12-bit counter in rand_a). */
class Uuid7Generator(
    private val nowMs: () -> Long = { System.currentTimeMillis() },
    private val random: SecureRandom = SecureRandom(),
) {
    private var lastMs = -1L
    private var counter = 0

    @Synchronized
    fun next(): String {
        var ms = nowMs()
        if (ms > lastMs) {
            counter = random.nextInt(0x800)
        } else {
            ms = lastMs
            counter++
            if (counter > 0xFFF) {
                ms++
                counter = 0
            }
        }
        lastMs = ms

        val b = ByteArray(16)
        for (i in 0 until 6) b[i] = ((ms shr (8 * (5 - i))) and 0xFF).toByte()
        b[6] = (0x70 or (counter shr 8)).toByte()
        b[7] = (counter and 0xFF).toByte()
        val tail = ByteArray(8).also { random.nextBytes(it) }
        tail.copyInto(b, 8)
        b[8] = ((b[8].toInt() and 0x3F) or 0x80).toByte()

        val h = b.joinToString("") { "%02x".format(it) }
        return "${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}" +
            "-${h.substring(16, 20)}-${h.substring(20)}"
    }

    companion object {
        private val default = Uuid7Generator()
        fun generate(): String = default.next()
    }
}
