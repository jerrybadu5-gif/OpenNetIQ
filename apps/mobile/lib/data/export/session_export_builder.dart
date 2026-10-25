import 'dart:convert';

import 'package:opennetiq_mobile/data/export/csv.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';

/// Everything stored for one session, as raw rows (raw-first: exports carry
/// stored values unchanged; derived KPIs stay in the analysis tools).
class SessionExportData {
  const SessionExportData({
    required this.session,
    required this.samples,
    required this.cells,
    this.device,
    this.speedTests = const [],
    this.latencyTests = const [],
    this.qoeTests = const [],
    this.voiceSmsTests = const [],
  });

  final SessionRow session;
  final DeviceRow? device;

  /// Ordered by timestamp.
  final List<SampleRow> samples;

  /// Cell observations per measurement_id, in insertion order.
  final Map<String, List<CellObservationRow>> cells;
  final List<SpeedTestRow> speedTests;
  final List<LatencyTestRow> latencyTests;
  final List<QoeTestRow> qoeTests;
  final List<VoiceSmsTestRow> voiceSmsTests;

  bool get hasTests => speedTests.isNotEmpty || latencyTests.isNotEmpty;
}

/// Serving cell (LTE anchor in NSA, the only cell in SA/legacy) and the NR
/// leg reported next to an LTE anchor.
class ServingCells {
  const ServingCells(this.primary, this.nrLeg, this.neighbours);

  /// First serving non-NR cell, else first serving cell (NR SA).
  factory ServingCells.of(List<CellObservationRow> cells) {
    final serving = [
      for (final c in cells)
        if (c.isServing) c,
    ];
    CellObservationRow? primary;
    for (final c in serving) {
      if (c.rat != 'NR') {
        primary = c;
        break;
      }
    }
    primary ??= serving.isEmpty ? null : serving.first;
    CellObservationRow? nr;
    if (primary != null && primary.rat != 'NR') {
      for (final c in serving) {
        if (c.rat == 'NR') {
          nr = c;
          break;
        }
      }
    }
    return ServingCells(primary, nr, cells.length - serving.length);
  }

  final CellObservationRow? primary;
  final CellObservationRow? nrLeg;
  final int neighbours;
}

/// CSV / GeoJSON serialisation of a session (docs/features/export/API.md).
class SessionExportBuilder {
  const SessionExportBuilder(this.data);

  final SessionExportData data;

  static const sampleColumns = [
    'session_id',
    'session_name',
    'session_type',
    'device_id',
    'device_manufacturer',
    'device_model',
    'android_version',
    'methodology_version',
    'measurement_id',
    'timestamp',
    'lat',
    'lon',
    'altitude_m',
    'speed_mps',
    'bearing_deg',
    'h_accuracy_m',
    'v_accuracy_m',
    'satellites_used',
    'gps_quality',
    'operator',
    'mcc',
    'mnc',
    'sim_operator',
    'network_type',
    'data_state',
    'is_roaming',
    'radio_timestamp',
    'quality_flag',
    'serving_rat',
    'serving_mcc',
    'serving_mnc',
    'serving_lac_tac',
    'serving_cell_id',
    'serving_enb_id',
    'serving_gnb_id',
    'serving_local_cell_id',
    'serving_pci_psc_bsic',
    'serving_arfcn',
    'serving_band',
    'serving_bandwidth_khz',
    'serving_rssi_dbm',
    'serving_rscp_dbm',
    'serving_ecno_db',
    'serving_rsrp_dbm',
    'serving_rsrq_db',
    'serving_sinr_db',
    'serving_cqi',
    'serving_timing_advance',
    'serving_quality_flag',
    'nr_cell_id',
    'nr_gnb_id',
    'nr_pci',
    'nr_arfcn',
    'nr_band',
    'nr_ss_rsrp_dbm',
    'nr_ss_rsrq_db',
    'nr_ss_sinr_db',
    'nr_csi_rsrp_dbm',
    'nr_csi_rsrq_db',
    'nr_csi_sinr_db',
    'neighbour_count',
  ];

  static const testColumns = [
    'test_type',
    'test_id',
    'session_id',
    'measurement_id',
    'timestamp',
    'methodology_version',
    'status',
    'method',
    'target',
    'lat',
    'lon',
    'network_type',
    'dl_mean_mbps',
    'dl_median_mbps',
    'dl_p10_mbps',
    'dl_p90_mbps',
    'dl_peak_mbps',
    'dl_bytes',
    'ul_mean_mbps',
    'ul_median_mbps',
    'ul_p10_mbps',
    'ul_p90_mbps',
    'ul_peak_mbps',
    'ul_bytes',
    'dns_ms',
    'tcp_connect_ms',
    'streams',
    'rat_changed',
    'probes_sent',
    'probes_received',
    'min_ms',
    'max_ms',
    'mean_ms',
    'median_ms',
    'p95_ms',
    'jitter_ms',
    'packet_loss_pct',
    'raw_rtts_ms',
    'error',
  ];

