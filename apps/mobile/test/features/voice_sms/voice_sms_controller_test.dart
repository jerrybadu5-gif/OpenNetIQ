import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';
import 'package:opennetiq_mobile/features/voice_sms/application/voice_sms_controller.dart';

import '../../fixtures/consent_fixtures.dart';
import '../../fixtures/db_fixtures.dart';
import '../../fixtures/qoe_fixtures.dart';
import '../../fixtures/script_fixtures.dart';
import '../../fixtures/voice_sms_fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeVoiceSmsEngine engine;
  late MemorySettings settings;
  late FakeTestContext context;

  ProviderContainer container({bool consent = true}) {
    final c = ProviderContainer(
      overrides: [
        if (consent) voiceSmsConsentOverride else grantedConsentOverride,
        appDatabaseProvider.overrideWithValue(db),
        voiceSmsEngineProvider.overrideWithValue(engine),
        settingsRepositoryProvider.overrideWithValue(settings),
        testContextProvider.overrideWith(
          (ref) => context = FakeTestContext(ref),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> ready({bool consent = true}) async {
    final c = container(consent: consent);
    final sub = c.listen(voiceSmsPipelineProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(voiceSmsSettingsProvider.future);
    await c.read(consentProvider.future);
    return c;
  }

  setUp(() {
    db = memoryDatabase();
    engine = FakeVoiceSmsEngine();
    settings = MemorySettings()
      ..values[voiceSmsSettingsKey] = jsonEncode(
        smallVoiceSmsSettings.toJson(),
      );
  });
  tearDown(() => db.close());

  test('runs every number of the selected kinds and stores each', () async {
    final c = await ready();
    await c
        .read(voiceSmsControllerProvider.notifier)
        .run(VoiceSmsKind.values.toSet());
    expect(engine.calls, [
      'call:Line A:30',
      'sms:Me:true:20',
      'sms:Line B:false:20',
    ]);
    final s = c.read(voiceSmsControllerProvider);
    expect(s.running, isFalse);
    expect(s.done, 3);
    expect(s.error, isNull);
    expect(context.links, ['Voice/SMS test']);
    final rows = await db.select(db.voiceSmsTests).get();
    expect(rows.map((r) => r.targetMasked).toSet(), {'••67', '••11', '••22'});
    final sub = c.listen(voiceSmsHistoryProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(voiceSmsHistoryProvider.future), hasLength(3));
  });

  test('refuses to run without voice/SMS consent', () async {
    final c = await ready(consent: false);
    await c.read(voiceSmsControllerProvider.notifier).run({VoiceSmsKind.call});
    expect(engine.calls, isEmpty);
    expect(
      c.read(voiceSmsControllerProvider).error,
      'Allow voice and SMS tests in Privacy first.',
    );
  });

  test('no numbers configured', () async {
    settings.values.remove(voiceSmsSettingsKey);
    final c = await ready();
    await c.read(voiceSmsControllerProvider.notifier).run({VoiceSmsKind.sms});
    expect(
      c.read(voiceSmsControllerProvider).error,
      'Nothing to test: add test numbers first.',
    );
  });

  test('broken settings fall back to defaults; save persists', () async {
    settings.values[voiceSmsSettingsKey] = '{oops';
    final c = await ready();
    expect(c.read(voiceSmsSettingsProvider).value!.callTargets, isEmpty);
    await c.read(voiceSmsSettingsProvider.notifier).save(smallVoiceSmsSettings);
    expect(settings.values[voiceSmsSettingsKey], contains('Line A'));
  });

  test('cancel stops the run and drops the interrupted result', () async {
    final c = await ready();
    engine.gate = Completer<void>();
    final run = c
        .read(voiceSmsControllerProvider.notifier)
        .run(VoiceSmsKind.values.toSet());
    await pumpEventQueue();
    expect(c.read(voiceSmsControllerProvider).running, isTrue);
    expect(c.read(voiceSmsControllerProvider).current, 'Voice call: Line A');
    await c.read(voiceSmsControllerProvider.notifier).cancel();
    engine.gate!.complete();
    await run;
    expect(engine.cancels, 1);
    expect(c.read(voiceSmsControllerProvider).results, isEmpty);
    expect(await db.select(db.voiceSmsTests).get(), isEmpty);
  });
}
