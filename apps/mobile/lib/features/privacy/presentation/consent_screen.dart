import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/privacy.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/privacy/presentation/privacy_summary.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

/// First-run consent (issue #24): asked before any radio or location
/// collection, and again when the privacy policy version changes.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _busy = false;

  Future<void> _decide({required bool granted}) async {
    setState(() => _busy = true);
    final permissions = ref.read(radioPermissionsProvider.notifier);
    await ref.read(consentProvider.notifier).setMeasurement(granted: granted);
    // Android prompts only after the user agreed here.
    if (granted) await permissions.request();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Welcome to OpenNetIQ', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'OpenNetIQ measures mobile network quality. Before it reads '
              'any network or location data, please review what it collects.',
            ),
            const SizedBox(height: 16),
            const PrivacySummary(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => _decide(granted: true),
              child: const Text('Agree and continue'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _decide(granted: false),
              child: const Text('Not now'),
            ),
            const SizedBox(height: 16),
            Text(
              'Without consent, speed and latency tests still work but are '
              'not linked to network or location data. You can change this '
              'at any time in Privacy. Policy version $privacyPolicyVersion.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
