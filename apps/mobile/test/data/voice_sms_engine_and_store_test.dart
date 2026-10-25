import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_consent_store.dart';
import 'package:opennetiq_mobile/data/local/drift_voice_sms_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_voice_sms_engine.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';

import '../fixtures/db_fixtures.dart';
import '../fixtures/voice_sms_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('platform engine', () {
    final calls = <MethodCall>[];
    const engine = PlatformVoiceSmsEngine();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      calls.clear();
      messenger.setMockMethodCallHandler(
        PlatformVoiceSmsEngine.voiceSmsChannel,
        (call) async {
          calls.add(call);
          return switch (call.method) {
            'permissions' => {'call': true, 'send_sms': true},
            'request_permissions' => throw PlatformException(code: 'NO'),
            'call' => {
              'status': 'ok',
              'outcome': 'completed',
              'target_masked': '••67',
              'window_s': 30,
              'call_ms': 30100.0,
              'setup_ms': 5100.0,
              'connected_s': 25,
              'dropped': false,
              'voice_rat': 'VoLTE',
            },
            'sms' => throw PlatformException(code: 'X', message: 'boom'),
            _ => null,
          };
        },
      );
    });
    tearDown(
      () => messenger.setMockMethodCallHandler(
        PlatformVoiceSmsEngine.voiceSmsChannel,
        null,
      ),
    );

    test('passes arguments and maps results', () async {
      final perms = await engine.permissions();
      expect(perms.call, isTrue);
      expect(perms.all, isFalse);
      expect((await engine.requestPermissions()).call, isFalse);
      const line = PhoneTarget('A', '+67571234567');
      final call = await engine.call(
        line,
        setupTimeout: const Duration(seconds: 20),
        hold: const Duration(seconds: 120),
      );
      expect(calls.last.arguments, {
        'number': '+67571234567',
        'window_ms': 140000,
        'setup_timeout_ms': 20000,
      });
      expect(call.status, TestStatus.ok);
      expect(call.setupMs, 5100);
      expect(call.connectedS, 25);
      expect(call.dropped, isFalse);
      expect(call.voiceRat, 'VoLTE');
      expect(call.loopback, isNull);
      const me = PhoneTarget('Me', '70000011', loopback: true);
      final sms = await engine.sms(me, timeout: const Duration(seconds: 20));
      expect(calls.last.arguments, {
        'number': '70000011',
        'loopback': true,
        'timeout_ms': 20000,
      });
      expect(sms.status, TestStatus.failed);
      expect(sms.outcome, 'not_sent');
      expect(sms.error, 'boom');
      expect(sms.targetMasked, '••11');
      expect(sms.loopback, isTrue);
      await engine.cancel();
      expect(calls.last.method, 'cancel');
    });
  });

  group('store', () {
    late AppDatabase db;
    setUp(() => db = memoryDatabase());
    tearDown(() => db.close());

    test('saves and watches newest first; no number stored', () async {
      final store = DriftVoiceSmsStore(db, now: () => DateTime.utc(2026, 10));
      final settings = smallVoiceSmsSettings;
      await store.saveVoiceSmsTests([
        VoiceSmsRecord(
          id: 'v1',
          timestamp: DateTime.utc(2026, 10, 1, 8),
          methodologyVersion: '1.0.0',
          result: callOk(settings.callTargets.first),
        ),
        VoiceSmsRecord(
          id: 'v2',
          timestamp: DateTime.utc(2026, 10, 1, 9),
          methodologyVersion: '1.0.0',
          result: smsOk(settings.smsTargets.first),
        ),
      ]);
      final list = await store.watchVoiceSmsTests().first;
      expect(list.map((r) => r.id), ['v2', 'v1']);
      expect(list.first.result.receiveMs, 5100);
      expect(list.last.result.setupMs, 4200);
      final rows = await db.select(db.voiceSmsTests).get();
      for (final r in rows) {
        expect(r.toJson().values.join(' '), isNot(contains('67571234567')));
      }
      expect(
        DriftVoiceSmsStore.recordOf(rows.first.copyWith(kind: 'nope')),
        isNull,
      );
      await DriftConsentStore(db).eraseMeasurements();
      expect(await db.select(db.voiceSmsTests).get(), isEmpty);
    });
  });

  test(
    'schema v2 upgrades to v3, keeping consent and adding voice_sms',
    () async {
      final raw = NativeDatabase.memory(
        setup: (db) {
          final ddl = File('../../database/mobile/schema_v2.sql')
              .readAsStringSync();
          final noComments = ddl
              .split('\n')
              .map((l) => l.split('--').first)
              .join('\n');
          for (final stmt in noComments.split(';')) {
            final sql = stmt.trim();
            if (sql.isEmpty || sql.startsWith('PRAGMA journal_mode')) continue;
            db.execute(sql);
          }
          db
            ..execute(
              "INSERT INTO consent_log VALUES ('c1','location',1,'1.0',"
              "'2026-10-01T00:00:00.000Z')",
            )
            ..execute('PRAGMA user_version = 2');
        },
      );
      final db = AppDatabase(DatabaseConnection(raw));
      addTearDown(db.close);
      final store = DriftConsentStore(db);
      final before = await store.ledger();
      expect(before.single.id, 'c1');
      await store.record(
        {ConsentScope.voiceSms},
        granted: true,
        policyVersion: '1.1',
      );
      final ledger = await store.ledger();
      expect(ledger.map((r) => r.scope), [
        ConsentScope.voiceSms,
        ConsentScope.location,
      ]);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 3);
      await expectLater(
        db.customStatement(
          "INSERT INTO consent_log VALUES ('c9','nope',1,'1.1','x')",
        ),
        throwsA(anything),
      );
    },
  );
}
