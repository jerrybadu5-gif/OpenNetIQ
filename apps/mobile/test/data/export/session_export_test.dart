import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/export/file_session_exporter.dart';
import 'package:opennetiq_mobile/data/export/session_export_builder.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_export_store.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/export_fixtures.dart';

/// Minimal RFC 4180 parser for assertions.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\r') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
      i++; // \n
    } else {
      field.write(c);
    }
  }
  return rows;
}

void main() {
  late AppDatabase db;
  late DriftExportStore store;

  setUp(() async {
    db = memoryDatabase();
    store = DriftExportStore(db);
    await seedExportSession(db);
  });
  tearDown(() => db.close());

  Future<SessionExportBuilder> builder() async =>
      SessionExportBuilder((await store.load(exportSessionId))!);

  test('missing session loads as null', () async {
    expect(await store.load('nope'), isNull);
  });

  test('samples CSV: one row per sample in time order, NSA split', () async {
    final rows = parseCsv((await builder()).samplesCsv());
    final header = rows.first;
    expect(header, SessionExportBuilder.sampleColumns);
    expect(rows, hasLength(4));
    for (final r in rows) {
      expect(r, hasLength(header.length));
    }
    Map<String, String> row(int i) => Map.fromIterables(header, rows[i]);

    final nsa = row(1);
    expect(nsa['measurement_id'], 'm1');
    expect(nsa['network_type'], 'NR_NSA');
    expect(nsa['operator'], 'Digicel, PNG');
    expect(nsa['device_model'], 'SM-A546E');
    expect(nsa['serving_rat'], 'LTE');
    expect(nsa['serving_enb_id'], '12345');
    expect(nsa['serving_rsrp_dbm'], '-88.0');
    expect(nsa['serving_pci_psc_bsic'], '101');
    expect(nsa['nr_gnb_id'], '777');
    expect(nsa['nr_ss_rsrp_dbm'], '-95.0');
    expect(nsa['nr_pci'], '501');
    expect(nsa['neighbour_count'], '1');
    expect(nsa['altitude_m'], '40.0');

    final lte = row(2);
    expect(lte['measurement_id'], 'm2');
    expect(lte['nr_ss_rsrp_dbm'], '');
    expect(lte['neighbour_count'], '0');

    final noFix = row(3);
    expect(noFix['lat'], '');
    expect(noFix['gps_quality'], 'NONE');
    expect(noFix['serving_rat'], '');
    expect(noFix['quality_flag'], 'NO_FIX');
  });

  test('tests CSV: both kinds, time order, located by their sample', () async {
    final rows = parseCsv((await builder()).testsCsv());
    final header = rows.first;
    expect(header, SessionExportBuilder.testColumns);
    expect(rows, hasLength(3));
    final latency = Map.fromIterables(header, rows[1]);
    final speed = Map.fromIterables(header, rows[2]);
    expect(latency['test_type'], 'latency');
    expect(latency['method'], 'tcp');
    expect(latency['lat'], '-9.45');
    expect(latency['raw_rtts_ms'], '[20.0,null,30.0]');
    expect(latency['dl_mean_mbps'], '');
    expect(speed['test_type'], 'speed');
    expect(speed['dl_mean_mbps'], '48.2');
    expect(speed['network_type'], 'LTE');
    expect(speed['rat_changed'], 'false');
    expect(speed['error'], 'upload: "slow", retried');
    expect(speed['probes_sent'], '');
  });

  test('GeoJSON: RFC 7946 track, located samples and tests', () async {
    final doc = jsonDecode((await builder()).geoJson()) as Map<String, Object?>;
    expect(doc['type'], 'FeatureCollection');
    final features = (doc['features']! as List).cast<Map<String, Object?>>();
    String type(Map<String, Object?> f) =>
        (f['properties']! as Map)['feature_type'] as String;
    expect(features.map(type), [
      'track',
      'sample',
      'sample',
      'speed_test',
      'latency_test',
    ]);
    final track = features.first;
    final geometry = track['geometry']! as Map;
    expect(geometry['type'], 'LineString');
    expect(geometry['coordinates'], [
      [147.17, -9.45],
      [147.18, -9.44],
    ]);
    expect((track['properties']! as Map)['samples_without_fix'], 1);
    final first = features[1]['geometry']! as Map;
    expect(first['coordinates'], [147.17, -9.45, 40.0]); // lon, lat, alt
    expect((features[1]['properties']! as Map)['nr_ss_rsrp_dbm'], -95.0);
    expect((features[3]['geometry']! as Map)['coordinates'], [147.18, -9.44]);
  });

  test('a track needs two located samples', () async {
    final data = (await store.load(exportSessionId))!;
    final single = SessionExportData(
      session: data.session,
      samples: data.samples.take(1).toList(),
      cells: data.cells,
    );
    final doc = jsonDecode(SessionExportBuilder(single).geoJson()) as Map;
    expect(((doc['features'] as List).first as Map)['geometry'], isNull);
  });

  test('file name: slug and compact UTC start', () async {
    expect(
      (await builder()).fileBase,
      'opennetiq_pom-route-1_20261013T010000Z',
    );
    final data = (await store.load(exportSessionId))!;
    final odd = SessionExportData(
      session: data.session.copyWith(name: '***', startedAt: const Value(null)),
      samples: const [],
      cells: const {},
    );
    expect(
      SessionExportBuilder(odd).fileBase,
      'opennetiq_session_20261013T010000Z',
    );
  });

  group('FileSessionExporter', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('onq_export_');
    });
    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    FileSessionExporter exporter() => FileSessionExporter(
      load: store.load,
      directory: () async => Directory('${dir.path}/exports'),
    );

    test('writes CSV, tests CSV and GeoJSON', () async {
      final files = await exporter().export(exportSessionId, {
        ExportFormat.csv,
        ExportFormat.geojson,
      });
      expect(files.map((f) => f.name), [
        'opennetiq_pom-route-1_20261013T010000Z.csv',
        'opennetiq_pom-route-1_20261013T010000Z_tests.csv',
        'opennetiq_pom-route-1_20261013T010000Z.geojson',
      ]);
      expect(files.map((f) => f.rows), [3, 2, 5]);
      expect(files.last.mimeType, 'application/geo+json');
      for (final f in files) {
        expect(File(f.path).existsSync(), isTrue);
      }
    });

    test(
      'previous exports are replaced; no tests file without tests',
      () async {
        await exporter().export(exportSessionId, {ExportFormat.geojson});
        await db.delete(db.speedTests).go();
        await db.delete(db.latencyTests).go();
        final files = await exporter().export(exportSessionId, {
          ExportFormat.csv,
        });
        expect(files.map((f) => f.name), [
          'opennetiq_pom-route-1_20261013T010000Z.csv',
        ]);
        expect(Directory('${dir.path}/exports').listSync(), hasLength(1));
      },
    );

    test('unknown session throws', () async {
      expect(
        exporter().export('nope', {ExportFormat.csv}),
        throwsA(isA<StateError>()),
      );
    });
  });
}
