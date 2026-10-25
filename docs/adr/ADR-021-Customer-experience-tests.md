# ADR-021: Customer-experience tests in the platform's own engines

## Context
#29 adds web, video, app-reachability and file-transfer tests. Options:
reimplement page loading/streaming in Dart, call third-party SDKs, or use
the Android engines users actually experience.

## Decision
- Web pages and page-embedded video: Android **WebView** (Chromium) with an
  empty cache; timings from W3C Navigation Timing; video events from the
  page's HTML5 `<video>` element.
- Direct video streams: **media3 ExoPlayer** (Apache-2.0), adaptive bitrate,
  no surface.
- App reachability and file transfer: **OkHttp** with an EventListener for
  phase timings, no connection reuse.
- One MethodChannel (`org.opennetiq/qoe`); one result map per target.
- New table `qoe_tests` (schema v2, migration from v1 creates it).
- Video sources (YouTube, Facebook, game streams, own HLS) are configured by
  NICTA, which accepts each platform's terms; the default is a public HLS
  test stream.

## Consequences
- Results reflect real device behaviour (browser engine, codecs, ABR) but
  vary with the site's content and ads; repeat tests and use stable targets
  for benchmarking.
- WebView/ExoPlayer code is verified on device; pure parts (timing parser,
  playback accumulator, HTTP probe) have JVM unit tests.
- Third-party targets see the phone's IP address (privacy notice 1.1, #30).
