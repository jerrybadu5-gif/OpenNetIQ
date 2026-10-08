package org.opennetiq.measurement.radio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

private const val NA = RadioRanges.UNAVAILABLE

class CellIdentityMathTest {
    @Test
    fun enbAndLocalCellIdSplitTheEci() {
        // ECI 0x1A2B3C4 = eNB 0x1A2B3, cell 0xC4
        assertEquals(0x1A2B3, CellIdentityMath.enbId(0x1A2B3C4))
        assertEquals(0xC4, CellIdentityMath.localCellId(0x1A2B3C4))
    }

    @Test
    fun gnbIdUsesConfigurableLength() {
        val nci = 0xABCDEF123L // 36-bit NCI
        assertEquals(0xABCDEFL, CellIdentityMath.gnbId(nci)) // default 24 bits
        assertEquals(0xABCDEF123L ushr 14, CellIdentityMath.gnbId(nci, 22))
        assertEquals(0xABCDEF12L, CellIdentityMath.gnbId(nci, 32))
    }

    @Test
    fun gnbIdRejectsInvalidLength() {
        try {
            CellIdentityMath.gnbId(1L, 21)
            fail("expected IllegalArgumentException")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("22..32"))
        }
    }
}

class CellObservationsTest {
    private fun lte(
        rsrp: Int = -95,
        rsrq: Int = -11,
        rssnr: Int = 12,
        eci: Int = 0x1A2B3C4,
        tac: Int = 1201,
        mcc: String? = "537",
        mnc: String? = "03",
    ) = CellObservations.lte(
        isServing = true, mcc = mcc, mnc = mnc, tac = tac, eci = eci, pci = 301, earfcn = 9410,
        band = 28, bandwidthKhz = 10_000, rsrp = rsrp, rsrq = rsrq, rssnr = rssnr, rssi = -65,
        cqi = 9, timingAdvance = 4,
    )

    @Test
    fun lteMapsAllFieldsAndDerivesEnb() {
        val cell = lte()
        assertEquals(Rat.LTE, cell.rat)
        assertEquals("537", cell.mcc)
        assertEquals("03", cell.mnc)
        assertEquals(1201, cell.lacTac)
        assertEquals(0x1A2B3C4L, cell.cellId)
        assertEquals(0x1A2B3, cell.enbId)
        assertEquals(0xC4, cell.localCellId)
        assertEquals(301, cell.pciPscBsic)
        assertEquals(9410, cell.arfcn)
        assertEquals("B28", cell.band)
        assertEquals(10_000, cell.bandwidthKhz)
        assertEquals(-95, cell.rsrpDbm)
        assertEquals(-11, cell.rsrqDb)
        assertEquals(12, cell.sinrDb)
        assertEquals(-65, cell.rssiDbm)
        assertEquals(9, cell.cqi)
        assertEquals(4, cell.timingAdvance)
        assertNull(cell.qualityFlag)
    }

    @Test
    fun unavailablePrimaryMetricIsNullAndFlagged() {
        val cell = lte(rsrp = NA)
        assertNull(cell.rsrpDbm)
        assertEquals("UNAVAILABLE", cell.qualityFlag)
    }

    @Test
    fun unavailableSecondaryMetricIsNullWithoutFlag() {
        val cell = lte(rssnr = NA)
        assertNull(cell.sinrDb)
        assertNull(cell.qualityFlag)
    }

    @Test
    fun outOfRangeIsNulledNeverClamped() {
        val cell = lte(rsrp = -30, rsrq = -40)
        assertNull(cell.rsrpDbm)
        assertNull(cell.rsrqDb)
        assertEquals("OUT_OF_RANGE", cell.qualityFlag)
    }

    @Test
    fun flagsAreSortedAndJoined() {
        assertEquals("OUT_OF_RANGE|UNAVAILABLE", lte(rsrp = NA, rsrq = 50).qualityFlag)
    }

    @Test
    fun invalidIdentitiesAreNullWithoutFlags() {
        val cell = lte(eci = NA, tac = NA, mcc = "", mnc = "x1")
        assertNull(cell.cellId)
        assertNull(cell.enbId)
        assertNull(cell.localCellId)
        assertNull(cell.lacTac)
        assertNull(cell.mcc)
        assertNull(cell.mnc)
        assertNull(cell.qualityFlag)
    }

    @Test
    fun nrMapsSsAndCsiMetricsAndDerivesGnb() {
        val cell = CellObservations.nr(
            isServing = false, mcc = "537", mnc = "03", tac = 70_000, nci = 0xABCDEF123L, pci = 900,
            nrArfcn = 640_000, band = 78, ssRsrp = -101, ssRsrq = -12, ssSinr = 8, csiRsrp = -99,
            csiRsrq = -11, csiSinr = NA,
        )
        assertEquals(Rat.NR, cell.rat)
        assertFalse(cell.isServing)
        assertEquals(70_000, cell.lacTac)
        assertEquals(0xABCDEF123L, cell.cellId)
        assertEquals(0xABCDEFL, cell.gnbId)
        assertEquals(900, cell.pciPscBsic)
        assertEquals("n78", cell.band)
        assertEquals(-101, cell.rsrpDbm)
        assertEquals(8, cell.sinrDb)
        assertEquals(-99, cell.csiRsrpDbm)
        assertNull(cell.csiSinrDb)
        assertNull(cell.qualityFlag)
    }

