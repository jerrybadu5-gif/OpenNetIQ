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
        ('Protocol', (r.protocol ?? 'http').toUpperCase()),
        ('Direction', r.direction ?? '-'),
        ('Duration', ms(r.totalMs)),
        (
          'Rate',
          r.rateMbps == null ? '-' : '${r.rateMbps!.toStringAsFixed(1)} Mbps',
        ),
        ('Bytes', '${r.bytes ?? '-'}'),
        (
          'Signal during transfer',
          r.servingLevelDbm == null
              ? '-'
              : '${r.servingLevelDbm!.toStringAsFixed(1)} dBm'
                    '${r.servingRat == null ? '' : ' (${r.servingRat})'}',
        ),
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
    final saved = await showDialog<QoeSettings>(
      context: context,
      builder: (context) => QoeOptionsDialog(initial: settings),
    );
    if (saved != null) await ref.read(qoeSettingsProvider.notifier).save(saved);
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
              'Video ${settings.videoSeconds} s · file transfer: '
              '${settings.fileProtocol == FileProtocol.ftp ? 'FTP${settings.ftpConfigured ? '' : ' (not set up)'}' : '${settings.fileSizeMib} MB HTTP to the speed-test server'}',
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

/// Video length and file-transfer options (HTTP or FTP, spec v3 M14).
class QoeOptionsDialog extends StatefulWidget {
  const QoeOptionsDialog({required this.initial, super.key});

  final QoeSettings initial;

  @override
  State<QoeOptionsDialog> createState() => _QoeOptionsDialogState();
}

class _QoeOptionsDialogState extends State<QoeOptionsDialog> {
  late final QoeSettings s = widget.initial;
  late final _video = TextEditingController(text: '${s.videoSeconds}');
  late final _file = TextEditingController(text: '${s.fileSizeMib}');
  late final _url = TextEditingController(text: s.ftpUrl);
  late final _user = TextEditingController(text: s.ftpUser);
  late final _password = TextEditingController(text: s.ftpPassword);
  late final _maxS = TextEditingController(text: '${s.ftpMaxSeconds}');
  late FileProtocol _protocol = s.fileProtocol;
  late bool _auto = s.ftpSizeAuto;
  late int _down = s.ftpDownloadMib;
  late int _up = s.ftpUploadMib;
  String? _error;

  @override
  void dispose() {
    for (final c in [_video, _file, _url, _user, _password, _maxS]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _number(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label),
  );

  Widget _size(String label, int value, ValueChanged<int> onChanged) => Row(
    children: [
      Expanded(child: Text(label)),
      DropdownButton<int>(
        value: value,
        items: [
          for (final mb in QoeSettings.ftpSizes)
            DropdownMenuItem(value: mb, child: Text('$mb MB')),
        ],
        onChanged: (v) => setState(() => onChanged(v ?? value)),
      ),
    ],
  );

  void _save() {
    final ftp = _protocol == FileProtocol.ftp;
    final url = _url.text.trim();
    if (ftp && !url.toLowerCase().startsWith('ftp://')) {
      setState(() => _error = 'FTP server must start with ftp://');
      return;
    }
    Navigator.of(context).pop(
      s.copyWith(
        videoSeconds: (int.tryParse(_video.text) ?? 30).clamp(5, 600),
        fileSizeMib: (int.tryParse(_file.text) ?? 5).clamp(1, 100),
        fileProtocol: _protocol,
        ftpUrl: url,
        ftpUser: _user.text.trim(),
        ftpPassword: _password.text,
        ftpSizeAuto: _auto,
        ftpDownloadMib: _down,
        ftpUploadMib: _up,
        ftpMaxSeconds: (int.tryParse(_maxS.text) ?? 600).clamp(30, 1800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ftp = _protocol == FileProtocol.ftp;
    return AlertDialog(
      title: const Text('Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _number(_video, 'Video test length (s)'),
            const SizedBox(height: 16),
            Text(
              'File transfer',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SegmentedButton<FileProtocol>(
              segments: const [
                ButtonSegment(value: FileProtocol.http, label: Text('HTTP')),
                ButtonSegment(value: FileProtocol.ftp, label: Text('FTP')),
              ],
              selected: {_protocol},
              onSelectionChanged: (v) => setState(() => _protocol = v.first),
            ),
            if (!ftp) _number(_file, 'File size (MB)'),
            if (ftp) ...[
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'FTP server',
                  hintText: 'ftp://ftp.example.pg:21/',
                ),
              ),
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'User'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Download size by network'),
                subtitle: const Text('100 MB on 4G/5G, 50 MB on 3G (NICTA)'),
                value: _auto,
                onChanged: (v) => setState(() => _auto = v),
              ),
              if (!_auto) _size('Download size', _down, (v) => _down = v),
              _size('Upload size', _up, (v) => _up = v),
              _number(_maxS, 'Cut off a transfer after (s)'),
              const SizedBox(height: 8),
              const Text(
                'NICTA QoS Rule 2022 Schedule 2: FTP download ≥ 2.5 Mbps and '
                'upload ≥ 0.5 Mbps in ≥ 90 % of samples. The password stays '
                'on this phone and is never exported.',
              ),
            ],
            if (_error case final e?)
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
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
                  ? 'One per line: Name | URL, optionally | page or | stream. '
                        'Without it, .m3u8/.mpd/.mp4 links are direct streams '
                        'and other links (YouTube, Facebook, game sites) are '
                        'videos on a web page.'
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
