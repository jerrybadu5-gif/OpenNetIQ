/// Session export (issue #23): CSV / GeoJSON files, shared by the OS.
library;

enum ExportFormat {
  /// Samples CSV (one row per sample) plus a tests CSV when the session
  /// holds speed or latency tests.
  csv,

  /// RFC 7946 FeatureCollection: track, samples, tests.
  geojson,

  /// KML 2.2 for Google Earth: coloured track, samples, estimated sites.
  kml,
}

class ExportedFile {
  const ExportedFile({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.rows,
  });

  final String path;
  final String name;
  final String mimeType;

  /// Data rows (CSV) or features (GeoJSON) written.
  final int rows;
}

abstract interface class SessionExporter {
  /// Writes the requested files; throws [StateError] if the session does
  /// not exist.
  Future<List<ExportedFile>> export(
    String sessionId,
    Set<ExportFormat> formats,
  );
}

abstract interface class FileSharer {
  Future<void> share(List<ExportedFile> files, {required String subject});
}
