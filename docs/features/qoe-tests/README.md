# Customer-experience tests (issue #29)

**Home → Experience tests.** Pick the kinds, tap *Start tests*:

| Kind | What it measures (defaults) |
|---|---|
| Web browsing | Page load, first byte, DNS/TCP/TLS, DOM ready for Google, Facebook, Wikipedia, NICTA, BSP |
| Video streaming | Start delay, rebuffers (count, time), played time, bitrate, resolution; 30 s; default source: public HLS test stream |
| App reachability | DNS/TCP/TLS, first byte, response time for Google, Facebook, WhatsApp, YouTube, TikTok, BSP |
| File transfer | 5 MB download and upload to the speed-test server: time and Mbps |

- **Targets**: edit each list (one per line `Name | URL`). Video links are
  detected automatically: `.m3u8`, `.mpd`, `.mp4` (and similar) are direct
  streams, any other link (YouTube, Facebook, game sites) is a video on a web
  page. Force it with `| stream` or `| page`.
- Page videos play in a strip at the bottom of the screen during the test
  (sites pause hidden videos); the test keeps the video playing, muted, and
  measures its progress. Ads before the video count as part of the
  experience. In the background (e.g. a script with the screen off) the page
  is loaded off-screen and some sites may not play.
- **Options**: video length (5–600 s), file size (1–100 MB).
- Tap a result for all timings. History lists the last 50 results.
- Works inside **test scripts** (web, video, apps, file steps) and during a
  drive recording: results are linked to the drive and exported as
  `<session>_qoe.csv` and `qoe_test` features in the GeoJSON.
- Sites and video platforms see the phone's IP address. YouTube, Facebook
  and other platforms' terms apply to the sources you configure.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md),
ADR-021, MEASUREMENT-METHODOLOGY.md §6b.
