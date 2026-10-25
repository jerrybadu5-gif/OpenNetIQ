package org.opennetiq.measurement.voice

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class VoiceSmsRulesTest {
    @Test
    fun `numbers are validated and masked to two digits`() {
        assertTrue(VoiceSmsRules.isValidNumber("+675 7123-4567"))
        assertTrue(VoiceSmsRules.isValidNumber("*100#"))
        assertFalse(VoiceSmsRules.isValidNumber("12"))
        assertFalse(VoiceSmsRules.isValidNumber("abc123"))
        assertEquals("••67", VoiceSmsRules.mask("+675 7123 4567"))
        assertEquals("••", VoiceSmsRules.mask("7"))
    }

    @Test
    fun `completed call derives setup time from the call log duration`() {
        val o = VoiceSmsRules.classifyCall(placed = true, endedByUs = true, wallMs = 45_400, connectedS = 39)
        assertEquals("ok", o.status)
        assertEquals("completed", o.outcome)
        assertEquals(6_400L, o.setupMs)
        assertEquals(false, o.dropped)
    }

    @Test
    fun `early release after connection is a drop`() {
        val o = VoiceSmsRules.classifyCall(placed = true, endedByUs = false, wallMs = 20_000, connectedS = 14)
        assertEquals("failed", o.status)
        assertEquals("dropped", o.outcome)
        assertEquals(true, o.dropped)
    }

    @Test
    fun `unanswered and rejected calls are setup failures`() {
        assertEquals("no_answer", VoiceSmsRules.classifyCall(true, true, 45_000, 0).outcome)
        val rejected = VoiceSmsRules.classifyCall(true, false, 8_000, 0)
        assertEquals("rejected", rejected.outcome)
        assertNull(rejected.setupMs)
        assertEquals("not_placed", VoiceSmsRules.classifyCall(false, false, 10_000, null).outcome)
    }

    @Test
    fun `missing call log gives a partial result`() {
        val o = VoiceSmsRules.classifyCall(true, true, 45_000, null)
        assertEquals("partial", o.status)
        assertNull(o.setupMs)
        assertEquals("ended_early", VoiceSmsRules.classifyCall(true, false, 9_000, null).outcome)
    }

    @Test
    fun `calls set up after the setup timeout are unsuccessful`() {
        // NICTA Schedule 1: 20 s setup + 120 s hold = 140 s from dialling.
        val ok = VoiceSmsRules.classifyCall(true, true, 140_300, 128, setupTimeoutMs = 20_000)
        assertEquals("completed", ok.outcome)
        assertEquals(12_300L, ok.setupMs)
        val late = VoiceSmsRules.classifyCall(true, true, 140_300, 115, setupTimeoutMs = 20_000)
        assertEquals("failed", late.status)
        assertEquals("setup_timeout", late.outcome)
        assertEquals(25_300L, late.setupMs)
        assertNull(late.dropped)
    }

    @Test
    fun `setup time never goes negative`() {
        assertEquals(0L, VoiceSmsRules.classifyCall(true, true, 44_800, 45).setupMs)
    }

    @Test
    fun `voice technology and sequence`() {
        assertEquals("GSM", VoiceSmsRules.voiceRat(16))
        assertEquals("UMTS", VoiceSmsRules.voiceRat(15))
        assertEquals("VoLTE", VoiceSmsRules.voiceRat(13))
        assertEquals("VoNR", VoiceSmsRules.voiceRat(20))
        assertNull(VoiceSmsRules.voiceRat(0))
        assertEquals("VoLTE>UMTS", VoiceSmsRules.ratSequence(listOf("VoLTE", "VoLTE", "UMTS", "UMTS")))
        assertNull(VoiceSmsRules.ratSequence(emptyList()))
    }

    @Test
    fun `sms outcomes`() {
        assertEquals("not_sent", VoiceSmsRules.classifySms(false, true, null, false).outcome)
        assertEquals("received", VoiceSmsRules.classifySms(true, true, null, true).outcome)
        assertEquals("not_received", VoiceSmsRules.classifySms(true, true, true, false).outcome)
        assertEquals("delivered", VoiceSmsRules.classifySms(true, false, true, false).outcome)
        assertEquals("delivery_failed", VoiceSmsRules.classifySms(true, false, false, false).outcome)
        assertEquals("no_report", VoiceSmsRules.classifySms(true, false, null, false).outcome)
    }

    @Test
    fun `delivery status and token`() {
        assertTrue(VoiceSmsRules.deliveredStatus(0))
        assertFalse(VoiceSmsRules.deliveredStatus(0x40))
        val t = VoiceSmsRules.token(Random(7))
        assertTrue(t.matches(Regex("^ONQ[A-Z2-9]{6}$")))
        assertTrue(VoiceSmsRules.body(t).endsWith(t))
    }
}
