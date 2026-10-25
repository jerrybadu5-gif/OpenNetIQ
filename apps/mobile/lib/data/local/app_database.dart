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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(qoeTests);
      if (from < 3) {
        await m.createTable(voiceSmsTests);
        // Rebuilds consent_log for the new voice_sms scope CHECK.
        await m.alterTable(TableMigration(consentLog));
      }
      if (from < 4) {
        // v4: campaign tags (M15), FTP columns (M14), voice technology.
        // Development builds shipped several v3 layouts, so each column is
        // added only when missing.
        await _addMissing(m, sessions, sessions.region);
        await _addMissing(m, sessions, sessions.areaClass);
        await _addMissing(m, sessions, sessions.locationName);
        await _addMissing(m, qoeTests, qoeTests.protocol);
        await _addMissing(m, qoeTests, qoeTests.servingLevelDbm);
        await _addMissing(m, qoeTests, qoeTests.servingRat);
        await _addMissing(m, voiceSmsTests, voiceSmsTests.voiceRat);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

extension on AppDatabase {
  Future<void> _addMissing(
    Migrator m,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final info = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    if (info.any((r) => r.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }
}

QueryExecutor _openOnDevice() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, AppDatabase.fileName));
  return NativeDatabase.createInBackground(
    file,
    setup: (db) => db.execute('PRAGMA journal_mode = WAL;'),
  );
});
