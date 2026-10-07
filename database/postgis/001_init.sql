-- OpenNetIQ server schema draft (Phase 2). Becomes Alembic revision 0001 in backend/api.
-- PostgreSQL 16 + PostGIS 3.4 + h3-pg.
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS h3;
CREATE EXTENSION IF NOT EXISTS h3_postgis CASCADE;

CREATE TABLE organisations (
  organisation_id  uuid PRIMARY KEY,
  name             text NOT NULL,
  org_type         text NOT NULL CHECK (org_type IN ('regulator','operator','university','public','other')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  version          integer NOT NULL DEFAULT 1
);

CREATE TABLE devices (
  device_id        uuid PRIMARY KEY,
  organisation_id  uuid REFERENCES organisations,
  manufacturer     text NOT NULL,
  model            text NOT NULL,
  android_version  text NOT NULL,
  api_level        integer NOT NULL,
  chipset          text,
  app_version      text NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  session_id           uuid PRIMARY KEY,
  device_id            uuid NOT NULL REFERENCES devices,
  organisation_id      uuid REFERENCES organisations,
  name                 text NOT NULL,
  session_type         text NOT NULL,
  status               text NOT NULL,
  sampling_interval_ms integer NOT NULL,
  operator_under_test  text,
  methodology_version  text NOT NULL,
  started_at           timestamptz,
  ended_at             timestamptz,
  track                geography(LineString, 4326),
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  created_by           uuid,
  version              integer NOT NULL DEFAULT 1
);

CREATE TABLE samples (
  measurement_id   uuid NOT NULL,
  session_id       uuid NOT NULL,
  ts               timestamptz NOT NULL,
  geom             geography(Point, 4326),
  h3_r9            h3index GENERATED ALWAYS AS (h3_lat_lng_to_cell(geom::geometry, 9)) STORED,
  altitude_m       real,
  speed_mps        real,
  h_accuracy_m     real,
  gps_quality      text,
  operator         text,
  mcc              text,
  mnc              text,
  network_type     text NOT NULL,
  is_roaming       boolean,
  serving_rat      text,
  serving_cell_id  bigint,
  serving_pci      integer,
  serving_arfcn    integer,
  rsrp_dbm         real,
  rsrq_db          real,
  sinr_db          real,
  rssi_dbm         real,
  cqi              smallint,
  quality_flag     text,
  ingested_at      timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (measurement_id, ts)
) PARTITION BY RANGE (ts);

CREATE INDEX ix_samples_geom    ON samples USING gist (geom);
CREATE INDEX ix_samples_ts_brin ON samples USING brin (ts);
CREATE INDEX ix_samples_h3      ON samples (h3_r9, operator, network_type);
CREATE INDEX ix_samples_session ON samples (session_id, ts);

-- Example monthly partition; created by a scheduled job in production.
CREATE TABLE samples_2026_10 PARTITION OF samples FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE cell_observations (
  observation_id   uuid PRIMARY KEY,
  measurement_id   uuid NOT NULL,
  ts               timestamptz NOT NULL,
  is_serving       boolean NOT NULL,
  rat              text NOT NULL,
  mcc text, mnc text, lac_tac integer, cell_id bigint, enb_id integer, gnb_id bigint,
  pci_psc_bsic integer, arfcn integer, band text, bandwidth_khz integer,
  rssi_dbm real, rscp_dbm real, ecno_db real, rsrp_dbm real, rsrq_db real, sinr_db real,
  cqi smallint, timing_advance integer, csi_rsrp_dbm real, csi_rsrq_db real, csi_sinr_db real,
  quality_flag text
);
CREATE INDEX ix_cells_measurement ON cell_observations (measurement_id);
CREATE INDEX ix_cells_identity    ON cell_observations (mcc, mnc, cell_id);

CREATE TABLE speed_tests (
  test_id uuid PRIMARY KEY, session_id uuid, measurement_id uuid, ts timestamptz NOT NULL,
  geom geography(Point, 4326), operator text, network_type text,
  method text NOT NULL, methodology_version text NOT NULL, server_id text NOT NULL, streams integer,
  dns_ms real, tcp_connect_ms real,
  dl_mean_mbps real, dl_median_mbps real, dl_p10_mbps real, dl_p90_mbps real, dl_peak_mbps real, dl_bytes bigint,
  ul_mean_mbps real, ul_median_mbps real, ul_p10_mbps real, ul_p90_mbps real, ul_peak_mbps real, ul_bytes bigint,
  rat_changed boolean NOT NULL DEFAULT false, status text NOT NULL, error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ix_speed_geom ON speed_tests USING gist (geom);

CREATE TABLE latency_tests (
  test_id uuid PRIMARY KEY, session_id uuid, measurement_id uuid, ts timestamptz NOT NULL,
  geom geography(Point, 4326), operator text, network_type text,
  protocol text NOT NULL, methodology_version text NOT NULL, target text NOT NULL,
  probes_sent integer NOT NULL, probes_received integer NOT NULL,
  min_ms real, max_ms real, mean_ms real, median_ms real, p95_ms real, jitter_ms real, packet_loss_pct real,
  raw_rtts_ms real[], status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Coverage aggregate (refreshed by worker): H3 r9 × operator × network_type.
CREATE MATERIALIZED VIEW coverage_h3_r9 AS
SELECT h3_r9, operator, network_type,
       count(*)                                                     AS sample_count,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY rsrp_dbm)        AS rsrp_median_dbm,
       percentile_cont(0.1) WITHIN GROUP (ORDER BY rsrp_dbm)        AS rsrp_p10_dbm,
       avg((rsrp_dbm >= -105)::int)::real * 100                     AS pct_rsrp_ge_minus105,
       max(ts)                                                      AS last_seen
FROM samples
WHERE rsrp_dbm IS NOT NULL AND gps_quality = 'GOOD'
GROUP BY h3_r9, operator, network_type;
CREATE UNIQUE INDEX ux_coverage_h3_r9 ON coverage_h3_r9 (h3_r9, operator, network_type);
