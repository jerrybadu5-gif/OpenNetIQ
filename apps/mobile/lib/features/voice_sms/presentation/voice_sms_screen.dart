import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/voice_sms_test.dart';
import 'package:opennetiq_mobile/features/privacy/application/consent_controller.dart';
import 'package:opennetiq_mobile/features/voice_sms/application/voice_sms_controller.dart';

IconData voiceSmsIcon(VoiceSmsKind k) =>
    k == VoiceSmsKind.call ? Icons.call : Icons.sms_outlined;

/// Voice call and SMS sequences (issue #30).
class VoiceSmsScreen extends ConsumerStatefulWidget {
  const VoiceSmsScreen({super.key});

  @override
  ConsumerState<VoiceSmsScreen> createState() => _VoiceSmsScreenState();
}

class _VoiceSmsScreenState extends ConsumerState<VoiceSmsScreen> {
  final Set<VoiceSmsKind> _kinds = {...VoiceSmsKind.values};

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(voiceSmsControllerProvider);
    final controller = ref.read(voiceSmsControllerProvider.notifier);
    final settings = ref.watch(voiceSmsSettingsProvider).value;
    final consent = ref.watch(voiceSmsConsentProvider);
    final theme = Theme.of(context);
    final error = run.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Voice and SMS tests')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const VoiceSmsConsentCard(),
          if (consent) const _PermissionsCard(),
          Wrap(
            spacing: 8,
            children: [
              for (final k in VoiceSmsKind.values)
                FilterChip(
                  avatar: Icon(voiceSmsIcon(k), size: 18),
                  label: Text(k.label),
                  selected: _kinds.contains(k),
                  onSelected: run.running
                      ? null
                      : (on) => setState(
                          () => on ? _kinds.add(k) : _kinds.remove(k),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    run.running ? run.current ?? 'Starting...' : 'Ready',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (run.total > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: run.done / run.total),
                    Text('${run.done} / ${run.total}'),
                  ],
                  const SizedBox(height: 12),
                  if (run.running)
                    OutlinedButton.icon(
                      onPressed: controller.cancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _kinds.isEmpty || !consent
                          ? null
                          : () => controller.run({..._kinds}),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start tests'),
                    ),
                ],
              ),
            ),
          ),
          if (error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(error),
              ),
            ),
          for (final r in run.results) VoiceSmsResultTile(result: r),
          const SizedBox(height: 8),
          if (settings != null)
            _LinesCard(settings: settings, locked: run.running),
          const SizedBox(height: 8),
          const _History(),
        ],
      ),
    );
  }
}

/// Opt-in switch for the voice_sms consent scope (policy 1.1).
class VoiceSmsConsentCard extends ConsumerWidget {
  const VoiceSmsConsentCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(consentProvider).value;
    return Card(
      child: SwitchListTile(
        title: const Text('Allow voice and SMS tests'),
        subtitle: const Text(
          'Places test calls and sends test SMS to the numbers you set. '
          'Normal call and SMS charges apply. Results keep only the last two '
          'digits of a number and never the message text.',
        ),
        value: status?.voiceSms ?? false,
        onChanged: status == null
            ? null
            : (on) async {
                final engine = ref.read(voiceSmsEngineProvider);
                await ref
                    .read(consentProvider.notifier)
                    .setVoiceSms(granted: on);
                if (on) {
                  await engine.requestPermissions();
                  ref.invalidate(voiceSmsPermissionsProvider);
                }
              },
      ),
    );
  }
}

class _PermissionsCard extends ConsumerWidget {
  const _PermissionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(voiceSmsPermissionsProvider).value;
    if (p == null || p.all) return const SizedBox.shrink();
    final missing = [
      if (!p.call) 'calls',
      if (!p.endCall) 'ending calls',
      if (!p.callLog) 'call log (setup time)',
      if (!p.sendSms) 'sending SMS',
      if (!p.receiveSms) 'receiving SMS',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Android permissions missing'),
        subtitle: Text(
          p.hasTelephony
              ? 'Needed: ${missing.join(', ')}.'
              : 'This device has no telephony.',
        ),
        trailing: TextButton(
          onPressed: () async {
            await ref.read(voiceSmsEngineProvider).requestPermissions();
            ref.invalidate(voiceSmsPermissionsProvider);
          },
          child: const Text('Grant'),
        ),
      ),
    );
  }
}

class VoiceSmsResultTile extends StatelessWidget {
  const VoiceSmsResultTile({required this.result, this.subtitle, super.key});

  final VoiceSmsResult result;
  final String? subtitle;

  static String ms(double? v) => v == null ? '-' : '${v.round()} ms';

