package org.opennetiq.measurement.qoe

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * Web browsing test (issue #29): loads a page in an off-screen WebView with
 * an empty cache and reads W3C Navigation Timing. Main thread only.
 */
class WebPageProbe(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var finish: ((Map<String, Any?>) -> Unit)? = null

    @SuppressLint("SetJavaScriptEnabled")
    fun run(url: String, timeoutMs: Long, onDone: (Map<String, Any?>) -> Unit) {
        cancel()
        val startNs = System.nanoTime()
        var done = false
        val view = WebView(context.applicationContext).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.loadsImagesAutomatically = true
            clearCache(true)
            layout(0, 0, 1080, 1920)
        }
        webView = view
        val complete: (Map<String, Any?>) -> Unit = { result ->
            if (!done) {
                done = true
                main.removeCallbacksAndMessages(TIMEOUT_TOKEN)
                release()
                onDone(result)
            }
        }
        finish = complete
        val elapsed = { (System.nanoTime() - startNs) / 1e6 }
        view.webViewClient = object : WebViewClient() {
            private var mainFrameError: String? = null

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) = Unit

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError,
            ) {
                if (request.isForMainFrame) {
                    mainFrameError = error.description?.toString() ?: "load error"
                    complete(mapOf("total_ms" to elapsed(), "error" to mainFrameError))
                }
            }

            override fun onPageFinished(view: WebView, url: String?) {
                if (mainFrameError != null) return
                val wall = elapsed()
                view.evaluateJavascript(NavigationTiming.SCRIPT) { json ->
                    val t = NavigationTiming.parse(json)
                    complete(
                        mapOf(
                            "dns_ms" to t?.dnsMs,
                            "connect_ms" to t?.connectMs,
                            "tls_ms" to t?.tlsMs,
                            "ttfb_ms" to t?.ttfbMs,
                            "dom_ms" to t?.domMs,
                            "total_ms" to (t?.loadMs ?: wall),
                            "bytes" to t?.transferBytes,
                            "error" to null,
                        ),
                    )
                }
            }
        }
        main.postAtTime(
            { complete(mapOf("total_ms" to elapsed(), "error" to "timeout after ${timeoutMs / 1000} s")) },
            TIMEOUT_TOKEN,
            android.os.SystemClock.uptimeMillis() + timeoutMs,
        )
        view.loadUrl(url)
    }

    fun cancel() {
        finish?.invoke(mapOf("error" to "cancelled"))
    }

    private fun release() {
        finish = null
        webView?.apply {
            stopLoading()
            destroy()
        }
        webView = null
    }

    private companion object {
        val TIMEOUT_TOKEN = Any()
    }
}
