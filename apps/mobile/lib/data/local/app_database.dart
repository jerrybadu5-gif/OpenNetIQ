import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:opennetiq_mobile/data/local/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local SQLite database (ADR-004), schema v2 = database/mobile/schema_v2.sql
/// (v1 + qoe_tests, issue #29).
/// Generated code: `dart run build_runner build --delete-conflicting-outputs`.
@DriftDatabase(
  tables: [
    Devices,
    Sessions,
    Samples,
    CellObservations,
    SpeedTests,
    LatencyTests,
    QoeTests,
    VoiceSmsTests,
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(qoeTests);
      if (from < 3) {
        await m.createTable(voiceSmsTests);
        await m.addColumn(sessions, sessions.region);
        await m.addColumn(sessions, sessions.areaClass);
        await m.addColumn(sessions, sessions.locationName);
        // Rebuilds consent_log for the new voice_sms scope CHECK.
        await m.alterTable(TableMigration(consentLog));
      }
    },
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
