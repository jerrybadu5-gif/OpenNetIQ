package org.opennetiq.measurement.bridge

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opennetiq.measurement.location.LocationCollector
import org.opennetiq.measurement.radio.RadioCollector
import org.opennetiq.measurement.service.DriveTestService
import org.opennetiq.measurement.service.DriveTestServiceEvents
import org.opennetiq.measurement.service.RecordingNotificationArgs

/**
 * Native side of the measurement platform channels.
 * Contracts: docs/features/signal-monitor/API.md, docs/features/location/API.md,
 * docs/features/drive-test/API.md (ADR-013, ADR-014).
 * Lives as long as the application-owned engine; the activity is optional and
 * only needed for permission dialogs.
 * Never exposes IMEI, IMSI, ICCID, MSISDN or other subscriber identifiers.
 */
class MeasurementBridge(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, DriveTestServiceEvents.Listener {

    private val appContext = context.applicationContext
    private val collector = RadioCollector(appContext)
    private val locationCollector = LocationCollector(appContext)
    private val controlChannel = MethodChannel(messenger, CONTROL_CHANNEL)
    private val radioChannel = EventChannel(messenger, RADIO_CHANNEL)
    private val locationChannel = EventChannel(messenger, LOCATION_CHANNEL)
    private var activity: Activity? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** Location stream (issue #14): one LocationStatus per interval. */
    private val locationStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            locationCollector.start(
                intervalMs = intervalFrom(arguments),
                onStatus = { events.success(it.toMap()) },
                onError = { code, message -> events.error(code, message, null) },
            )
        }

        override fun onCancel(arguments: Any?) {
            locationCollector.stop()
        }
    }

    init {
        controlChannel.setMethodCallHandler(this)
        radioChannel.setStreamHandler(this)
        locationChannel.setStreamHandler(locationStreamHandler)
        DriveTestServiceEvents.listener = this
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachActivity(activity: Activity) {
        if (this.activity !== activity) return
        this.activity = null
        pendingPermissionResult?.error("CANCELLED", "Activity destroyed", null)
        pendingPermissionResult = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPermissionStatus" -> result.success(permissionStatus())
            "requestPermissions" -> requestPermissions(result)
            "getDeviceInfo" -> result.success(deviceInfo())
            "startRecordingService" -> startRecordingService(call.arguments, result)
            "updateRecordingService" -> {
                DriveTestService.update(appContext, RecordingNotificationArgs.fromChannel(call.arguments))
                result.success(null)
            }
            "stopRecordingService" -> {
                DriveTestService.stop(appContext)
                result.success(null)
            }
            "getBatteryOptimization" -> result.success(mapOf("ignoring" to isIgnoringBatteryOptimizations()))
            "openBatterySettings" -> result.success(openBatterySettings())
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        collector.start(
            intervalMs = intervalFrom(arguments),
            onSnapshot = { events.success(it.toMap()) },
            onError = { code, message -> events.error(code, message, null) },
        )
    }

    override fun onCancel(arguments: Any?) {
        collector.stop()
    }

    // DriveTestServiceEvents.Listener: notification "Stop" -> Dart.
    override fun onStopRequested(onUnhandled: () -> Unit) {
        controlChannel.invokeMethod(
            "onStopRequested",
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (result != true) onUnhandled()
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = onUnhandled()

                override fun notImplemented() = onUnhandled()
            },
        )
    }

    override fun onServiceError(code: String, message: String) {
        controlChannel.invokeMethod("onServiceError", mapOf("code" to code, "message" to message))
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode == NOTIFICATION_REQUEST_CODE) return true
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        pendingPermissionResult?.success(permissionStatus())
        pendingPermissionResult = null
        return true
    }

    fun dispose() {
        collector.stop()
        locationCollector.stop()
        controlChannel.setMethodCallHandler(null)
        radioChannel.setStreamHandler(null)
        locationChannel.setStreamHandler(null)
        if (DriveTestServiceEvents.listener === this) DriveTestServiceEvents.listener = null
        pendingPermissionResult?.error("CANCELLED", "Bridge disposed", null)
        pendingPermissionResult = null
    }

    private fun intervalFrom(arguments: Any?): Long {
        val requested = ((arguments as? Map<*, *>)?.get("interval_ms") as? Number)?.toLong()
        return (requested ?: DEFAULT_INTERVAL_MS).coerceIn(MIN_INTERVAL_MS, MAX_INTERVAL_MS)
    }

    private fun startRecordingService(arguments: Any?, result: MethodChannel.Result) {
        if (!isGranted(Manifest.permission.ACCESS_FINE_LOCATION)) {
            result.error("PERMISSION_DENIED", "Precise location is required for drive tests.", null)
            return
        }
        requestNotificationPermissionIfNeeded()
        try {
            DriveTestService.start(appContext, RecordingNotificationArgs.fromChannel(arguments))
            result.success(null)
        } catch (e: RuntimeException) {
            // e.g. ForegroundServiceStartNotAllowedException when not visible.
            result.error("SERVICE_UNAVAILABLE", e.message ?: e.javaClass.simpleName, null)
        }
    }

    /** Android 13+: without it the ongoing notification is hidden (service still runs). */
    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (isGranted(Manifest.permission.POST_NOTIFICATIONS)) return
        activity?.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_REQUEST_CODE)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(appContext.packageName)
    }

    /** Opens the battery-optimisation list (no special permission required). */
    private fun openBatterySettings(): Boolean {
        val primary = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", appContext.packageName, null))
        for (intent in listOf(primary, fallback)) {
            try {
                appContext.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return true
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
        return false
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
        val host = activity
        if (host == null) {
            result.error("NO_ACTIVITY", "Open the app to grant permissions.", null)
            return
        }
        pendingPermissionResult = result
        host.requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private fun permissionStatus(): Map<String, Any> = mapOf(
        "location" to isGranted(Manifest.permission.ACCESS_FINE_LOCATION),
        "phone_state" to isGranted(Manifest.permission.READ_PHONE_STATE),
        "has_telephony" to appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
        "api_level" to Build.VERSION.SDK_INT,
    )

    /** `devices` row fields (DATA-DICTIONARY.md). No IMEI or other identifiers. */
    private fun deviceInfo(): Map<String, Any?> = mapOf(
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "android_version" to Build.VERSION.RELEASE,
        "api_level" to Build.VERSION.SDK_INT,
        "chipset" to chipset(),
        "app_version" to appVersion(),
    )

    private fun chipset(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Build.SOC_MODEL.takeUnless { it.isBlank() || it == Build.UNKNOWN }
        } else {
            null
        }

    @Suppress("DEPRECATION")
    private fun appVersion(): String =
        try {
            appContext.packageManager.getPackageInfo(appContext.packageName, 0).versionName ?: "unknown"
        } catch (e: PackageManager.NameNotFoundException) {
            "unknown"
        }

    private fun isGranted(permission: String): Boolean =
        appContext.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    companion object {
        const val CONTROL_CHANNEL = "org.opennetiq/measurement"
        const val RADIO_CHANNEL = "org.opennetiq/radio"
        const val LOCATION_CHANNEL = "org.opennetiq/location"
        private const val PERMISSION_REQUEST_CODE = 0x4E51 // "NQ"
        private const val NOTIFICATION_REQUEST_CODE = 0x4E53
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
