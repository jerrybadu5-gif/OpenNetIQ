import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/location/presentation/location_card.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/recording/presentation/record_button.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_history.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/cell_card.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/level_trend_chart.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/neighbour_list.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/network_header.dart';

/// Live Signal Dashboard (issue #15): serving cell(s), neighbours and a
/// one-minute level trend, refreshed every sampling interval.
class SignalMonitorScreen extends ConsumerWidget {
  const SignalMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(radioPermissionsProvider);
    final canRecord = switch (permissions) {
      AsyncData(:final value) => value.canMonitor,
      _ => false,
    };
    final recording = ref.watch(
      recordingControllerProvider.select((s) => s.isRecording),
    );
    return PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stop recording before leaving this screen.'),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Signal monitor'),
          actions: [if (canRecord) const RecordButton()],
        ),
        body: _body(ref, permissions),
      ),
    );
  }

  Widget _body(WidgetRef ref, AsyncValue<RadioPermissions> permissions) {
    return switch (permissions) {
      AsyncData(:final value) when !value.hasTelephony => const Center(
        child: StatusMessage(
          icon: Icons.signal_cellular_off,
          title: 'No cellular radio',
          message: 'This device cannot measure mobile networks.',
        ),
      ),
      AsyncData(:final value) when !value.canMonitor => PermissionPrompt(
        onRequest: () => ref.read(radioPermissionsProvider.notifier).request(),
      ),
      AsyncData(:final value) => LiveSignalView(permissions: value),
      AsyncError(:final error) => Center(
        child: StatusMessage(
          icon: Icons.error_outline,
          title: 'Permissions unavailable',
          message: '$error',
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class LiveSignalView extends ConsumerWidget {
  const LiveSignalView({required this.permissions, super.key});

  final RadioPermissions permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(radioSnapshotProvider);
    // Watched here (not in _SnapshotView) so the trend records from the
    // first snapshot onwards.
    final history = ref.watch(signalHistoryProvider);
    final location = ref.watch(locationStatusProvider);
    // Each radio tick is stored (with the latest location) while recording.
    ref.listen<AsyncValue<RadioSnapshot>>(radioSnapshotProvider, (
      previous,
      next,
    ) {
      if (next case AsyncData(:final value)) {
        final latestLocation = switch (ref.read(locationStatusProvider)) {
          AsyncData(value: final status) => status,
          _ => null,
        };
        ref
            .read(recordingControllerProvider.notifier)
            .onSnapshot(value, latestLocation);
      }
    });
    return switch (snapshot) {
      AsyncData(:final value) => _SnapshotView(
        snapshot: value,
        permissions: permissions,
        history: history,
        location: location,
      ),
      AsyncError(:final error) => Center(
        child: StatusMessage(
          icon: Icons.error_outline,
          title:
              error is RadioException &&
                  error.code == RadioException.permissionDenied
              ? 'Permission required'
              : 'Radio data unavailable',
          message: error is RadioException ? error.message : '$error',
        ),
      ),
      _ => const Center(
        child: StatusMessage(
          icon: Icons.cell_tower,
          title: 'Waiting for radio data',
          message: 'Reading serving and neighbour cells...',
          busy: true,
        ),
      ),
    };
  }
}

class _SnapshotView extends StatelessWidget {
  const _SnapshotView({
    required this.snapshot,
    required this.permissions,
    required this.history,
    required this.location,
  });

  final RadioSnapshot snapshot;
  final RadioPermissions permissions;
  final List<SignalPoint> history;
  final AsyncValue<LocationStatus> location;

  @override
  Widget build(BuildContext context) {
    final primary = snapshot.primaryCell;
    final nrLeg = snapshot.nrLeg;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        NetworkHeader(snapshot: snapshot, permissions: permissions),
        LocationCard(status: location),
        if (primary == null)
          const StatusMessage(
            icon: Icons.signal_cellular_connected_no_internet_0_bar,
            title: 'No serving cell',
            message: 'The modem did not report a registered cell.',
          )
        else
          CellCard(
            cell: primary,
            title: snapshot.networkType.isNsa ? 'LTE anchor' : 'Serving cell',
          ),
        if (nrLeg != null) CellCard(cell: nrLeg, title: '5G NR leg'),
        LevelTrendChart(points: history),
        NeighbourList(cells: snapshot.neighbourCellsExcludingNrLeg),
      ],
    );
  }
}

class PermissionPrompt extends StatelessWidget {
  const PermissionPrompt({required this.onRequest, super.key});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'Location and phone-state access needed',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Android only shares cell information with apps that have '
              'precise location access. Phone-state access lets OpenNetIQ '
              'detect 5G NSA. Nothing leaves this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.lock_open),
              label: const Text('Grant access'),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          if (busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
