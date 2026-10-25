import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/methodology.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/drift_qoe_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_qoe_engine.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/domain/repositories/qoe_repository.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

final qoeEngineProvider = Provider<QoeEngine>(
  (ref) => const PlatformQoeEngine(),
);

final qoeStoreProvider = Provider<QoeStore>(
  (ref) => DriftQoeStore(ref.watch(appDatabaseProvider)),
);

/// `app_settings` key of [QoeSettings] JSON.
const String qoeSettingsKey = 'qoe.settings.v1';

class QoeSettingsController extends AsyncNotifier<QoeSettings> {
  @override
  Future<QoeSettings> build() async {
    final raw = await ref
        .watch(settingsRepositoryProvider)
        .getSetting(qoeSettingsKey);
    if (raw == null || raw.isEmpty) return const QoeSettings();
    try {
      return QoeSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return const QoeSettings();
    }
  }

  Future<void> save(QoeSettings settings) async {
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(qoeSettingsKey, jsonEncode(settings.toJson()));
    state = AsyncData(settings);
  }
}

final qoeSettingsProvider =
    AsyncNotifierProvider<QoeSettingsController, QoeSettings>(
      QoeSettingsController.new,
    );

final qoeHistoryProvider = StreamProvider<List<QoeRecord>>(
  (ref) => ref.watch(qoeStoreProvider).watchQoeTests(),
  isAutoDispose: true,
);

class QoeRunState {
  const QoeRunState({
    this.running = false,
    this.current,
    this.done = 0,
    this.total = 0,
    this.results = const [],
    this.error,
  });

  final bool running;

  /// e.g. "Web browsing: Google".
  final String? current;
  final int done;
  final int total;
  final List<QoeResult> results;
  final String? error;
}

/// One planned measurement.
typedef _Item = (QoeKind kind, QoeTarget? target, bool upload);

/// Runs the selected QoE tests over the configured targets (issue #29).
/// Results are stored one by one, linked to the open drive (or a
/// stand-alone session) like the other tests.
class QoeTestController extends Notifier<QoeRunState> {
  @override
  QoeRunState build() => const QoeRunState();

  Future<void> run(Set<QoeKind> kinds) async {
    if (state.running) return;
    final QoeSettings settings;
    String? server;
    try {
      settings = await ref.read(qoeSettingsProvider.future);
      if (kinds.contains(QoeKind.file)) {
        server = await ref.read(speedTestServerProvider.future);
      }
    } on Object catch (e) {
      state = QoeRunState(error: 'Could not read settings: $e');
      return;
    }
    final plan = <_Item>[
      for (final k in QoeKind.values)
        if (kinds.contains(k))
          if (k == QoeKind.file) ...[
            (k, null, false),
            (k, null, true),
          ] else
            for (final t in settings.targets(k)) (k, t, false),
    ];
    if (plan.isEmpty) {
      state = const QoeRunState(error: 'Nothing to test: add targets first.');
      return;
    }
    final engine = ref.read(qoeEngineProvider);
    final context = ref.read(testContextProvider);
    state = QoeRunState(running: true, total: plan.length);
    final startedAt = context.now();
    final radio = await context.awaitRadio(() => state.running);
    final location = context.latestLocation();
    ({String? sessionId, String? measurementId})? link;
    final results = <QoeResult>[];
    String? error;
    for (final (kind, target, upload) in plan) {
      if (!state.running) break;
      final label = target?.name ?? '${upload ? 'Upload' : 'Download'} file';
      state = QoeRunState(
        running: true,
        current: '${kind.label}: $label',
        done: results.length,
        total: plan.length,
        results: List.unmodifiable(results),
      );
      final at = context.now();
      final QoeResult result;
      if (kind == QoeKind.file && server == null) {
        result = QoeResult(
          kind: kind,
          label: label,
          target: '',
          status: TestStatus.failed,
          error: 'Set the test server on the Speed test screen',
        );
      } else {
        result = await switch (kind) {
          QoeKind.web => engine.web(
            target!,
            timeout: Duration(seconds: settings.pageTimeoutSeconds),
          ),
          QoeKind.video => engine.video(
            target!,
            duration: Duration(seconds: settings.videoSeconds),
          ),
          QoeKind.app => engine.app(target!),
          QoeKind.file => engine.file(
            serverUrl: server!,
            sizeMib: settings.fileSizeMib,
            upload: upload,
          ),
        };
      }
      if (!state.running) break; // cancelled: the interrupted result is dropped
      results.add(result);
      try {
        link ??= await context.link(
          label: 'QoE test',
          startedAt: startedAt,
          radio: radio,
          location: location,
        );
        await ref.read(qoeStoreProvider).saveQoeTests([
          QoeRecord(
            id: uuid7(),
            timestamp: at,
            methodologyVersion: methodologyVersion,
            result: result,
            sessionId: link.sessionId,
            measurementId: link.measurementId,
          ),
        ]);
      } on Object catch (e) {
        error = 'Results not saved: $e';
      }
    }
    state = QoeRunState(
      done: results.length,
      total: plan.length,
      results: List.unmodifiable(results),
      error: error,
    );
  }

  Future<void> cancel() async {
    if (!state.running) return;
    state = QoeRunState(
      done: state.done,
      total: state.total,
      results: state.results,
    );
    await ref.read(qoeEngineProvider).cancel();
  }
}

final qoeTestControllerProvider =
    NotifierProvider<QoeTestController, QoeRunState>(QoeTestController.new);

/// Keeps radio and GNSS subscribed while QoE tests run.
final qoeTestPipelineProvider = Provider<void>((ref) {
  final running = ref.watch(qoeTestControllerProvider.select((s) => s.running));
  if (!running) return;
  ref
    ..listen(radioSnapshotProvider, (previous, next) {})
    ..listen(locationStatusProvider, (previous, next) {});
});