    @Test
    fun nrUnavailableNciGivesNullGnb() {
        val cell = CellObservations.nr(
            isServing = true, mcc = null, mnc = null, tac = NA, nci = RadioRanges.UNAVAILABLE_LONG,
            pci = NA, nrArfcn = NA, band = null, ssRsrp = -150, ssRsrq = NA, ssSinr = NA,
            csiRsrp = NA, csiRsrq = NA, csiSinr = NA,
        )
        assertNull(cell.cellId)
        assertNull(cell.gnbId)
        assertEquals(-150, cell.rsrpDbm) // valid for NR (-156..-31), invalid for LTE
    }

    @Test
    fun gsmAndWcdmaUseTheirPrimaryLevels() {
        val gsm = CellObservations.gsm(true, "537", "01", lac = 100, cid = 2001, arfcn = 62, bsic = 41, rssi = -77)
        assertEquals(Rat.GSM, gsm.rat)
        assertEquals(-77, gsm.rssiDbm)
        assertEquals(41, gsm.pciPscBsic)
        assertEquals(2001L, gsm.cellId)

        val wcdma = CellObservations.wcdma(false, "537", "01", lac = 100, cid = 30_001, psc = 256, uarfcn = 10_700, rscp = -88, ecNo = NA)
        assertEquals(Rat.WCDMA, wcdma.rat)
        assertEquals(-88, wcdma.rscpDbm)
        assertNull(wcdma.ecnoDb)
        assertEquals(256, wcdma.pciPscBsic)
        assertNull(wcdma.qualityFlag)
    }

    @Test
    fun toMapUsesDataDictionaryKeys() {
        val map = lte().toMap()
        assertEquals("LTE", map["rat"])
        assertEquals(true, map["is_serving"])
        assertEquals(-95, map["rsrp_dbm"])
        assertEquals(0x1A2B3, map["enb_id"])
        assertTrue(map.containsKey("csi_sinr_db"))
        assertNull(map["csi_sinr_db"])
        assertEquals(25, map.size)
    }
}

class NetworkTypeResolverTest {
    private fun resolve(data: Int, override: Int = 0, voice: Int = 0, serving: Boolean = true) =
        NetworkTypeResolver.resolve(serving, data, voice, override)

    @Test
    fun mapsLegacyTechnologies() {
        assertEquals("GSM", resolve(16))
        assertEquals("GPRS", resolve(1))
        assertEquals("EDGE", resolve(2))
        assertEquals("UMTS", resolve(3))
        assertEquals("HSPA", resolve(8))
        assertEquals("HSPA", resolve(10))
        assertEquals("HSPAP", resolve(15))
    }

    @Test
    fun mapsLteAndCarrierAggregation() {
        assertEquals("LTE", resolve(13))
        assertEquals("LTE_CA", resolve(13, override = 1))
        assertEquals("LTE_CA", resolve(13, override = 2))
        assertEquals("LTE_CA", resolve(19))
    }

    @Test
    fun detectsNsaFromDisplayOverride() {
        assertEquals("NR_NSA", resolve(13, override = 3))
        assertEquals("NR_NSA", resolve(13, override = 5))
        assertEquals("NR_NSA_MMWAVE", resolve(13, override = 4))
    }

    @Test
    fun nrDataTypeIsStandalone() {
        assertEquals("NR_SA", resolve(20))
        assertEquals("NR_SA", resolve(20, override = 3))
    }

    @Test
    fun fallsBackToVoiceTypeThenUnknownOrNone() {
        assertEquals("GSM", resolve(0, voice = 16))
        assertEquals("UNKNOWN", resolve(0))
        assertEquals("NONE", resolve(0, serving = false))
        assertEquals("UNKNOWN", resolve(18)) // IWLAN
    }
}

class SnapshotHelpersTest {
    @Test
    fun plmnSplitsMccAndMnc() {
        assertEquals("537" to "03", Plmn.split("53703"))
        assertEquals("310" to "260", Plmn.split("310260"))
        assertEquals(null to null, Plmn.split(""))
        assertEquals(null to null, Plmn.split(null))
        assertEquals(null to null, Plmn.split("53A03"))
    }

    @Test
    fun dataStateNames() {
        assertEquals("CONNECTED", DataStates.name(2))
        assertEquals("DISCONNECTED", DataStates.name(0))
        assertNull(DataStates.name(-1))
    }

    @Test
    fun snapshotFlags() {
        assertNull(RadioSnapshot.snapshotFlags(10_000, 9_000, hasPhoneStatePermission = true, usedCachedCellInfo = false))
        assertEquals("STALE", RadioSnapshot.snapshotFlags(10_000, 7_999, true, false))
        assertEquals(
            "CACHED|NO_PHONE_STATE|STALE",
            RadioSnapshot.snapshotFlags(10_000, 1_000, hasPhoneStatePermission = false, usedCachedCellInfo = true),
        )
        assertNull(RadioSnapshot.snapshotFlags(10_000, null, true, false))
    }

    @Test
    fun snapshotMapNestsCells() {
        val cell = CellObservations.gsm(true, "537", "01", 1, 2, 3, 4, -70)
        val map = RadioSnapshot(
            timestamp = "2026-10-08T00:00:00.000Z", radioTimestamp = null, operatorName = "Digicel",
            mcc = "537", mnc = "03", simOperator = null, networkType = "GSM", dataState = "CONNECTED",
            isRoaming = false, qualityFlag = null, cells = listOf(cell),
        ).toMap()
        assertEquals("Digicel", map["operator"])
        assertEquals("GSM", map["network_type"])
        assertEquals(listOf(cell.toMap()), map["cells"])
    }
}
