import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/core/flavor.dart';
import 'package:opennetiq_mobile/features/drive_test/presentation/drive_test_screen.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

import '../fixtures/radio_fixtures.dart';
import '../fixtures/recording_fixtures.dart';

void main() {
  for (final flavor in Flavor.values) {
    testWidgets('app shows ${flavor.name} title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [flavorProvider.overrideWithValue(flavor)],
          child: const OpenNetIqApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(flavor.label), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }

  testWidgets('recording banner and drive test entry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordingControllerProvider.overrideWith(
            () => StubRecordingController(
              const RecordingState(
                phase: RecordingPhase.paused,
                sessionId: 's1',
                sessionName: 'Highway 1',
                recordedSamples: 42,
              ),
            ),
          ),
          recordingServiceProvider.overrideWithValue(FakeRecordingService()),
          radioRepositoryProvider.overrideWithValue(
            FakeRadioRepository(permissions: deniedPermissions),
          ),
        ],
        child: const OpenNetIqApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording paused'), findsOneWidget);
    expect(find.text('Highway 1 - 42 samples'), findsOneWidget);

    await tester.tap(find.text('Recording paused'));
    await tester.pumpAndSettle();
    expect(find.byType(DriveTestScreen), findsOneWidget);
  });

  testWidgets('no banner while idle', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpenNetIqApp()));
    await tester.pumpAndSettle();
    expect(find.text('Recording'), findsNothing);
    expect(find.text('Drive test'), findsOneWidget);
  });
}
