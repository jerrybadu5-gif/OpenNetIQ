package org.opennetiq.measurement.radio

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.CellInfo
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyDisplayInfo
import android.telephony.TelephonyManager
import org.opennetiq.core.UtcTime

/**
 * Periodically refreshes cell info with `requestCellInfoUpdate` (bypasses the
 * stale `getAllCellInfo` cache) and emits a [RadioSnapshot] per tick.
 * Tracks the TelephonyDisplayInfo override for 5G NSA detection.
 *
 * Must be started and stopped on the main thread.
 */
class RadioCollector(
    private val context: Context,
    private val gnbIdLengthBits: Int = CellIdentityMath.DEFAULT_GNB_ID_LENGTH,
) {
    private val telephony: TelephonyManager? = context.getSystemService(TelephonyManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var tick: Runnable? = null
    private var displayInfoCallback: Any? = null

    @Volatile
    private var overrideNetworkType = NetworkTypeResolver.OVERRIDE_NONE

    fun start(
        intervalMs: Long,
        onSnapshot: (RadioSnapshot) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
        stop()
        val tm = telephony
        if (tm == null || !context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) {
            onError(ERROR_NO_TELEPHONY, "This device has no cellular radio.")
            return
        }
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            onError(ERROR_PERMISSION_DENIED, "Precise location permission is required to read cell information.")
            return
        }
        registerDisplayInfo(tm)
        val runnable = object : Runnable {
            override fun run() {
                requestUpdate(tm, onSnapshot, onError)
                handler.postDelayed(this, intervalMs)
            }
        }
        tick = runnable
        handler.post(runnable)
    }

    fun stop() {
        tick?.let { handler.removeCallbacks(it) }
        tick = null
        telephony?.let(::unregisterDisplayInfo)
        overrideNetworkType = NetworkTypeResolver.OVERRIDE_NONE
    }

    @SuppressLint("MissingPermission")
    private fun requestUpdate(
        tm: TelephonyManager,
        onSnapshot: (RadioSnapshot) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        try {
            tm.requestCellInfoUpdate(
                context.mainExecutor,
                object : TelephonyManager.CellInfoCallback() {
                    override fun onCellInfo(cellInfo: List<CellInfo>) {
                        onSnapshot(buildSnapshot(tm, cellInfo, usedCache = false))
                    }

                    override fun onError(errorCode: Int, detail: Throwable?) {
                        val cached = runCatching { tm.allCellInfo }.getOrNull().orEmpty()
                        onSnapshot(buildSnapshot(tm, cached, usedCache = true))
                    }
                },
            )
        } catch (e: SecurityException) {
            stop()
            onError(ERROR_PERMISSION_DENIED, e.message ?: "Permission revoked.")
        }
    }

    @SuppressLint("MissingPermission")
    private fun buildSnapshot(tm: TelephonyManager, cells: List<CellInfo>, usedCache: Boolean): RadioSnapshot {
        val nowMs = System.currentTimeMillis()
        val observations = cells.mapNotNull { CellInfoAdapter.toObservation(it, gnbIdLengthBits) }
        val newestCellMs = cells.maxOfOrNull(CellInfoAdapter::reportedAtEpochMs)
        val hasPhoneState = hasPermission(Manifest.permission.READ_PHONE_STATE)
        val (mcc, mnc) = Plmn.split(tm.networkOperator)
        return RadioSnapshot(
            timestamp = UtcTime.formatEpochMs(nowMs),
            radioTimestamp = newestCellMs?.let(UtcTime::formatEpochMs),
            operatorName = tm.networkOperatorName?.takeIf { it.isNotBlank() },
            mcc = mcc,
            mnc = mnc,
            simOperator = tm.simOperatorName?.takeIf { it.isNotBlank() },
            networkType = NetworkTypeResolver.resolve(
                hasServingCell = observations.any { it.isServing },
                dataNetworkType = if (hasPhoneState) readOrDefault(0) { tm.dataNetworkType } else 0,
                voiceNetworkType = if (hasPhoneState) readOrDefault(0) { tm.voiceNetworkType } else 0,
                overrideNetworkType = overrideNetworkType,
            ),
            dataState = DataStates.name(tm.dataState),
            isRoaming = tm.isNetworkRoaming,
            qualityFlag = RadioSnapshot.snapshotFlags(nowMs, newestCellMs, hasPhoneState, usedCache),
            cells = observations,
        )
    }

    @SuppressLint("MissingPermission")
    private fun registerDisplayInfo(tm: TelephonyManager) {
        if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val callback = object : TelephonyCallback(), TelephonyCallback.DisplayInfoListener {
                    override fun onDisplayInfoChanged(telephonyDisplayInfo: TelephonyDisplayInfo) {
                        overrideNetworkType = telephonyDisplayInfo.overrideNetworkType
                    }
                }
                tm.registerTelephonyCallback(context.mainExecutor, callback)
                displayInfoCallback = callback
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val listener = LegacyDisplayInfoListener(context) { overrideNetworkType = it }
                @Suppress("DEPRECATION")
                tm.listen(listener, PhoneStateListener.LISTEN_DISPLAY_INFO_CHANGED)
                displayInfoCallback = listener
            }
            // API 29: no display info, 5G NSA cannot be detected (reported as LTE).
        } catch (e: SecurityException) {
            displayInfoCallback = null
        }
    }

    private fun unregisterDisplayInfo(tm: TelephonyManager) {
        val callback = displayInfoCallback ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && callback is TelephonyCallback) {
            tm.unregisterTelephonyCallback(callback)
        } else if (callback is PhoneStateListener) {
            @Suppress("DEPRECATION")
            tm.listen(callback, PhoneStateListener.LISTEN_NONE)
        }
        displayInfoCallback = null
    }

    private fun hasPermission(permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private inline fun <T> readOrDefault(default: T, block: () -> T): T =
        try {
            block()
        } catch (e: SecurityException) {
            default
        }

    companion object {
        const val ERROR_PERMISSION_DENIED = "PERMISSION_DENIED"
        const val ERROR_NO_TELEPHONY = "NO_TELEPHONY"
    }
}

/** API 30 only: display-info updates through the deprecated PhoneStateListener. */
@Suppress("DEPRECATION")
private class LegacyDisplayInfoListener(
    context: Context,
    private val onOverride: (Int) -> Unit,
) : PhoneStateListener(context.mainExecutor) {
    @Deprecated("Deprecated in Java")
    override fun onDisplayInfoChanged(telephonyDisplayInfo: TelephonyDisplayInfo) {
        onOverride(telephonyDisplayInfo.overrideNetworkType)
    }
}
