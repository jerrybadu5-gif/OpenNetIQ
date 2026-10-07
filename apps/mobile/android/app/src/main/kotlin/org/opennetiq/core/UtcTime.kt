package org.opennetiq.core

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/** ISO 8601 UTC helpers. Output always ends in `Z`. */
object UtcTime {
    private val formatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC)

    fun format(instant: Instant): String = formatter.format(instant)

    fun formatEpochMs(epochMs: Long): String = format(Instant.ofEpochMilli(epochMs))

    fun now(): String = format(Instant.now())
}
