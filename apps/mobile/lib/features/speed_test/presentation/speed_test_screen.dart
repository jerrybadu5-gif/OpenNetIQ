import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';
import 'package:opennetiq_mobile/domain/entities/test_server.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';
import 'package:opennetiq_mobile/features/speed_test/presentation/throughput_chart.dart';

/// Speed test (issues #19, #22): server presets, start/cancel, live rate
/// and throughput curve, result and history.
class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  static String mbps(double? v) =>
      v == null ? '-' : '${v.toStringAsFixed(1)} Mbps';

  static String ms(double? v) => v == null ? '-' : '${v.toStringAsFixed(0)} ms';

  static String megabytes(int bytes) =>
      '${(bytes / 1e6).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestControllerProvider);
    final controller = ref.read(speedTestControllerProvider.notifier);
    final server = switch (ref.watch(speedTestServerProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final result = state.result;
    final error = state.error;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Speed test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ServerCard(
            current: server,
            presets: ref.watch(testServerPresetsProvider),
            enabled: !state.running,
            onSave: controller.saveServer,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    state.running
                        ? state.phase?.label ?? 'Starting...'
                        : 'Ready',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.running ? mbps(state.liveMbps) : '-',
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  if (state.running)
                    OutlinedButton.icon(
                      onPressed: controller.cancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: server == null ? null : controller.start,
                      icon: const Icon(Icons.speed),
                      label: const Text('Start test'),
                    ),
                ],
              ),
            ),
          ),
          ThroughputChart(
            download: state.downloadCurve,
            upload: state.uploadCurve,
          ),
          if (error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber),
                title: Text(error),
              ),
            ),
          if (result != null)
            ResultCard(result: result, ratChanged: state.ratChanged),
          const SizedBox(height: 8),
          Text(
            'Each test runs 12 s per direction over 4 connections and can '
            'use several hundred MB of mobile data on fast networks.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const SpeedHistoryCard(),
        ],
      ),
    );
  }
}

/// Server base URL (LibreSpeed-compatible endpoints).
class ServerCard extends StatefulWidget {
  const ServerCard({
    required this.current,
    required this.enabled,
    required this.onSave,
    this.presets = const [],
    super.key,
  });

  final String? current;
  final List<TestServer> presets;
  final bool enabled;
  final Future<void> Function(String url) onSave;

  @override
  State<ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<ServerCard> {
  late final TextEditingController _url = TextEditingController(
    text: widget.current ?? '',
  );
  String? _error;

  @override
  void didUpdateWidget(covariant ServerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current && widget.current != null) {
      _url.text = widget.current!;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  /// http(s) URL with a host; the engine adds `garbage.php` / `empty.php`.
  static String? validate(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      return 'Enter an http:// or https:// URL';
    }
    return null;
  }

  Future<void> _choose(TestServer preset) async {
    _url.text = preset.url;
    setState(() => _error = null);
    await widget.onSave(preset.url);
  }

  Future<void> _save() async {
    final error = validate(_url.text);
    setState(() => _error = error);
    if (error == null) await widget.onSave(_url.text);
  }

  @override
  Widget build(BuildContext context) {
    final preset = presetFor(widget.presets, widget.current);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _url,
              enabled: widget.enabled,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Test server URL',
                hintText: 'https://speed.example.org/backend/',
                errorText: _error,
                suffixIcon: widget.presets.isEmpty
                    ? null
                    : PopupMenuButton<TestServer>(
                        tooltip: 'Server presets',
                        enabled: widget.enabled,
                        icon: const Icon(Icons.list),
                        onSelected: _choose,
                        itemBuilder: (context) => [
                          for (final p in widget.presets)
                            PopupMenuItem(value: p, child: Text(p.name)),
                        ],
                      ),
              ),
            ),
            if (preset?.kind == TestServerKind.public)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Public server: measures the international path, not '
                  'the operator network. Use a controlled server for '
                  'benchmarking.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.enabled ? _save : null,
              child: const Text('Save server'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({required this.result, required this.ratChanged, super.key});

  final SpeedTestResult result;
  final bool ratChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
    List<Widget> direction(String title, ThroughputResult? d) => [
      const SizedBox(height: 8),
      Text(title, style: theme.textTheme.titleSmall),
      if (d == null)
        row('Result', 'No valid data')
      else ...[
        row('Mean', SpeedTestScreen.mbps(d.meanMbps)),
        row('Median', SpeedTestScreen.mbps(d.medianMbps)),
        row(
          'P10 / P90',
          '${d.p10Mbps.toStringAsFixed(1)} / '
              '${d.p90Mbps.toStringAsFixed(1)} Mbps',
        ),
        row('Peak (1 s)', SpeedTestScreen.mbps(d.peakMbps)),
        row('Transferred', SpeedTestScreen.megabytes(d.bytes)),
      ],
    ];
    final error = result.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Result: ${result.status.wireValue}',
              style: theme.textTheme.titleMedium,
            ),
            ...direction('Download', result.download),
            ...direction('Upload', result.upload),
            const SizedBox(height: 8),
            row('DNS', SpeedTestScreen.ms(result.dnsMs)),
            row('TCP connect', SpeedTestScreen.ms(result.tcpConnectMs)),
            row('Server', result.serverHost),
            row('Method', '${result.method}, ${result.streams} streams'),
            if (ratChanged)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Network type changed during the test (result flagged).',
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stored speed tests, newest first; tap for the full result.
class SpeedHistoryCard extends ConsumerWidget {
  const SpeedHistoryCard({super.key});

  static String summary(SpeedTestResult r) =>
      'Down ${SpeedTestScreen.mbps(r.download?.meanMbps)} · '
      'Up ${SpeedTestScreen.mbps(r.upload?.meanMbps)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(speedTestHistoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('History', style: theme.textTheme.titleMedium),
        switch (history) {
          AsyncData(:final value) when value.isEmpty => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tests yet.'),
          ),
          AsyncData(:final value) => Card(
            child: Column(
              children: [
                for (final record in value)
                  ListTile(
                    title: Text(summary(record.result)),
                    subtitle: Text(
                      '${formatLocalDateTime(record.timestamp)} · '
                      '${record.result.serverHost} · '
                      '${record.result.status.wireValue}',
                    ),
                    trailing: record.ratChanged
                        ? const Icon(
                            Icons.swap_horiz,
                            semanticLabel: 'RAT changed',
                          )
                        : null,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: ResultCard(
                            result: record.result,
                            ratChanged: record.ratChanged,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AsyncError(:final error) => Text('Could not load history: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
        },
      ],
    );
  }
}
