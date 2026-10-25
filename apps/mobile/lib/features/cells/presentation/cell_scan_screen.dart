import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/features/cells/application/cell_layer_providers.dart';
import 'package:opennetiq_mobile/features/map/presentation/track_map.dart';

/// Cell scan (issue #27): every cell seen, grouped by band and channel, and
/// the sites estimated from drive data. [sessionId] null = all sessions.
class CellScanScreen extends ConsumerWidget {
  const CellScanScreen({this.sessionId, super.key});

  final String? sessionId;

  static String dbm(double? v) =>
      v == null ? '-' : '${v.toStringAsFixed(0)} dBm';

  static String cellTitle(ScannedCell c) => [
    if (c.pci != null) 'PCI ${c.pci}',
    if (c.cellId != null) 'Cell ${c.cellId}',
    if (c.siteId != null)
      '${c.rat.wireValue == 'NR' ? 'gNB' : 'eNB'} ${c.siteId}',
    if (c.cellId == null) 'not identified',
  ].join(' · ');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(cellLayerProvider(sessionId));
    return Scaffold(
      appBar: AppBar(
        title: Text(sessionId == null ? 'Cell scan: all drives' : 'Cell scan'),
      ),
      body: switch (layer) {
        AsyncData(:final value) when value.cells.isEmpty => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No cells yet. Record a drive or use the signal monitor with '
              'recording on.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncData(:final value) => _CellScanView(layer: value),
        AsyncError(:final error) => Center(
          child: Text('Could not load cells: $error'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _CellScanView extends StatelessWidget {
  const _CellScanView({required this.layer});

  final CellLayer layer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = <String, List<ScannedCell>>{};
    for (final c in layer.cells) {
      (groups[c.bandLabel] ??= []).add(c);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (layer.sites.isNotEmpty) ...[
          TrackMap(points: const [], layer: layer, height: 260),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Site positions are estimated from your drives, not surveyed. '
              'Circles show the uncertainty; short lines the sector '
              'directions. Accuracy improves with more drives around a site.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
        Text(
          '${layer.cells.length} cells · ${layer.sites.length} estimated sites',
          style: theme.textTheme.titleMedium,
        ),
        for (final e in groups.entries)
          Card(
            child: ExpansionTile(
              initiallyExpanded: groups.length <= 3,
              title: Text(e.key),
              subtitle: Text('${e.value.length} cells'),
              children: [
                for (final c in e.value)
                  ListTile(
                    dense: true,
                    title: Text(CellScanScreen.cellTitle(c)),
                    subtitle: Text(
                      'best ${CellScanScreen.dbm(c.bestLevelDbm)} · mean '
                      '${CellScanScreen.dbm(c.meanLevelDbm)} · serving '
                      '${c.servingCount} · neighbour ${c.neighbourCount}\n'
                      '${formatLocalDateTime(c.firstSeen)} – '
                      '${formatLocalDateTime(c.lastSeen)}',
                    ),
                    isThreeLine: true,
                    trailing: layer.site(c.siteKey) == null
                        ? null
                        : const Icon(
                            Icons.cell_tower,
                            semanticLabel: 'Site estimated',
                          ),
                  ),
              ],
            ),
          ),
        if (layer.sites.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Estimated sites', style: theme.textTheme.titleMedium),
          for (final s in layer.sites)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cell_tower),
                title: Text(s.label),
                subtitle: Text(
                  '${s.method.label} · ±${s.uncertaintyM.round()} m · '
                  '${s.samples} samples\n'
                  '${s.lat.toStringAsFixed(5)}, ${s.lon.toStringAsFixed(5)}\n'
                  '${s.cells.map((c) => c.azimuthDeg == null ? c.label : '${c.label} → ${c.azimuthDeg!.round()}°').join('; ')}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ],
    );
  }
}
