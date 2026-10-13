import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/core/theme/chart_legend.dart';

/// RTT per probe (issue #22). Lost probes break the line and are marked
/// on the x axis.
class RttChart extends StatelessWidget {
  const RttChart({required this.rttsMs, super.key});

  /// One entry per probe in sequence order; null = lost/timed out.
  final List<double?> rttsMs;

  static List<FlSpot> spots(List<double?> rtts) => [
    for (var i = 0; i < rtts.length; i++)
      rtts[i] == null ? FlSpot.nullSpot : FlSpot(i + 1.0, rtts[i]!),
  ];

  static List<FlSpot> lost(List<double?> rtts) => [
    for (var i = 0; i < rtts.length; i++)
      if (rtts[i] == null) FlSpot(i + 1.0, 0),
  ];

  @override
  Widget build(BuildContext context) {
    if (rttsMs.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    var peak = 0.0;
    for (final r in rttsMs) {
      if (r != null) peak = math.max(peak, r);
    }
    final lostSpots = lost(rttsMs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            ChartLegend(color: scheme.primary, label: 'RTT'),
            if (lostSpots.isNotEmpty)
              ChartLegend(color: scheme.error, label: 'Lost'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minX: 1,
              maxX: math.max(2, rttsMs.length).toDouble(),
              minY: 0,
              maxY: math.max(1, peak * 1.15),
              lineBarsData: [
                if (lostSpots.length < rttsMs.length)
                  LineChartBarData(
                    spots: spots(rttsMs),
                    color: scheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  ),
                if (lostSpots.isNotEmpty)
                  LineChartBarData(
                    spots: lostSpots,
                    color: scheme.error,
                    barWidth: 0,
                    dotData: const FlDotData(show: true),
                  ),
              ],
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                leftTitles: AxisTitles(
                  axisNameWidget: Text('ms'),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: Text('probe'),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
