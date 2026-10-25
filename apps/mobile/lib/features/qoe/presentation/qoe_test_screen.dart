import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/features/qoe/application/qoe_controller.dart';

IconData qoeIcon(QoeKind k) => switch (k) {
  QoeKind.web => Icons.public,
  QoeKind.video => Icons.ondemand_video,
  QoeKind.app => Icons.apps,
  QoeKind.file => Icons.swap_vert,
};

/// Customer-experience tests (issue #29): web, video, apps, file transfer.
class QoeTestScreen extends ConsumerStatefulWidget {
  const QoeTestScreen({super.key});

  @override
  ConsumerState<QoeTestScreen> createState() => _QoeTestScreenState();
}

class _QoeTestScreenState extends ConsumerState<QoeTestScreen> {
  final Set<QoeKind> _kinds = {...QoeKind.values};

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(qoeTestControllerProvider);
    final controller = ref.read(qoeTestControllerProvider.notifier);
    final settings = ref.watch(qoeSettingsProvider).value;
    final theme = Theme.of(context);
    final error = run.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Experience tests')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final k in QoeKind.values)
                FilterChip(
                  avatar: Icon(qoeIcon(k), size: 18),
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
                      onPressed: _kinds.isEmpty
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
          for (final r in run.results) QoeResultTile(result: r),
          const SizedBox(height: 8),
          if (settings != null)
            _TargetsCard(settings: settings, locked: run.running),
          const SizedBox(height: 8),
          const _QoeHistory(),
        ],
      ),
    );
  }
}

class QoeResultTile extends StatelessWidget {
  const QoeResultTile({required this.result, this.subtitle, super.key});

  final QoeResult result;
  final String? subtitle;

  static String ms(double? v) => v == null ? '-' : '${v.round()} ms';

  List<(String, String)> details() {
    final r = result;
    return [
      ('Target', r.target),
      ('Status', r.status.wireValue),
      if (r.error != null) ('Error', r.error!),
      if (r.kind == QoeKind.web || r.kind == QoeKind.app) ...[
        ('DNS', ms(r.dnsMs)),
        ('TCP connect', ms(r.connectMs)),
        ('TLS', ms(r.tlsMs)),
        ('First byte', ms(r.ttfbMs)),
        if (r.kind == QoeKind.web) ('DOM ready', ms(r.domMs)),
        (r.kind == QoeKind.web ? 'Page load' : 'Total', ms(r.totalMs)),
        if (r.httpStatus != null) ('HTTP status', '${r.httpStatus}'),
      ],
      if (r.kind == QoeKind.video) ...[
        ('Start delay', ms(r.startDelayMs)),
        ('Rebuffers', '${r.rebufferCount ?? 0} (${ms(r.rebufferMs)})'),
        ('Played', ms(r.playedMs)),
        (
          'Bitrate',
          r.bitrateKbps == null ? '-' : '${r.bitrateKbps!.round()} kbps',
        ),
        ('Resolution', r.resolution ?? '-'),
      ],
      if (r.kind == QoeKind.file) ...[
        ('Direction', r.direction ?? '-'),
        ('Duration', ms(r.totalMs)),
        (
          'Rate',
          r.rateMbps == null ? '-' : '${r.rateMbps!.toStringAsFixed(1)} Mbps',
        ),
        ('Bytes', '${r.bytes ?? '-'}'),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final failed = result.status == TestStatus.failed;
    return Card(
      child: ListTile(
        leading: Icon(
          qoeIcon(result.kind),
          color: failed ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(result.label),
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

class _TargetsCard extends ConsumerWidget {
  const _TargetsCard({required this.settings, required this.locked});

  final QoeSettings settings;
  final bool locked;

  Future<void> _edit(BuildContext context, WidgetRef ref, QoeKind kind) async {
    final video = kind == QoeKind.video;
    final controller = TextEditingController(
      text: QoeTarget.toLines(settings.targets(kind), video: video),
    );
    final saved = await showDialog<List<QoeTarget>>(
      context: context,
      builder: (context) => _TargetsDialog(kind: kind, controller: controller),
    );
    if (saved == null) return;
    await ref.read(qoeSettingsProvider.notifier).save(switch (kind) {
      QoeKind.web => settings.copyWith(web: saved),
      QoeKind.app => settings.copyWith(apps: saved),
      _ => settings.copyWith(videos: saved),
    });
  }

  Future<void> _options(BuildContext context, WidgetRef ref) async {
    final video = TextEditingController(text: '${settings.videoSeconds}');
    final file = TextEditingController(text: '${settings.fileSizeMib}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: video,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Video test length (s)',
              ),
            ),
            TextField(
              controller: file,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'File size (MB)'),
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
        .read(qoeSettingsProvider.notifier)
        .save(
          settings.copyWith(
            videoSeconds: (int.tryParse(video.text) ?? 30).clamp(5, 600),
            fileSizeMib: (int.tryParse(file.text) ?? 5).clamp(1, 100),
          ),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget section(QoeKind kind) => ExpansionTile(
      leading: Icon(qoeIcon(kind)),
      title: Text(kind.label),
      subtitle: Text('${settings.targets(kind).length} targets'),
      children: [
        for (final t in settings.targets(kind))
          ListTile(
            dense: true,
            title: Text(t.name),
            subtitle: Text(
              kind == QoeKind.video ? '${t.mode.label} · ${t.url}' : t.url,
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: locked ? null : () => _edit(context, ref, kind),
            child: Text('Edit ${kind.label.toLowerCase()} list'),
          ),
        ),
      ],
    );
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Targets'),
            subtitle: Text(
              'Video ${settings.videoSeconds} s · file ${settings.fileSizeMib} MB '
              'to the speed-test server',
            ),
            trailing: TextButton(
              onPressed: locked ? null : () => _options(context, ref),
              child: const Text('Options'),
            ),
          ),
          section(QoeKind.web),
          section(QoeKind.video),
          section(QoeKind.app),
        ],
      ),
    );
  }
}

class _TargetsDialog extends StatefulWidget {
  const _TargetsDialog({required this.kind, required this.controller});

  final QoeKind kind;
  final TextEditingController controller;

  @override
  State<_TargetsDialog> createState() => _TargetsDialogState();
}

class _TargetsDialogState extends State<_TargetsDialog> {
  List<String> _errors = const [];

  @override
  Widget build(BuildContext context) {
    final video = widget.kind == QoeKind.video;
    return AlertDialog(
      title: Text(widget.kind.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              video
                  ? 'One per line: Name | URL | page. Add "page" for videos on '
                        'web pages (YouTube, Facebook, game streams); leave it '
                        'out for direct HLS/DASH/MP4 streams.'
                  : 'One per line: Name | URL',
            ),
            TextField(
              controller: widget.controller,
              minLines: 4,
              maxLines: 10,
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
            final (targets, errors) = QoeTarget.parseLines(
              widget.controller.text,
              video: video,
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
}

class _QoeHistory extends ConsumerWidget {
  const _QoeHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(qoeHistoryProvider);
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
                QoeResultTile(
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
