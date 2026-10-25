import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/features/qoe/application/qoe_controller.dart';
import 'package:opennetiq_mobile/features/qoe/presentation/qoe_test_screen.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../../fixtures/qoe_fixtures.dart';
import '../../fixtures/script_fixtures.dart';

class StubQoeController extends QoeTestController {
  StubQoeController(this.initial);

  final QoeRunState initial;
  final runs = <Set<QoeKind>>[];
  int cancels = 0;

  @override
  QoeRunState build() => initial;

  @override
  Future<void> run(Set<QoeKind> kinds) async => runs.add(kinds);

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  late MemorySettings settings;

  Future<StubQoeController> pump(
    WidgetTester tester, {
    QoeRunState state = const QoeRunState(),
    List<QoeRecord> history = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stub = StubQoeController(state);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qoeTestControllerProvider.overrideWith(() => stub),
          settingsRepositoryProvider.overrideWithValue(settings),
          qoeHistoryProvider.overrideWith((ref) => Stream.value(history)),
        ],
        child: const MaterialApp(home: QoeTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return stub;
  }

  setUp(() {
    settings = MemorySettings()
      ..values[qoeSettingsKey] = jsonEncode(smallSettings.toJson());
  });

  testWidgets('starts the selected kinds', (tester) async {
    final stub = await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Video streaming'));
    await tester.pump();
    await tester.tap(find.text('Start tests'));
    expect(stub.runs.single, {QoeKind.web, QoeKind.app, QoeKind.file});
    expect(find.text('No tests yet.'), findsOneWidget);
  });

  testWidgets('running: progress, results with details, cancel', (
    tester,
  ) async {
    final stub = await pump(
      tester,
      state: QoeRunState(
        running: true,
        current: 'Web browsing: Google',
        done: 1,
        total: 4,
        results: [
          qoeOk(QoeKind.web, 'Google', totalMs: 1800),
          const QoeResult(
            kind: QoeKind.video,
            label: 'Clip',
            target: 'https://v/',
            status: TestStatus.ok,
            startDelayMs: 900,
            rebufferCount: 2,
            rebufferMs: 1500,
            bitrateKbps: 2500,
            resolution: '720p',
          ),
          const QoeResult(
            kind: QoeKind.file,
            label: '5 MB download',
            target: 'http://s/',
            status: TestStatus.ok,
            totalMs: 2000,
            rateMbps: 21,
            direction: 'download',
          ),
        ],
      ),
    );
    expect(find.text('Web browsing: Google'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('load 1.8 s'), findsOneWidget);
    expect(find.text('start 0.9 s · 2 rebuffers · 720p'), findsOneWidget);
    await tester.tap(find.text('Clip'));
    await tester.pumpAndSettle();
    expect(find.text('2500 kbps'), findsOneWidget);
    expect(find.text('2 (1500 ms)'), findsOneWidget);
    Navigator.of(tester.element(find.text('Rebuffers'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Google').first);
    await tester.pumpAndSettle();
    expect(find.text('Page load'), findsOneWidget);
    Navigator.of(tester.element(find.text('Page load'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 MB download'));
    await tester.pumpAndSettle();
    expect(find.text('21.0 Mbps'), findsOneWidget);
    Navigator.of(tester.element(find.text('21.0 Mbps'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    expect(stub.cancels, 1);
  });

  testWidgets('edit the video list with validation', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Video streaming').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Video on a web page'), findsOneWidget);
    await tester.tap(find.text('Edit video streaming list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bad | nope');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Line 1: not an http(s) URL'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Facebook live | https://fb.watch/x | page\nOwn | https://srv/v.m3u8',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(settings.values[qoeSettingsKey], contains('Facebook live'));
    expect(find.text('2 targets'), findsNWidgets(2)); // videos + apps
  });

  testWidgets('options and other lists', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Video test length (s)'),
      '60',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'File size (MB)'),
      '10',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Video 60 s · file 10 MB'), findsOneWidget);
    for (final label in ['Web browsing', 'App reachability']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit ${label.toLowerCase()} list'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'https://one.test/');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }
    expect(settings.values[qoeSettingsKey], contains('one.test'));
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('history and errors', (tester) async {
    await pump(
      tester,
      state: const QoeRunState(error: 'Results not saved: disk full'),
      history: [
        QoeRecord(
          id: 'h',
          timestamp: DateTime.utc(2026, 10, 25),
          methodologyVersion: '1.0.0',
          result: const QoeResult(
            kind: QoeKind.app,
            label: 'WhatsApp',
            target: 'https://web.whatsapp.com/',
            status: TestStatus.failed,
            error: 'timeout',
          ),
        ),
      ],
    );
    expect(find.text('Results not saved: disk full'), findsOneWidget);
    expect(find.textContaining('failed: timeout'), findsOneWidget);
  });
}
