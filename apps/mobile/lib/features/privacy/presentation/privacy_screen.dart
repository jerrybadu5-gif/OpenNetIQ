import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/consent.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/privacy/presentation/privacy_summary.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

/// Privacy settings (issue #24): consent switch, data deletion, ledger.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(consentProvider).value;
    final recording = ref.watch(
      recordingControllerProvider.select((s) => s.isActive),
    );
    final ledger = ref.watch(consentLedgerProvider).value ?? const [];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Measure radio and location'),
              subtitle: Text(
                recording
                    ? 'Stop the recording to change this.'
                    : 'Signal monitor, drive tests and test snapshots.',
              ),
              value: consent?.measurement ?? false,
              onChanged: consent == null || recording
                  ? null
                  : (on) => _setMeasurement(ref, granted: on),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: PrivacySummary(),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete all measurement data'),
              subtitle: Text(
                recording
                    ? 'Stop the recording first.'
                    : 'Sessions, samples and test results on this phone.',
              ),
              enabled: !recording,
              onTap: () => _confirmErase(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          Text('Consent history', style: theme.textTheme.titleMedium),
          Text(
            'Kept as a record of your decisions. Policy version '
            '$privacyPolicyVersion.',
            style: theme.textTheme.bodySmall,
          ),
          if (ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No decisions recorded.'),
            ),
          for (final r in ledger.take(20)) ConsentLedgerTile(record: r),
          const SizedBox(height: 16),
          Text(
            'To revoke Android permissions as well, open Android Settings '
            '> Apps > OpenNetIQ > Permissions.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static Future<void> _setMeasurement(
    WidgetRef ref, {
    required bool granted,
  }) async {
    final permissions = ref.read(radioPermissionsProvider.notifier);
    await ref.read(consentProvider.notifier).setMeasurement(granted: granted);
    if (granted) await permissions.request();
  }

  static Future<void> _confirmErase(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all measurement data?'),
        content: const Text(
          'All sessions, samples, cell observations, speed and latency '
          'results are removed from this phone. Exported files you already '
          'shared are not affected. This cannot be undone.',
        ),
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
    if (!(ok ?? false)) return;
    try {
      await ref.read(measurementDataEraserProvider).eraseMeasurements();
      messenger.showSnackBar(
        const SnackBar(content: Text('All measurement data deleted.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

class ConsentLedgerTile extends StatelessWidget {
  const ConsentLedgerTile({required this.record, super.key});

  final ConsentRecord record;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      record.granted ? Icons.check_circle_outline : Icons.cancel_outlined,
    ),
    title: Text(
      '${record.scope.wireValue}: ${record.granted ? 'granted' : 'refused'}',
    ),
    subtitle: Text(
      '${formatLocalDateTime(record.timestamp)} · policy '
      '${record.policyVersion}',
    ),
  );
}