  /// `opennetiq_<session-name>_<UTC-start>` (ROADMAP 1.8).
  String get fileBase {
    final s = data.session;
    final slug = s.name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final name = slug.isEmpty
        ? 'session'
        : slug.substring(0, slug.length > 40 ? 40 : slug.length);
    final start = (s.startedAt ?? s.createdAt)
        .replaceAll(RegExp(r'\.\d+'), '')
        .replaceAll(RegExp('[-:]'), '');
    return 'opennetiq_${name}_$start';
  }

  List<Object?> _sampleRow(SampleRow s) {
    final session = data.session;
    final device = data.device;
    final cells = ServingCells.of(data.cells[s.measurementId] ?? const []);
    final p = cells.primary;
    final nr = cells.nrLeg;
    return [
      session.sessionId,
      session.name,
      session.sessionType,
      session.deviceId,
      device?.manufacturer,
      device?.model,
      device?.androidVersion,
      session.methodologyVersion,
      s.measurementId,
      s.timestamp,
      s.lat,
      s.lon,
      s.altitudeM,
      s.speedMps,
      s.bearingDeg,
      s.hAccuracyM,
      s.vAccuracyM,
      s.satellitesUsed,
      s.gpsQuality,
      s.operatorName,
      s.mcc,
      s.mnc,
      s.simOperator,
      s.networkType,
      s.dataState,
      s.isRoaming,
      s.radioTimestamp,
      s.qualityFlag,
      p?.rat,
      p?.mcc,
      p?.mnc,
      p?.lacTac,
      p?.cellId,
      p?.enbId,
      p?.gnbId,
      p?.localCellId,
      p?.pciPscBsic,
      p?.arfcn,
      p?.band,
      p?.bandwidthKhz,
      p?.rssiDbm,
      p?.rscpDbm,
      p?.ecnoDb,
      p?.rsrpDbm,
      p?.rsrqDb,
      p?.sinrDb,
      p?.cqi,
      p?.timingAdvance,
      p?.qualityFlag,
      nr?.cellId,
      nr?.gnbId,
      nr?.pciPscBsic,
      nr?.arfcn,
      nr?.band,
      nr?.rsrpDbm,
      nr?.rsrqDb,
      nr?.sinrDb,
      nr?.csiRsrpDbm,
      nr?.csiRsrqDb,
      nr?.csiSinrDb,
      cells.neighbours,
    ];
  }

  String samplesCsv() =>
      csvDocument(sampleColumns, data.samples.map(_sampleRow));

  Map<String, SampleRow> get _samplesById => {
    for (final s in data.samples) s.measurementId: s,
  };

