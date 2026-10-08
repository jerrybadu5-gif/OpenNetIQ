import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/repositories/session_repository.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/session_detail_screen.dart';

import '../fixtures/map_fixtures.dart';
import '../fixtures/session_fixtures.dart';
import '../fixtures/track_fixtures.dart';

class FakeSampleRepository implements SampleRepository {
  FakeSampleRepository(this.points);

  final List<SamplePoint> points;

  @override
  Future<List<SamplePoint>> loadSamplePoints(String sessionId) async => points;

  @override
  Future<List<DateTime>> sampleTimestamps(String sessionId) async => [
    for (final p in points) p.timestamp,
  ];

  @override
  Future<int> countSamples(String sessionId) async => points.length;

  @override
  Future<String> recordSample({
    required String sessionId,
    required RadioSnapshot radio,
    LocationStatus? location,
  }) => throw UnimplementedError();
}

void main() {
  late FakeSessionRepository sessions;

  Future<void> pumpDetail(
    WidgetTester tester, {
    MeasurementSession? stored,
    List<SamplePoint>? points,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    sessions = FakeSessionRepository([?stored]);
    final router = GoRouter(
      initialLocation: '/sessions/s1',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('Sessions list'),
          routes: [
            GoRoute(
              path: 'sessions/:id',
              builder: (context, state) =>
                  SessionDetailScreen(sessionId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noTiles,
          sessionRepositoryProvider.overrideWithValue(sessions),
          sampleRepositoryProvider.overrideWithValue(
            FakeSampleRepository(points ?? const []),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  final track = [
    pt(0, level: -80),
    pt(1, level: -90),
    pt(2, level: -100),
    pt(5, level: -110),
    pt(6, level: null, positioned: false, networkType: NetworkType.nrNsa),
  ];

  testWidgets('shows map, summary, completeness and statistics', (
    tester,
  ) async {
    await pumpDetail(tester, stored: session(sampleCount: 5), points: track);

    expect(find.text('Session 2026-10-08 09:05'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('2.35 km'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    // 2 s -> 5 s misses 2 ticks: 5 recorded, 7 expected.
    expect(find.text('2 (28.57 %)'), findsOneWidget);
    // With GPS position and LTE network share.
    expect(find.text('80.0 %'), findsNWidgets(2));
    expect(find.text(SessionDetailScreen.ratMetric(Rat.lte)), findsOneWidget);
    expect(find.text('-110 / -95 / -80 (4)'), findsOneWidget);
    expect(find.text('LTE'), findsOneWidget);
    expect(find.text('5G NSA'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(6));
  });

  testWidgets('deletes after confirmation and returns', (tester) async {
    await pumpDetail(tester, stored: session(), points: track);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sessions.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(sessions.deleted, ['s1']);
    expect(find.text('Sessions list'), findsOneWidget);
  });

  testWidgets('an active session cannot be deleted here', (tester) async {
    await pumpDetail(
      tester,
      stored: session(status: SessionStatus.recording),
      points: track,
    );
    expect(find.text('Recording in progress'), findsOneWidget);
    expect(find.byTooltip('Delete session'), findsNothing);
  });

  testWidgets('missing session and empty track', (tester) async {
    await pumpDetail(tester);
    expect(find.text('Session not found.'), findsOneWidget);
  });

  testWidgets('session without samples', (tester) async {
    await pumpDetail(tester, stored: session(sampleCount: 0, distanceM: null));
    expect(find.text('No serving cell data'), findsOneWidget);
    expect(find.text('Waiting for a GPS fix'), findsOneWidget);
  });
}
