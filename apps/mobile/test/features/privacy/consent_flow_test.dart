import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/domain/repositories/consent_repository.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/privacy/presentation/privacy_screen.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';

import '../../fixtures/consent_fixtures.dart';
import '../../fixtures/db_fixtures.dart';
import '../../fixtures/radio_fixtures.dart';
import '../../fixtures/recording_fixtures.dart';

class FakeEraser implements MeasurementDataEraser {
  int erases = 0;
  Object? error;

  @override
  Future<void> eraseMeasurements() async {
    final e = error;
    if (e != null) throw e;
    erases++;
  }
}

void main() {
  group('controller with the Drift ledger', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() {
      db = memoryDatabase();
      c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('undecided until answered, then logged per scope', () async {
      expect((await c.read(consentProvider.future)).decided, isFalse);
      expect(c.read(measurementConsentProvider), isFalse);
      await c.read(consentProvider.notifier).setMeasurement(granted: true);
      final status = await c.read(consentProvider.future);
      expect(status.measurement, isTrue);
      expect(c.read(measurementConsentProvider), isTrue);
      final rows = await db.select(db.consentLog).get();
      expect(rows.map((r) => r.scope).toSet(), {'location', 'radio'});
      expect(
        rows.every((r) => r.policyVersion == privacyPolicyVersion),
        isTrue,
      );

      await c.read(consentProvider.notifier).setMeasurement(granted: false);
      expect((await c.read(consentProvider.future)).measurement, isFalse);
      expect(await c.read(consentLedgerProvider.future), hasLength(4));
    });
  });

  group('radio permissions follow consent', () {
    test('no consent: Android is not asked, nothing monitored', () async {
      final radio = FakeRadioRepository(
        permissions: deniedPermissions,
        afterRequest: grantedPermissions,
      );
      final c = ProviderContainer(
        overrides: [
          consentProvider.overrideWith(
            () => FakeConsentController(consentStatus(measurement: false)),
          ),
          radioRepositoryProvider.overrideWithValue(radio),
        ],
      );
      addTearDown(c.dispose);
      await c.read(consentProvider.future);
      await c.read(radioPermissionsProvider.notifier).request();
      final p = await c.read(radioPermissionsProvider.future);
      expect(radio.requestCount, 0);
      expect(p.consent, isFalse);
      expect(p.canMonitor, isFalse);
    });

    test('granting consent re-evaluates permissions', () async {
      final radio = FakeRadioRepository(permissions: grantedPermissions);
      final c = ProviderContainer(
        overrides: [
          consentProvider.overrideWith(
            () => FakeConsentController(consentStatus(measurement: false)),
          ),
          radioRepositoryProvider.overrideWithValue(radio),
        ],
      );
      addTearDown(c.dispose);
      c.listen(radioPermissionsProvider, (_, _) {});
      await c.read(consentProvider.future);
      expect(
        (await c.read(radioPermissionsProvider.future)).canMonitor,
        isFalse,
      );
      await c.read(consentProvider.notifier).setMeasurement(granted: true);
      await c.read(radioPermissionsProvider.notifier).request();
      expect(
        (await c.read(radioPermissionsProvider.future)).canMonitor,
        isTrue,
      );
      expect(radio.requestCount, 1);
    });
  });

  group('first-run gate', () {
    late FakeConsentController consent;
    late FakeRadioRepository radio;

    Future<void> pumpApp(WidgetTester tester, ConsentStatus status) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      consent = FakeConsentController(status);
      radio = FakeRadioRepository(
        permissions: deniedPermissions,
        afterRequest: grantedPermissions,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            consentProvider.overrideWith(() => consent),
            radioRepositoryProvider.overrideWithValue(radio),
            recordingServiceProvider.overrideWithValue(FakeRecordingService()),
          ],
          child: const OpenNetIqApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('agree logs consent, then asks Android', (tester) async {
      await pumpApp(tester, consentStatus());
      expect(find.text('Welcome to OpenNetIQ'), findsOneWidget);
      expect(find.textContaining('IMEI'), findsOneWidget);
      await tester.ensureVisible(find.text('Agree and continue'));
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(consent.decisions, [true]);
      expect(radio.requestCount, 1);
      expect(find.text('Welcome to OpenNetIQ'), findsNothing);
      expect(find.byTooltip('Privacy'), findsOneWidget);
    });

    testWidgets('not now: app opens, Android not asked', (tester) async {
      await pumpApp(tester, consentStatus());
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(consent.decisions, [false]);
      expect(radio.requestCount, 0);
      expect(find.byTooltip('Privacy'), findsOneWidget);
    });

    testWidgets('decided users go straight to home', (tester) async {
      await pumpApp(tester, consentStatus(measurement: false));
      expect(find.text('Welcome to OpenNetIQ'), findsNothing);
      await tester.tap(find.byTooltip('Privacy'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyScreen), findsOneWidget);
    });
  });

  testWidgets('signal monitor without consent links to privacy', (
    tester,
  ) async {
    final radio = FakeRadioRepository(permissions: grantedPermissions);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consentProvider.overrideWith(
            () => FakeConsentController(consentStatus(measurement: false)),
          ),
          radioRepositoryProvider.overrideWithValue(radio),
          recordingServiceProvider.overrideWithValue(FakeRecordingService()),
        ],
        child: const MaterialApp(home: SignalMonitorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Measurement is switched off'), findsOneWidget);
    expect(radio.watchCount, 0);
  });

  group('privacy screen', () {
    late FakeConsentController consent;
    late FakeEraser eraser;
    late FakeRadioRepository radio;

    Future<void> pump(
      WidgetTester tester, {
      bool measurement = true,
      RecordingState recording = const RecordingState(),
      List<ConsentRecord> ledger = const [],
    }) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      consent = FakeConsentController(consentStatus(measurement: measurement));
      eraser = FakeEraser();
      radio = FakeRadioRepository(permissions: grantedPermissions);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            consentProvider.overrideWith(() => consent),
            consentLedgerProvider.overrideWith((ref) async => ledger),
            measurementDataEraserProvider.overrideWithValue(eraser),
            radioRepositoryProvider.overrideWithValue(radio),
            recordingControllerProvider.overrideWith(
              () => StubRecordingController(recording),
            ),
          ],
          child: const MaterialApp(home: PrivacyScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    SwitchListTile toggle(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));

    testWidgets('switch withdraws and grants consent', (tester) async {
      await pump(tester);
      expect(toggle(tester).value, isTrue);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(consent.decisions, [false]);
      expect(toggle(tester).value, isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(consent.decisions, [false, true]);
      expect(radio.requestCount, 1);
    });

    testWidgets('locked while recording', (tester) async {
      await pump(
        tester,
        recording: const RecordingState(
          phase: RecordingPhase.recording,
          sessionId: 's',
        ),
      );
      expect(toggle(tester).onChanged, isNull);
      expect(find.text('Stop the recording first.'), findsOneWidget);
      await tester.tap(find.text('Delete all measurement data'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('delete asks first, then erases', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Delete all measurement data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(eraser.erases, 0);
      await tester.tap(find.text('Delete all measurement data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(eraser.erases, 1);
      expect(find.text('All measurement data deleted.'), findsOneWidget);
    });

    testWidgets('delete failures are reported', (tester) async {
      await pump(tester);
      eraser.error = StateError('locked');
      await tester.tap(find.text('Delete all measurement data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Delete failed'), findsOneWidget);
    });

    testWidgets('shows the ledger', (tester) async {
      await pump(
        tester,
        ledger: [
          ConsentRecord(
            id: '1',
            scope: ConsentScope.radio,
            granted: false,
            policyVersion: '1.0',
            timestamp: DateTime.utc(2026, 10, 13),
          ),
        ],
      );
      expect(find.text('radio: refused'), findsOneWidget);
    });

    testWidgets('empty ledger', (tester) async {
      await pump(tester);
      expect(find.text('No decisions recorded.'), findsOneWidget);
    });
  });
}
