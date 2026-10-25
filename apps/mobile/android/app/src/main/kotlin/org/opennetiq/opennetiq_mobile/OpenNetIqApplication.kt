package org.opennetiq.opennetiq_mobile

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.opennetiq.measurement.bridge.MeasurementBridge
import org.opennetiq.measurement.qoe.QoeBridge
import org.opennetiq.measurement.voice.VoiceSmsBridge

/**
 * Owns the app's single FlutterEngine (ADR-014). The engine outlives
 * MainActivity, so the Dart recording pipeline keeps running while the
 * drive-test foreground service is active, even after the task is swiped away.
 */
class OpenNetIqApplication : Application() {
    lateinit var bridge: MeasurementBridge
        private set
    lateinit var qoe: QoeBridge
        private set
    lateinit var voiceSms: VoiceSmsBridge
        private set

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        // Channel handlers are registered before Dart starts.
        bridge = MeasurementBridge(this, engine.dartExecutor.binaryMessenger)
        qoe = QoeBridge(this, engine.dartExecutor.binaryMessenger)
        voiceSms = VoiceSmsBridge(this, engine.dartExecutor.binaryMessenger)
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                qoe.activity = activity
                voiceSms.activity = activity
            }
            override fun onActivityPaused(activity: Activity) {
                if (qoe.activity === activity) qoe.activity = null
            }
            override fun onActivityDestroyed(activity: Activity) {
                if (voiceSms.activity === activity) voiceSms.activity = null
            }
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityStarted(activity: Activity) = Unit
            override fun onActivityStopped(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        })
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "opennetiq_main"
    }
}
