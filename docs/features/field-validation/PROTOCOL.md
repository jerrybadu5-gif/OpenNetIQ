# M1 field-validation protocol

Version 1.0 (methodology 1.0.0, privacy policy 1.0). Owner: NICTA.

## 1. Equipment
- **Device A (test)**: Android 10+ phone with OpenNetIQ (release candidate).
- **Reference radio log**: G-NetTrack Pro (or Network Cell Info) running **on
  the same phone** during the drive. Same device = same modem, so differences
  come from the apps, not the hardware. Optionally a second phone of the
  **same model** running only the reference app.
- **Reference speed test**: the reference tool's speed test against the
  **same test server** OpenNetIQ uses (`infra/test-server`). Record each
  result (time, DL Mbps, UL Mbps) in `speed_reference.csv`.
- Car charger only for routes 1–3; the soak test runs on battery.
- One SIM per operator under test; note operator, SIM plan, device model,
  Android version, app versions.

## 2. Setup (each device, before leaving)
1. Settings → Date & time: automatic (network) time on. Both apps use the
   phone clock, so logs align without an offset.
2. OpenNetIQ: fresh install, *Agree* on the consent screen, grant
   permissions, disable battery optimisation when the Drive test screen asks.
3. Reference app: logging interval 1 s, export format CSV.
4. Note battery % and start time.

## 3. Routes (Port Moresby)
| Route | Type | Suggested path | Duration |
|---|---|---|---|
| 1 | Urban | Waigani – Boroko – Gordons (dense sites, handovers) | 45–60 min |
| 2 | Suburban | Gerehu – Morata – Hohola | 45–60 min |
| 3 | Highway | Hubert Murray Hwy / Magi Hwy outbound and back | 45–60 min |

Adjust to local conditions; record the actual path (the GeoJSON is the
record). Drive at normal traffic speed; do not stop the logs mid-route.

## 4. Procedure per route
1. Start the reference log, then OpenNetIQ *Drive test → Start* (type
   drive, 1 s).
2. Every ~10 min, stop in a safe place: run an OpenNetIQ speed test, then
   the reference speed test against the same server within 2 minutes.
   Repeat across routes until **≥ 30 pairs** in total.
3. At the end: stop OpenNetIQ, stop the reference log.
4. Export: OpenNetIQ session → *All formats*; reference log → CSV.
   Name files `routeN_*`. Keep originals unedited.

## 5. Soak and battery test
1. Phone charged to 100 %, unplugged, screen off, typical car or desk
   placement, OpenNetIQ drive recording at 1 s, no reference app running.
2. Run ≥ 2 h 10 min. Note battery % at start and stop.
3. Export CSV → `soak.csv`.

## 6. Analysis
```bash
onq-validate --json results/route1_radio.json radio --onq route1.csv \
  --ref route1_gnettrack.csv --profile gnettrack --ref-utc-offset 10
onq-validate --json results/throughput.json throughput \
  --onq all_tests.csv --ref speed_reference.csv
onq-validate --json results/soak.json sampling --onq soak.csv \
  --battery-start 100 --battery-end <end %>
onq-validate files --csv route1.csv --geojson route1.geojson
```
- Check the reference header first; if columns differ from the profile, add
  `--map rsrp=<col>` etc. If the reference stores local time, use
  `--ref-utc-offset 10` (PNG, UTC+10).
- `all_tests.csv`: concatenate the `_tests.csv` files of all routes (one
  header).
- Open every CSV in Excel and every GeoJSON in QGIS; note any problem.

## 7. Acceptance
All graded checks PASS on every route (radio per route; throughput pooled,
n ≥ 30; sampling and battery on the soak run). A FAIL is investigated, fixed
in a new issue and re-driven; results files are kept, not overwritten.

## 8. Data handling
Drive logs contain precise locations of the tester. Store them on NICTA
systems only, share with the project as needed, and delete raw logs after
the release decision unless retained as evidence.
