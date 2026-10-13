import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:opennetiq_mobile/core/theme/chart_legend.dart';
import 'package:opennetiq_mobile/domain/entities/speed_test.dart';

/// Throughput over time per direction (1 s rate, every 100 ms), issue #22.
/// Download and upload share the x axis (seconds since phase start).
class ThroughputChart extends StatelessWidget {
  const ThroughputChart({
    required this.download,
    required this.upload,
    super.key,
  });

  final List<SpeedTestProgress> download;
  final List<SpeedTestProgress> upload;

  static List<FlSpot> spots(List<SpeedTestProgress> curve) => [
    for (final p in curve) FlSpot(p.elapsed.inMilliseconds / 1000, p.mbps),
  ];

  /// Upper y bound: 10 % head-room, at least 1 Mbps.
  static double maxY(List<SpeedTestProgress> a, List<SpeedTestProgress> b) {
    var peak = 0.0;
    for (final p in [...a, ...b]) {
      peak = math.max(peak, p.mbps);
    }
    return math.max(1, peak * 1.1);
  }

  @override
  Widget build(BuildContext context) {
    if (download.isEmpty && upload.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final downColor = scheme.primary;
    final upColor = scheme.tertiary;
    LineChartBarData line(List<SpeedTestProgress> curve, Color color) =>
        LineChartBarData(
          spots: spots(curve),
          color: color,
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
        );
    var maxX = 1.0;
    for (final p in [...download, ...upload]) {
      maxX = math.max(maxX, p.elapsed.inMilliseconds / 1000);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Wrap(
                spacing: 16,
                children: [
                  if (download.isNotEmpty)
                    ChartLegend(color: downColor, label: 'Download'),
                  if (upload.isNotEmpty)
                    ChartLegend(color: upColor, label: 'Upload'),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY(download, upload),
                  lineBarsData: [
                    if (download.isNotEmpty) line(download, downColor),
                    if (upload.isNotEmpty) line(upload, upColor),
                  ],
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('Mbps'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('seconds'),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
