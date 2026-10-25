import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_runner.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_store.dart';
import 'package:opennetiq_mobile/features/scripts/presentation/script_editor_screen.dart';
import 'package:opennetiq_mobile/features/scripts/presentation/scripts_screen.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../../fixtures/recording_fixtures.dart';
import '../../fixtures/script_fixtures.dart';

void main() {
  late FakeStepExecutor executor;
  late MemorySettings settings;

  Future<void> pumpApp(
    WidgetTester tester, {
    RecordingState recording = const RecordingState(),
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/scripts',
      routes: [
        GoRoute(
          path: '/scripts',
          builder: (context, state) => const ScriptsScreen(),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) =>
                  ScriptEditorScreen(scriptId: state.uri.queryParameters['id']),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stepExecutorProvider.overrideWithValue(executor),
          scriptDelayProvider.overrideWithValue((d) async {}),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 25)),
          settingsRepositoryProvider.overrideWithValue(settings),
          recordingControllerProvider.overrideWith(
            () => StubRecordingController(recording),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    executor = FakeStepExecutor();
    settings = MemorySettings();
  });

  testWidgets('presets listed; run shows the log', (tester) async {
    await pumpApp(tester);
    expect(find.text('No recording open'), findsOneWidget);
    expect(find.text('Quick check'), findsOneWidget);
    expect(find.text('Drive loop'), findsOneWidget);
    await tester.tap(find.byTooltip('Run Quick check'));
    await tester.pumpAndSettle();
    expect(executor.ran, [StepType.latency, StepType.speed]);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('1. Speed test'), findsOneWidget);
    expect(find.textContaining('speed done'), findsOneWidget);
  });

  testWidgets('recording banner names the session', (tester) async {
    await pumpApp(
      tester,
      recording: const RecordingState(
        phase: RecordingPhase.recording,
        sessionId: 's',
        sessionName: 'Highway 1',
      ),
    );
    expect(find.text('Results link to recording "Highway 1"'), findsOneWidget);
  });

  testWidgets('running script shows progress and stops', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ScriptsScreen)),
    );
    final gate = Completer<void>();
    executor.onRun = () {};
    final blocking = _BlockingExecutor(gate);
    container.updateOverrides([
      stepExecutorProvider.overrideWithValue(blocking),
      scriptDelayProvider.overrideWithValue((d) async {}),
      clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 25)),
      settingsRepositoryProvider.overrideWithValue(settings),
      recordingControllerProvider.overrideWith(StubRecordingController.new),
    ]);
    unawaited(
      container.read(scriptRunnerProvider.notifier).start(presetScripts[1]),
    );
    await tester.pump();
    expect(find.text('Cycle 1 of ∞'), findsOneWidget);
    expect(find.text('Now: Speed test'), findsOneWidget);
    await tester.tap(find.text('Stop'));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Stopped'), findsOneWidget);
    expect(blocking.cancels, 1);
  });

  testWidgets('editor: build, validate and save a script', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New script'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Give the script a name'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Script name'),
      'Loop',
    );
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    expect(find.text('Voice call'), findsOneWidget);
    await tester.tap(find.text('Speed test').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wait').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latency test').last);
    await tester.pumpAndSettle();
    expect(find.text('Wait 30 s'), findsOneWidget);
    await tester.tap(find.byTooltip('Move up').last); // latency above wait
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove step').last); // remove wait
    await tester.pumpAndSettle();
    expect(find.text('Wait 30 s'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Cycles'), '0');
    await tester.tap(find.text('Start each cycle on a fixed interval'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Interval (minutes)'),
      '1.5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Loop'), findsOneWidget);
    expect(
      find.text('Speed test → Latency test · until stopped, every 1 min'),
      findsOneWidget,
    );
    expect(settings.values[scriptsKey], contains('"cycle_interval_s":90'));
  });

  testWidgets('edit an existing script and delete it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Quick check'));
    await tester.pumpAndSettle();
    expect(find.text('Edit script'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Script name'),
      'Quick check 2',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Quick check 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete Quick check 2'));
    await tester.pumpAndSettle();
    expect(find.text('Quick check 2'), findsNothing);
  });
}

class _BlockingExecutor implements StepExecutor {
  _BlockingExecutor(this.gate);

  final Completer<void> gate;
  int cancels = 0;

  @override
  Future<StepOutcome> run(ScriptStep step) async {
    await gate.future;
    return const StepOutcome(ok: true, summary: 'ok');
  }

  @override
  Future<void> cancel() async => cancels++;
}
