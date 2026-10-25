package org.opennetiq.measurement.voice

import kotlin.math.max

/**
 * Pure outcome rules of the voice and SMS sequences (issue #30, ADR-022,
 * methodology §6c). KPI naming follows ETSI TS 102 250-2.
 */
object VoiceSmsRules {
    /** Accepted dial string: optional +, then 3..20 digits, * or #. */
    private val NUMBER = Regex("^\\+?[0-9*#]{3,20}$")

    fun normalise(number: String): String = number.filterNot { it == ' ' || it == '-' || it == '(' || it == ')' }

    fun isValidNumber(number: String): Boolean = NUMBER.matches(normalise(number))

    /** Only the last two digits are ever returned to Dart or stored. */
    fun mask(number: String): String {
        val n = normalise(number)
        return if (n.length <= 2) "••" else "••${n.takeLast(2)}"
    }

    data class CallOutcome(
        val status: String,
        val outcome: String,
        val setupMs: Long?,
        val connectedS: Int?,
        val dropped: Boolean?,
    )

    /**
     * @param placed the phone entered a call after dialling
     * @param endedByUs we released the call at the end of the window
     * @param wallMs dialling to call end
     * @param connectedS call-log duration (s), null when the call log is unreadable
     * @param setupTimeoutMs a call set up later than this is unsuccessful
     *   (NICTA QoS Rule 2022 Schedule 1: 20 s)
     */
    fun classifyCall(
        placed: Boolean,
        endedByUs: Boolean,
        wallMs: Long,
        connectedS: Int?,
        setupTimeoutMs: Long = Long.MAX_VALUE,
    ): CallOutcome {
        if (!placed) return CallOutcome("failed", "not_placed", null, null, null)
        if (connectedS == null) {
            return CallOutcome("partial", if (endedByUs) "unknown" else "ended_early", null, null, null)
        }
        if (connectedS <= 0) {
            return CallOutcome("failed", if (endedByUs) "no_answer" else "rejected", null, 0, null)
        }
        val setup = max(0L, wallMs - connectedS * 1000L)
        if (setup > setupTimeoutMs) return CallOutcome("failed", "setup_timeout", setup, connectedS, null)
        return if (endedByUs) {
            CallOutcome("ok", "completed", setup, connectedS, false)
        } else {
            CallOutcome("failed", "dropped", setup, connectedS, true)
        }
    }

    /**
     * Voice technology from `TelephonyManager.getVoiceNetworkType()` while in
     * call: GSM/UMTS = circuit switched (incl. CS fallback), VoLTE, VoNR.
     */
    fun voiceRat(networkType: Int): String? = when (networkType) {
        1, 2, 16 -> "GSM"
        3, 8, 9, 10, 15 -> "UMTS"
        13, 19 -> "VoLTE"
        20 -> "VoNR"
        else -> null
    }

    /** Distinct technologies in order of appearance, e.g. `VoLTE>UMTS` (SRVCC). */
    fun ratSequence(seen: List<String>): String? =
        seen.fold(mutableListOf<String>()) { acc, r -> if (acc.lastOrNull() != r) acc += r; acc }
            .takeIf { it.isNotEmpty() }?.joinToString(">")

    data class SmsOutcome(val status: String, val outcome: String)

    /**
     * @param loopback the target is this phone, so the message must arrive
     * @param delivered delivery report: true ok, false failed, null none
     */
    fun classifySms(sent: Boolean, loopback: Boolean, delivered: Boolean?, received: Boolean): SmsOutcome = when {
        !sent -> SmsOutcome("failed", "not_sent")
        loopback && received -> SmsOutcome("ok", "received")
        loopback -> SmsOutcome("partial", "not_received")
        delivered == true -> SmsOutcome("ok", "delivered")
        delivered == false -> SmsOutcome("failed", "delivery_failed")
        else -> SmsOutcome("partial", "no_report")
    }

    /** GSM TP-Status 0x00..0x1F = short message received by the SME. */
    fun deliveredStatus(tpStatus: Int): Boolean = tpStatus in 0x00..0x1F

    private const val TOKEN_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    fun token(random: kotlin.random.Random = kotlin.random.Random.Default): String =
        "ONQ" + (1..6).map { TOKEN_CHARS[random.nextInt(TOKEN_CHARS.length)] }.joinToString("")

    fun body(token: String): String = "OpenNetIQ test $token"
}
