package org.opennetiq.measurement.service

import org.junit.Assert.assertEquals
import org.junit.Test

class RecordingNotificationArgsTest {
    @Test
    fun readsTitleAndTextFromChannelMap() {
        val args = RecordingNotificationArgs.fromChannel(mapOf("title" to " Drive test ", "text" to "120 samples"))
        assertEquals("Drive test", args.title)
        assertEquals("120 samples", args.text)
    }

    @Test
    fun fallsBackToDefaultsForMissingOrBlankValues() {
        assertEquals(RecordingNotificationArgs(RecordingNotificationArgs.DEFAULT_TITLE, ""), RecordingNotificationArgs.fromChannel(null))
        assertEquals(RecordingNotificationArgs.DEFAULT_TITLE, RecordingNotificationArgs.of("   ", null).title)
        assertEquals(RecordingNotificationArgs.DEFAULT_TITLE, RecordingNotificationArgs.fromChannel(mapOf("title" to 42)).title)
    }

    @Test
    fun truncatesOverlongValues() {
        val args = RecordingNotificationArgs.of("t".repeat(500), "x".repeat(500))
        assertEquals(RecordingNotificationArgs.MAX_TITLE, args.title.length)
        assertEquals(RecordingNotificationArgs.MAX_TEXT, args.text.length)
    }
}
