import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/services/sample_gaps.dart';
import 'package:opennetiq_mobile/features/drive_test/presentation/drive_test_screen.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';

import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';

void main() {
  final clock = FakeClock();

  Future<(StubRecordingController, FakeRecordingService)> pumpScreen(
    WidgetTester tester, {
    RecordingState state = const RecordingState(),
    bool permitted = true,
    bool? ignoringBattery = true,
  }) async {
    final controller = StubRecordingController(state);
    final service = FakeRecordingService(
      ignoringBatteryOptimizations: ignoringBattery,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(() => controller),
          recordingServiceProvider.overrideWithValue(service),
          clockProvider.overrideWithValue(clock.call),
          radioRepositoryProvider.overrideWithValue(
            FakeRadioRepository(
              permissions: permitted ? grantedPermissions : deniedPermissions,
              snapshots: [snapshot()],
            ),
          ),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(statuses: [locationStatus()]),
          ),
        ],
        child: const MaterialApp(home: DriveTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return (controller, service);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('asks for permissions first', (tester) async {
    await pumpScreen(tester, permitted: false);
    expect(find.byType(PermissionPrompt), findsOneWidget);
  });

  testWidgets('starts a session with the chosen options', (tester) async {
    final (controller, _) = await pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Session name'),
      'Highway 1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Operator under test (optional)'),
      'Digicel PNG',
    );
    await tapVisible(tester, find.text('Walk'));
    await tapVisible(tester, find.text('5 s'));
    await tapVisible(tester, find.text('Start recording'));

    final options = controller.started!;
    expect(options.name, 'Highway 1');
    expect(options.operatorUnderTest, 'Digicel PNG');
    expect(options.type, SessionType.walk);
    expect(options.interval, const Duration(seconds: 5));
  });

  testWidgets('battery optimisation warning opens settings', (tester) async {
    final (_, service) = await pumpScreen(tester, ignoringBattery: false);
    expect(find.text('Battery optimisation is on'), findsOneWidget);

    await tapVisible(tester, find.text('Settings'));
    expect(service.batterySettingsOpened, 1);
  });

  testWidgets('no battery warning when exempt', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Battery optimisation is on'), findsNothing);
  });

  testWidgets('no battery warning when the status is unknown', (tester) async {
    await pumpScreen(tester, ignoringBattery: null);
    expect(find.text('Battery optimisation is on'), findsNothing);
  });

  testWidgets('shows errors and the last session gap report', (tester) async {
    final t0 = DateTime.utc(2026, 10, 8, 1);
    await pumpScreen(
      tester,
      state: RecordingState(
        lastSessionId: 's1',
        activeBefore: const Duration(seconds: 10),
        lastReport: GapReport(
          recorded: 9,
          missing: 1,
          gaps: [
            SampleGap(
              from: t0,
              to: t0.add(const Duration(seconds: 2)),
              missing: 1,
            ),
          ],
        ),
        error: 'Sample not stored: disk full',
      ),
    );
    expect(find.text('Sample not stored: disk full'), findsOneWidget);
    expect(find.text('Last session'), findsOneWidget);
    expect(find.text('1 (10.00 %)'), findsOneWidget);
    expect(find.text('0:02'), findsOneWidget);
  });

  testWidgets('recording status with pause, resume and stop', (tester) async {
    final (controller, _) = await pumpScreen(
      tester,
      state: RecordingState(
        phase: RecordingPhase.recording,
        sessionId: 's1',
        sessionName: 'Highway 1',
        recordedSamples: 8,
        activeSince: clock.now.subtract(const Duration(seconds: 10)),
      ),
    );
    expect(find.text('Recording'), findsOneWidget);
    expect(find.text('Highway 1'), findsOneWidget);
    expect(find.text('0:10'), findsOneWidget);
    expect(find.text('80.0 %'), findsOneWidget);
    expect(find.textContaining('RSRP -95 dBm'), findsOneWidget);
    expect(find.textContaining('±4 m'), findsOneWidget);

    await tapVisible(tester, find.text('Pause'));
    expect(controller.pauses, 1);
    expect(find.text('Paused'), findsOneWidget);

    await tapVisible(tester, find.text('Resume'));
    expect(controller.resumes, 1);

    await tapVisible(tester, find.text('Stop'));
    expect(find.text('Stop recording?'), findsOneWidget);
    await tapVisible(tester, find.text('Cancel'));
    expect(controller.stops, 0);

    await tapVisible(tester, find.text('Stop'));
    await tapVisible(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Stop'),
      ),
    );
    expect(controller.stops, 1);
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('warns when background recording is unavailable', (tester) async {
    await pumpScreen(
      tester,
      state: RecordingState(
        phase: RecordingPhase.recording,
        sessionId: 's1',
        activeSince: clock.now,
        backgroundAvailable: false,
      ),
    );
    expect(find.text('Background recording unavailable.'), findsOneWidget);
    expect(find.text('-'), findsOneWidget); // completeness not yet known
  });
}
