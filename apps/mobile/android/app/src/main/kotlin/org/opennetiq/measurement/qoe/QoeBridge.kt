package org.opennetiq.measurement.qoe

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Customer-experience tests over MethodChannel `org.opennetiq/qoe`
 * (issue #29). Each call returns one result map when the test ends;
 * `cancel` ends the running test early with error "cancelled".
 */
class QoeBridge(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val http = HttpProbe()
    private val web by lazy { WebPageProbe(appContext) }
    private val video by lazy { VideoProbe(appContext) }

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reply: (Any?) -> Unit = { value -> main.post { result.success(value) } }
        when (call.method) {
            "web" -> web.run(
                call.argument<String>("url") ?: return badArgs(result),
                (call.argument<Number>("timeout_ms") ?: 30_000).toLong(),
            ) { reply(it) }
            "video" -> video.run(
                call.argument<String>("url") ?: return badArgs(result),
                call.argument<String>("mode") ?: "stream",
                (call.argument<Number>("duration_ms") ?: 30_000).toLong(),
            ) { reply(it) }
            "app" -> {
                val url = call.argument<String>("url") ?: return badArgs(result)
                val timeout = (call.argument<Number>("timeout_ms") ?: 15_000).toLong()
                io.execute { reply(http.get(url, timeout).toMap()) }
            }
            "file" -> {
                val base = call.argument<String>("server_url") ?: return badArgs(result)
                val mib = (call.argument<Number>("size_mib") ?: 5).toInt().coerceIn(1, 100)
                val upload = call.argument<String>("direction") == "upload"
                io.execute { reply(transfer(base, mib, upload)) }
            }
            "cancel" -> {
                http.cancel()
                web.cancel()
                video.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Fixed-size transfer against the LibreSpeed-compatible test server. */
    private fun transfer(base: String, mib: Int, upload: Boolean): Map<String, Any?> {
        val root = if (base.endsWith("/")) base else "$base/"
        val bytes = mib * 1024L * 1024L
        val t = if (upload) {
            http.post("${root}empty.php", bytes)
        } else {
            http.get("${root}garbage.php?ckSize=$mib&r=${System.nanoTime()}", 120_000)
        }
        return t.toMap() + mapOf(
            "direction" to if (upload) "upload" else "download",
            "rate_mbps" to if (t.ok) HttpProbe.mbps(t.bytes, t.totalMs) else null,
        )
    }

    private fun badArgs(result: MethodChannel.Result) =
        result.error("BAD_ARGS", "Missing argument", null)

    fun dispose() {
        channel.setMethodCallHandler(null)
        http.cancel()
        io.shutdownNow()
    }

    companion object {
        const val CHANNEL = "org.opennetiq/qoe"
    }
}
