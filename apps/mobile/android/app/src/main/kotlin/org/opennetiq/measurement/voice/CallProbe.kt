package org.opennetiq.measurement.voice

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.SystemClock
import android.provider.CallLog
import android.telecom.TelecomManager

/**
 * One mobile-originated test call (issue #30): dial, keep the call for the
 * window counted from dialling, release, then read the connected duration
 * of that call from the call log. Answer detection is not available to
 * non-dialer apps, so the setup time is derived as window - connected time
 * (1 s resolution, ADR-022). Blocking: run off the main thread.
 */
class CallProbe(context: Context) {
    private val appContext = context.applicationContext
    private val telecom = appContext.getSystemService(TelecomManager::class.java)

    @Volatile private var cancelled = false

    fun cancel() {
        cancelled = true
    }

    private fun granted(p: String) =
        appContext.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    @SuppressLint("MissingPermission")
    private fun inCall(): Boolean = try {
        telecom?.isInCall == true
    } catch (e: SecurityException) {
        false
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun endCall(): Boolean = try {
        telecom?.endCall() == true
    } catch (e: SecurityException) {
        false
    }

    @SuppressLint("MissingPermission")
    fun run(number: String, windowMs: Long): Map<String, Any?> {
        cancelled = false
        val n = VoiceSmsRules.normalise(number)
        val masked = VoiceSmsRules.mask(n)
        fun fail(error: String) = mapOf("status" to "failed", "outcome" to "not_placed", "target_masked" to masked, "error" to error)
        if (!VoiceSmsRules.isValidNumber(n)) return fail("Invalid number")
        if (!granted(Manifest.permission.CALL_PHONE)) return fail("Call permission not granted")
        if (telecom == null) return fail("No telephony")
        if (inCall()) return fail("Phone is already in a call")
        val dialWall = System.currentTimeMillis()
        val dialAt = SystemClock.elapsedRealtime()
        try {
            telecom.placeCall(Uri.fromParts("tel", n, null), null)
        } catch (e: SecurityException) {
            return fail("Call permission not granted")
        } catch (e: RuntimeException) {
            return fail(e.message ?: "Call could not be placed")
        }
        // Wait for the call to appear (max 10 s).
        var placed = false
        while (SystemClock.elapsedRealtime() - dialAt < PLACE_TIMEOUT_MS && !cancelled) {
            if (inCall()) {
                placed = true
                break
            }
            SystemClock.sleep(POLL_MS)
        }
        var endedByUs = false
        if (placed) {
            while (!cancelled) {
                if (!inCall()) break
                if (SystemClock.elapsedRealtime() - dialAt >= windowMs) {
                    endedByUs = true
                    endCall()
                    break
                }
                SystemClock.sleep(POLL_MS)
            }
            if (cancelled) {
                endCall()
                endedByUs = true
            }
            // Wait for release (max 5 s).
            val releaseStart = SystemClock.elapsedRealtime()
            while (inCall() && SystemClock.elapsedRealtime() - releaseStart < RELEASE_TIMEOUT_MS) {
                SystemClock.sleep(POLL_MS)
            }
        }
        val wallMs = SystemClock.elapsedRealtime() - dialAt
        val connected = if (placed) connectedSeconds(dialWall) else null
        val o = VoiceSmsRules.classifyCall(placed, endedByUs, wallMs, connected)
        return mapOf(
            "status" to o.status,
            "outcome" to o.outcome,
            "target_masked" to masked,
            "window_s" to (windowMs / 1000).toInt(),
            "call_ms" to wallMs.toDouble(),
            "setup_ms" to o.setupMs?.toDouble(),
            "connected_s" to o.connectedS,
            "dropped" to o.dropped,
            "error" to when {
                cancelled -> "cancelled"
                placed && connected == null -> "Call log not readable: setup time unknown"
                !placed -> "Call was not placed"
                else -> null
            },
        )
    }

    /**
     * Connected duration of the outgoing call started at [dialWall]. Only the
     * DATE, TYPE and DURATION columns are read (never the number). The row is
     * written shortly after release, so the query is retried for 5 s.
     */
    private fun connectedSeconds(dialWall: Long): Int? {
        if (!granted(Manifest.permission.READ_CALL_LOG)) return null
        val start = SystemClock.elapsedRealtime()
        while (SystemClock.elapsedRealtime() - start < CALL_LOG_TIMEOUT_MS) {
            try {
                appContext.contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    arrayOf(CallLog.Calls.DURATION),
                    "${CallLog.Calls.TYPE} = ? AND ${CallLog.Calls.DATE} >= ?",
                    arrayOf(CallLog.Calls.OUTGOING_TYPE.toString(), (dialWall - CLOCK_SLACK_MS).toString()),
                    "${CallLog.Calls.DATE} DESC",
                )?.use { c ->
                    if (c.moveToFirst()) return c.getInt(0)
                }
            } catch (e: SecurityException) {
                return null
            }
            SystemClock.sleep(500)
        }
        return null
    }

    private companion object {
        const val POLL_MS = 200L
        const val PLACE_TIMEOUT_MS = 10_000L
        const val RELEASE_TIMEOUT_MS = 5_000L
        const val CALL_LOG_TIMEOUT_MS = 5_000L
        const val CLOCK_SLACK_MS = 3_000L
    }
}
