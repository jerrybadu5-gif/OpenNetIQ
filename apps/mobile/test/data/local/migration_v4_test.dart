import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_measurement_store.dart';
import 'package:opennetiq_mobile/domain/entities/campaign_tags.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';

/// Opens a database created from the Phase D (#30) v3 DDL, as on test phones.
AppDatabase v3Database({bool withVoiceRat = false}) {
  final raw = NativeDatabase.memory(
    setup: (db) {
      final ddl = File('../../database/mobile/schema_v3.sql')
          .readAsStringSync();
      final sql = ddl.split('\n').map((l) => l.split('--').first).join('\n');
      for (final stmt in sql.split(';')) {
        final s = stmt.trim();
        if (s.isEmpty || s.startsWith('PRAGMA journal_mode')) continue;
        db.execute(s);
      }
      // A later development v3 build already had this column.
      if (withVoiceRat) {
        db.execute('ALTER TABLE voice_sms_tests ADD COLUMN voice_rat TEXT');
      }
      db
        ..execute(
          "INSERT INTO devices VALUES ('d1','m','x','14',34,NULL,'1.0.0',"
          "'2026-10-20T00:00:00.000Z','2026-10-20T00:00:00.000Z')",
        )
        ..execute(
          "INSERT INTO sessions (session_id, device_id, name, session_type, "
          "status, sampling_interval_ms, methodology_version, created_at, "
          "updated_at) VALUES ('old','d1','Old drive','drive','completed',"
          "1000,'1.0.0','2026-10-20T00:00:00.000Z','2026-10-20T00:00:00.000Z')",
        )
        ..execute('PRAGMA user_version = 3');
    },
  );
  return AppDatabase(DatabaseConnection(raw));
}

Future<Set<String>> columns(AppDatabase db, String table) async => {
  for (final r in await db.customSelect('PRAGMA table_info($table)').get())
    r.read<String>('name'),
};

void main() {
  for (final withVoiceRat in [false, true]) {
    test(
      'v3 (voice_rat: $withVoiceRat) upgrades to v4; recording works',
      () async {
        final db = v3Database(withVoiceRat: withVoiceRat);
        addTearDown(db.close);
        final store = DriftMeasurementStore(db);
        final old = await store.getSession('old');
        expect(old!.name, 'Old drive'); // existing data kept
        expect(old.tags.isEmpty, isTrue);
        expect(
          await columns(db, 'sessions'),
          containsAll(['region', 'area_class', 'location_name']),
        );
        expect(
          await columns(db, 'qoe_tests'),
          containsAll(['protocol', 'serving_level_dbm', 'serving_rat']),
        );
        expect(await columns(db, 'voice_sms_tests'), contains('voice_rat'));
        final s = await store.createSession(
          deviceId: 'd1',
          name: 'New',
          type: SessionType.drive,
          samplingIntervalMs: 1000,
          tags: const CampaignTags(
            region: 'Southern',
            areaClass: AreaClass.urban,
          ),
        );
        expect(s.tags.region, 'Southern');
        final v = await db.customSelect('PRAGMA user_version').getSingle();
        expect(v.read<int>('user_version'), 4);
      },
    );
  }
}
