# Testing: customer-experience tests (#29)

## Automated
- Kotlin (`QoeProbesTest.kt`): HTTP probe timings/bytes/upload/errors
  against a local server; Navigation Timing parser; playback accumulator
  (start delay, rebuffers, played time, weighted bitrate, errors).
- Dart: entities/mapper status rules, target-line parsing; platform engine
  (mock channel); Drift store; schema v1 → v2 migration; controller (plan,
  linking, file without server, cancel, errors, settings); screen (kinds,
  progress, details, list editing, options, history); export `_qoe.csv` and
  GeoJSON; script steps.

## On device
1. Set the speed-test server. Experience tests → Start (all kinds).
2. Web: 5 sites with load times; App: 6 rows; File: download + upload Mbps.
3. Video: default HLS stream shows start delay and resolution. Add a
   YouTube or Facebook video as `Name | URL | page` and run Video only.
4. Airplane mode → Start: every row failed, no crash.
5. Record a drive with a script containing a web and a video step; export
   *All formats*: `_qoe.csv` rows have positions.
