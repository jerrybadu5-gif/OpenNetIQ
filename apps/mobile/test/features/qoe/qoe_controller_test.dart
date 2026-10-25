import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/features/qoe/application/qoe_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/qoe_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';
import '../../fixtures/script_fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeQoeEngine engine;
  late MemorySettings settings;
  late FakeTestContext context;

  ProviderContainer container({String? server = 'http://srv/backend/'}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        qoeEngineProvider.overrideWithValue(engine),
        settingsRepositoryProvider.overrideWithValue(settings),
        speedTestServerProvider.overrideWith((ref) async => server),
        testContextProvider.overrideWith(
          (ref) => context = FakeTestContext(ref),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = memoryDatabase();
    engine = FakeQoeEngine();
    settings = MemorySettings()
      ..values[qoeSettingsKey] = jsonEncode(smallSettings.toJson());
  });
  tearDown(() => db.close());

  test('runs every target of the selected kinds and stores each', () async {
    final c = container();
    await c
        .read(qoeTestControllerProvider.notifier)
        .run(QoeKind.values.toSet());
    expect(engine.calls, [
      'web:Google:30',
      'video:YouTube clip:20',
      'app:WhatsApp',
      'app:BSP',
      'file:2:down:http://srv/backend/',
      'file:2:up:http://srv/backend/',
    ]);
    final s = c.read(qoeTestControllerProvider);
    expect(s.running, isFalse);
    expect(s.done, 6);
    expect(s.total, 6);
    expect(s.error, isNull);
    expect(context.links, ['QoE test']); // linked once per run
    final rows = await db.select(db.qoeTests).get();
    expect(rows, hasLength(6));
    expect(rows.map((r) => r.kind).toSet(), {'web', 'video', 'app', 'file'});
    expect(rows.firstWhere((r) => r.kind == 'video').resolution, '720p');
    final sub = c.listen(qoeHistoryProvider, (_, _) {});
    addTearDown(sub.close);
    final history = await c.read(qoeHistoryProvider.future);
    expect(history, hasLength(6));
  });

  test('file transfer without a test server fails that step only', () async {
    final c = container(server: null);
    await c.read(qoeTestControllerProvider.notifier).run({
      QoeKind.app,
      QoeKind.file,
    });
    final s = c.read(qoeTestControllerProvider);
    expect(engine.calls, ['app:WhatsApp', 'app:BSP']);
    expect(s.results.last.status, TestStatus.failed);
    expect(s.results.last.error, contains('test server'));
  });

  test('cancel stops after the running target, nothing more stored', () async {
    final c = container();
    engine.gate = Completer<void>();
    final controller = c.read(qoeTestControllerProvider.notifier);
    final run = controller.run({QoeKind.app});
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(qoeTestControllerProvider).current,
      'App reachability: WhatsApp',
    );
    await controller.cancel();
    engine.gate!.complete();
    await run;
    expect(engine.cancels, 1);
    expect(engine.calls, ['app:WhatsApp']);
    expect(await db.select(db.qoeTests).get(), isEmpty);
    await controller.cancel(); // idle: no-op
    expect(engine.cancels, 1);
  });

  test('empty target lists and save errors are reported', () async {
    settings.values[qoeSettingsKey] = jsonEncode(
      const QoeSettings(web: [], apps: [], videos: []).toJson(),
    );
    final c = container();
    await c.read(qoeTestControllerProvider.notifier).run({QoeKind.web});
    expect(
      c.read(qoeTestControllerProvider).error,
      contains('Nothing to test'),
    );

    settings.values[qoeSettingsKey] = jsonEncode(smallSettings.toJson());
    final c2 = container();
    await c2.read(qoeSettingsProvider.future);
    await c2.read(qoeTestControllerProvider.notifier).run({QoeKind.web});
    expect(c2.read(qoeTestControllerProvider).error, isNull);
    context.linkError = StateError('disk full');
    await c2.read(qoeTestControllerProvider.notifier).run({QoeKind.web});
    expect(c2.read(qoeTestControllerProvider).error, contains('disk full'));
  });

  test('FTP: size by network, upload size, level tracked', () async {
    settings.values[qoeSettingsKey] = jsonEncode(
      smallSettings
          .copyWith(
            fileProtocol: FileProtocol.ftp,
            ftpUrl: 'ftp://ix.test/',
            ftpUser: 'onq',
            ftpPassword: 'long-test-pass',
            ftpUploadMib: 20,
            ftpMaxSeconds: 300,
          )
          .toJson(),
    );
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        qoeEngineProvider.overrideWithValue(engine),
        settingsRepositoryProvider.overrideWithValue(settings),
        testContextProvider.overrideWith(
          (ref) =>
              context = FakeTestContext(ref)
                ..radio = snapshot(networkType: 'UMTS'),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(qoeTestControllerProvider.notifier).run({QoeKind.file});
    expect(engine.calls, [
      'ftp:50:down:ftp://ix.test/:onq:300', // 3G: 50 MB (Rule Sch. 2 G9)
      'ftp:20:up:ftp://ix.test/:onq:300',
    ]);
    final rows = await db.select(db.qoeTests).get();
    expect(rows.map((r) => r.protocol).toSet(), {'ftp'});
    expect(rows.first.servingLevelDbm, -97.0);
    expect(rows.first.servingRat, 'LTE');
    expect(
      c.read(qoeTestControllerProvider).results.first.summary,
      startsWith('FTP download 20.0 Mbps'),
    );
  });

  test('FTP without server details fails each transfer', () async {
    settings.values[qoeSettingsKey] = jsonEncode(
      smallSettings.copyWith(fileProtocol: FileProtocol.ftp).toJson(),
    );
    final c = container(server: null);
    await c.read(qoeTestControllerProvider.notifier).run({QoeKind.file});
    expect(engine.calls, isEmpty);
    final r = c.read(qoeTestControllerProvider).results;
    expect(r, hasLength(2));
    expect(r.first.status, TestStatus.failed);
    expect(r.first.protocol, 'ftp');
    expect(r.first.error, contains('FTP server'));
  });

  test('settings: defaults, save, unreadable value', () async {
    settings.values.remove(qoeSettingsKey);
    final c = container();
    expect((await c.read(qoeSettingsProvider.future)).web.length, 5);
    await c.read(qoeSettingsProvider.notifier).save(smallSettings);
    expect(settings.values[qoeSettingsKey], contains('YouTube clip'));
    settings.values[qoeSettingsKey] = '{broken';
    final c2 = container();
    expect((await c2.read(qoeSettingsProvider.future)).web.length, 5);
  });
}
