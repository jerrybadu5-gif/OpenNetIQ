package org.opennetiq.measurement.radio

enum class Rat { GSM, WCDMA, LTE, NR }

/**
 * One serving or neighbour cell. Field names and semantics follow the
 * `cell_observations` table in docs/standards/DATA-DICTIONARY.md.
 */
data class CellObservation(
    val isServing: Boolean,
    val rat: Rat,
    val mcc: String? = null,
    val mnc: String? = null,
    val lacTac: Int? = null,
    val cellId: Long? = null,
    val enbId: Int? = null,
    val gnbId: Long? = null,
    val localCellId: Int? = null,
    val pciPscBsic: Int? = null,
    val arfcn: Int? = null,
    val band: String? = null,
    val bandwidthKhz: Int? = null,
    val rssiDbm: Int? = null,
    val rscpDbm: Int? = null,
    val ecnoDb: Int? = null,
    val rsrpDbm: Int? = null,
    val rsrqDb: Int? = null,
    val sinrDb: Int? = null,
    val cqi: Int? = null,
    val timingAdvance: Int? = null,
    val csiRsrpDbm: Int? = null,
    val csiRsrqDb: Int? = null,
    val csiSinrDb: Int? = null,
    val qualityFlag: String? = null,
) {
    /** Platform-channel payload (snake_case keys, see docs/features/signal-monitor/API.md). */
    fun toMap(): Map<String, Any?> = mapOf(
        "is_serving" to isServing,
        "rat" to rat.name,
        "mcc" to mcc,
        "mnc" to mnc,
        "lac_tac" to lacTac,
        "cell_id" to cellId,
        "enb_id" to enbId,
        "gnb_id" to gnbId,
        "local_cell_id" to localCellId,
        "pci_psc_bsic" to pciPscBsic,
        "arfcn" to arfcn,
        "band" to band,
        "bandwidth_khz" to bandwidthKhz,
        "rssi_dbm" to rssiDbm,
        "rscp_dbm" to rscpDbm,
        "ecno_db" to ecnoDb,
        "rsrp_dbm" to rsrpDbm,
        "rsrq_db" to rsrqDb,
        "sinr_db" to sinrDb,
        "cqi" to cqi,
        "timing_advance" to timingAdvance,
        "csi_rsrp_dbm" to csiRsrpDbm,
        "csi_rsrq_db" to csiRsrqDb,
        "csi_sinr_db" to csiSinrDb,
        "quality_flag" to qualityFlag,
    )
}
