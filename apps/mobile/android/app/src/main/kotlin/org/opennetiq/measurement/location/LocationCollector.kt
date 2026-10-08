package org.opennetiq.measurement.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock

/**
 * Raw GNSS positions from `LocationManager.GPS_PROVIDER` (ADR-006: no Google
 * Play Services, no fused smoothing). Emits a [LocationStatus] every interval
 * with the latest fix, its age, quality and satellite counts.
 *
 * Must be started and stopped on the main thread.
 */
class LocationCollector(private val context: Context) {
    private val locationManager: LocationManager? = context.getSystemService(LocationManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var tick: Runnable? = null
    private var listener: LocationListener? = null
    private var gnssCallback: GnssStatus.Callback? = null

    private var latestFix: LocationFix? = null
    private var latestFixElapsedNanos: Long = 0L
    private var satellitesUsed: Int? = null
    private var satellitesVisible: Int? = null

    fun start(
        intervalMs: Long,
        onStatus: (LocationStatus) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
        stop()
        val lm = locationManager
        if (lm == null || !context.packageManager.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)) {
            onError(ERROR_NO_GNSS, "This device has no GPS receiver.")
            return
        }
        if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            onError(ERROR_PERMISSION_DENIED, "Precise location permission is required for GPS.")
            return
        }
        try {
            register(lm, intervalMs)
        } catch (e: SecurityException) {
            stop()
            onError(ERROR_PERMISSION_DENIED, e.message ?: "Permission revoked.")
            return
        }
        val runnable = object : Runnable {
            override fun run() {
                onStatus(currentStatus(lm))
                handler.postDelayed(this, intervalMs)
            }
        }
        tick = runnable
        handler.post(runnable)
    }

    fun stop() {
        tick?.let { handler.removeCallbacks(it) }
        tick = null
        val lm = locationManager
        listener?.let { lm?.removeUpdates(it) }
        listener = null
        gnssCallback?.let { lm?.unregisterGnssStatusCallback(it) }
        gnssCallback = null
        latestFix = null
        latestFixElapsedNanos = 0L
        satellitesUsed = null
        satellitesVisible = null
    }

    @SuppressLint("MissingPermission")
    private fun register(lm: LocationManager, intervalMs: Long) {
        val locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) = onLocation(location)

            // Overridden explicitly: on API 29 these are abstract (no default methods).
            override fun onProviderEnabled(provider: String) = Unit

            override fun onProviderDisabled(provider: String) {
                latestFix = null
            }

            @Deprecated("Deprecated in Java")
            @Suppress("DEPRECATION")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        }
        lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, intervalMs, 0f, locationListener, Looper.getMainLooper())
        listener = locationListener

        val callback = object : GnssStatus.Callback() {
            override fun onSatelliteStatusChanged(status: GnssStatus) {
                var used = 0
                for (i in 0 until status.satelliteCount) {
                    if (status.usedInFix(i)) used++
                }
                satellitesUsed = used
                satellitesVisible = status.satelliteCount
            }

            override fun onStopped() {
                satellitesUsed = null
                satellitesVisible = null
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lm.registerGnssStatusCallback(context.mainExecutor, callback)
        } else {
            lm.registerGnssStatusCallback(callback, handler)
        }
        gnssCallback = callback
    }

    private fun onLocation(location: Location) {
        val fix = LocationRules.fix(
            timeEpochMs = location.time,
            lat = location.latitude,
            lon = location.longitude,
            altitudeM = if (location.hasAltitude()) location.altitude else null,
            speedMps = if (location.hasSpeed()) location.speed.toDouble() else null,
            bearingDeg = if (location.hasBearing()) location.bearing.toDouble() else null,
            hAccuracyM = if (location.hasAccuracy()) location.accuracy.toDouble() else null,
            vAccuracyM = if (location.hasVerticalAccuracy()) location.verticalAccuracyMeters.toDouble() else null,
            provider = location.provider ?: LocationManager.GPS_PROVIDER,
            isMock = isMock(location),
        ) ?: return
        latestFix = fix
        latestFixElapsedNanos = location.elapsedRealtimeNanos
    }

    private fun currentStatus(lm: LocationManager): LocationStatus {
        val fix = latestFix
        val ageMs = if (fix != null) (SystemClock.elapsedRealtimeNanos() - latestFixElapsedNanos) / 1_000_000L else null
        return LocationRules.status(
            nowEpochMs = System.currentTimeMillis(),
            providerEnabled = lm.isProviderEnabled(LocationManager.GPS_PROVIDER),
            latest = fix,
            fixAgeMs = ageMs?.coerceAtLeast(0L),
            satellitesUsed = satellitesUsed,
            satellitesVisible = satellitesVisible,
        )
    }

    private fun isMock(location: Location): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) location.isMock else legacyIsMock(location)

    @Suppress("DEPRECATION")
    private fun legacyIsMock(location: Location): Boolean = location.isFromMockProvider

    companion object {
        const val ERROR_PERMISSION_DENIED = "PERMISSION_DENIED"
        const val ERROR_NO_GNSS = "NO_GNSS"
    }
}
