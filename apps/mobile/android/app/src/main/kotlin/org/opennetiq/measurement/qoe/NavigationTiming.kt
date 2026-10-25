package org.opennetiq.measurement.qoe

/**
 * Page-load timings read from the W3C Navigation Timing API in the page
 * (issue #29). [SCRIPT] returns an object; WebView serialises it to JSON.
 */
data class NavigationTiming(
    val dnsMs: Double?,
    val connectMs: Double?,
    val tlsMs: Double?,
    val ttfbMs: Double?,
    val domMs: Double?,
    val loadMs: Double?,
    val transferBytes: Long?,
) {
    companion object {
        /** All values in ms relative to navigation start; null when unknown. */
        const val SCRIPT = """
(function(){
  var e = performance.getEntriesByType && performance.getEntriesByType('navigation')[0];
  function d(a,b){ return (a>0 && b>=a) ? (b-a) : null; }
  if (e) {
    return {
      dns: d(e.domainLookupStart, e.domainLookupEnd),
      connect: d(e.connectStart, e.secureConnectionStart > 0 ? e.secureConnectionStart : e.connectEnd),
      tls: e.secureConnectionStart > 0 ? d(e.secureConnectionStart, e.connectEnd) : null,
      ttfb: e.responseStart > 0 ? e.responseStart : null,
      dom: e.domContentLoadedEventEnd > 0 ? e.domContentLoadedEventEnd : null,
      load: e.loadEventEnd > 0 ? e.loadEventEnd : (e.duration > 0 ? e.duration : null),
      bytes: e.transferSize > 0 ? e.transferSize : null
    };
  }
  var t = performance.timing, s = t.navigationStart;
  return {
    dns: d(t.domainLookupStart, t.domainLookupEnd),
    connect: d(t.connectStart, t.secureConnectionStart > 0 ? t.secureConnectionStart : t.connectEnd),
    tls: t.secureConnectionStart > 0 ? d(t.secureConnectionStart, t.connectEnd) : null,
    ttfb: t.responseStart > 0 ? t.responseStart - s : null,
    dom: t.domContentLoadedEventEnd > 0 ? t.domContentLoadedEventEnd - s : null,
    load: t.loadEventEnd > 0 ? t.loadEventEnd - s : null,
    bytes: null
  };
})()
"""

        private fun num(json: String, key: String): Double? {
            val m = Regex("\"$key\"\\s*:\\s*(-?[0-9.eE+-]+)").find(json) ?: return null
            return m.groupValues[1].toDoubleOrNull()?.takeIf { it.isFinite() && it >= 0 }
        }

        /** Parses the JSON WebView returns for [SCRIPT]; null if unusable. */
        fun parse(json: String?): NavigationTiming? {
            if (json == null || !json.trim().startsWith("{")) return null
            return NavigationTiming(
                dnsMs = num(json, "dns"),
                connectMs = num(json, "connect"),
                tlsMs = num(json, "tls"),
                ttfbMs = num(json, "ttfb"),
                domMs = num(json, "dom"),
                loadMs = num(json, "load"),
                transferBytes = num(json, "bytes")?.toLong(),
            )
        }
    }
}
