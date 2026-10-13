import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/latency_test.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/latency_test/presentation/rtt_chart.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

/// Latency test (issues #21, #22): ICMP, TCP and DNS against the test
/// server, live RTT chart, results and history.
class LatencyTestScreen extends ConsumerWidget {
  const LatencyTestScreen({super.key});

  static String ms(double? v) => v == null ? '-' : '${v.toStringAsFixed(1)} ms';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(latencyTestControllerProvider);
    final controller = ref.read(latencyTestControllerProvider.notifier);
    final server = switch (ref.watch(speedTestServerProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final target = server == null ? null : LatencyConfig.targetOf(server);
    final error = state.error;
    final theme = Theme.of(context);
    final protocol = state.protocol;
    return Scaffold(
      appBar: AppBar(title: const Text('Latency test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(
                target == null
                    ? 'No test server set'
                    : '${target.host}:${target.port}',
              ),
              subtitle: const Text('Same server as the speed test'),
              trailing: TextButton(
                onPressed: state.running
                    ? null
                    : () => context.push(AppRoutes.speed),
                child: const Text('Change'),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    state.running ? protocol?.label ?? 'Starting...' : 'Ready',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (state.running)
                    Text(
                      '${state.probes.length} / 20 probes',
                      style: theme.textTheme.headlineSmall,
                    ),
                  if (state.running && state.probes.isNotEmpty) ...[
                    Text('Last: ${ms(state.probes.last.rttMs)}'),
                    const SizedBox(height: 8),
                    RttChart(rttsMs: [for (final p in state.probes) p.rttMs]),
                  ],
                  const SizedBox(height: 16),
                  if (state.running)
                    OutlinedButton.icon(
                      onPressed: controller.cancel,
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: target == null ? null : controller.start,
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('Start test'),
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
          for (final r in state.results) LatencyResultCard(result: r),
          const SizedBox(height: 8),
          Text(
            '20 probes per protocol, 200 ms apart, 2 s timeout. ICMP may be '
            'blocked by some networks; that shows as 100 % loss.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const LatencyHistoryCard(),
        ],
      ),
    );
  }
}

class LatencyResultCard extends StatelessWidget {
  const LatencyResultCard({required this.result, super.key});

  final LatencyResult result;

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
    final loss = result.packetLossPct;
    final error = result.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.protocol.label}: ${result.status.wireValue}',
              style: theme.textTheme.titleMedium,
            ),
            Text(result.target, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            row('Median', LatencyTestScreen.ms(result.medianMs)),
            row(
              'Min / Max',
              '${LatencyTestScreen.ms(result.minMs)} / '
                  '${LatencyTestScreen.ms(result.maxMs)}',
            ),
            row('Mean', LatencyTestScreen.ms(result.meanMs)),
            row('P95', LatencyTestScreen.ms(result.p95Ms)),
            row('Jitter', LatencyTestScreen.ms(result.jitterMs)),
            row(
              'Packet loss',
              loss == null
                  ? '-'
                  : '${loss.toStringAsFixed(0)} % '
                        '(${result.probesReceived}/${result.probesSent})',
            ),
            if (result.rawRttsMs.isNotEmpty) ...[
              const SizedBox(height: 12),
              RttChart(rttsMs: result.rawRttsMs),
            ],
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

/// Stored latency rows (one per protocol), newest first.
class LatencyHistoryCard extends ConsumerWidget {
  const LatencyHistoryCard({super.key});

  static String summary(LatencyResult r) {
    final loss = r.packetLossPct;
    return '${r.protocol.label} · median ${LatencyTestScreen.ms(r.medianMs)}'
        ' · loss ${loss == null ? '-' : '${loss.toStringAsFixed(0)} %'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(latencyHistoryProvider);
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
                      '${record.result.target} · '
                      '${record.result.status.wireValue}',
                    ),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: LatencyResultCard(result: record.result),
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
