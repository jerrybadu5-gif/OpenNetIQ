package org.opennetiq.measurement.radio

/**
 * Network context plus all visible cells at one sampling tick.
 * Location is added by the LocationCollector (issue #14) when the sample is stored.
 */
data class RadioSnapshot(
    val timestamp: String,
    val radioTimestamp: String?,
    val operatorName: String?,
    val mcc: String?,
    val mnc: String?,
    val simOperator: String?,
    val networkType: String,
    val dataState: String?,
    val isRoaming: Boolean?,
    val qualityFlag: String?,
    val cells: List<CellObservation>,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "timestamp" to timestamp,
        "radio_timestamp" to radioTimestamp,
        "operator" to operatorName,
        "mcc" to mcc,
        "mnc" to mnc,
        "sim_operator" to simOperator,
        "network_type" to networkType,
        "data_state" to dataState,
        "is_roaming" to isRoaming,
        "quality_flag" to qualityFlag,
        "cells" to cells.map(CellObservation::toMap),
    )

    companion object {
        /** Cell data older than this is flagged STALE (MEASUREMENT-METHODOLOGY.md section 1). */
        const val STALE_AFTER_MS = 2_000L

        fun snapshotFlags(
            nowMs: Long,
            newestCellMs: Long?,
            hasPhoneStatePermission: Boolean,
            usedCachedCellInfo: Boolean,
        ): String? {
            val flags = sortedSetOf<String>()
            if (newestCellMs != null && nowMs - newestCellMs > STALE_AFTER_MS) flags += "STALE"
            if (!hasPhoneStatePermission) flags += "NO_PHONE_STATE"
            if (usedCachedCellInfo) flags += "CACHED"
            return if (flags.isEmpty()) null else flags.joinToString("|")
        }
    }
}
