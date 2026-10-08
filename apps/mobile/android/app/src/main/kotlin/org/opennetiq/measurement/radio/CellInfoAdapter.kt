package org.opennetiq.measurement.radio

import android.os.Build
import android.os.SystemClock
import android.telephony.CellIdentityNr
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.CellSignalStrengthNr

/** Extracts raw values from Android [CellInfo] and delegates to [CellObservations]. */
internal object CellInfoAdapter {

    fun toObservation(info: CellInfo, gnbIdLengthBits: Int): CellObservation? = when (info) {
        is CellInfoLte -> lte(info)
        is CellInfoNr -> nr(info, gnbIdLengthBits)
        is CellInfoGsm -> gsm(info)
        is CellInfoWcdma -> wcdma(info)
        else -> null // CDMA / TD-SCDMA not supported in M1
    }

    /** Wall-clock time (epoch ms) at which the modem reported [info]. */
    fun reportedAtEpochMs(info: CellInfo): Long {
        val sinceBootMs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            info.timestampMillis
        } else {
            legacyTimestampMs(info)
        }
        return System.currentTimeMillis() - (SystemClock.elapsedRealtime() - sinceBootMs)
    }

    @Suppress("DEPRECATION")
    private fun legacyTimestampMs(info: CellInfo): Long = info.timeStamp / 1_000_000L

    private fun lte(info: CellInfoLte): CellObservation {
        val id = info.cellIdentity
        val ss = info.cellSignalStrength
        val band = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) id.bands.firstOrNull() else null
        return CellObservations.lte(
            isServing = info.isRegistered,
            mcc = id.mccString,
            mnc = id.mncString,
            tac = id.tac,
            eci = id.ci,
            pci = id.pci,
            earfcn = id.earfcn,
            band = band,
            bandwidthKhz = id.bandwidth,
            rsrp = ss.rsrp,
            rsrq = ss.rsrq,
            rssnr = ss.rssnr,
            rssi = ss.rssi,
            cqi = ss.cqi,
            timingAdvance = ss.timingAdvance,
        )
    }

    private fun nr(info: CellInfoNr, gnbIdLengthBits: Int): CellObservation {
        val id = info.cellIdentity as CellIdentityNr
        val ss = info.cellSignalStrength as CellSignalStrengthNr
        val band = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) id.bands.firstOrNull() else null
        return CellObservations.nr(
            isServing = info.isRegistered,
            mcc = id.mccString,
            mnc = id.mncString,
            tac = id.tac,
            nci = id.nci,
            pci = id.pci,
            nrArfcn = id.nrarfcn,
            band = band,
            ssRsrp = ss.ssRsrp,
            ssRsrq = ss.ssRsrq,
            ssSinr = ss.ssSinr,
            csiRsrp = ss.csiRsrp,
            csiRsrq = ss.csiRsrq,
            csiSinr = ss.csiSinr,
            gnbIdLengthBits = gnbIdLengthBits,
        )
    }

    private fun gsm(info: CellInfoGsm): CellObservation {
        val id = info.cellIdentity
        val ss = info.cellSignalStrength
        val rssi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ss.rssi else ss.dbm
        return CellObservations.gsm(
            isServing = info.isRegistered,
            mcc = id.mccString,
            mnc = id.mncString,
            lac = id.lac,
            cid = id.cid,
            arfcn = id.arfcn,
            bsic = id.bsic,
            rssi = rssi,
        )
    }

    private fun wcdma(info: CellInfoWcdma): CellObservation {
        val id = info.cellIdentity
        val ss = info.cellSignalStrength
        val ecNo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) ss.ecNo else RadioRanges.UNAVAILABLE
        return CellObservations.wcdma(
            isServing = info.isRegistered,
            mcc = id.mccString,
            mnc = id.mncString,
            lac = id.lac,
            cid = id.cid,
            psc = id.psc,
            uarfcn = id.uarfcn,
            rscp = ss.dbm,
            ecNo = ecNo,
        )
    }
}
