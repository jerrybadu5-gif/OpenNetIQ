import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_qoe_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_qoe_engine.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';

import 'dart:io';

import '../fixtures/db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('platform engine', () {
    final calls = <MethodCall>[];
    const engine = PlatformQoeEngine();

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformQoeEngine.qoeChannel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'web' => {'total_ms': 1500.0, 'dns_ms': 12.0},
              'video' => {'start_delay_ms': 800.0, 'rebuffer_count': 0},
              'app' => throw PlatformException(code: 'X', message: 'boom'),
              'ftp' => {
                'protocol': 'ftp',
                'direction': 'download',
                'bytes': 104857600,
                'total_ms': 40000.0,
                'rate_mbps': 20.9,
              },
              'file' => {
                'total_ms': 1000.0,
                'rate_mbps': 41.9,
                'direction': 'upload',
              },
              _ => null,
            };
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformQoeEngine.qoeChannel, null),
    );

    test('passes arguments and maps results', () async {
      final web = await engine.web(
        const QoeTarget('G', 'https://g/'),
        timeout: const Duration(seconds: 30),
      );
      expect(calls.last.arguments, {'url': 'https://g/', 'timeout_ms': 30000});
      expect(web.totalMs, 1500);
      expect(web.label, 'G');
      final video = await engine.video(
        const QoeTarget('V', 'https://v/', mode: VideoMode.page),
        duration: const Duration(seconds: 20),
      );
      expect(calls.last.arguments, {
        'url': 'https://v/',
        'mode': 'page',
        'duration_ms': 20000,
      });
      expect(video.status, TestStatus.ok);
      final app = await engine.app(const QoeTarget('A', 'https://a/'));
      expect(app.status, TestStatus.failed);
      expect(app.error, 'boom');
      final file = await engine.file(
        serverUrl: 'http://s/backend/',
        sizeMib: 5,
        upload: true,
      );
      expect(calls.last.arguments, {
        'server_url': 'http://s/backend/',
        'size_mib': 5,
        'direction': 'upload',
      });
      expect(file.label, '5 MB upload');
      expect(file.rateMbps, 41.9);
      final ftp = await engine.ftp(
        url: 'ftp://ix/',
        user: 'onq',
        password: 'pw',
        sizeMib: 100,
        upload: false,
        maxDuration: const Duration(seconds: 600),
      );
      expect(calls.last.arguments, {
        'url': 'ftp://ix/',
        'user': 'onq',
        'password': 'pw',
        'size_mib': 100,
        'direction': 'download',
        'max_ms': 600000,
      });
      expect(ftp.protocol, 'ftp');
      expect(ftp.label, 'FTP 100 MB download');
      expect(ftp.rateMbps, 20.9);
      expect(file.protocol, 'http');
      await engine.cancel();
      expect(calls.last.method, 'cancel');
    });
  });

  group('store', () {
    late AppDatabase db;
    setUp(() => db = memoryDatabase());
    tearDown(() => db.close());

    test('saves and watches newest first', () async {
      final store = DriftQoeStore(db, now: () => DateTime.utc(2026, 10, 25, 2));
      await store.saveQoeTests([
        for (var i = 0; i < 3; i++)
          QoeRecord(
            id: 'q$i',
            timestamp: DateTime.utc(2026, 10, 25, 1, i),
            methodologyVersion: '1.0.0',
            result: QoeResult(
              kind: QoeKind.video,
              label: 'V$i',
              target: 'https://v/',
              status: TestStatus.partial,
              startDelayMs: 900,
              rebufferCount: i,
              resolution: '720p',
              error: 'late error',
            ),
          ),
      ]);
      final rows = await db.select(db.qoeTests).get();
      expect(rows.first.createdAt, '2026-10-25T02:00:00.000Z');
      final list = await store.watchQoeTests(limit: 2).first;
      expect(list.map((r) => r.id), ['q2', 'q1']);
      expect(list.first.result.rebufferCount, 2);
      expect(list.first.result.status, TestStatus.partial);
      expect(DriftQoeStore.recordOf(rows.first.copyWith(kind: 'nope')), isNull);
      await store.saveQoeTests([
        QoeRecord(
          id: 'f1',
          timestamp: DateTime.utc(2026, 10, 25, 3),
          methodologyVersion: '1.0.0',
          result: const QoeResult(
            kind: QoeKind.file,
            label: 'FTP',
            target: 'ftp://ix/',
            status: TestStatus.ok,
            rateMbps: 20,
            direction: 'download',
            protocol: 'ftp',
            servingLevelDbm: -97.5,
            servingRat: 'LTE',
          ),
        ),
      ]);
      final ftp = (await store.watchQoeTests(limit: 1).first).single.result;
      expect(ftp.protocol, 'ftp');
      expect(ftp.servingLevelDbm, -97.5);
      expect(ftp.servingRat, 'LTE');
    });
  });

  test(
    'schema v1 databases upgrade to the current version with qoe_tests',
    () async {
      final raw = NativeDatabase.memory(
        setup: (db) {
          final ddl = File('../../database/mobile/schema_v1.sql')
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
          db.execute('PRAGMA user_version = 1');
        },
      );
      final db = AppDatabase(DatabaseConnection(raw));
      addTearDown(db.close);
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(tables.map((r) => r.read<String>('name')), contains('qoe_tests'));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 3);
    },
  );
}
