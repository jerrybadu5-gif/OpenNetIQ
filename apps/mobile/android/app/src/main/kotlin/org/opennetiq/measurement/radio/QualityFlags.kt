package org.opennetiq.measurement.radio

/**
 * Validates signal metrics and collects quality flags.
 * Rules (DATA-DICTIONARY.md): unavailable or out-of-range values become null,
 * never clamped. OUT_OF_RANGE is flagged for any metric; UNAVAILABLE only for
 * the RAT's primary level metric (neighbours often omit secondary metrics).
 */
internal class QualityFlags {
    private val flags = sortedSetOf<String>()

    fun metric(raw: Int, range: IntRange): Int? = when (raw) {
        RadioRanges.UNAVAILABLE -> null
        in range -> raw
        else -> {
            flags += OUT_OF_RANGE
            null
        }
    }

    fun primaryMetric(raw: Int, range: IntRange): Int? {
        if (raw == RadioRanges.UNAVAILABLE) flags += UNAVAILABLE
        return metric(raw, range)
    }

    fun value(): String? = if (flags.isEmpty()) null else flags.joinToString("|")

    companion object {
        const val OUT_OF_RANGE = "OUT_OF_RANGE"
        const val UNAVAILABLE = "UNAVAILABLE"
    }
}

/** Identity fields are nulled silently when unavailable or invalid. */
internal fun identity(raw: Int, range: IntRange): Int? = if (raw in range) raw else null

internal fun identity(raw: Long, range: LongRange): Long? = if (raw in range) raw else null

/** MCC is 3 digits, MNC 2–3 digits; text keeps leading zeros. */
internal fun plmnPart(value: String?, lengths: IntRange): String? =
    value?.takeIf { it.length in lengths && it.all(Char::isDigit) }
