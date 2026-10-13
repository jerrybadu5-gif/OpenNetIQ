# Architecture: session export (#23)

```
domain/repositories/session_export_repository.dart  ExportFormat, ExportedFile,
                                                     SessionExporter, FileSharer
data/local/drift_export_store.dart                   load(sessionId) -> SessionExportData
data/export/csv.dart                                 RFC 4180 writer
data/export/session_export_builder.dart              samplesCsv / testsCsv / geoJson / fileBase
data/export/file_session_exporter.dart               SessionExporter -> cache/exports/*
platform/share_plus_file_sharer.dart                 FileSharer (share_plus, ADR-017)
features/export/application/session_export_controller.dart
features/export/presentation/export_sheet.dart       format picker, snack-bar outcome
```

Flow: `ExportSheet.show` → formats → `SessionExportController.export` →
`SessionExporter` (load in one read transaction, build strings, write files)
→ `FileSharer` → share sheet.

- **Serving-cell selection** (`ServingCells.of`): primary = first serving
  non-NR cell, else first serving cell (NR SA). In NSA the serving NR cell
  next to an LTE anchor fills the `nr_*` columns. Non-serving cells are
  counted (`neighbour_count`); full neighbour lists stay in the database for
  the Phase 2 upload format.
- Whole session held in memory: a 4 h drive at 1 s ≈ 14 400 samples, a few
  MB of CSV; streaming is not needed in Phase 1.
- No new tables, columns or permissions. share_plus provides its own
  FileProvider; files are never written to shared storage.
