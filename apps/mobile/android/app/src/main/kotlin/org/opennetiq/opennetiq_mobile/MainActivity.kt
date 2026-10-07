package org.opennetiq.opennetiq_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.opennetiq.measurement.latency.LatencyEngine
import org.opennetiq.measurement.latency.LatencyProtocol
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val latencyEngine = LatencyEngine()
    private val latencyExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LATENCY_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "measure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val protocol = call.argument<String>("protocol")
                    ?.let(LatencyProtocol::fromWire)
                val target = call.argument<String>("target")
                val port = call.argument<Int>("port") ?: 443
                if (protocol == null || target.isNullOrBlank() || target.length > 253 ||
                    port !in 1..65535
                ) {
                    result.error("invalid_argument", "Invalid latency measurement arguments", null)
                    return@setMethodCallHandler
                }

                latencyExecutor.execute {
                    try {
                        val measurement = latencyEngine.measure(protocol, target, port)
                        val stats = measurement.statistics
                        runOnUiThread {
                            result.success(
                                mapOf(
                                    "protocol" to measurement.protocol.wireValue,
                                    "target" to measurement.target,
                                    "probes_sent" to stats.probesSent,
                                    "probes_received" to stats.probesReceived,
                                    "min_ms" to stats.minMs,
                                    "max_ms" to stats.maxMs,
                                    "mean_ms" to stats.meanMs,
                                    "median_ms" to stats.medianMs,
                                    "p95_ms" to stats.p95Ms,
                                    "jitter_ms" to stats.jitterMs,
                                    "packet_loss_pct" to stats.packetLossPct,
                                    "raw_rtts_ms" to measurement.rawRttsMs,
                                    "status" to measurement.status,
                                    "methodology_version" to "1.0.0",
                                ),
                            )
                        }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("measurement_failed", error.message, null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        latencyExecutor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val LATENCY_CHANNEL = "opennetiq/latency"
    }
}
