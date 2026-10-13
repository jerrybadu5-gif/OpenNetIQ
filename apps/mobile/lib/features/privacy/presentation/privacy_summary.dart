import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';

/// What is collected, where it stays, what is never collected
/// (PRIVACY.md, policy 1.0).
class PrivacySummary extends StatelessWidget {
  const PrivacySummary({super.key});

  static const collected = [
    'Mobile network: operator, network type (2G-5G), cell identifiers '
        'and signal levels of the serving and neighbouring cells.',
    'Location: GPS position, speed and accuracy while the signal monitor, '
        'a drive test or a speed/latency test is running.',
    'Test results: speed, latency, the test server used, phone model and '
        'Android version.',
  ];

  static const never = [
    'Phone number, IMEI, IMSI or SIM serial',
    'Contacts, messages, call logs, photos or files',
    'Browsing history or the content of your traffic',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bullets(List<String> items, IconData icon) => Column(
      children: [
        for (final i in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, size: 20),
            title: Text(i),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What OpenNetIQ measures', style: theme.textTheme.titleSmall),
        bullets(collected, Icons.check_circle_outline),
        const SizedBox(height: 8),
        Text('Never collected', style: theme.textTheme.titleSmall),
        bullets(never, Icons.block),
        const SizedBox(height: 8),
        Text('Where it goes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text(
          'Measurements stay on this phone. They leave it only when you '
          'export a session and choose where to share it. Speed and latency '
          'tests connect to the test server you set, which sees your IP '
          'address. You can delete all measurements at any time.',
        ),
      ],
    );
  }
}

/// Shown instead of live data when measurement consent is missing.
class ConsentPrompt extends StatelessWidget {
  const ConsentPrompt({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            'Measurement is switched off',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You have not agreed to radio and location measurement. Review '
            'what is collected and switch it on in Privacy.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.privacy),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Open privacy settings'),
          ),
        ],
      ),
    ),
  );
}
