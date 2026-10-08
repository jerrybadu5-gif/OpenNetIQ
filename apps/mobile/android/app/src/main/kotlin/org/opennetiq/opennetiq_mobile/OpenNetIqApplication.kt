package org.opennetiq.opennetiq_mobile

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.opennetiq.measurement.bridge.MeasurementBridge

/**
 * Owns the app's single FlutterEngine (ADR-014). The engine outlives
 * MainActivity, so the Dart recording pipeline keeps running while the
 * drive-test foreground service is active, even after the task is swiped away.
 */
class OpenNetIqApplication : Application() {
    lateinit var bridge: MeasurementBridge
        private set

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        // Channel handlers are registered before Dart starts.
        bridge = MeasurementBridge(this, engine.dartExecutor.binaryMessenger)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "opennetiq_main"
    }
}
