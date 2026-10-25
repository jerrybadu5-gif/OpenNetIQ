package org.opennetiq.measurement.voice

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Telephony
import android.telephony.SmsManager
import android.telephony.SmsMessage

/**
 * One SMS test (issue #30): send a tagged message, time the sent and delivery
 * reports and, for a loopback target, the arrival. Message text is only
 * compared in memory with the token, never stored or returned.
 */
class SmsProbe(context: Context) {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var active: Run? = null

    private fun granted(p: String) =
        appContext.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    /** Must be called on the main thread; [done] is called once on it. */
    fun run(number: String, loopback: Boolean, timeoutMs: Long, done: (Map<String, Any?>) -> Unit) {
        val n = VoiceSmsRules.normalise(number)
        val masked = VoiceSmsRules.mask(n)
        fun fail(error: String) = done(
            mapOf("status" to "failed", "outcome" to "not_sent", "target_masked" to masked, "error" to error),
        )
        if (active != null) return fail("An SMS test is already running")
        if (!VoiceSmsRules.isValidNumber(n)) return fail("Invalid number")
        if (!granted(Manifest.permission.SEND_SMS)) return fail("SMS permission not granted")
        if (loopback && !granted(Manifest.permission.RECEIVE_SMS)) return fail("SMS receive permission not granted")
        val run = Run(VoiceSmsRules.token(), masked, loopback, done)
        active = run
        run.start(n, timeoutMs)
    }

    fun cancel() {
        active?.finish("cancelled")
    }

    private inner class Run(
        val token: String,
        val masked: String,
        val loopback: Boolean,
        val done: (Map<String, Any?>) -> Unit,
    ) {
        private val sentAction = "org.opennetiq.SMS_SENT.$token"
        private val deliveredAction = "org.opennetiq.SMS_DELIVERED.$token"
        private var t0 = 0L
        private var sent: Boolean? = null
        private var sendMs: Double? = null
        private var delivered: Boolean? = null
        private var deliveryMs: Double? = null
        private var receiveMs: Double? = null
        private var resultCode: Int? = null
        private var finished = false
        private val receivers = mutableListOf<BroadcastReceiver>()
        private val timeout = Runnable { finish(null) }

        private fun elapsed() = (SystemClock.elapsedRealtime() - t0).toDouble()

        fun start(number: String, timeoutMs: Long) {
            register(IntentFilter(sentAction), exported = false) { _, code ->
                resultCode = code
                sent = code == Activity.RESULT_OK
                sendMs = elapsed()
                if (sent == false) finish(null) else maybeFinish()
            }
            register(IntentFilter(deliveredAction), exported = false) { intent, _ ->
                val pdu = intent.getByteArrayExtra("pdu")
                val format = intent.getStringExtra("format")
                delivered = pdu?.let { SmsMessage.createFromPdu(it, format) }
                    ?.let { VoiceSmsRules.deliveredStatus(it.status) } ?: true
                deliveryMs = elapsed()
                maybeFinish()
            }
            if (loopback) {
                // Protected system broadcast (sender holds BROADCAST_SMS).
                register(IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION), exported = true) { intent, _ ->
                    val bodies = Telephony.Sms.Intents.getMessagesFromIntent(intent)
                        ?.joinToString("") { it?.messageBody ?: "" } ?: ""
                    if (bodies.contains(token)) {
                        receiveMs = elapsed()
                        maybeFinish()
                    }
                }
            }
            t0 = SystemClock.elapsedRealtime()
            main.postDelayed(timeout, timeoutMs)
            try {
                val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    appContext.getSystemService(SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }
                sms.sendTextMessage(number, null, VoiceSmsRules.body(token), pending(sentAction), pending(deliveredAction))
            } catch (e: SecurityException) {
                finish("SMS permission not granted")
            } catch (e: RuntimeException) {
                finish(e.message ?: "SMS could not be sent")
            }
        }

        private fun pending(action: String) = PendingIntent.getBroadcast(
            appContext,
            action.hashCode(),
            Intent(action).setPackage(appContext.packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_ONE_SHOT,
        )

        /** [handler] gets the intent and the broadcast's result code. */
        private fun register(filter: IntentFilter, exported: Boolean, handler: (Intent, Int) -> Unit) {
            val r = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) = handler(intent, this.resultCode)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                appContext.registerReceiver(r, filter, if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED)
            } else {
                appContext.registerReceiver(r, filter)
            }
            receivers += r
        }

        private fun maybeFinish() {
            if (sent != true) return
            if (if (loopback) receiveMs != null else delivered != null) finish(null)
        }

        fun finish(error: String?) {
            if (finished) return
            finished = true
            main.removeCallbacks(timeout)
            for (r in receivers) runCatching { appContext.unregisterReceiver(r) }
            receivers.clear()
            active = null
            val o = VoiceSmsRules.classifySms(sent == true, loopback, delivered, receiveMs != null)
            done(
                mapOf(
                    "status" to o.status,
                    "outcome" to o.outcome,
                    "target_masked" to masked,
                    "loopback" to loopback,
                    "send_ms" to sendMs,
                    "delivery_ms" to deliveryMs,
                    "receive_ms" to receiveMs,
                    "result_code" to resultCode,
                    "error" to (error ?: when {
                        sent == null -> "No sent report before timeout"
                        sent == false -> "Send failed (result $resultCode)"
                        o.status == "partial" && loopback -> "Not received before timeout"
                        o.status == "partial" -> "No delivery report before timeout"
                        else -> null
                    }),
                ),
            )
        }
    }
}
