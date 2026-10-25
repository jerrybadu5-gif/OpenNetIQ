import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/methodology.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/data/local/drift_voice_sms_store.dart';
import 'package:opennetiq_mobile/data/repositories/platform_voice_sms_engine.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/domain/repositories/voice_sms_repository.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

final voiceSmsEngineProvider = Provider<VoiceSmsEngine>(
  (ref) => const PlatformVoiceSmsEngine(),
);

final voiceSmsStoreProvider = Provider<VoiceSmsStore>(
  (ref) => DriftVoiceSmsStore(ref.watch(appDatabaseProvider)),
);

/// `app_settings` key of [VoiceSmsSettings] JSON. Numbers stay in this
/// local setting and are never exported.
const String voiceSmsSettingsKey = 'voice_sms.settings.v1';

class VoiceSmsSettingsController extends AsyncNotifier<VoiceSmsSettings> {
  @override
  Future<VoiceSmsSettings> build() async {
    final raw = await ref
        .watch(settingsRepositoryProvider)
        .getSetting(voiceSmsSettingsKey);
    if (raw == null || raw.isEmpty) return const VoiceSmsSettings();
    try {
      return VoiceSmsSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } on Object {
      return const VoiceSmsSettings();
    }
  }

  Future<void> save(VoiceSmsSettings settings) async {
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(voiceSmsSettingsKey, jsonEncode(settings.toJson()));
    state = AsyncData(settings);
  }
}

final voiceSmsSettingsProvider =
    AsyncNotifierProvider<VoiceSmsSettingsController, VoiceSmsSettings>(
      VoiceSmsSettingsController.new,
    );

final voiceSmsHistoryProvider = StreamProvider<List<VoiceSmsRecord>>(
  (ref) => ref.watch(voiceSmsStoreProvider).watchVoiceSmsTests(),
  isAutoDispose: true,
);

/// Waits between calls; overridable so tests do not sleep.
final voiceSmsDelayProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

/// Android permission state; refresh with `ref.invalidate`.
final voiceSmsPermissionsProvider =
    FutureProvider.autoDispose<VoiceSmsPermissions>(
      (ref) => ref.watch(voiceSmsEngineProvider).permissions(),
    );

class VoiceSmsRunState {
  const VoiceSmsRunState({
    this.running = false,
    this.current,
    this.done = 0,
    this.total = 0,
    this.results = const [],
    this.error,
  });

  final bool running;

  /// e.g. "Voice call: Test line A".
  final String? current;
  final int done;
  final int total;
  final List<VoiceSmsResult> results;
  final String? error;
}

/// Runs the voice-call and SMS sequences over the configured test lines
/// (issue #30). Refuses to run without the voice_sms consent.
class VoiceSmsController extends Notifier<VoiceSmsRunState> {
  @override
  VoiceSmsRunState build() => const VoiceSmsRunState();

  Future<void> run(Set<VoiceSmsKind> kinds) async {
    if (state.running) return;
    if (!ref.read(voiceSmsConsentProvider)) {
      state = const VoiceSmsRunState(
        error: 'Allow voice and SMS tests in Privacy first.',
      );
      return;
    }
    final VoiceSmsSettings settings;
    try {
      settings = await ref.read(voiceSmsSettingsProvider.future);
    } on Object catch (e) {
      state = VoiceSmsRunState(error: 'Could not read settings: $e');
      return;
    }
    final plan = <(VoiceSmsKind, PhoneTarget)>[
      for (final k in VoiceSmsKind.values)
        if (kinds.contains(k))
          for (final t in settings.targets(k)) (k, t),
    ];
    if (plan.isEmpty) {
      state = const VoiceSmsRunState(
        error: 'Nothing to test: add test numbers first.',
      );
      return;
    }
    final engine = ref.read(voiceSmsEngineProvider);
    final context = ref.read(testContextProvider);
    state = VoiceSmsRunState(running: true, total: plan.length);
    final startedAt = context.now();
    final radio = await context.awaitRadio(() => state.running);
    final location = context.latestLocation();
    ({String? sessionId, String? measurementId})? link;
    final results = <VoiceSmsResult>[];
    String? error;
    var callsMade = 0;
    for (final (kind, target) in plan) {
      if (!state.running) break;
      if (kind == VoiceSmsKind.call && callsMade > 0) {
        state = VoiceSmsRunState(
          running: true,
          current: 'Interval ${settings.intervalSeconds} s',
          done: results.length,
          total: plan.length,
          results: List.unmodifiable(results),
        );
        await ref.read(voiceSmsDelayProvider)(
          Duration(seconds: settings.intervalSeconds),
        );
        if (!state.running) break;
      }
      if (kind == VoiceSmsKind.call) callsMade++;
      state = VoiceSmsRunState(
        running: true,
        current: '${kind.label}: ${target.name}',
        done: results.length,
        total: plan.length,
        results: List.unmodifiable(results),
      );
      final at = context.now();
      final result = await switch (kind) {
        VoiceSmsKind.call => engine.call(
          target,
          setupTimeout: Duration(seconds: settings.setupTimeoutSeconds),
          hold: Duration(seconds: settings.holdSeconds),
        ),
        VoiceSmsKind.sms => engine.sms(
          target,
          timeout: Duration(seconds: settings.smsTimeoutSeconds),
        ),
      };
      if (!state.running) break; // cancelled: the interrupted result is dropped
      results.add(result);
      try {
        link ??= await context.link(
          label: 'Voice/SMS test',
          startedAt: startedAt,
          radio: radio,
          location: location,
        );
        await ref.read(voiceSmsStoreProvider).saveVoiceSmsTests([
          VoiceSmsRecord(
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
    state = VoiceSmsRunState(
      done: results.length,
      total: plan.length,
      results: List.unmodifiable(results),
      error: error,
    );
  }

  Future<void> cancel() async {
    if (!state.running) return;
    state = VoiceSmsRunState(
      done: state.done,
      total: state.total,
      results: state.results,
    );
    await ref.read(voiceSmsEngineProvider).cancel();
  }
}

final voiceSmsControllerProvider =
    NotifierProvider<VoiceSmsController, VoiceSmsRunState>(
      VoiceSmsController.new,
    );

/// Keeps radio and GNSS subscribed while voice/SMS tests run.
final voiceSmsPipelineProvider = Provider<void>((ref) {
  final running = ref.watch(
    voiceSmsControllerProvider.select((s) => s.running),
  );
  if (!running) return;
  ref
    ..listen(radioSnapshotProvider, (previous, next) {})
    ..listen(locationStatusProvider, (previous, next) {});
});
