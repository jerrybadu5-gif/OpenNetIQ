package org.opennetiq.measurement.qoe

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
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
 *   in a WebView shown at the bottom of the app while the test runs (sites
 *   pause hidden videos); off-screen when the app is in the background. The
 *   first <video> is muted, kept playing, and its progress is polled.
 * Main thread only.
 */
class VideoProbe(
    private val context: Context,
    private val activity: () -> Activity? = { null },
) {
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
        val host = activity()
        val view = WebView(host ?: context.applicationContext)
        val overlay = host?.let { show(it, view) }
        val complete: (Map<String, Any?>) -> Unit = { extra ->
            if (!done) {
                done = true
                main.removeCallbacksAndMessages(TOKEN)
                val result = stats.finish(System.nanoTime()) + extra.filterValues { it != null }
                (overlay?.parent as? ViewGroup)?.removeView(overlay)
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
        if (overlay == null) view.layout(0, 0, 1080, 1920)
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
        // Single-page sites may finish late: inject again (the script is idempotent).
        for (delay in longArrayOf(3_000, 6_000, 10_000)) {
            main.postAtTime(
                { if (!done) view.evaluateJavascript(PAGE_SCRIPT, null) },
                TOKEN,
                SystemClock.uptimeMillis() + delay,
            )
        }
        schedule(durationMs) { complete(emptyMap()) }
    }

    /** 16:9 player strip at the bottom of the activity, removed afterwards. */
    private fun show(host: Activity, view: WebView): FrameLayout {
        val width = host.resources.displayMetrics.widthPixels
        val frame = FrameLayout(host)
        frame.addView(
            view,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, width * 9 / 16, Gravity.BOTTOM),
        )
        host.addContentView(
            frame,
            ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        return frame
    }

    private companion object {
        val TOKEN = Any()

        /**
         * Keeps the first <video> playing (muted) and polls its progress every
         * 500 ms: advancing time = playing, stalled for >= 1 s = buffering.
         * Polling works where sites swallow media events. Idempotent.
         */
        const val PAGE_SCRIPT = """
(function(){
  if (window.__onqHooked) return; window.__onqHooked = true;
  var last = -1, playing = false, stall = 0, lastH = 0, hooked = null;
  function send(n, v){ OnqVideo.event(n, (v && v.videoHeight) || 0); }
  setInterval(function(){
    var v = document.querySelector('video');
    if (!v) return;
    if (v !== hooked) {
      hooked = v; last = -1;
      v.addEventListener('ended', function(){ send('ended', v); });
      v.addEventListener('error', function(){ send('error', v); });
    }
    v.muted = true;
    if (v.paused && !v.ended) { var p = v.play(); if (p && p.catch) p.catch(function(){}); }
    var t = v.currentTime;
    if (t > last + 0.05) {
      if (!playing) { playing = true; send('playing', v); }
      stall = 0;
    } else if (playing && !v.ended) {
      stall++;
      if (stall >= 2) { playing = false; send('waiting', v); }
    }
    last = t;
    if (v.videoHeight && v.videoHeight !== lastH) { lastH = v.videoHeight; send('resize', v); }
  }, 500);
})()
"""
    }
}
