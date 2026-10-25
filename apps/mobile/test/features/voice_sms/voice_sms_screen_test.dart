import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';
import 'package:opennetiq_mobile/features/voice_sms/application/voice_sms_controller.dart';
import 'package:opennetiq_mobile/features/voice_sms/presentation/voice_sms_screen.dart';

import '../../fixtures/consent_fixtures.dart';
import '../../fixtures/script_fixtures.dart';
import '../../fixtures/voice_sms_fixtures.dart';

class StubVoiceSms extends VoiceSmsController {
  StubVoiceSms(this.initial);

  final VoiceSmsRunState initial;
  final runs = <Set<VoiceSmsKind>>[];
  int cancels = 0;

  @override
  VoiceSmsRunState build() => initial;

  @override
  Future<void> run(Set<VoiceSmsKind> kinds) async => runs.add(kinds);

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  late MemorySettings settings;
  late FakeVoiceSmsEngine engine;
  late FakeConsentController consent;

  Future<StubVoiceSms> pump(
    WidgetTester tester, {
    bool granted = true,
    VoiceSmsRunState state = const VoiceSmsRunState(),
    List<VoiceSmsRecord> history = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stub = StubVoiceSms(state);
    consent = FakeConsentController(
      consentStatus(measurement: true, voiceSms: granted),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consentProvider.overrideWith(() => consent),
          voiceSmsControllerProvider.overrideWith(() => stub),
          voiceSmsEngineProvider.overrideWithValue(engine),
          settingsRepositoryProvider.overrideWithValue(settings),
          voiceSmsHistoryProvider.overrideWith((ref) => Stream.value(history)),
        ],
        child: const MaterialApp(home: VoiceSmsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return stub;
  }

  setUp(() {
    engine = FakeVoiceSmsEngine();
    settings = MemorySettings()
      ..values[voiceSmsSettingsKey] = jsonEncode(
        smallVoiceSmsSettings.toJson(),
      );
  });

  testWidgets('without consent start is disabled; opting in asks Android', (
    tester,
  ) async {
    await pump(tester, granted: false);
    final start = find.widgetWithText(FilledButton, 'Start tests');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.tap(find.text('Allow voice and SMS tests'));
    await tester.pumpAndSettle();
    expect(consent.voiceSmsDecisions, [true]);
    expect(engine.requests, 1);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
  });

  testWidgets('starts selected kinds and lists numbers', (tester) async {
    final stub = await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'SMS'));
    await tester.pump();
    await tester.tap(find.text('Start tests'));
    await tester.pump();
    expect(stub.runs.single, {VoiceSmsKind.call});
    expect(find.text('1 numbers'), findsOneWidget);
    expect(find.text('2 numbers'), findsOneWidget);
    await tester.tap(find.text('SMS').last);
    await tester.pumpAndSettle();
    expect(find.text('+67570000011 · this phone'), findsOneWidget);
  });

  testWidgets('missing permissions card grants', (tester) async {
    engine.perms = const VoiceSmsPermissions(call: true);
    await pump(tester);
    expect(find.text('Android permissions missing'), findsOneWidget);
    expect(find.textContaining('call log (setup time)'), findsOneWidget);
    await tester.tap(find.text('Grant'));
    await tester.pumpAndSettle();
    expect(engine.requests, 1);
  });

  testWidgets('running state cancels; results show details', (tester) async {
    final line = smallVoiceSmsSettings.callTargets.first;
    final stub = await pump(
      tester,
      state: VoiceSmsRunState(
        running: true,
        current: 'Voice call: Line A',
        done: 1,
        total: 3,
        results: [callOk(line)],
        error: 'Results not saved: x',
      ),
    );
    expect(find.text('Voice call: Line A'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Results not saved: x'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(stub.cancels, 1);
    await tester.tap(find.text('Line A (••67)'));
    await tester.pumpAndSettle();
    expect(find.text('Setup time'), findsOneWidget);
    expect(find.text('4200 ms'), findsOneWidget);
    expect(find.text('26 s'), findsOneWidget);
  });

  testWidgets('edits numbers with validation and saves options', (
    tester,
  ) async {
    await pump(
      tester,
      history: [
        VoiceSmsRecord(
          id: 'h',
          timestamp: DateTime.utc(2026, 10, 1),
          methodologyVersion: '1.0.0',
          result: smsOk(smallVoiceSmsSettings.smsTargets.first),
        ),
      ],
    );
    expect(find.text('Me (••11)'), findsOneWidget);
    await tester.tap(find.text('Voice call').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit voice call numbers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'X | abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Line 1: not a phone number'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Echo | 7000 1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.values[voiceSmsSettingsKey], contains('70001234'));
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '90');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      settings.values[voiceSmsSettingsKey],
      contains('"call_window_s":90'),
    );
  });
}
