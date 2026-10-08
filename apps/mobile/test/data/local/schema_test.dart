import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';

import '../../fixtures/db_fixtures.dart';

/// Column definitions parsed from database/mobile/schema_v1.sql.
class DdlColumn {
  DdlColumn(this.name, this.type, {required this.notNull});

  final String name;
  final String type;
  final bool notNull;
}

Map<String, List<DdlColumn>> parseDdl(String sql) {
  final tables = <String, List<DdlColumn>>{};
  String? current;
  for (final raw in sql.split('\n')) {
    final line = raw.split('--').first.trim();
    final create = RegExp(r'^CREATE TABLE (\w+)').firstMatch(line);
    if (create != null) {
      current = create.group(1);
      tables[current!] = [];
      continue;
    }
    if (current == null || line.isEmpty) continue;
    if (line.startsWith(')')) {
      current = null;
      continue;
    }
    final col = RegExp(r'^(\w+)\s+(TEXT|INTEGER|REAL)\b(.*)$').firstMatch(line);
    if (col == null) continue;
    final rest = col.group(3)!;
    tables[current]!.add(
      DdlColumn(
        col.group(1)!,
        col.group(2)!,
        notNull: rest.contains('NOT NULL') || rest.contains('PRIMARY KEY'),
      ),
    );
  }
  return tables;
}

void main() {
  late AppDatabase db;
  final ddl = parseDdl(
    File('../../database/mobile/schema_v1.sql').readAsStringSync(),
  );

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('reference DDL defines the 8 schema v1 tables', () {
    expect(ddl.keys.toSet(), {
      'devices',
      'sessions',
      'samples',
      'cell_observations',
      'speed_tests',
      'latency_tests',
      'app_settings',
      'consent_log',
    });
  });

  test(
    'every Drift table matches the reference DDL column by column',
    () async {
      for (final entry in ddl.entries) {
        final info = await db
            .customSelect('PRAGMA table_info(${entry.key})')
            .get();
        final actual = {
          for (final r in info)
            r.read<String>('name'): (
              r.read<String>('type').toUpperCase(),
              r.read<int>('notnull') == 1 || r.read<int>('pk') > 0,
            ),
        };
        expect(
          actual.keys.toSet(),
          entry.value.map((c) => c.name).toSet(),
          reason: 'columns of ${entry.key}',
        );
        for (final c in entry.value) {
          expect(actual[c.name]!.$1, c.type, reason: '${entry.key}.${c.name}');
          expect(
            actual[c.name]!.$2,
            c.notNull,
            reason: '${entry.key}.${c.name} NOT NULL',
          );
        }
      }
    },
  );

  test('indexes and foreign keys are in place', () async {
    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      containsAll(<String>['ix_samples_session_ts', 'ix_cells_measurement']),
    );
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.read<int>('foreign_keys'), 1);
  });

  test('check constraints reject invalid enum values', () async {
    const now = '2026-10-08T00:00:00.000Z';
    await db.customStatement(
      "INSERT INTO devices VALUES ('d1','m','x','14',34,NULL,'1.0.0','$now','$now')",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO sessions (session_id, device_id, name, session_type, "
        "status, sampling_interval_ms, methodology_version, created_at, "
        "updated_at) VALUES ('s1','d1','n','drive','recording',3000,'1.0.0',"
        "'$now','$now')",
      ),
      throwsA(anything),
    );
  });
}
