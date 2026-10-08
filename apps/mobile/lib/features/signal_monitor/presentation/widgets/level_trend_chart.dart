import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_history.dart';

/// One-minute trend of the primary cell's level (dBm). Gaps = unavailable.
class LevelTrendChart extends StatelessWidget {
  const LevelTrendChart({required this.points, super.key});

  final List<SignalPoint> points;

  static const double minDbm = -140;
  static const double maxDbm = -40;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = points.where((p) => p.levelDbm != null).length >= 2;
    final spots = [
      for (var i = 0; i < points.length; i++)
        points[i].levelDbm == null
            ? FlSpot.nullSpot
            : FlSpot(
                i.toDouble(),
                points[i].levelDbm!.clamp(minDbm, maxDbm).toDouble(),
              ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Level trend (last ${signalHistoryCapacity}s)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            SizedBox(
              height: 160,
              child: hasData
                  ? LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (signalHistoryCapacity - 1).toDouble(),
                        minY: minDbm,
                        maxY: maxDbm,
                        lineTouchData: const LineTouchData(enabled: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(sideTitles: SideTitles()),
                          rightTitles: AxisTitles(sideTitles: SideTitles()),
                          bottomTitles: AxisTitles(sideTitles: SideTitles()),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 20,
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            color: theme.colorScheme.primary,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    )
                  : const Center(child: Text('Collecting samples...')),
            ),
          ],
        ),
      ),
    );
  }
}
