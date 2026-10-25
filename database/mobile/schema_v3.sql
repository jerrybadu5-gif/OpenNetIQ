-- OpenNetIQ mobile local schema v3 (v2 + voice_sms_tests, consent scope voice_sms) (SQLite / Drift). Reference DDL; Drift table classes must match.
-- Conventions: UUIDv7 TEXT ids, UTC ISO 8601 TEXT timestamps, snake_case, NULL = unavailable.
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

CREATE TABLE devices (
  device_id            TEXT PRIMARY KEY,          -- random install UUIDv7, never IMEI
  manufacturer         TEXT NOT NULL,
  model                TEXT NOT NULL,
  android_version      TEXT NOT NULL,
  api_level            INTEGER NOT NULL,
  chipset              TEXT,
  app_version          TEXT NOT NULL,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE TABLE sessions (
  session_id           TEXT PRIMARY KEY,
  device_id            TEXT NOT NULL REFERENCES devices(device_id),
  name                 TEXT NOT NULL,
  session_type         TEXT NOT NULL CHECK (session_type IN ('drive','walk','static','single_test')),
  status               TEXT NOT NULL CHECK (status IN ('created','recording','paused','completed','aborted')),
  sampling_interval_ms INTEGER NOT NULL CHECK (sampling_interval_ms IN (1000,2000,5000)),
  operator_under_test  TEXT,
  notes                TEXT,
  region               TEXT,                      -- v3 campaign tags (spec v3 M15), e.g. Southern
  area_class           TEXT CHECK (area_class IN ('urban','semi_urban','rural')),
  location_name        TEXT,                      -- place name, e.g. Waigani
  methodology_version  TEXT NOT NULL,
  started_at           TEXT,
  ended_at             TEXT,
  sample_count         INTEGER NOT NULL DEFAULT 0,
  distance_m           REAL,
  sync_state           TEXT NOT NULL DEFAULT 'local' CHECK (sync_state IN ('local','queued','synced','failed')),
  version              INTEGER NOT NULL DEFAULT 1,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

-- One row per sampling tick: location + network context + serving-cell summary.
CREATE TABLE samples (
  measurement_id       TEXT PRIMARY KEY,
  session_id           TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  timestamp            TEXT NOT NULL,
  lat                  REAL,
  lon                  REAL,
  altitude_m           REAL,
  speed_mps            REAL,
  bearing_deg          REAL,
  h_accuracy_m         REAL,
  v_accuracy_m         REAL,
  satellites_used      INTEGER,
  gps_quality          TEXT CHECK (gps_quality IN ('GOOD','POOR','NONE')),
  operator             TEXT,                      -- network operator name
  mcc                  TEXT,
  mnc                  TEXT,
  sim_operator         TEXT,
  network_type         TEXT NOT NULL,
  data_state           TEXT,
  is_roaming           INTEGER,
  radio_timestamp      TEXT,
  quality_flag         TEXT,
  created_at           TEXT NOT NULL
);
CREATE INDEX ix_samples_session_ts ON samples(session_id, timestamp);

-- Serving and neighbour cells per sample.
CREATE TABLE cell_observations (
  observation_id       TEXT PRIMARY KEY,
  measurement_id       TEXT NOT NULL REFERENCES samples(measurement_id) ON DELETE CASCADE,
  is_serving           INTEGER NOT NULL,
  rat                  TEXT NOT NULL CHECK (rat IN ('GSM','WCDMA','LTE','NR','CDMA','TDSCDMA')),
  mcc                  TEXT,
  mnc                  TEXT,
  lac_tac              INTEGER,
  cell_id              INTEGER,                   -- CID / ECI / NCI (NCI may need 64-bit)
  enb_id               INTEGER,
  gnb_id               INTEGER,
  local_cell_id        INTEGER,
  pci_psc_bsic         INTEGER,
  arfcn                INTEGER,                   -- ARFCN / UARFCN / EARFCN / NR-ARFCN
  band                 TEXT,
  bandwidth_khz        INTEGER,
  rssi_dbm             REAL,
  rscp_dbm             REAL,
  ecno_db              REAL,
  rsrp_dbm             REAL,
  rsrq_db              REAL,
  sinr_db              REAL,
  cqi                  INTEGER,
  timing_advance       INTEGER,
  csi_rsrp_dbm         REAL,
  csi_rsrq_db          REAL,
  csi_sinr_db          REAL,
  quality_flag         TEXT
);
CREATE INDEX ix_cells_measurement ON cell_observations(measurement_id);

CREATE TABLE speed_tests (
  test_id              TEXT PRIMARY KEY,
  session_id           TEXT REFERENCES sessions(session_id) ON DELETE CASCADE,
  measurement_id       TEXT REFERENCES samples(measurement_id),  -- radio/GPS snapshot at start
  timestamp            TEXT NOT NULL,
  method               TEXT NOT NULL,             -- http-mc-1.0 | ndt7
  methodology_version  TEXT NOT NULL,
  server_id            TEXT NOT NULL,
  server_host          TEXT NOT NULL,
  streams              INTEGER NOT NULL,
  dns_ms               REAL,
  tcp_connect_ms       REAL,
  dl_mean_mbps         REAL,
  dl_median_mbps       REAL,
  dl_p10_mbps          REAL,
  dl_p90_mbps          REAL,
  dl_peak_mbps         REAL,
  dl_bytes             INTEGER,
  ul_mean_mbps         REAL,
  ul_median_mbps       REAL,
  ul_p10_mbps          REAL,
  ul_p90_mbps          REAL,
  ul_peak_mbps         REAL,
  ul_bytes             INTEGER,
  rat_changed          INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL CHECK (status IN ('ok','partial','failed')),
  error                TEXT,
  created_at           TEXT NOT NULL
);

CREATE TABLE latency_tests (
  test_id              TEXT PRIMARY KEY,
  session_id           TEXT REFERENCES sessions(session_id) ON DELETE CASCADE,
  measurement_id       TEXT REFERENCES samples(measurement_id),
  timestamp            TEXT NOT NULL,
  protocol             TEXT NOT NULL CHECK (protocol IN ('icmp','tcp','http','dns')),
  methodology_version  TEXT NOT NULL,
  target               TEXT NOT NULL,
  probes_sent          INTEGER NOT NULL,
  probes_received      INTEGER NOT NULL,
  min_ms               REAL,
  max_ms               REAL,
  mean_ms              REAL,
  median_ms            REAL,
  p95_ms               REAL,
  jitter_ms            REAL,
  packet_loss_pct      REAL,
  raw_rtts_ms          TEXT,                      -- JSON array, for recomputation
  status               TEXT NOT NULL CHECK (status IN ('ok','partial','failed')),
  created_at           TEXT NOT NULL
);

CREATE TABLE qoe_tests (                         -- v2 (issue #29), method qoe-1.0
  test_id              TEXT PRIMARY KEY,
  session_id           TEXT REFERENCES sessions(session_id) ON DELETE CASCADE,
  measurement_id       TEXT REFERENCES samples(measurement_id),
  timestamp            TEXT NOT NULL,
  kind                 TEXT NOT NULL CHECK (kind IN ('web','video','app','file')),
  methodology_version  TEXT NOT NULL,
  label                TEXT NOT NULL,             -- site / app / source name
  target               TEXT NOT NULL,             -- URL tested
  status               TEXT NOT NULL CHECK (status IN ('ok','partial','failed')),
  error                TEXT,
  total_ms             REAL,                      -- page load / response / transfer / test duration
  dns_ms               REAL,
  connect_ms           REAL,                      -- TCP only
  tls_ms               REAL,
  ttfb_ms              REAL,
  dom_ms               REAL,                      -- web: DOMContentLoaded
  http_status          INTEGER,
  start_delay_ms       REAL,                      -- video
  rebuffer_count       INTEGER,
  rebuffer_ms          REAL,
  played_ms            REAL,
  bitrate_kbps         REAL,
  resolution           TEXT,
  bytes                INTEGER,
  rate_mbps            REAL,                      -- file transfer
  direction            TEXT,                      -- file: download / upload
  protocol             TEXT CHECK (protocol IN ('http','ftp')), -- file (v3, M14)
  serving_level_dbm    REAL,                      -- file: mean serving RSRP/RSCP/RSSI during the transfer (v3)
  serving_rat          TEXT,                      -- file: LTE / NR / WCDMA / GSM (v3)
  created_at           TEXT NOT NULL
);

CREATE TABLE voice_sms_tests (                   -- v3 (issue #30), ADR-022; no number, no message text
  test_id              TEXT PRIMARY KEY,
  session_id           TEXT REFERENCES sessions(session_id) ON DELETE CASCADE,
  measurement_id       TEXT REFERENCES samples(measurement_id),
  timestamp            TEXT NOT NULL,             -- dialling / sending start
  kind                 TEXT NOT NULL CHECK (kind IN ('call','sms')),
  methodology_version  TEXT NOT NULL,
  label                TEXT NOT NULL,             -- test line name
  target_masked        TEXT NOT NULL,             -- last two digits only, e.g. ••67
  status               TEXT NOT NULL CHECK (status IN ('ok','partial','failed')),
  outcome              TEXT NOT NULL,             -- completed/dropped/setup_timeout/no_answer/rejected/not_placed/unknown/ended_early; received/delivered/not_received/no_report/delivery_failed/not_sent
  error                TEXT,
  window_s             INTEGER,                   -- call: release after dialling (setup timeout + holding)
  call_ms              REAL,                      -- call: dialling to release
  setup_ms             REAL,                      -- call: call_ms - connected_s (1 s resolution)
  connected_s          INTEGER,                   -- call: call-log duration
  dropped              INTEGER,                   -- call: released before the window ended after connecting
  voice_rat            TEXT,                      -- call: GSM / UMTS / VoLTE / VoNR seen in call, e.g. VoLTE>UMTS
  loopback             INTEGER,                   -- sms: sent to this phone
  send_ms              REAL,                      -- sms: submit to sent report
  delivery_ms          REAL,                      -- sms: submit to delivery report
  receive_ms           REAL,                      -- sms: submit to arrival (loopback)
  created_at           TEXT NOT NULL
);

CREATE TABLE app_settings (
  key                  TEXT PRIMARY KEY,
  value                TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE TABLE consent_log (
  consent_id           TEXT PRIMARY KEY,
  scope                TEXT NOT NULL CHECK (scope IN ('location','radio','background_location','upload','voice_sms')),
  granted              INTEGER NOT NULL,
  policy_version       TEXT NOT NULL,
  timestamp            TEXT NOT NULL
);
