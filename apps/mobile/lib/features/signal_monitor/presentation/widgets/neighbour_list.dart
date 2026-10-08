import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/signal_colors.dart';

/// Neighbour cells sorted strongest first.
class NeighbourList extends StatelessWidget {
  const NeighbourList({required this.cells, super.key});

  final List<CellObservation> cells;

  @override
  Widget build(BuildContext context) {
    final sorted = [...cells]
      ..sort(
        (a, b) => (b.levelDbm ?? double.negativeInfinity).compareTo(
          a.levelDbm ?? double.negativeInfinity,
        ),
      );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Neighbour cells (${sorted.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No neighbour cells reported.'),
            ),
          for (final cell in sorted) _NeighbourTile(cell: cell),
        ],
      ),
    );
  }
}

class _NeighbourTile extends StatelessWidget {
  const _NeighbourTile({required this.cell});

  final CellObservation cell;

  @override
  Widget build(BuildContext context) {
    final level = cell.levelDbm;
    final quality = level == null
        ? null
        : SignalQuality.fromLevel(cell.rat, level);
    return ListTile(
      dense: true,
      leading: Text(cell.rat.wireValue),
      title: Text(
        '${cell.physicalIdLabel} ${formatInt(cell.pciPscBsic)} - '
        '${cell.channelLabel} ${formatInt(cell.arfcn)}',
      ),
      subtitle: cell.band == null ? null : Text(cell.band!),
      trailing: Text(
        '${cell.levelLabel} ${formatDb(level, 'dBm')}',
        style: TextStyle(
          color: quality == null ? null : signalQualityColor(quality),
        ),
      ),
    );
  }
}
