import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';

class NetworkHeader extends StatelessWidget {
  const NetworkHeader({
    required this.snapshot,
    required this.permissions,
    super.key,
  });

  final RadioSnapshot snapshot;
  final RadioPermissions permissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (snapshot.plmn != null) 'PLMN ${snapshot.plmn}',
      if (snapshot.isRoaming ?? false) 'Roaming',
      if (snapshot.dataState != null)
        'Data ${snapshot.dataState!.toLowerCase()}',
    ];
    final warnings = [
      if (snapshot.isStale) 'Cell data is older than 2 s (stale).',
      if (snapshot.hasFlag(RadioSnapshot.flagCached))
        'Fresh cell scan failed; showing cached cell info.',
      if (!permissions.canDetectNsa)
        '5G NSA detection needs phone-state access on Android 11 or newer.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.operatorName ?? 'Unknown operator',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Chip(
                  label: Text(
                    '${snapshot.networkType.label} '
                    '(${snapshot.networkType.generation.label})',
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) Text(details.join(' - ')),
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(warning, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
