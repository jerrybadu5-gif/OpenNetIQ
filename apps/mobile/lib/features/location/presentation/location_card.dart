import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/widgets/metric_tile.dart';

/// GNSS card (issue #14): position, accuracy, speed, satellites and fix
/// quality, or the reason there is no fix.
class LocationCard extends StatelessWidget {
  const LocationCard({required this.status, super.key});

  final AsyncValue<LocationStatus> status;

  static const Color goodColor = Color(0xFF1B8A3A);
  static const Color poorColor = Color(0xFFC98A00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (status) {
          AsyncData(:final value) => _content(context, value),
          AsyncError(:final error) => _message(
            theme,
            Icons.location_disabled,
            'GPS unavailable',
            error is MeasurementException ? error.message : '$error',
          ),
          _ => _message(theme, Icons.gps_not_fixed, 'GPS', 'Starting GPS...'),
        },
      ),
    );
  }

  Widget _content(BuildContext context, LocationStatus s) {
    final theme = Theme.of(context);
    if (!s.providerEnabled) {
      return _message(
        theme,
        Icons.location_off,
        'Location is off',
        'Turn on Location in Android quick settings to geotag measurements.',
      );
    }
    final satellites = _satellites(s);
    final fix = s.fix;
    if (fix == null) {
      return _message(
        theme,
        Icons.gps_not_fixed,
        'Searching for GPS fix',
        satellites == null
            ? 'Go outdoors or near a window.'
            : 'Satellites used / visible: $satellites',
      );
    }
    final qualityColor = s.quality == GpsQuality.good ? goodColor : poorColor;
    final metrics = <(String, String)>[
      ('Accuracy', _meters(fix.hAccuracyM, prefix: '±')),
      ('Altitude', _meters(fix.altitudeM)),
      ('Speed', _number(fix.speedKmh, 'km/h')),
      ('Bearing', _number(fix.bearingDeg, '°', space: false)),
      ('Satellites', satellites ?? '-'),
      (
        'Fix age',
        s.fixAgeMs == null
            ? '-'
            : '${(s.fixAgeMs! / 1000).toStringAsFixed(1)} s',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.gps_fixed, color: qualityColor),
            const SizedBox(width: 8),
            Text('GPS', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              s.quality.label,
              style: theme.textTheme.labelLarge?.copyWith(color: qualityColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          '${fix.lat.toStringAsFixed(6)}, ${fix.lon.toStringAsFixed(6)}',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (label, value) in metrics)
              MetricTile(label: label, value: value),
          ],
        ),
        if (fix.isMock)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Mock location detected: samples will be flagged '
                    'MOCK_LOCATION and excluded from statistics.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _message(
    ThemeData theme,
    IconData icon,
    String title,
    String message,
  ) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              Text(message),
            ],
          ),
        ),
      ],
    );
  }

  static String? _satellites(LocationStatus s) => s.satellitesVisible == null
      ? null
      : '${s.satellitesUsed ?? 0} / ${s.satellitesVisible}';

  static String _meters(double? value, {String prefix = ''}) =>
      value == null ? '-' : '$prefix${value.toStringAsFixed(0)} m';

  static String _number(double? value, String unit, {bool space = true}) =>
      value == null
      ? '-'
      : '${value.toStringAsFixed(0)}${space ? ' ' : ''}$unit';
}
