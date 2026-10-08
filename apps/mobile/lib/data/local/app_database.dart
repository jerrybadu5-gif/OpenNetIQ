import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opennetiq_mobile/data/local/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local SQLite database (ADR-004), schema v1 = database/mobile/schema_v1.sql.
/// Generated code: `dart run build_runner build --delete-conflicting-outputs`.
@DriftDatabase(
  tables: [
    Devices,
    Sessions,
    Samples,
    CellObservations,
    SpeedTests,
    LatencyTests,
    AppSettings,
    ConsentLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Database file in the app's private documents directory, WAL journal.
  factory AppDatabase.onDevice() => AppDatabase(_openOnDevice());

  static const String fileName = 'opennetiq.sqlite';

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openOnDevice() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, AppDatabase.fileName));
  return NativeDatabase.createInBackground(
    file,
    setup: (db) => db.execute('PRAGMA journal_mode = WAL;'),
  );
});
