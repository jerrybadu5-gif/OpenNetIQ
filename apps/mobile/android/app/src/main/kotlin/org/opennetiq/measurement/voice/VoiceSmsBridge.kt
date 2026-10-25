package org.opennetiq.measurement.voice

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Voice and SMS tests over MethodChannel `org.opennetiq/voice_sms`
 * (issue #30). Methods: permissions, request_permissions, call, sms, cancel.
 */
class VoiceSmsBridge(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val calls = CallProbe(appContext)
    private val sms = SmsProbe(appContext)
    private var pendingPermissions: MethodChannel.Result? = null

    @Volatile var activity: Activity? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissions" -> result.success(status())
            "request_permissions" -> request(result)
            "call" -> {
                val number = call.argument<String>("number") ?: return badArgs(result)
                val window = (call.argument<Number>("window_ms") ?: 140_000).toLong().coerceIn(10_000, 600_000)
                val setupTimeout = (call.argument<Number>("setup_timeout_ms") ?: 20_000).toLong().coerceIn(1_000, window)
                io.execute {
                    val r = calls.run(number, window, setupTimeout)
                    main.post { result.success(r) }
                }
            }
            "sms" -> sms.run(
                call.argument<String>("number") ?: return badArgs(result),
                call.argument<Boolean>("loopback") ?: false,
                (call.argument<Number>("timeout_ms") ?: 60_000).toLong().coerceIn(5_000, 600_000),
            ) { result.success(it) }
            "cancel" -> {
                calls.cancel()
                sms.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun granted(p: String) =
        appContext.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    private fun status(): Map<String, Any> = mapOf(
        "call" to granted(Manifest.permission.CALL_PHONE),
        "end_call" to granted(Manifest.permission.ANSWER_PHONE_CALLS),
        "call_log" to granted(Manifest.permission.READ_CALL_LOG),
        "send_sms" to granted(Manifest.permission.SEND_SMS),
        "receive_sms" to granted(Manifest.permission.RECEIVE_SMS),
        "has_telephony" to appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
    )

    private fun request(result: MethodChannel.Result) {
        if (pendingPermissions != null) {
            result.error("IN_PROGRESS", "A permission request is already showing.", null)
            return
        }
        val missing = PERMISSIONS.filterNot(::granted)
        if (missing.isEmpty()) return result.success(status())
        val host = activity ?: return result.error("NO_ACTIVITY", "Open the app to grant permissions.", null)
        pendingPermissions = result
        host.requestPermissions(missing.toTypedArray(), REQUEST_CODE)
    }

    /** Forwarded by MainActivity; true when the code was ours. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermissions?.success(status())
        pendingPermissions = null
        return true
    }

    private fun badArgs(result: MethodChannel.Result) =
        result.error("BAD_ARGS", "Missing argument", null)

    fun dispose() {
        channel.setMethodCallHandler(null)
        calls.cancel()
        sms.cancel()
        io.shutdownNow()
    }

    companion object {
        const val CHANNEL = "org.opennetiq/voice_sms"
        const val REQUEST_CODE = 0x4E56 // "NV"
        val PERMISSIONS = listOf(
            Manifest.permission.CALL_PHONE,
            Manifest.permission.ANSWER_PHONE_CALLS,
            Manifest.permission.READ_CALL_LOG,
            Manifest.permission.SEND_SMS,
            Manifest.permission.RECEIVE_SMS,
        )
    }
}
