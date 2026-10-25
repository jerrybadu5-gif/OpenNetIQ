# Customer-experience tests (issue #29)

**Home → Experience tests.** Pick the kinds, tap *Start tests*:

| Kind | What it measures (defaults) |
|---|---|
| Web browsing | Page load, first byte, DNS/TCP/TLS, DOM ready for Google, Facebook, Wikipedia, NICTA, BSP |
| Video streaming | Start delay, rebuffers (count, time), played time, bitrate, resolution; 30 s; default source: public HLS test stream |
| App reachability | DNS/TCP/TLS, first byte, response time for Google, Facebook, WhatsApp, YouTube, TikTok, BSP |
| File transfer | 5 MB download and upload to the speed-test server: time and Mbps |

- **Targets**: edit each list (one per line `Name | URL`). For video, add
  `| page` for a video on a web page (YouTube, Facebook, game streams);
  leave it out for direct HLS/DASH/MP4 streams (e.g. your own server).
- **Options**: video length (5–600 s), file size (1–100 MB).
- Tap a result for all timings. History lists the last 50 results.
- Works inside **test scripts** (web, video, apps, file steps) and during a
  drive recording: results are linked to the drive and exported as
  `<session>_qoe.csv` and `qoe_test` features in the GeoJSON.
- Sites and video platforms see the phone's IP address. YouTube, Facebook
  and other platforms' terms apply to the sources you configure.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md),
ADR-021, MEASUREMENT-METHODOLOGY.md §6b.
