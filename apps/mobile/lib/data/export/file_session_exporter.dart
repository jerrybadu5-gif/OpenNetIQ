import 'dart:io';

import 'package:opennetiq_mobile/data/export/kml_builder.dart';
import 'package:opennetiq_mobile/data/export/session_export_builder.dart';
import 'package:opennetiq_mobile/domain/repositories/session_export_repository.dart';
import 'package:path/path.dart' as p;

/// Writes export files into a private directory (shared afterwards through
/// the share sheet; nothing is written to public storage).
class FileSessionExporter implements SessionExporter {
  const FileSessionExporter({required this.load, required this.directory});

  final Future<SessionExportData?> Function(String sessionId) load;

  /// Target directory, created if missing. Old exports there are replaced.
  final Future<Directory> Function() directory;

  static const csvMime = 'text/csv';
  static const geoJsonMime = 'application/geo+json';
  static const kmlMime = 'application/vnd.google-earth.kml+xml';

  @override
  Future<List<ExportedFile>> export(
    String sessionId,
    Set<ExportFormat> formats,
  ) async {
    final data = await load(sessionId);
    if (data == null) throw StateError('Session $sessionId not found');
    final builder = SessionExportBuilder(data);
    final dir = await directory();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await dir.create(recursive: true);
    final base = builder.fileBase;
    final files = <ExportedFile>[];
    Future<void> write(String name, String mime, String body, int rows) async {
      final path = p.join(dir.path, name);
      await File(path).writeAsString(body, flush: true);
      files.add(
        ExportedFile(path: path, name: name, mimeType: mime, rows: rows),
      );
    }

    if (formats.contains(ExportFormat.csv)) {
      await write(
        '$base.csv',
        csvMime,
        builder.samplesCsv(),
        data.samples.length,
      );
      if (data.hasTests) {
        await write(
          '${base}_tests.csv',
          csvMime,
          builder.testsCsv(),
          data.speedTests.length + data.latencyTests.length,
        );
      }
    }
    if (formats.contains(ExportFormat.csv) && data.qoeTests.isNotEmpty) {
      await write(
        '${base}_qoe.csv',
        csvMime,
        builder.qoeCsv(),
        data.qoeTests.length,
      );
    }
    if (formats.contains(ExportFormat.geojson)) {
      final located = data.samples
          .where((s) => s.lat != null && s.lon != null)
          .length;
      await write(
        '$base.geojson',
        geoJsonMime,
        builder.geoJson(),
        1 +
            located +
            data.speedTests.length +
            data.latencyTests.length +
            data.qoeTests.length,
      );
    }
    if (formats.contains(ExportFormat.kml)) {
      final kml = KmlBuilder(data);
      await write(
        '$base.kml',
        kmlMime,
        kml.build(),
        data.samples.where((s) => s.lat != null && s.lon != null).length,
      );
    }
    return files;
  }
}
