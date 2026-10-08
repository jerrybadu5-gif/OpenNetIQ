import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/features/map/presentation/track_map.dart';

import '../fixtures/map_fixtures.dart';
import '../fixtures/track_fixtures.dart';

Widget host(List<SamplePoint> points, {bool follow = false}) => ProviderScope(
  overrides: [noTiles],
  child: MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          TrackMap(points: points, follow: follow),
          const TrackLegend(),
        ],
      ),
    ),
  ),
);

List<Polyline<Object>> polylines(WidgetTester tester) => tester
    .widget<PolylineLayer<Object>>(find.byType(PolylineLayer<Object>))
    .polylines;

void main() {
  testWidgets('placeholder until the first fix', (tester) async {
    await tester.pumpWidget(host([pt(0, positioned: false)]));
    await tester.pump();
    expect(find.text('Waiting for a GPS fix'), findsOneWidget);
    expect(polylines(tester), isEmpty);
    expect(find.byType(CircleLayer<Object>), findsNothing);
  });

  testWidgets('one coloured polyline per signal-class run', (tester) async {
    await tester.pumpWidget(
      host([pt(0), pt(1), pt(2, level: -105), pt(3, level: -105)]),
    );
    await tester.pump();

    final lines = polylines(tester);
    expect(lines, hasLength(2));
    expect(lines.first.color, trackColor(pt(0).quality));
    expect(lines.last.color, trackColor(pt(2, level: -105).quality));
    expect(find.byType(CircleLayer<Object>), findsOneWidget);
    expect(find.text('Waiting for a GPS fix'), findsNothing);
  });

  testWidgets('legend pairs every colour with a label', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pump();
    for (final label in [
      'Excellent',
      'Good',
      'Fair',
      'Poor',
      'No service',
      'No level',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('renders a 10 k point track', (tester) async {
    final points = [
      for (var i = 0; i < 10000; i++) pt(i, level: i % 1000 < 500 ? -85 : -95),
    ];
    await tester.pumpWidget(host(points));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(polylines(tester), hasLength(20));
  });

  testWidgets('follow mode keeps up with new points', (tester) async {
    await tester.pumpWidget(host([pt(0)], follow: true));
    await tester.pump();
    await tester.pumpWidget(host([pt(0), pt(1), pt(2)], follow: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(polylines(tester), hasLength(1));
  });

  test('unknown level has its own colour', () {
    expect(trackColor(null), unknownLevelColor);
  });
}
