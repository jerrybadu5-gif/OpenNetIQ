import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/features/cells/application/cell_layer_providers.dart';
import 'package:opennetiq_mobile/features/cells/presentation/cell_scan_screen.dart';
import 'package:opennetiq_mobile/features/map/presentation/track_map.dart';

import '../fixtures/cell_layer_fixtures.dart';
import '../fixtures/map_fixtures.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    Future<CellLayer> Function() layer, {
    String? sessionId,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noTiles,
          cellLayerProvider.overrideWith((ref, id) => layer()),
        ],
        child: MaterialApp(home: CellScanScreen(sessionId: sessionId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups cells by band and lists estimated sites', (tester) async {
    await pumpScreen(tester, () async => testLayer());
    expect(find.text('Cell scan: all drives'), findsOneWidget);
    expect(find.text('2 cells · 1 estimated sites'), findsOneWidget);
    expect(find.text('LTE · B1 · EARFCN 500'), findsOneWidget);
    expect(find.text('LTE · B3 · EARFCN 1300'), findsOneWidget);
    expect(find.text('PCI 422 · Cell 77 · eNB 84'), findsOneWidget);
    expect(find.text('PCI 99 · not identified'), findsOneWidget);
    expect(find.textContaining('best -71 dBm · mean -88 dBm'), findsOneWidget);
    expect(find.text('eNB 84'), findsOneWidget);
    expect(find.textContaining('Timing advance · ±120 m'), findsOneWidget);
    expect(find.textContaining('PCI 422 · cell 77 → 45°'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('empty and error states', (tester) async {
    await pumpScreen(tester, () async => CellLayer.empty, sessionId: 's1');
    expect(find.text('Cell scan'), findsOneWidget);
    expect(find.textContaining('No cells yet'), findsOneWidget);
    await pumpScreen(tester, () async => throw StateError('db'));
    expect(find.textContaining('Could not load cells'), findsOneWidget);
  });

  testWidgets('map: tap a sample to see its serving site; serving lines', (
    tester,
  ) async {
    final points = [
      for (var i = 0; i < 5; i++)
        SamplePoint(
          timestamp: DateTime.utc(2026, 10, 21, 1, 0, i),
          lat: -9.44 + i * 1e-4,
          lon: 147.18,
          rat: Rat.lte,
          levelDbm: -85,
          measurementId: 'm$i',
        ),
    ];
    final layer = testLayer(
      serving: {for (var i = 0; i < 5; i++) 'm$i': testSite.key},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noTiles],
        child: MaterialApp(
          home: Scaffold(
            body: TrackMap(points: points, layer: layer),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkerLayer), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(-9.44, 147.18),
    );
    await tester.pump();
    expect(find.text('Serving: eNB 84'), findsOneWidget);
    expect(find.textContaining('m to estimated site'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(find.text('Serving: eNB 84'), findsNothing);

    // Far from any sample: nothing selected.
    map.options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(-9.5, 147.3),
    );
    await tester.pump();
    expect(find.textContaining('Serving:'), findsNothing);

    int lineCount() => tester
        .widgetList<PolylineLayer<Object>>(find.byType(PolylineLayer<Object>))
        .last
        .polylines
        .length;
    final before = lineCount();
    await tester.tap(find.text('Serving lines'));
    await tester.pump();
    expect(lineCount(), before + 5);
  });

  testWidgets('a sample without a located serving site says so', (
    tester,
  ) async {
    final p = SamplePoint(
      timestamp: DateTime.utc(2026),
      lat: -9.44,
      lon: 147.18,
      measurementId: 'x',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noTiles],
        child: MaterialApp(
          home: Scaffold(
            body: TrackMap(points: [p], layer: testLayer()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<FlutterMap>(find.byType(FlutterMap)).options.onTap!(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(-9.44, 147.18),
    );
    await tester.pump();
    expect(find.text('Serving cell not located'), findsOneWidget);
  });
}
