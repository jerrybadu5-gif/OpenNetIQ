package org.opennetiq.measurement.location

/**
 * One validated GNSS fix. Field names follow the `samples` table in
 * docs/standards/DATA-DICTIONARY.md (lat, lon, altitude_m, ...).
 */
data class LocationFix(
    val fixTime: String,
    val lat: Double,
    val lon: Double,
    val altitudeM: Double?,
    val speedMps: Double?,
    val bearingDeg: Double?,
    val hAccuracyM: Double?,
    val vAccuracyM: Double?,
    val provider: String,
    val isMock: Boolean,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "fix_time" to fixTime,
        "lat" to lat,
        "lon" to lon,
        "altitude_m" to altitudeM,
        "speed_mps" to speedMps,
        "bearing_deg" to bearingDeg,
        "h_accuracy_m" to hAccuracyM,
        "v_accuracy_m" to vAccuracyM,
        "provider" to provider,
        "is_mock" to isMock,
    )
}

/** Location state at one sampling tick: the latest fix (if any) plus GNSS status. */
data class LocationStatus(
    val timestamp: String,
    val providerEnabled: Boolean,
    val gpsQuality: GpsQuality,
    val fixAgeMs: Long?,
    val satellitesUsed: Int?,
    val satellitesVisible: Int?,
    val fix: LocationFix?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "timestamp" to timestamp,
        "provider_enabled" to providerEnabled,
        "gps_quality" to gpsQuality.name,
        "fix_age_ms" to fixAgeMs,
        "satellites_used" to satellitesUsed,
        "satellites_visible" to satellitesVisible,
        "fix" to fix?.toMap(),
    )
}

enum class GpsQuality { GOOD, POOR, NONE }
