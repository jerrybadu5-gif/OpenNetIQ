import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/flavor.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(flavorProvider);
    return Scaffold(
      appBar: AppBar(title: Text(flavor.label)),
      body: ListView(
        children: [
          const RecordingBanner(),
          ListTile(
            leading: const Icon(Icons.signal_cellular_alt),
            title: const Text('Signal monitor'),
            subtitle: const Text(
              'Live serving and neighbour cells, 2G to 5G NSA/SA',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.signal),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Sessions'),
            subtitle: const Text('Recorded measurements stored on this device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sessions),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.speed),
            title: Text('Speed & latency tests'),
            subtitle: Text('Coming in M1'),
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Drive test'),
            subtitle: const Text(
              'Record sessions at 1, 2 or 5 s, also with the screen off',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.drive),
          ),
        ],
      ),
    );
  }
}

/// Shown while a session is open, from any entry point.
class RecordingBanner extends ConsumerWidget {
  const RecordingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    if (!state.isActive) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(12),
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          state.isPaused ? Icons.pause_circle : Icons.fiber_manual_record,
          color: scheme.onErrorContainer,
        ),
        title: Text(
          state.isPaused ? 'Recording paused' : 'Recording',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        subtitle: Text(
          '${state.sessionName ?? ''} - ${state.recordedSamples} samples',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onErrorContainer),
        onTap: () => context.push(AppRoutes.drive),
      ),
    );
  }
}
