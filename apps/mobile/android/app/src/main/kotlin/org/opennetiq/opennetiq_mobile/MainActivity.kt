package org.opennetiq.opennetiq_mobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import org.opennetiq.measurement.bridge.MeasurementBridge

/** Hosts the cached engine created by [OpenNetIqApplication] (ADR-014). */
class MainActivity : FlutterActivity() {
    private val bridge: MeasurementBridge
        get() = (application as OpenNetIqApplication).bridge

    override fun getCachedEngineId(): String = OpenNetIqApplication.ENGINE_ID

    /** The engine must survive the activity while a drive test records. */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        bridge.attachActivity(this)
    }

    override fun onDestroy() {
        bridge.detachActivity(this)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bridge.onRequestPermissionsResult(requestCode)
    }
}
