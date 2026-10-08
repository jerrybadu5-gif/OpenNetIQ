package org.opennetiq.measurement.radio

/**
 * Valid reporting ranges for radio metrics and cell identities.
 * Metrics: 3GPP TS 36.133 / TS 38.133 as summarised in
 * docs/standards/MEASUREMENT-METHODOLOGY.md section 2.
 */
object RadioRanges {
    /** `CellInfo.UNAVAILABLE`. */
    const val UNAVAILABLE: Int = Int.MAX_VALUE

    /** `CellInfo.UNAVAILABLE_LONG`. */
    const val UNAVAILABLE_LONG: Long = Long.MAX_VALUE

    // Signal metrics
    val LTE_RSRP = -140..-43
    val LTE_RSRQ = -34..3
    val LTE_SINR = -20..30
    val LTE_RSSI = -113..-51
    val LTE_CQI = 0..15
    val LTE_TIMING_ADVANCE = 0..1282
    val NR_SS_RSRP = -156..-31
    val NR_SS_RSRQ = -43..20
    val NR_SS_SINR = -23..40
    val NR_CSI_RSRP = -156..-31
    val NR_CSI_RSRQ = -43..20
    val NR_CSI_SINR = -23..23
    val GSM_RSSI = -113..-51
    val WCDMA_RSCP = -120..-24
    val WCDMA_ECNO = -24..1

    // Cell identities
    val LAC = 0..65535
    val LTE_TAC = 0..65535
    val NR_TAC = 0..16_777_215
    val GSM_CID = 0..65535
    val WCDMA_CID = 0..268_435_455
    val LTE_ECI = 0..268_435_455
    val NR_NCI = 0L..68_719_476_735L
    val GSM_ARFCN = 0..65535
    val GSM_BSIC = 0..63
    val WCDMA_UARFCN = 0..16383
    val WCDMA_PSC = 0..511
    val LTE_EARFCN = 0..262_143
    val LTE_PCI = 0..503
    val NR_ARFCN = 0..3_279_165
    val NR_PCI = 0..1007
    val BANDWIDTH_KHZ = 1..400_000
}
