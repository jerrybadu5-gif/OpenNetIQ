import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/latency_test/presentation/latency_test_screen.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

import '../fixtures/latency_fixtures.dart';

class StubLatencyController extends LatencyTestController {
  StubLatencyController(this.initial);

  final LatencyTestState initial;
  int starts = 0;
  int cancels = 0;

  @override
  LatencyTestState build() => initial;

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  Future<StubLatencyController> pump(
    WidgetTester tester, {
    LatencyTestState state = const LatencyTestState(),
    String? server = 'https://speed.example.org/backend/',
  }) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stub = StubLatencyController(state);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          latencyTestControllerProvider.overrideWith(() => stub),
          speedTestServerProvider.overrideWith((ref) async => server),
        ],
        child: const MaterialApp(home: LatencyTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return stub;
  }

  testWidgets('shows the target and starts', (tester) async {
    final stub = await pump(tester);
    expect(find.text('speed.example.org:443'), findsOneWidget);
    await tester.tap(find.text('Start test'));
    expect(stub.starts, 1);
  });

  testWidgets('no server: start disabled', (tester) async {
    await pump(tester, server: null);
    expect(find.text('No test server set'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Start test'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('running shows protocol, probe count and cancel', (tester) async {
    final stub = await pump(
      tester,
      state: const LatencyTestState(
        running: true,
        protocol: LatencyProtocol.tcp,
        probes: [
          LatencyProbe(LatencyProtocol.tcp, 1, 20.4),
          LatencyProbe(LatencyProtocol.tcp, 2, 31.2),
        ],
      ),
    );
    expect(find.text('TCP connect'), findsOneWidget);
    expect(find.text('2 / 20 probes'), findsOneWidget);
    expect(find.text('Last: 31.2 ms'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(stub.cancels, 1);
  });

  testWidgets('result cards and errors', (tester) async {
    await pump(
      tester,
      state: LatencyTestState(
        results: [
          latencyResult(),
          LatencyResult(
            protocol: LatencyProtocol.icmp,
            method: 'lat-1.0',
            target: 'speed.example.org',
            probesSent: 20,
            probesReceived: 0,
            rawRttsMs: List.filled(20, null),
            status: TestStatus.failed,
            packetLossPct: 100,
            error: 'no reply',
          ),
        ],
        error: 'Results not saved: disk full',
      ),
    );
    expect(find.text('TCP connect: ok'), findsOneWidget);
    expect(find.text('27.4 ms'), findsOneWidget);
    expect(find.text('20.0 ms / 40.0 ms'), findsOneWidget);
    expect(find.text('12.6 ms'), findsOneWidget);
    expect(find.text('20 % (4/5)'), findsOneWidget);
    expect(find.text('ICMP ping: failed'), findsOneWidget);
    expect(find.text('100 % (0/20)'), findsOneWidget);
    expect(find.text('no reply'), findsOneWidget);
    expect(find.text('Results not saved: disk full'), findsOneWidget);
  });
}
