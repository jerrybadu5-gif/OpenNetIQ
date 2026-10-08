package org.opennetiq.measurement.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class LocationRulesTest {
    private fun fix(
        lat: Double = -9.4438,
        lon: Double = 147.1803,
        altitude: Double? = 35.0,
        speed: Double? = 13.9,
        bearing: Double? = 271.5,
        hAcc: Double? = 4.5,
        vAcc: Double? = 7.0,
        time: Long = 1_791_460_800_000L,
        mock: Boolean = false,
    ) = LocationRules.fix(time, lat, lon, altitude, speed, bearing, hAcc, vAcc, "gps", mock)

    @Test
    fun validFixKeepsAllFields() {
        val f = fix()!!
        assertEquals(-9.4438, f.lat, 0.0)
        assertEquals(147.1803, f.lon, 0.0)
        assertEquals(35.0, f.altitudeM!!, 0.0)
        assertEquals(13.9, f.speedMps!!, 0.0)
        assertEquals(271.5, f.bearingDeg!!, 0.0)
        assertEquals(4.5, f.hAccuracyM!!, 0.0)
        assertEquals(7.0, f.vAccuracyM!!, 0.0)
        assertEquals("2026-10-08T12:00:00.000Z", f.fixTime)
        assertEquals("gps", f.provider)
        assertFalse(f.isMock)
    }

    @Test
    fun invalidPositionsAreRejected() {
        assertNull(fix(lat = 91.0))
        assertNull(fix(lon = -180.5))
        assertNull(fix(lat = Double.NaN))
        assertNull(fix(lat = 0.0, lon = 0.0))
        assertNull(fix(time = 0L))
    }

    @Test
    fun invalidOptionalFieldsBecomeNull() {
        val f = fix(altitude = Double.NaN, speed = -1.0, bearing = 360.0, hAcc = 0.0, vAcc = -2.0)!!
        assertNull(f.altitudeM)
        assertNull(f.speedMps)
        assertNull(f.bearingDeg)
        assertNull(f.hAccuracyM)
        assertNull(f.vAccuracyM)
    }

    @Test
    fun qualityFollowsMethodology() {
        assertEquals(GpsQuality.GOOD, LocationRules.quality(500, 10.0))
        assertEquals(GpsQuality.GOOD, LocationRules.quality(2_000, 50.0))
        assertEquals(GpsQuality.POOR, LocationRules.quality(2_001, 10.0))
        assertEquals(GpsQuality.POOR, LocationRules.quality(500, 50.1))
        assertEquals(GpsQuality.POOR, LocationRules.quality(500, null))
        assertEquals(GpsQuality.NONE, LocationRules.quality(null, 10.0))
        assertEquals(GpsQuality.NONE, LocationRules.quality(30_001, 10.0))
    }

    @Test
    fun statusDropsFixWhenProviderDisabledOrTooOld() {
        val f = fix()!!
        val good = LocationRules.status(1_000L, true, f, 800, 9, 14)
        assertEquals(GpsQuality.GOOD, good.gpsQuality)
        assertEquals(f, good.fix)
        assertEquals(800L, good.fixAgeMs)
        assertEquals("1970-01-01T00:00:01.000Z", good.timestamp)

        val disabled = LocationRules.status(1_000L, false, f, 800, null, null)
        assertEquals(GpsQuality.NONE, disabled.gpsQuality)
        assertNull(disabled.fix)
        assertNull(disabled.fixAgeMs)

        val ancient = LocationRules.status(1_000L, true, f, 60_000, 0, 3)
        assertEquals(GpsQuality.NONE, ancient.gpsQuality)
        assertNull(ancient.fix)
    }

    @Test
    fun mapsUseDataDictionaryKeys() {
        val f = fix(mock = true)!!
        val map = LocationRules.status(1_000L, true, f, 3_000, 4, 11).toMap()
        assertEquals("POOR", map["gps_quality"])
        assertEquals(true, map["provider_enabled"])
        assertEquals(3_000L, map["fix_age_ms"])
        assertEquals(4, map["satellites_used"])
        assertEquals(11, map["satellites_visible"])
        @Suppress("UNCHECKED_CAST")
        val fixMap = map["fix"] as Map<String, Any?>
        assertEquals(-9.4438, fixMap["lat"])
        assertEquals(true, fixMap["is_mock"])
        assertTrue(fixMap.keys.containsAll(listOf("lat", "lon", "altitude_m", "speed_mps", "bearing_deg", "h_accuracy_m", "v_accuracy_m", "fix_time", "provider")))
        assertEquals(10, fixMap.size)

        val none = LocationRules.status(1_000L, true, null, null, null, null).toMap()
        assertNull(none["fix"])
        assertEquals("NONE", none["gps_quality"])
    }
}
