package org.opennetiq.measurement.radio

/**
 * Pure factories from raw Android values (with UNAVAILABLE sentinels) to
 * validated [CellObservation]s. No Android types, so fully unit-testable.
 */
object CellObservations {

    fun lte(
        isServing: Boolean,
        mcc: String?,
        mnc: String?,
        tac: Int,
        eci: Int,
        pci: Int,
        earfcn: Int,
        band: Int?,
        bandwidthKhz: Int,
        rsrp: Int,
        rsrq: Int,
        rssnr: Int,
        rssi: Int,
        cqi: Int,
        timingAdvance: Int,
    ): CellObservation {
        val flags = QualityFlags()
        val ci = identity(eci, RadioRanges.LTE_ECI)
        return CellObservation(
            isServing = isServing,
            rat = Rat.LTE,
            mcc = plmnPart(mcc, 3..3),
            mnc = plmnPart(mnc, 2..3),
            lacTac = identity(tac, RadioRanges.LTE_TAC),
            cellId = ci?.toLong(),
            enbId = ci?.let(CellIdentityMath::enbId),
            localCellId = ci?.let(CellIdentityMath::localCellId),
            pciPscBsic = identity(pci, RadioRanges.LTE_PCI),
            arfcn = identity(earfcn, RadioRanges.LTE_EARFCN),
            band = band?.takeIf { it > 0 }?.let { "B$it" },
            bandwidthKhz = identity(bandwidthKhz, RadioRanges.BANDWIDTH_KHZ),
            rsrpDbm = flags.primaryMetric(rsrp, RadioRanges.LTE_RSRP),
            rsrqDb = flags.metric(rsrq, RadioRanges.LTE_RSRQ),
            sinrDb = flags.metric(rssnr, RadioRanges.LTE_SINR),
            rssiDbm = flags.metric(rssi, RadioRanges.LTE_RSSI),
            cqi = flags.metric(cqi, RadioRanges.LTE_CQI),
            timingAdvance = flags.metric(timingAdvance, RadioRanges.LTE_TIMING_ADVANCE),
            qualityFlag = flags.value(),
        )
    }

    fun nr(
        isServing: Boolean,
        mcc: String?,
        mnc: String?,
        tac: Int,
        nci: Long,
        pci: Int,
        nrArfcn: Int,
        band: Int?,
        ssRsrp: Int,
        ssRsrq: Int,
        ssSinr: Int,
        csiRsrp: Int,
        csiRsrq: Int,
        csiSinr: Int,
        gnbIdLengthBits: Int = CellIdentityMath.DEFAULT_GNB_ID_LENGTH,
    ): CellObservation {
        val flags = QualityFlags()
        val cellId = identity(nci, RadioRanges.NR_NCI)
        return CellObservation(
            isServing = isServing,
            rat = Rat.NR,
            mcc = plmnPart(mcc, 3..3),
            mnc = plmnPart(mnc, 2..3),
            lacTac = identity(tac, RadioRanges.NR_TAC),
            cellId = cellId,
            gnbId = cellId?.let { CellIdentityMath.gnbId(it, gnbIdLengthBits) },
            pciPscBsic = identity(pci, RadioRanges.NR_PCI),
            arfcn = identity(nrArfcn, RadioRanges.NR_ARFCN),
            band = band?.takeIf { it > 0 }?.let { "n$it" },
            rsrpDbm = flags.primaryMetric(ssRsrp, RadioRanges.NR_SS_RSRP),
            rsrqDb = flags.metric(ssRsrq, RadioRanges.NR_SS_RSRQ),
            sinrDb = flags.metric(ssSinr, RadioRanges.NR_SS_SINR),
            csiRsrpDbm = flags.metric(csiRsrp, RadioRanges.NR_CSI_RSRP),
            csiRsrqDb = flags.metric(csiRsrq, RadioRanges.NR_CSI_RSRQ),
            csiSinrDb = flags.metric(csiSinr, RadioRanges.NR_CSI_SINR),
            qualityFlag = flags.value(),
        )
    }

    fun gsm(
        isServing: Boolean,
        mcc: String?,
        mnc: String?,
        lac: Int,
        cid: Int,
        arfcn: Int,
        bsic: Int,
        rssi: Int,
    ): CellObservation {
        val flags = QualityFlags()
        return CellObservation(
            isServing = isServing,
            rat = Rat.GSM,
            mcc = plmnPart(mcc, 3..3),
            mnc = plmnPart(mnc, 2..3),
            lacTac = identity(lac, RadioRanges.LAC),
            cellId = identity(cid, RadioRanges.GSM_CID)?.toLong(),
            pciPscBsic = identity(bsic, RadioRanges.GSM_BSIC),
            arfcn = identity(arfcn, RadioRanges.GSM_ARFCN),
            rssiDbm = flags.primaryMetric(rssi, RadioRanges.GSM_RSSI),
            qualityFlag = flags.value(),
        )
    }

    fun wcdma(
        isServing: Boolean,
        mcc: String?,
        mnc: String?,
        lac: Int,
        cid: Int,
        psc: Int,
        uarfcn: Int,
        rscp: Int,
        ecNo: Int,
    ): CellObservation {
        val flags = QualityFlags()
        return CellObservation(
            isServing = isServing,
            rat = Rat.WCDMA,
            mcc = plmnPart(mcc, 3..3),
            mnc = plmnPart(mnc, 2..3),
            lacTac = identity(lac, RadioRanges.LAC),
            cellId = identity(cid, RadioRanges.WCDMA_CID)?.toLong(),
            pciPscBsic = identity(psc, RadioRanges.WCDMA_PSC),
            arfcn = identity(uarfcn, RadioRanges.WCDMA_UARFCN),
            rscpDbm = flags.primaryMetric(rscp, RadioRanges.WCDMA_RSCP),
            ecnoDb = flags.metric(ecNo, RadioRanges.WCDMA_ECNO),
            qualityFlag = flags.value(),
        )
    }
}
