import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/clock.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/services/sample_gaps.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/map/presentation/track_map.dart';
import 'package:opennetiq_mobile/features/recording/application/live_track.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_providers.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/sessions_screen.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';

/// Drive test (issue #17): session setup, live recording status with
/// pause/resume/stop and the gap report of the last session.
class DriveTestScreen extends ConsumerWidget {
  const DriveTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(radioPermissionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Drive test')),
      body: switch (permissions) {
        AsyncData(:final value) when !value.hasTelephony => const Center(
          child: StatusMessage(
            icon: Icons.signal_cellular_off,
            title: 'No cellular radio',
            message: 'This device cannot measure mobile networks.',
          ),
        ),
        AsyncData(:final value) when !value.canMonitor => PermissionPrompt(
          onRequest: () =>
              ref.read(radioPermissionsProvider.notifier).request(),
        ),
        AsyncData() => const _DriveTestBody(),
        AsyncError(:final error) => Center(
          child: StatusMessage(
            icon: Icons.error_outline,
            title: 'Permissions unavailable',
            message: '$error',
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DriveTestBody extends ConsumerWidget {
  const _DriveTestBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(recordingControllerProvider.select((s) => s.phase));
    return switch (phase) {
      RecordingPhase.idle || RecordingPhase.starting => const DriveTestSetup(),
      _ => const DriveTestStatus(),
    };
  }
}

/// Session form: name, type, sampling interval, operator under test.
class DriveTestSetup extends ConsumerStatefulWidget {
  const DriveTestSetup({super.key});

  @override
  ConsumerState<DriveTestSetup> createState() => _DriveTestSetupState();
}

class _DriveTestSetupState extends ConsumerState<DriveTestSetup> {
  final _name = TextEditingController();
  final _operator = TextEditingController();
  SessionType _type = SessionType.drive;
  Duration _interval = RecordingOptions.defaultInterval;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-check battery optimisation after returning from system settings.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(batteryOptimizationProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _name.dispose();
    _operator.dispose();
    super.dispose();
  }

  void _start() {
    ref
        .read(recordingControllerProvider.notifier)
        .start(
          RecordingOptions(
            type: _type,
            interval: _interval,
            name: _name.text,
            operatorUnderTest: _operator.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingControllerProvider);
    final starting = state.phase == RecordingPhase.starting;
    final error = state.error;
    final report = state.lastReport;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null) ErrorCard(message: error),
        if (report != null) LastSessionCard(report: report, state: state),
        TextField(
          controller: _name,
          enabled: !starting,
          decoration: const InputDecoration(
            labelText: 'Session name',
            hintText: 'Defaults to date and time',
          ),
        ),
        const SizedBox(height: 16),
        Text('Type', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<SessionType>(
          segments: [
            for (final t in const [
              SessionType.drive,
              SessionType.walk,
              SessionType.stationary,
            ])
              ButtonSegment(value: t, label: Text(t.label)),
          ],
          selected: {_type},
          onSelectionChanged: starting
              ? null
              : (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        Text(
          'Sampling interval',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<Duration>(
          segments: [
            for (final i in RecordingOptions.allowedIntervals)
              ButtonSegment(value: i, label: Text('${i.inSeconds} s')),
          ],
          selected: {_interval},
          onSelectionChanged: starting
              ? null
              : (s) => setState(() => _interval = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _operator,
          enabled: !starting,
          decoration: const InputDecoration(
            labelText: 'Operator under test (optional)',
            hintText: 'e.g. Digicel PNG',
          ),
        ),
        const SizedBox(height: 16),
        const BatteryOptimizationCard(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: starting ? null : _start,
          icon: starting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fiber_manual_record),
          label: const Text('Start recording'),
        ),
        const SizedBox(height: 8),
        Text(
          'Recording continues with the screen off or the app closed. '
          'Stop it here or from the notification.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Live status of the open session.
class DriveTestStatus extends ConsumerWidget {
  const DriveTestStatus({super.key});

  static String formatPercent(double? ratio) =>
      ratio == null ? '-' : '${(ratio * 100).toStringAsFixed(1)} %';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);
    final now = ref.watch(clockProvider)();
    final radio = switch (ref.watch(radioSnapshotProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final location = switch (ref.watch(locationStatusProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final stopping = state.phase == RecordingPhase.stopping;
    final error = state.error;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!state.backgroundAvailable || error != null)
          ErrorCard(message: error ?? 'Background recording unavailable.'),
        TrackMap(points: ref.watch(liveTrackProvider), follow: true),
        const TrackLegend(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.isPaused ? Icons.pause_circle : Icons.circle,
                      color: state.isPaused
                          ? theme.colorScheme.outline
                          : const Color(0xFFC62828),
                    ),
                    const SizedBox(width: 8),
                    Text(switch (state.phase) {
                      RecordingPhase.paused => 'Paused',
                      RecordingPhase.stopping => 'Stopping...',
                      _ => 'Recording',
                    }, style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(state.sessionName ?? ''),
                const Divider(height: 24),
                _Row(
                  'Elapsed',
                  SessionTile.formatDuration(state.activeDuration(now)),
                ),
                _Row('Samples', '${state.recordedSamples}'),
                _Row(
                  'Completeness',
                  formatPercent(state.liveCompleteness(now)),
                ),
                _Row('Interval', '${state.interval.inSeconds} s'),
                _Row('Type', state.options.type.label),
                if (state.failedSamples > 0)
                  _Row('Not stored', '${state.failedSamples}'),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _Row('Network', _networkText(radio)),
                _Row('GPS', _gpsText(location)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: stopping
                    ? null
                    : state.isPaused
                    ? controller.resume
                    : controller.pause,
                icon: Icon(state.isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(state.isPaused ? 'Resume' : 'Pause'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: stopping ? null : () => _confirmStop(context, ref),
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _networkText(RadioSnapshot? radio) {
    if (radio == null) return 'Waiting...';
    final cell = radio.primaryCell;
    final level = cell?.levelDbm;
    return cell == null || level == null
        ? radio.networkType.label
        : '${radio.networkType.label}  ${cell.levelLabel} ${level.round()} dBm';
  }

  static String _gpsText(LocationStatus? location) {
    if (location == null) return 'Waiting...';
    final accuracy = location.fix?.hAccuracyM;
    return accuracy == null
        ? location.quality.label
        : '${location.quality.label}  ±${accuracy.round()} m';
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop recording?'),
        content: const Text('The session is closed and cannot be resumed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(recordingControllerProvider.notifier).stop();
    }
  }
}

/// Gap report of the session that just finished.
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({required this.report, required this.state, super.key});

  final GapReport report;
  final RecordingState state;

  @override
  Widget build(BuildContext context) {
    final missingPct = report.missingPct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Row('Samples', '${report.recorded}'),
            _Row('Expected', '${report.expected}'),
            _Row(
              'Missing',
              missingPct == null
                  ? '-'
                  : '${report.missing} (${missingPct.toStringAsFixed(2)} %)',
            ),
            _Row('Gaps', '${report.gaps.length}'),
            if (report.gaps.isNotEmpty)
              _Row(
                'Longest gap',
                SessionTile.formatDuration(report.longestGap),
              ),
            _Row('Active time', SessionTile.formatDuration(state.activeBefore)),
          ],
        ),
      ),
    );
  }
}

/// Warns when Android battery optimisation may throttle screen-off runs.
class BatteryOptimizationCard extends ConsumerWidget {
  const BatteryOptimizationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ignoring = switch (ref.watch(batteryOptimizationProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (ignoring != false) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.battery_alert),
        title: const Text('Battery optimisation is on'),
        subtitle: const Text(
          'Some phones pause apps with the screen off. Set OpenNetIQ to '
          '"Unrestricted" / "Not optimised" for long drive tests.',
        ),
        trailing: TextButton(
          onPressed: () =>
              ref.read(recordingServiceProvider).openBatterySettings(),
          child: const Text('Settings'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  const ErrorCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: scheme.onErrorContainer),
        title: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
