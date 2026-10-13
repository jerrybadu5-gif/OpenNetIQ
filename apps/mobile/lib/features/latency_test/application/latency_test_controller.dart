import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/methodology.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/drift_latency_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_latency_engine.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/domain/repositories/latency_test_repository.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

final latencyEngineProvider = Provider<LatencyEngine>(
  (ref) => const PlatformLatencyEngine(),
);

final latencyStoreProvider = Provider<LatencyStore>(
  (ref) => DriftLatencyStore(ref.watch(appDatabaseProvider)),
);

/// Latest stored latency rows, newest first.
final latencyHistoryProvider = StreamProvider<List<LatencyRecord>>(
  (ref) => ref.watch(latencyStoreProvider).watchLatencyTests(limit: 30),
  isAutoDispose: true,
);

class LatencyTestState {
  const LatencyTestState({
    this.running = false,
    this.protocol,
    this.probes = const [],
    this.results = const [],
    this.target,
    this.error,
  });

  final bool running;

  /// Protocol being measured.
  final LatencyProtocol? protocol;

  /// Probes of the current protocol (live list).
  final List<LatencyProbe> probes;

  /// Completed protocols of this run.
  final List<LatencyResult> results;
  final String? target;
  final String? error;
}

/// Runs one latency test (issue #21): ICMP, TCP and DNS against the
/// configured test server, start snapshot linked, one row per protocol.
class LatencyTestController extends Notifier<LatencyTestState> {
  StreamSubscription<LatencyEvent>? _subscription;
  Completer<bool>? _done;

  @override
  LatencyTestState build() {
    ref.onDispose(() => _subscription?.cancel());
    return const LatencyTestState();
  }

  Future<void> start() async {
    if (state.running) return;
    final String? url;
    try {
      url = await ref.read(speedTestServerProvider.future);
    } on Object catch (e) {
      state = LatencyTestState(error: 'Could not read settings: $e');
      return;
    }
    final target = url == null ? null : LatencyConfig.targetOf(url);
    if (target == null) {
      state = const LatencyTestState(
        error: 'Set the test server URL on the Speed test screen first.',
      );
      return;
    }
    final targetText = '${target.host}:${target.port}';
    state = LatencyTestState(running: true, target: targetText);
    final context = ref.read(testContextProvider);
    final startedAt = context.now();
    final startRadio = await context.awaitRadio(() => state.running);
    if (!state.running) return;
    final startLocation = context.latestLocation();

    final results = <LatencyResult>[];
    final done = Completer<bool>();
    _done = done;
    _subscription = ref
        .read(latencyEngineProvider)
        .run(LatencyConfig(host: target.host, port: target.port))
        .listen(
          (event) => _onEvent(event, results),
          onError: (Object e) {
            if (!done.isCompleted) done.completeError(e);
          },
          onDone: () {
            if (!done.isCompleted) done.complete(true);
          },
        );
    try {
      final finished = await done.future;
      if (!finished) return; // cancelled
    } on Object catch (e) {
      state = LatencyTestState(
        target: targetText,
        error: 'Latency test failed: $e',
      );
      return;
    } finally {
      _subscription = null;
      _done = null;
    }
    if (results.isEmpty) {
      state = LatencyTestState(
        target: targetText,
        error: 'Latency test ended without results.',
      );
      return;
    }
    String? error;
    try {
      final link = await context.link(
        label: 'Latency test',
        startedAt: startedAt,
        radio: startRadio,
        location: startLocation,
      );
      await ref.read(latencyStoreProvider).saveLatencyTests([
        for (final r in results)
          LatencyRecord(
            id: uuid7(),
            timestamp: startedAt,
            methodologyVersion: methodologyVersion,
            result: r,
            sessionId: link.sessionId,
            measurementId: link.measurementId,
          ),
      ]);
    } on Object catch (e) {
      error = 'Results not saved: $e';
    }
    state = LatencyTestState(
      results: List.unmodifiable(results),
      target: targetText,
      error: error,
    );
  }

  /// Stops the test; nothing is stored.
  Future<void> cancel() async {
    if (!state.running) return;
    final subscription = _subscription;
    _subscription = null;
    state = const LatencyTestState();
    final done = _done;
    if (done != null && !done.isCompleted) done.complete(false);
    await subscription?.cancel();
  }

  void _onEvent(LatencyEvent event, List<LatencyResult> results) {
    if (!state.running) return;
    switch (event) {
      case LatencyProtocolStarted(:final protocol):
        state = LatencyTestState(
          running: true,
          protocol: protocol,
          results: List.unmodifiable(results),
          target: state.target,
        );
      case final LatencyProbe probe:
        state = LatencyTestState(
          running: true,
          protocol: probe.protocol,
          probes: [...state.probes, probe],
          results: state.results,
          target: state.target,
        );
      case LatencyCompleted(:final result):
        results.add(result);
        state = LatencyTestState(
          running: true,
          protocol: state.protocol,
          probes: state.probes,
          results: List.unmodifiable(results),
          target: state.target,
        );
    }
  }
}

final latencyTestControllerProvider =
    NotifierProvider<LatencyTestController, LatencyTestState>(
      LatencyTestController.new,
    );

/// Keeps radio and GNSS subscribed while a latency test runs.
final latencyTestPipelineProvider = Provider<void>((ref) {
  final running = ref.watch(
    latencyTestControllerProvider.select((s) => s.running),
  );
  if (!running) return;
  ref
    ..listen(radioSnapshotProvider, (previous, next) {})
    ..listen(locationStatusProvider, (previous, next) {});
});
