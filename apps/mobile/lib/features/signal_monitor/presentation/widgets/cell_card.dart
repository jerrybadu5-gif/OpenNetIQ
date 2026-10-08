import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/signal_colors.dart';

/// Serving-cell card: level with quality class, identity and all metrics.
class CellCard extends StatelessWidget {
  const CellCard({required this.cell, required this.title, super.key});

  final CellObservation cell;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = cell.levelDbm;
    final quality = level == null
        ? null
        : SignalQuality.fromLevel(cell.rat, level);
    final metrics = <(String, String)>[
      (cell.areaLabel, formatInt(cell.lacTac)),
      (cell.physicalIdLabel, formatInt(cell.pciPscBsic)),
      ('Cell ID', formatInt(cell.cellId)),
      if (cell.rat == Rat.lte) ('eNB ID', formatInt(cell.enbId)),
      if (cell.rat == Rat.lte) ('Local cell', formatInt(cell.localCellId)),
      if (cell.rat == Rat.nr) ('gNB ID', formatInt(cell.gnbId)),
      (cell.channelLabel, formatInt(cell.arfcn)),
      if (cell.bandwidthKhz != null)
        ('Bandwidth', '${cell.bandwidthKhz! ~/ 1000} MHz'),
      if (cell.rat == Rat.lte || cell.rat == Rat.nr) ...[
        (cell.rat == Rat.nr ? 'SS-RSRQ' : 'RSRQ', formatDb(cell.rsrqDb, 'dB')),
        (cell.rat == Rat.nr ? 'SS-SINR' : 'SINR', formatDb(cell.sinrDb, 'dB')),
      ],
      if (cell.rat == Rat.lte) ...[
        ('RSSI', formatDb(cell.rssiDbm, 'dBm')),
        ('CQI', formatInt(cell.cqi)),
        ('TA', formatInt(cell.timingAdvance)),
      ],
      if (cell.rat == Rat.nr) ...[
        ('CSI-RSRP', formatDb(cell.csiRsrpDbm, 'dBm')),
        ('CSI-SINR', formatDb(cell.csiSinrDb, 'dB')),
      ],
      if (cell.rat == Rat.wcdma) ('Ec/No', formatDb(cell.ecnoDb, 'dB')),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  [cell.rat.wireValue, ?cell.band].join(' '),
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDb(level, 'dBm'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: quality == null ? null : signalQualityColor(quality),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${cell.levelLabel} - ${quality?.label ?? 'Unavailable'}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final (label, value) in metrics)
                  _Metric(label: label, value: value),
              ],
            ),
            if (cell.qualityFlag != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Quality flag: ${cell.qualityFlag}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
