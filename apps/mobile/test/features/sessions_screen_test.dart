import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/measurement_session.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';
import 'package:opennetiq_mobile/features/sessions/presentation/sessions_screen.dart';

import '../fixtures/session_fixtures.dart';

Future<void> pumpSessions(
  WidgetTester tester,
  FakeSessionRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SessionsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists sessions with samples, distance and duration', (
    tester,
  ) async {
    await pumpSessions(tester, FakeSessionRepository([session()]));

    expect(find.text('Session 2026-10-08 09:05'), findsOneWidget);
    expect(
      find.text('Drive - Completed - 120 samples - 2.35 km - 2:05'),
      findsOneWidget,
    );
  });

  testWidgets('empty state', (tester) async {
    await pumpSessions(tester, FakeSessionRepository([]));

    expect(find.textContaining('No sessions yet'), findsOneWidget);
    expect(find.byTooltip('Delete all sessions'), findsNothing);
  });

  testWidgets('delete asks for confirmation', (tester) async {
    final repo = FakeSessionRepository([
      session(),
      session(id: 's2', name: 'Second', distanceM: null),
    ]);
    await pumpSessions(tester, repo);

    await tester.tap(find.byTooltip('Delete session').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byTooltip('Delete session').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('120 samples are removed'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['s1']);
    expect(find.text('Session 2026-10-08 09:05'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('delete all clears the list', (tester) async {
    final repo = FakeSessionRepository([session(), session(id: 's2')]);
    await pumpSessions(tester, repo);

    await tester.tap(find.byTooltip('Delete all sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['s1', 's2']);
    expect(find.textContaining('No sessions yet'), findsOneWidget);
  });

  testWidgets('recording sessions show their status', (tester) async {
    await pumpSessions(
      tester,
      FakeSessionRepository([
        session(status: SessionStatus.recording, distanceM: 0),
      ]),
    );

    expect(find.text('Drive - Recording - 120 samples'), findsOneWidget);
    expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);
  });

  test('duration formatting', () {
    expect(SessionTile.formatDuration(const Duration(seconds: 65)), '1:05');
    expect(
      SessionTile.formatDuration(
        const Duration(hours: 1, minutes: 2, seconds: 3),
      ),
      '1:02:03',
    );
  });
}
