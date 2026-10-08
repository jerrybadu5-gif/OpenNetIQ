package org.opennetiq.measurement.bridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opennetiq.measurement.radio.RadioCollector

/**
 * Native side of the measurement platform channels.
 * Contract: docs/features/signal-monitor/API.md (ADR-013).
 * Never exposes IMEI, IMSI, ICCID, MSISDN or other subscriber identifiers.
 */
class MeasurementBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val collector = RadioCollector(activity.applicationContext)
    private val controlChannel = MethodChannel(messenger, CONTROL_CHANNEL)
    private val radioChannel = EventChannel(messenger, RADIO_CHANNEL)
    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        controlChannel.setMethodCallHandler(this)
        radioChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(permissionStatus())
            "requestPermissions" -> requestPermissions(result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val requested = ((arguments as? Map<*, *>)?.get("interval_ms") as? Number)?.toLong()
        val intervalMs = (requested ?: DEFAULT_INTERVAL_MS).coerceIn(MIN_INTERVAL_MS, MAX_INTERVAL_MS)
        collector.start(
            intervalMs = intervalMs,
            onSnapshot = { events.success(it.toMap()) },
            onError = { code, message -> events.error(code, message, null) },
        )
    }

    override fun onCancel(arguments: Any?) {
        collector.stop()
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        pendingPermissionResult?.success(permissionStatus())
        pendingPermissionResult = null
        return true
    }

    fun dispose() {
        collector.stop()
        controlChannel.setMethodCallHandler(null)
        radioChannel.setStreamHandler(null)
        pendingPermissionResult?.error("CANCELLED", "Activity destroyed", null)
        pendingPermissionResult = null
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("IN_PROGRESS", "A permission request is already showing.", null)
            return
        }
        val missing = REQUIRED_PERMISSIONS.filterNot(::isGranted)
        if (missing.isEmpty()) {
            result.success(permissionStatus())
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private fun permissionStatus(): Map<String, Any> = mapOf(
        "location" to isGranted(Manifest.permission.ACCESS_FINE_LOCATION),
        "phone_state" to isGranted(Manifest.permission.READ_PHONE_STATE),
        "has_telephony" to activity.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
        "api_level" to Build.VERSION.SDK_INT,
    )

    private fun isGranted(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        const val CONTROL_CHANNEL = "org.opennetiq/measurement"
        const val RADIO_CHANNEL = "org.opennetiq/radio"
        private const val PERMISSION_REQUEST_CODE = 0x4E51 // "NQ"
        private const val DEFAULT_INTERVAL_MS = 1_000L
        private const val MIN_INTERVAL_MS = 500L
        private const val MAX_INTERVAL_MS = 10_000L
        private val REQUIRED_PERMISSIONS = listOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.ACCESS_COARSE_LOCATION,
            Manifest.permission.READ_PHONE_STATE,
        )
    }
}
