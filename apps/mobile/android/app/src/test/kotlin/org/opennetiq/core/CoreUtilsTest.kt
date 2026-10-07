package org.opennetiq.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class CoreUtilsTest {
    @Test
    fun uuid7HasVersionAndVariant() {
        val id = Uuid7Generator.generate()
        assertTrue(Regex("^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$").matches(id))
    }

    @Test
    fun uuid7IsMonotonicWithFrozenClock() {
        val gen = Uuid7Generator(nowMs = { 1_700_000_000_000L })
        var prev = gen.next()
        repeat(10_000) {
            val cur = gen.next()
            assertTrue(cur > prev)
            prev = cur
        }
    }

    @Test
    fun uuid7IsMonotonicWhenClockGoesBackwards() {
        var t = 2000L
        val gen = Uuid7Generator(nowMs = { t })
        val a = gen.next()
        t = 1000L
        assertTrue(gen.next() > a)
    }

    @Test
    fun timestampEndsInZ() {
        assertEquals("1970-01-01T00:00:00.000Z", UtcTime.formatEpochMs(0))
        assertTrue(UtcTime.now().endsWith("Z"))
    }
}
