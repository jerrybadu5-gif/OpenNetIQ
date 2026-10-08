import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/presentation/speed_test_screen.dart';

import '../fixtures/speed_fixtures.dart';

class StubSpeedTestController extends SpeedTestController {
  StubSpeedTestController(this.initial);

  final SpeedTestState initial;
  int starts = 0;
  int cancels = 0;
  final saved = <String>[];

  @override
  SpeedTestState build() => initial;

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> saveServer(String url) async => saved.add(url);
}

void main() {
  Future<StubSpeedTestController> pump(
    WidgetTester tester, {
    SpeedTestState state = const SpeedTestState(),
    String? server = 'https://speed.example.org/backend/',
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stub = StubSpeedTestController(state);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          speedTestControllerProvider.overrideWith(() => stub),
          speedTestServerProvider.overrideWith((ref) async => server),
        ],
        child: const MaterialApp(home: SpeedTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return stub;
  }

  testWidgets('start is disabled until a server is set', (tester) async {
    await pump(tester, server: null);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Start test'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('starts a test with the saved server', (tester) async {
    final stub = await pump(tester);
    final field = find.widgetWithText(TextField, 'Test server URL');
    expect(field, findsOneWidget);
    // Read the controller: newer Flutter also renders a display copy.
    expect(
      tester.widget<TextField>(field).controller!.text,
      'https://speed.example.org/backend/',
    );
    await tester.tap(find.text('Start test'));
    expect(stub.starts, 1);
  });

  testWidgets('validates and saves the server URL', (tester) async {
    final stub = await pump(tester, server: null);
    final field = find.widgetWithText(TextField, 'Test server URL');

    await tester.enterText(field, 'ftp://nope');
    await tester.tap(find.text('Save server'));
    await tester.pump();
    expect(find.text('Enter an http:// or https:// URL'), findsOneWidget);
    expect(stub.saved, isEmpty);

    await tester.enterText(field, 'http://192.168.1.10:8080/backend/');
    await tester.tap(find.text('Save server'));
    await tester.pump();
    expect(stub.saved, ['http://192.168.1.10:8080/backend/']);
  });

  testWidgets('running shows phase, live rate and cancel', (tester) async {
    final stub = await pump(
      tester,
      state: const SpeedTestState(
        running: true,
        phase: SpeedTestPhase.download,
        liveMbps: 42.26,
      ),
    );
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('42.3 Mbps'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(stub.cancels, 1);
  });

  testWidgets('shows the result card', (tester) async {
    await pump(
      tester,
      state: const SpeedTestState(result: okResult, ratChanged: true),
    );
    expect(find.text('Result: ok'), findsOneWidget);
    expect(find.text('48.2 Mbps'), findsOneWidget);
    expect(find.text('30.1 / 60.4 Mbps'), findsOneWidget);
    expect(find.text('66.6 Mbps'), findsOneWidget);
    expect(find.text('72.0 MB'), findsOneWidget);
    expect(find.text('12.1 Mbps'), findsOneWidget);
    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('31 ms'), findsOneWidget);
    expect(find.text('http-mc-1.0, 4 streams'), findsOneWidget);
    expect(find.textContaining('Network type changed'), findsOneWidget);
  });

  testWidgets('shows errors and missing directions', (tester) async {
    await pump(
      tester,
      state: const SpeedTestState(
        error: 'Result not saved: disk full',
        result: SpeedTestResult(
          status: SpeedTestStatus.failed,
          method: 'http-mc-1.0',
          serverHost: 'h',
          streams: 4,
          error: 'download: HTTP 500',
        ),
      ),
    );
    expect(find.text('Result not saved: disk full'), findsOneWidget);
    expect(find.text('No valid data'), findsNWidgets(2));
    expect(find.text('download: HTTP 500'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(3)); // live, DNS, TCP
  });
}
