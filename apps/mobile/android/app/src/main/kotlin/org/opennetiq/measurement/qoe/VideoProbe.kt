package org.opennetiq.measurement.qoe

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.webkit.JavascriptInterface
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.DecoderReuseEvaluation

/**
 * Video streaming test (issue #29). Two modes:
 * - `stream`: direct HLS / DASH / progressive URL played by ExoPlayer
 *   (adaptive bitrate, real buffering; no surface, so decoding cost does not
 *   affect the result);
 * - `page`: a web page with an HTML5 video (YouTube, Facebook, game streams)
 *   in an off-screen WebView; the first <video> element is muted and played.
 * Main thread only.
 */
class VideoProbe(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var finish: ((Map<String, Any?>) -> Unit)? = null

    fun run(url: String, mode: String, durationMs: Long, onDone: (Map<String, Any?>) -> Unit) {
        cancel()
        if (mode == "page") runPage(url, durationMs, onDone) else runStream(url, durationMs, onDone)
    }

    fun cancel() {
        finish?.invoke(mapOf("error" to "cancelled"))
    }

    private fun schedule(durationMs: Long, block: () -> Unit) {
        main.postAtTime(block, TOKEN, SystemClock.uptimeMillis() + durationMs)
    }

    private fun runStream(url: String, durationMs: Long, onDone: (Map<String, Any?>) -> Unit) {
        val start = System.nanoTime()
        val stats = PlaybackStats(start)
        val player = ExoPlayer.Builder(context.applicationContext).build()
        var done = false
        val complete: (Map<String, Any?>) -> Unit = { extra ->
            if (!done) {
                done = true
                main.removeCallbacksAndMessages(TOKEN)
                val result = stats.finish(System.nanoTime()) + extra.filterValues { it != null }
                player.release()
                finish = null
                onDone(result)
            }
        }
        finish = complete
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                val t = System.nanoTime()
                when (state) {
                    Player.STATE_READY -> if (player.playWhenReady) stats.onPlaying(t)
                    Player.STATE_BUFFERING -> stats.onBuffering(t)
                    Player.STATE_ENDED -> complete(emptyMap())
                    else -> Unit
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                stats.onError(error.errorCodeName)
                complete(emptyMap())
            }
        })
        player.addAnalyticsListener(object : AnalyticsListener {
            override fun onVideoInputFormatChanged(
                eventTime: AnalyticsListener.EventTime,
                format: Format,
                decoderReuseEvaluation: DecoderReuseEvaluation?,
            ) {
                stats.onFormat(
                    System.nanoTime(),
                    format.height.takeIf { it != Format.NO_VALUE },
                    format.bitrate.takeIf { it != Format.NO_VALUE },
                )
            }
        })
        player.volume = 0f
        player.setMediaItem(MediaItem.fromUri(url))
        player.playWhenReady = true
        player.prepare()
        schedule(durationMs) { complete(emptyMap()) }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun runPage(url: String, durationMs: Long, onDone: (Map<String, Any?>) -> Unit) {
        val start = System.nanoTime()
        val stats = PlaybackStats(start)
        var done = false
        val view = WebView(context.applicationContext)
        val complete: (Map<String, Any?>) -> Unit = { extra ->
            if (!done) {
                done = true
                main.removeCallbacksAndMessages(TOKEN)
                val result = stats.finish(System.nanoTime()) + extra.filterValues { it != null }
                view.stopLoading()
                view.destroy()
                finish = null
                onDone(result)
            }
        }
        finish = complete
        view.settings.javaScriptEnabled = true
        view.settings.domStorageEnabled = true
        view.settings.mediaPlaybackRequiresUserGesture = false
        view.clearCache(true)
        view.layout(0, 0, 1080, 1920)
        view.addJavascriptInterface(
            object {
                @JavascriptInterface
                fun event(name: String, height: Int) {
                    main.post {
                        val t = System.nanoTime()
                        when (name) {
                            "playing" -> stats.onPlaying(t)
                            "waiting" -> stats.onBuffering(t)
                            "resize" -> stats.onFormat(t, height.takeIf { it > 0 }, null)
                            "error" -> stats.onError("video element error")
                            "ended" -> complete(emptyMap())
                        }
                    }
                }
            },
            "OnqVideo",
        )
        view.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                view.evaluateJavascript(PAGE_SCRIPT, null)
            }
        }
        view.loadUrl(url)
        schedule(durationMs) { complete(emptyMap()) }
    }

    private companion object {
        val TOKEN = Any()

        /** Hooks the first <video> (now or once it appears), muted autoplay. */
        const val PAGE_SCRIPT = """
(function(){
  if (window.__onqHooked) return; window.__onqHooked = true;
  function hook(v){
    if (v.__onq) return; v.__onq = true; v.muted = true;
    ['playing','waiting','ended','error'].forEach(function(n){
      v.addEventListener(n, function(){ OnqVideo.event(n, v.videoHeight || 0); });
    });
    v.addEventListener('resize', function(){ OnqVideo.event('resize', v.videoHeight || 0); });
    var p = v.play(); if (p && p.catch) p.catch(function(){});
    if (!v.paused && v.readyState > 2) OnqVideo.event('playing', v.videoHeight || 0);
  }
  function scan(){ var v = document.querySelector('video'); if (v) { hook(v); return true; } return false; }
  if (!scan()) {
    var o = new MutationObserver(function(){ if (scan()) o.disconnect(); });
    o.observe(document.documentElement, {childList: true, subtree: true});
  }
})()
"""
    }
}
