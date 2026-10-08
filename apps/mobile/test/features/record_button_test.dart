import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/presentation/record_button.dart';

import '../fixtures/session_fixtures.dart';

class FakeRecordingController extends RecordingController {
  FakeRecordingController(this.initial);

  final RecordingState initial;
  int starts = 0;
  int stops = 0;

  @override
  RecordingState build() => initial;

  @override
  Future<void> start([
    RecordingOptions options = const RecordingOptions(),
  ]) async {
    starts++;
    state = const RecordingState(
      phase: RecordingPhase.recording,
      sessionId: 's1',
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    state = const RecordingState(lastSessionId: 's1');
  }

  @override
  void onSnapshot(RadioSnapshot radio, LocationStatus? location) {}
}

Future<FakeRecordingController> pumpButton(
  WidgetTester tester,
  RecordingState initial,
) async {
  final fake = FakeRecordingController(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordingControllerProvider.overrideWith(() => fake),
        activeSessionProvider.overrideWith(
          (ref) => Stream.value(
            session(status: SessionStatus.recording, sampleCount: 42),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [RecordButton()])),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  testWidgets('idle shows a record button that starts recording', (
    tester,
  ) async {
    final fake = await pumpButton(tester, const RecordingState());

    await tester.tap(find.byTooltip('Start recording'));
    await tester.pump();
    await tester.pump();

    expect(fake.starts, 1);
    expect(find.text('REC 42'), findsOneWidget);
  });

  testWidgets('recording shows the sample count and stops', (tester) async {
    final fake = await pumpButton(
      tester,
      const RecordingState(phase: RecordingPhase.recording, sessionId: 's1'),
    );
    await tester.pump();
    expect(find.text('REC 42'), findsOneWidget);

    await tester.tap(find.text('REC 42'));
    await tester.pump();

    expect(fake.stops, 1);
    expect(find.byTooltip('Start recording'), findsOneWidget);
  });

  testWidgets('paused shows the paused counter and stops', (tester) async {
    final fake = await pumpButton(
      tester,
      const RecordingState(phase: RecordingPhase.paused, sessionId: 's1'),
    );
    await tester.pump();
    expect(find.text('PAUSED 42'), findsOneWidget);

    await tester.tap(find.text('PAUSED 42'));
    await tester.pump();
    expect(fake.stops, 1);
  });

  testWidgets('busy phases show progress', (tester) async {
    await pumpButton(
      tester,
      const RecordingState(phase: RecordingPhase.starting),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
