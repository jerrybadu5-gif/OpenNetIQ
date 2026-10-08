package org.opennetiq.measurement.service

/** Validated notification content sent by Dart (`title`, `text`). */
data class RecordingNotificationArgs(val title: String, val text: String) {
    companion object {
        const val DEFAULT_TITLE = "Drive test recording"
        const val MAX_TITLE = 80
        const val MAX_TEXT = 200

        fun of(title: String?, text: String?): RecordingNotificationArgs =
            RecordingNotificationArgs(
                title = title?.trim()?.takeIf { it.isNotEmpty() }?.take(MAX_TITLE) ?: DEFAULT_TITLE,
                text = text?.trim()?.take(MAX_TEXT) ?: "",
            )

        fun fromChannel(arguments: Any?): RecordingNotificationArgs {
            val map = arguments as? Map<*, *>
            return of(map?.get("title") as? String, map?.get("text") as? String)
        }
    }
}
