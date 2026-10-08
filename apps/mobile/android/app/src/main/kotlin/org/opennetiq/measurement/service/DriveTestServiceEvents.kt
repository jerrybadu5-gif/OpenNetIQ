package org.opennetiq.measurement.service

/**
 * Service -> app notifications. The bridge registers itself as [listener];
 * when nothing is listening the service falls back to stopping itself.
 */
object DriveTestServiceEvents {
    interface Listener {
        /** User tapped "Stop" in the notification; call [onUnhandled] if Dart did not take it. */
        fun onStopRequested(onUnhandled: () -> Unit)

        fun onServiceError(code: String, message: String)
    }

    @Volatile
    var listener: Listener? = null

    fun stopRequested(onUnhandled: () -> Unit) {
        val l = listener
        if (l == null) onUnhandled() else l.onStopRequested(onUnhandled)
    }

    fun serviceError(code: String, message: String) {
        listener?.onServiceError(code, message)
    }
}