  List<List<Object?>> _testRows() {
    final byId = _samplesById;
    final rows = <(String, List<Object?>)>[];
    for (final t in data.speedTests) {
      final s = byId[t.measurementId];
      rows.add((
        t.timestamp,
        [
          'speed',
          t.testId,
          t.sessionId,
          t.measurementId,
          t.timestamp,
          t.methodologyVersion,
          t.status,
          t.method,
          t.serverHost,
          s?.lat,
          s?.lon,
          s?.networkType,
          t.dlMeanMbps,
          t.dlMedianMbps,
          t.dlP10Mbps,
          t.dlP90Mbps,
          t.dlPeakMbps,
          t.dlBytes,
          t.ulMeanMbps,
          t.ulMedianMbps,
          t.ulP10Mbps,
          t.ulP90Mbps,
          t.ulPeakMbps,
          t.ulBytes,
          t.dnsMs,
          t.tcpConnectMs,
          t.streams,
          t.ratChanged,
          ...List<Object?>.filled(9, null),
          null,
          t.error,
        ],
      ));
    }
    for (final t in data.latencyTests) {
      final s = byId[t.measurementId];
      rows.add((
        t.timestamp,
        [
          'latency',
          t.testId,
          t.sessionId,
          t.measurementId,
          t.timestamp,
          t.methodologyVersion,
          t.status,
          t.protocol,
          t.target,
          s?.lat,
          s?.lon,
          s?.networkType,
          ...List<Object?>.filled(16, null),
          t.probesSent,
          t.probesReceived,
          t.minMs,
          t.maxMs,
          t.meanMs,
          t.medianMs,
          t.p95Ms,
          t.jitterMs,
          t.packetLossPct,
          t.rawRttsMs,
          null,
        ],
      ));
    }
    rows.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final r in rows) r.$2];
  }

  /// Speed and latency tests of the session, in time order.
  String testsCsv() => csvDocument(testColumns, _testRows());

  static const qoeColumns = [
    'test_id',
    'session_id',
    'measurement_id',
    'timestamp',
    'methodology_version',
    'kind',
    'label',
    'target',
    'status',
    'error',
    'lat',
    'lon',
    'network_type',
    'total_ms',
    'dns_ms',
    'connect_ms',
    'tls_ms',
    'ttfb_ms',
    'dom_ms',
    'http_status',
    'start_delay_ms',
    'rebuffer_count',
    'rebuffer_ms',
    'played_ms',
    'bitrate_kbps',
    'resolution',
    'bytes',
    'rate_mbps',
    'direction',
  ];

  /// Customer-experience tests (issue #29), in time order.
  String qoeCsv() {
    final byId = _samplesById;
    final rows = [...data.qoeTests]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return csvDocument(qoeColumns, [
      for (final t in rows)
        [
          t.testId,
          t.sessionId,
          t.measurementId,
          t.timestamp,
          t.methodologyVersion,
          t.kind,
          t.label,
          t.target,
          t.status,
          t.error,
          byId[t.measurementId]?.lat,
          byId[t.measurementId]?.lon,
          byId[t.measurementId]?.networkType,
          t.totalMs,
          t.dnsMs,
          t.connectMs,
          t.tlsMs,
          t.ttfbMs,
          t.domMs,
          t.httpStatus,
          t.startDelayMs,
          t.rebufferCount,
          t.rebufferMs,
          t.playedMs,
          t.bitrateKbps,
          t.resolution,
          t.bytes,
          t.rateMbps,
          t.direction,
        ],
    ]);
  }

  static const voiceSmsColumns = [
    'test_id',
    'session_id',
    'measurement_id',
    'timestamp',
    'methodology_version',
    'kind',
    'label',
    'target_masked',
    'status',
    'outcome',
    'error',
    'lat',
    'lon',
    'network_type',
    'window_s',
    'call_ms',
    'setup_ms',
    'connected_s',
    'dropped',
    'loopback',
    'send_ms',
    'delivery_ms',
    'receive_ms',
  ];

  /// Voice call and SMS tests (issue #30), in time order.
  String voiceSmsCsv() {
    final byId = _samplesById;
    final rows = [...data.voiceSmsTests]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return csvDocument(voiceSmsColumns, [
      for (final t in rows)
        [
          t.testId,
          t.sessionId,
          t.measurementId,
          t.timestamp,
          t.methodologyVersion,
          t.kind,
          t.label,
          t.targetMasked,
          t.status,
          t.outcome,
          t.error,
          byId[t.measurementId]?.lat,
          byId[t.measurementId]?.lon,
          byId[t.measurementId]?.networkType,
          t.windowS,
          t.callMs,
          t.setupMs,
          t.connectedS,
          t.dropped,
          t.loopback,
          t.sendMs,
          t.deliveryMs,
          t.receiveMs,
        ],
    ]);
  }

  /// RFC 7946 FeatureCollection (WGS 84, [lon, lat(, alt)]). Samples without
  /// a fix are left out; their count is in the track properties.
  String geoJson() {
    final s = data.session;
    final located = [
      for (final x in data.samples)
        if (x.lat != null && x.lon != null) x,
    ];
    List<double> coords(SampleRow x) => [
      x.lon!,
      x.lat!,
      if (x.altitudeM != null) x.altitudeM!,
    ];
    final features = <Map<String, Object?>>[
      {
        'type': 'Feature',
        'geometry': located.length < 2
            ? null
            : {
                'type': 'LineString',
                'coordinates': [
                  for (final x in located) [x.lon, x.lat],
                ],
              },
        'properties': {
          'feature_type': 'track',
          'session_id': s.sessionId,
          'session_name': s.name,
          'session_type': s.sessionType,
          'status': s.status,
          'device_id': s.deviceId,
          'methodology_version': s.methodologyVersion,
          'started_at': s.startedAt,
          'ended_at': s.endedAt,
          'sampling_interval_ms': s.samplingIntervalMs,
          'sample_count': data.samples.length,
          'samples_without_fix': data.samples.length - located.length,
          'distance_m': s.distanceM,
        },
      },
      for (final x in located)
        {
          'type': 'Feature',
          'geometry': {'type': 'Point', 'coordinates': coords(x)},
          'properties': _sampleProperties(x),
        },
    ];
    final byId = _samplesById;
    for (final t in data.speedTests) {
      final at = byId[t.measurementId];
      features.add({
        'type': 'Feature',
        'geometry': at?.lat == null || at?.lon == null
            ? null
            : {'type': 'Point', 'coordinates': coords(at!)},
        'properties': {
          'feature_type': 'speed_test',
          'test_id': t.testId,
          'measurement_id': t.measurementId,
          'timestamp': t.timestamp,
          'status': t.status,
          'method': t.method,
          'server_host': t.serverHost,
          'dl_mean_mbps': t.dlMeanMbps,
          'ul_mean_mbps': t.ulMeanMbps,
          'tcp_connect_ms': t.tcpConnectMs,
          'rat_changed': t.ratChanged,
          'methodology_version': t.methodologyVersion,
        },
      });
    }
    for (final t in data.latencyTests) {
      final at = byId[t.measurementId];
      features.add({
        'type': 'Feature',
        'geometry': at?.lat == null || at?.lon == null
            ? null
            : {'type': 'Point', 'coordinates': coords(at!)},
        'properties': {
          'feature_type': 'latency_test',
          'test_id': t.testId,
          'measurement_id': t.measurementId,
          'timestamp': t.timestamp,
          'status': t.status,
          'protocol': t.protocol,
          'target': t.target,
          'median_ms': t.medianMs,
          'jitter_ms': t.jitterMs,
          'packet_loss_pct': t.packetLossPct,
          'methodology_version': t.methodologyVersion,
        },
      });
    }
    for (final t in data.qoeTests) {
      final at = byId[t.measurementId];
      features.add({
        'type': 'Feature',
        'geometry': at?.lat == null || at?.lon == null
            ? null
            : {'type': 'Point', 'coordinates': coords(at!)},
        'properties': {
          'feature_type': 'qoe_test',
          'test_id': t.testId,
          'measurement_id': t.measurementId,
          'timestamp': t.timestamp,
          'kind': t.kind,
          'label': t.label,
          'status': t.status,
          'total_ms': t.totalMs,
          'start_delay_ms': t.startDelayMs,
          'rebuffer_count': t.rebufferCount,
          'rate_mbps': t.rateMbps,
          'methodology_version': t.methodologyVersion,
        },
      });
    }
    for (final t in data.voiceSmsTests) {
      final at = byId[t.measurementId];
      features.add({
        'type': 'Feature',
        'geometry': at?.lat == null || at?.lon == null
            ? null
            : {'type': 'Point', 'coordinates': coords(at!)},
        'properties': {
          'feature_type': 'voice_sms_test',
          'test_id': t.testId,
          'measurement_id': t.measurementId,
          'timestamp': t.timestamp,
          'kind': t.kind,
          'label': t.label,
          'status': t.status,
          'outcome': t.outcome,
          'setup_ms': t.setupMs,
          'dropped': t.dropped,
          'delivery_ms': t.deliveryMs,
          'receive_ms': t.receiveMs,
          'methodology_version': t.methodologyVersion,
        },
      });
    }
    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Map<String, Object?> _sampleProperties(SampleRow x) {
    final cells = ServingCells.of(data.cells[x.measurementId] ?? const []);
    final p = cells.primary;
    final nr = cells.nrLeg;
    return {
      'feature_type': 'sample',
      'measurement_id': x.measurementId,
      'timestamp': x.timestamp,
      'h_accuracy_m': x.hAccuracyM,
      'speed_mps': x.speedMps,
      'gps_quality': x.gpsQuality,
      'operator': x.operatorName,
      'mcc': x.mcc,
      'mnc': x.mnc,
      'network_type': x.networkType,
      'quality_flag': x.qualityFlag,
      'serving_rat': p?.rat,
      'serving_lac_tac': p?.lacTac,
      'serving_cell_id': p?.cellId,
      'serving_enb_id': p?.enbId,
      'serving_gnb_id': p?.gnbId,
      'serving_pci_psc_bsic': p?.pciPscBsic,
      'serving_arfcn': p?.arfcn,
      'serving_band': p?.band,
      'serving_rssi_dbm': p?.rssiDbm,
      'serving_rscp_dbm': p?.rscpDbm,
      'serving_rsrp_dbm': p?.rsrpDbm,
      'serving_rsrq_db': p?.rsrqDb,
      'serving_sinr_db': p?.sinrDb,
      'nr_ss_rsrp_dbm': nr?.rsrpDbm,
      'nr_ss_rsrq_db': nr?.rsrqDb,
      'nr_ss_sinr_db': nr?.sinrDb,
      'neighbour_count': cells.neighbours,
    };
  }
}