  List<(String, String)> details() {
    final r = result;
    return [
      ('Number', r.targetMasked),
      ('Status', r.status.wireValue),
      ('Outcome', r.outcome.replaceAll('_', ' ')),
      if (r.error != null) ('Error', r.error!),
      if (r.kind == VoiceSmsKind.call) ...[
        ('Call window', r.windowS == null ? '-' : '${r.windowS} s'),
        ('Setup time', ms(r.setupMs)),
        ('Connected', r.connectedS == null ? '-' : '${r.connectedS} s'),
        ('Dropped', r.dropped == null ? '-' : (r.dropped! ? 'yes' : 'no')),
      ] else ...[
        ('To this phone', (r.loopback ?? false) ? 'yes' : 'no'),
        ('Sent report', ms(r.sendMs)),
        ('Delivery report', ms(r.deliveryMs)),
        ('Received', ms(r.receiveMs)),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final failed = result.status == TestStatus.failed;
    return Card(
      child: ListTile(
        leading: Icon(
          voiceSmsIcon(result.kind),
          color: failed ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text('${result.label} (${result.targetMasked})'),
        subtitle: Text(
          subtitle == null ? result.summary : '${result.summary}\n$subtitle',
        ),
        isThreeLine: subtitle != null,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${result.kind.label}: ${result.label}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final (k, v) in details())
                  ListTile(dense: true, title: Text(k), trailing: Text(v)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinesCard extends ConsumerWidget {
  const _LinesCard({required this.settings, required this.locked});

  final VoiceSmsSettings settings;
  final bool locked;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    VoiceSmsKind kind,
  ) async {
    final controller = TextEditingController(
      text: PhoneTarget.toLines(settings.targets(kind)),
    );
    final saved = await showDialog<List<PhoneTarget>>(
      context: context,
      builder: (context) => _LinesDialog(kind: kind, controller: controller),
    );
    if (saved == null) return;
    await ref
        .read(voiceSmsSettingsProvider.notifier)
        .save(
          kind == VoiceSmsKind.call
              ? settings.copyWith(callTargets: saved)
              : settings.copyWith(smsTargets: saved),
        );
  }

  Future<void> _options(BuildContext context, WidgetRef ref) async {
    final window = TextEditingController(text: '${settings.callWindowSeconds}');
    final timeout = TextEditingController(
      text: '${settings.smsTimeoutSeconds}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: window,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Call length from dialling (s)',
              ),
            ),
            TextField(
              controller: timeout,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'SMS timeout (s)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    await ref
        .read(voiceSmsSettingsProvider.notifier)
        .save(
          settings.copyWith(
            callWindowSeconds: (int.tryParse(window.text) ?? 45).clamp(10, 600),
            smsTimeoutSeconds: (int.tryParse(timeout.text) ?? 60).clamp(5, 600),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget section(VoiceSmsKind kind) => ExpansionTile(
      leading: Icon(voiceSmsIcon(kind)),
      title: Text(kind.label),
      subtitle: Text('${settings.targets(kind).length} numbers'),
      children: [
        for (final t in settings.targets(kind))
          ListTile(
            dense: true,
            title: Text(t.name),
            subtitle: Text('${t.number}${t.loopback ? ' · this phone' : ''}'),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: locked ? null : () => _edit(context, ref, kind),
            child: Text('Edit ${kind.label.toLowerCase()} numbers'),
          ),
        ),
      ],
    );
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Test numbers'),
            subtitle: Text(
              'Call ${settings.callWindowSeconds} s from dialling · SMS '
              'timeout ${settings.smsTimeoutSeconds} s',
            ),
            trailing: TextButton(
              onPressed: locked ? null : () => _options(context, ref),
              child: const Text('Options'),
            ),
          ),
          section(VoiceSmsKind.call),
          section(VoiceSmsKind.sms),
        ],
      ),
    );
  }
}

class _LinesDialog extends StatefulWidget {
  const _LinesDialog({required this.kind, required this.controller});

  final VoiceSmsKind kind;
  final TextEditingController controller;

  @override
  State<_LinesDialog> createState() => _LinesDialogState();
}

class _LinesDialogState extends State<_LinesDialog> {
  List<String> _errors = const [];

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind.label),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.kind == VoiceSmsKind.call
                ? 'One per line: Name | number. Use a test line that answers '
                      'automatically and keeps the call up.'
                : 'One per line: Name | number. Add | self for this '
                      "phone's own number to also time the arrival.",
          ),
          TextField(
            controller: widget.controller,
            minLines: 3,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
          ),
          for (final e in _errors)
            Text(
              e,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final (targets, errors) = PhoneTarget.parseLines(
            widget.controller.text,
          );
          if (errors.isNotEmpty) {
            setState(() => _errors = errors);
            return;
          }
          Navigator.of(context).pop(targets);
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(voiceSmsHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: Theme.of(context).textTheme.titleMedium),
        switch (history) {
          AsyncData(:final value) when value.isEmpty => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tests yet.'),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final r in value)
                VoiceSmsResultTile(
                  result: r.result,
                  subtitle: formatLocalDateTime(r.timestamp),
                ),
            ],
          ),
          AsyncError(:final error) => Text('Could not load history: $error'),
          _ => const LinearProgressIndicator(),
        },
      ],
    );
  }
}
