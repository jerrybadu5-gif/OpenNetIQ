package org.opennetiq.measurement.location

import org.opennetiq.core.UtcTime

/**
 * Pure GNSS validation and quality rules
 * (docs/standards/MEASUREMENT-METHODOLOGY.md section 1, DATA-DICTIONARY `samples`).
 */
object LocationRules {
    /** Fix older than this is POOR. */
    const val MAX_FIX_AGE_MS = 2_000L

    /** Horizontal accuracy worse than this is POOR. */
    const val MAX_H_ACCURACY_M = 50.0

    /** A fix older than this is dropped entirely (reported as NONE). */
    const val DISCARD_FIX_AGE_MS = 30_000L

    fun quality(fixAgeMs: Long?, hAccuracyM: Double?): GpsQuality = when {
        fixAgeMs == null || fixAgeMs > DISCARD_FIX_AGE_MS -> GpsQuality.NONE
        fixAgeMs > MAX_FIX_AGE_MS -> GpsQuality.POOR
        hAccuracyM == null || hAccuracyM > MAX_H_ACCURACY_M -> GpsQuality.POOR
        else -> GpsQuality.GOOD
    }

    /**
     * Builds a validated fix from raw Location values (null = not reported).
     * Returns null when the position itself is invalid.
     */
    fun fix(
        timeEpochMs: Long,
        lat: Double,
        lon: Double,
        altitudeM: Double?,
        speedMps: Double?,
        bearingDeg: Double?,
        hAccuracyM: Double?,
        vAccuracyM: Double?,
        provider: String,
        isMock: Boolean,
    ): LocationFix? {
        if (!lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) return null
        if (lat == 0.0 && lon == 0.0) return null // "null island": uninitialised receiver
        if (timeEpochMs <= 0L) return null
        return LocationFix(
            fixTime = UtcTime.formatEpochMs(timeEpochMs),
            lat = lat,
            lon = lon,
            altitudeM = altitudeM?.takeIf { it.isFinite() && it in -500.0..9_000.0 },
            speedMps = speedMps?.takeIf { it.isFinite() && it >= 0.0 },
            bearingDeg = bearingDeg?.takeIf { it.isFinite() && it >= 0.0 && it < 360.0 },
            hAccuracyM = hAccuracyM?.takeIf { it.isFinite() && it > 0.0 },
            vAccuracyM = vAccuracyM?.takeIf { it.isFinite() && it > 0.0 },
            provider = provider,
            isMock = isMock,
        )
    }

    /** Status for one tick given the latest fix and its age. */
    fun status(
        nowEpochMs: Long,
        providerEnabled: Boolean,
        latest: LocationFix?,
        fixAgeMs: Long?,
        satellitesUsed: Int?,
        satellitesVisible: Int?,
    ): LocationStatus {
        val quality = if (!providerEnabled) GpsQuality.NONE else quality(fixAgeMs, latest?.hAccuracyM)
        val keepFix = latest != null && quality != GpsQuality.NONE
        return LocationStatus(
            timestamp = UtcTime.formatEpochMs(nowEpochMs),
            providerEnabled = providerEnabled,
            gpsQuality = quality,
            fixAgeMs = if (keepFix) fixAgeMs else null,
            satellitesUsed = satellitesUsed,
            satellitesVisible = satellitesVisible,
            fix = if (keepFix) latest else null,
        )
    }
}
