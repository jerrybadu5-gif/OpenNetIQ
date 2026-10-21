import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/export/file_session_exporter.dart';
import 'package:opennetiq_mobile/data/export/kml_builder.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_export_store.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/export_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftExportStore store;

  setUp(() async {
    db = memoryDatabase();
    store = DriftExportStore(db);
    await seedExportSession(db, name: 'Route <1> & "A"');
  });
  tearDown(() => db.close());

  test('KML: escaped name, styles, track, samples, site folder', () async {
    final kml = KmlBuilder((await store.load(exportSessionId))!).build();
    expect(kml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(kml, contains('<kml xmlns="http://www.opengis.net/kml/2.2">'));
    expect(kml, contains('<name>Route &lt;1&gt; &amp; &quot;A&quot;</name>'));
    expect(kml, contains('<Style id="q_good">'));
    expect(kml, contains('<Folder><name>Track</name>'));
    expect(kml, contains('<Folder><name>Estimated sites</name>'));
    // Two located samples, lon,lat order.
    expect('<Point>'.allMatches(kml).length, greaterThanOrEqualTo(2));
    expect(kml, contains('<coordinates>147.17,-9.45,0</coordinates>'));
    expect(kml, contains('<when>2026-10-13T01:00:01.000Z</when>'));
    expect(kml.trimRight(), endsWith('</kml>'));
    // Balanced placemarks.
    expect(
      '<Placemark>'.allMatches(kml).length,
      '</Placemark>'.allMatches(kml).length,
    );
  });

  test('exporter writes the .kml file', () async {
    final dir = await Directory.systemTemp.createTemp('onq_kml_');
    addTearDown(() => dir.delete(recursive: true));
    final files = await FileSessionExporter(
      load: store.load,
      directory: () async => Directory('${dir.path}/x'),
    ).export(exportSessionId, {ExportFormat.kml});
    expect(files.single.name, endsWith('.kml'));
    expect(files.single.mimeType, 'application/vnd.google-earth.kml+xml');
    expect(files.single.rows, 2);
    expect(File(files.single.path).readAsStringSync(), contains('</kml>'));
  });
}
