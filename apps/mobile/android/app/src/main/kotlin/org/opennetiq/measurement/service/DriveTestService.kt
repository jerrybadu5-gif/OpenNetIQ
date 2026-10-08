package org.opennetiq.measurement.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import org.opennetiq.opennetiq_mobile.R

/**
 * Drive-test foreground service (issue #17, ADR-014).
 *
 * Keeps the process, GNSS and radio sampling alive with the screen off or the
 * task swiped away. Sampling itself stays in the measurement collectors and the
 * Dart pipeline; this service only provides foreground status (type `location`),
 * a partial wake lock and the mandatory ongoing notification.
 * Started only while the app is visible, so no background-location permission
 * is needed.
 */
class DriveTestService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_REQUEST) {
            DriveTestServiceEvents.stopRequested { stopSelf() }
            return START_NOT_STICKY
        }
        val args = RecordingNotificationArgs.of(
            intent?.getStringExtra(EXTRA_TITLE),
            intent?.getStringExtra(EXTRA_TEXT),
        )
        ensureChannel(this)
        try {
            startForeground(
                NOTIFICATION_ID,
                buildNotification(this, args),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } catch (e: RuntimeException) {
            // SecurityException (permission revoked) or
            // ForegroundServiceStartNotAllowedException (started from background).
            DriveTestServiceEvents.serviceError(
                "FOREGROUND_DENIED",
                e.message ?: e.javaClass.simpleName,
            )
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        acquireWakeLock()
        // A killed process cannot resume a session: the app marks it aborted.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        wakeLock?.takeIf { it.isHeld }?.release()
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
            setReferenceCounted(false)
            acquire(MAX_WAKE_LOCK_MS)
        }
    }

    companion object {
        const val NOTIFICATION_ID = 0x4E52
        const val CHANNEL_ID = "drive_test_recording"
        const val ACTION_START = "org.opennetiq.action.START_RECORDING"
        const val ACTION_STOP_REQUEST = "org.opennetiq.action.STOP_REQUEST"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        private const val WAKE_LOCK_TAG = "OpenNetIQ:DriveTest"

        /** Upper bound so a lost stop can never drain the battery indefinitely. */
        const val MAX_WAKE_LOCK_MS = 12L * 60 * 60 * 1000

        @Volatile
        var running: Boolean = false
            private set

        fun start(context: Context, args: RecordingNotificationArgs) {
            val intent = Intent(context, DriveTestService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TITLE, args.title)
                .putExtra(EXTRA_TEXT, args.text)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, DriveTestService::class.java))
        }

        /** Refreshes the ongoing notification; no-op when not recording. */
        fun update(context: Context, args: RecordingNotificationArgs) {
            if (!running) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, buildNotification(context, args))
        }

        private fun ensureChannel(context: Context) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Drive test recording",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while OpenNetIQ records a measurement session."
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        private fun buildNotification(context: Context, args: RecordingNotificationArgs): Notification {
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = launch?.let { PendingIntent.getActivity(context, 0, it, flags) }
            val stopIntent = PendingIntent.getService(
                context,
                1,
                Intent(context, DriveTestService::class.java).setAction(ACTION_STOP_REQUEST),
                flags,
            )
            val icon = Icon.createWithResource(context, R.drawable.ic_stat_recording)
            val builder = Notification.Builder(context, CHANNEL_ID)
                .setSmallIcon(icon)
                .setContentTitle(args.title)
                .setContentText(args.text)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setCategory(Notification.CATEGORY_SERVICE)
                .addAction(Notification.Action.Builder(icon, "Stop", stopIntent).build())
            if (contentIntent != null) builder.setContentIntent(contentIntent)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
            }
            return builder.build()
        }
    }
}
