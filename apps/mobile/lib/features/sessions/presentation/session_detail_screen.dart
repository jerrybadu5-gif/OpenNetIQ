import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/services/session_stats.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';
import 'package:opennetiq_mobile/features/map/presentation/track_map.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/sessions/application/session_detail_providers.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/sessions_screen.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/signal_colors.dart';

/// Session detail (issue #18): track map, summary, completeness, signal
/// level statistics and distributions, delete.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  static String percent(double share) =>
      '${(share * 100).toStringAsFixed(1)} %';

  static String ratMetric(Rat rat) => switch (rat) {
    Rat.lte => '4G RSRP',
    Rat.nr => '5G SS-RSRP',
    Rat.wcdma => '3G RSCP',
    Rat.gsm => '2G RSSI',
    _ => '${rat.wireValue} level',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sessionDetailProvider(sessionId));
    final session = switch (detail) {
      AsyncData(:final value) => value?.session,
      _ => null,
    };
    final canDelete = session != null && !session.status.isActive;
    return Scaffold(
      appBar: AppBar(
        title: Text(session?.name ?? 'Session'),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Delete session',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: switch (detail) {
        AsyncData(value: final d?) => _DetailView(detail: d),
        AsyncData() => const Center(child: Text('Session not found.')),
        AsyncError(:final error) => Center(
          child: Text('Could not load session: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text(
          'All its samples and cell observations are removed from this '
          'device.',
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
    await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
    if (context.mounted) context.pop();
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.detail});

  final SessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.session;
    final stats = detail.stats;
    final gaps = detail.gaps;
    final distance = s.distanceM;
    final duration = s.duration();
    final missingPct = gaps.missingPct;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (s.status.isActive)
          const Card(
            child: ListTile(
              leading: Icon(Icons.fiber_manual_record),
              title: Text('Recording in progress'),
              subtitle: Text('Statistics show the samples stored so far.'),
            ),
          ),
        TrackMap(points: detail.points),
        const TrackLegend(),
        _Section(
          title: 'Summary',
          rows: [
            ('Status', SessionTile.statusLabel(s.status)),
            ('Type', s.type.label),
            if (s.startedAt case final t?) ('Started', formatLocalDateTime(t)),
            if (s.endedAt case final t?) ('Ended', formatLocalDateTime(t)),
            if (duration != null)
              ('Duration', SessionTile.formatDuration(duration)),
            ('Samples', '${s.sampleCount}'),
            if (distance != null)
              ('Distance', '${(distance / 1000).toStringAsFixed(2)} km'),
            ('Interval', '${s.samplingIntervalMs ~/ 1000} s'),
            if (s.operatorUnderTest case final op?) ('Operator', op),
            ('Methodology', s.methodologyVersion),
          ],
        ),
        _Section(
          title: 'Completeness',
          rows: [
            ('Expected', '${gaps.expected}'),
            (
              'Missing',
              missingPct == null
                  ? '-'
                  : '${gaps.missing} (${missingPct.toStringAsFixed(2)} %)',
            ),
            ('Gaps', '${gaps.gaps.length}'),
            if (gaps.gaps.isNotEmpty)
              ('Longest gap', SessionTile.formatDuration(gaps.longestGap)),
            (
              'With GPS position',
              SessionDetailScreen.percent(stats.share(stats.positioned)),
            ),
          ],
          note: 'Pauses count as gaps here.',
        ),
        _Section(
          title: 'Signal level (dBm)',
          rows: [
            for (final e in stats.levelByRat.entries)
              (SessionDetailScreen.ratMetric(e.key), _levelText(e.value)),
            if (stats.levelByRat.isEmpty) ('Level', 'No serving cell data'),
          ],
          note: 'min / median / max (samples)',
        ),
        _DistributionCard(stats: stats),
        _Section(
          title: 'Network type',
          rows: [
            for (final e in stats.networkCounts.entries)
              (e.key.label, SessionDetailScreen.percent(stats.share(e.value))),
          ],
        ),
      ],
    );
  }

  static String _levelText(LevelStats l) =>
      '${l.min.round()} / ${l.median.round()} / ${l.max.round()} '
      '(${l.count})';
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.stats});

  final SessionStats stats;

  @override
  Widget build(BuildContext context) {
    Widget bar(Color color, String label, int count) {
      final share = stats.share(count);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(label)),
            Expanded(
              child: LinearProgressIndicator(
                value: share,
                color: color,
                minHeight: 8,
                semanticsLabel: label,
                semanticsValue: SessionDetailScreen.percent(share),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                SessionDetailScreen.percent(share),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Signal class',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final q in SignalQuality.values)
              bar(signalQualityColor(q), q.label, stats.qualityCounts[q] ?? 0),
            bar(unknownLevelColor, 'No level', stats.noServiceCell),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.note});

  final String title;
  final List<(String, String)> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = this.note;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: 4),
              Text(note, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
