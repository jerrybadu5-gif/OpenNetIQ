package org.opennetiq.measurement.radio

/**
 * Resolves the `network_type` wire value (DATA-DICTIONARY.md `samples.network_type`)
 * from TelephonyManager network types and the TelephonyDisplayInfo override.
 *
 * 5G NSA is only visible through the display-info override (API 30+, needs
 * READ_PHONE_STATE): the data network type stays LTE while the NR leg is active.
 */
object NetworkTypeResolver {
    // android.telephony.TelephonyManager.NETWORK_TYPE_* (stable public values)
    private const val NETWORK_TYPE_UNKNOWN = 0
    private const val NETWORK_TYPE_GPRS = 1
    private const val NETWORK_TYPE_EDGE = 2
    private const val NETWORK_TYPE_UMTS = 3
    private const val NETWORK_TYPE_HSDPA = 8
    private const val NETWORK_TYPE_HSUPA = 9
    private const val NETWORK_TYPE_HSPA = 10
    private const val NETWORK_TYPE_LTE = 13
    private const val NETWORK_TYPE_HSPAP = 15
    private const val NETWORK_TYPE_GSM = 16
    private const val NETWORK_TYPE_LTE_CA = 19 // hidden constant, reported by some OEMs
    private const val NETWORK_TYPE_NR = 20

    // android.telephony.TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_*
    const val OVERRIDE_NONE = 0
    private const val OVERRIDE_LTE_CA = 1
    private const val OVERRIDE_LTE_ADVANCED_PRO = 2
    private const val OVERRIDE_NR_NSA = 3
    private const val OVERRIDE_NR_NSA_MMWAVE = 4
    private const val OVERRIDE_NR_ADVANCED = 5

    fun resolve(
        hasServingCell: Boolean,
        dataNetworkType: Int,
        voiceNetworkType: Int,
        overrideNetworkType: Int,
    ): String {
        val base = if (dataNetworkType != NETWORK_TYPE_UNKNOWN) dataNetworkType else voiceNetworkType
        if (base == NETWORK_TYPE_UNKNOWN) return if (hasServingCell) "UNKNOWN" else "NONE"
        return when (base) {
            NETWORK_TYPE_NR -> "NR_SA"
            NETWORK_TYPE_LTE, NETWORK_TYPE_LTE_CA -> when (overrideNetworkType) {
                OVERRIDE_NR_NSA, OVERRIDE_NR_ADVANCED -> "NR_NSA"
                OVERRIDE_NR_NSA_MMWAVE -> "NR_NSA_MMWAVE"
                OVERRIDE_LTE_CA, OVERRIDE_LTE_ADVANCED_PRO -> "LTE_CA"
                else -> if (base == NETWORK_TYPE_LTE_CA) "LTE_CA" else "LTE"
            }
            NETWORK_TYPE_HSPAP -> "HSPAP"
            NETWORK_TYPE_HSDPA, NETWORK_TYPE_HSUPA, NETWORK_TYPE_HSPA -> "HSPA"
            NETWORK_TYPE_UMTS -> "UMTS"
            NETWORK_TYPE_EDGE -> "EDGE"
            NETWORK_TYPE_GPRS -> "GPRS"
            NETWORK_TYPE_GSM -> "GSM"
            else -> "UNKNOWN"
        }
    }
}

/** Splits `TelephonyManager.getNetworkOperator()` ("53703") into MCC and MNC. */
object Plmn {
    fun split(networkOperator: String?): Pair<String?, String?> {
        val value = networkOperator?.trim()
        if (value == null || value.length !in 5..6 || !value.all(Char::isDigit)) return null to null
        return value.substring(0, 3) to value.substring(3)
    }
}

/** Maps `TelephonyManager.getDataState()` to a readable value. */
object DataStates {
    fun name(state: Int): String? = when (state) {
        0 -> "DISCONNECTED"
        1 -> "CONNECTING"
        2 -> "CONNECTED"
        3 -> "SUSPENDED"
        4 -> "DISCONNECTING"
        5 -> "HANDOVER_IN_PROGRESS"
        else -> null
    }
}
