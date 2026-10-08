import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

/// Recorded sessions stored on this device, with delete controls.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final hasSessions = switch (sessions) {
      AsyncData(:final value) => value.isNotEmpty,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          if (hasSessions)
            IconButton(
              tooltip: 'Delete all sessions',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmDeleteAll(context, ref),
            ),
        ],
      ),
      body: switch (sessions) {
        AsyncData(:final value) when value.isEmpty => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No sessions yet. Start recording from the Signal monitor.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncData(:final value) => ListView.separated(
          itemCount: value.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => SessionTile(
            session: value[index],
            onDelete: () => _confirmDelete(context, ref, value[index]),
          ),
        ),
        AsyncError(:final error) => Center(
          child: Text('Could not load sessions: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MeasurementSession session,
  ) async {
    final ok = await _confirm(
      context,
      'Delete "${session.name}"?',
      'Its ${session.sampleCount} samples are removed from this device.',
    );
    if (ok) {
      await ref.read(sessionRepositoryProvider).deleteSession(session.id);
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      'Delete all sessions?',
      'All recorded measurements are removed from this device.',
    );
    if (ok) {
      await ref.read(sessionRepositoryProvider).deleteAllSessions();
    }
  }

  static Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile({required this.session, required this.onDelete, super.key});

  final MeasurementSession session;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = [
      session.type.label,
      _statusLabel(session.status),
      '${session.sampleCount} samples',
      if (session.distanceM != null && session.distanceM! > 0)
        '${(session.distanceM! / 1000).toStringAsFixed(2)} km',
      if (session.duration() case final d?) formatDuration(d),
    ];
    return ListTile(
      leading: Icon(
        session.status == SessionStatus.recording
            ? Icons.fiber_manual_record
            : Icons.route,
      ),
      title: Text(session.name),
      subtitle: Text(details.join(' - ')),
      trailing: IconButton(
        tooltip: 'Delete session',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }

  static String _statusLabel(SessionStatus s) => switch (s) {
    SessionStatus.created => 'Created',
    SessionStatus.recording => 'Recording',
    SessionStatus.paused => 'Paused',
    SessionStatus.completed => 'Completed',
    SessionStatus.aborted => 'Aborted',
  };

  /// `h:mm:ss` or `m:ss`.
  static String formatDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }
}
