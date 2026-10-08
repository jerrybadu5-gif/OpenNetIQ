import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/features/location/presentation/location_card.dart';

import '../fixtures/location_fixtures.dart';

Future<void> pumpCard(WidgetTester tester, AsyncValue<LocationStatus> status) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LocationCard(status: status)),
      ),
    );

void main() {
  testWidgets('shows position, accuracy, speed and satellites', (tester) async {
    await pumpCard(tester, AsyncData(locationStatus()));

    expect(find.text('-9.443800, 147.180300'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('±4 m'), findsOneWidget);
    expect(find.text('35 m'), findsOneWidget);
    expect(find.text('50 km/h'), findsOneWidget);
    expect(find.text('272°'), findsOneWidget);
    expect(find.text('9 / 14'), findsOneWidget);
    expect(find.text('0.8 s'), findsOneWidget);
    expect(find.textContaining('Mock location'), findsNothing);
  });

  testWidgets('poor fix and mock location warning', (tester) async {
    await pumpCard(
      tester,
      AsyncData(locationStatus(quality: 'POOR', mock: true)),
    );

    expect(find.text('Poor'), findsOneWidget);
    expect(find.textContaining('MOCK_LOCATION'), findsOneWidget);
  });

  testWidgets('searching for a fix shows satellites', (tester) async {
    await pumpCard(
      tester,
      AsyncData(locationStatus(quality: 'NONE', withFix: false)),
    );

    expect(find.text('Searching for GPS fix'), findsOneWidget);
    expect(find.text('Satellites used / visible: 9 / 14'), findsOneWidget);
  });

  testWidgets('searching without satellite data gives advice', (tester) async {
    await pumpCard(
      tester,
      AsyncData(
        locationStatus(
          quality: 'NONE',
          withFix: false,
          satellitesVisible: null,
        ),
      ),
    );

    expect(find.text('Go outdoors or near a window.'), findsOneWidget);
  });

  testWidgets('location switched off', (tester) async {
    await pumpCard(
      tester,
      AsyncData(
        locationStatus(providerEnabled: false, quality: 'NONE', withFix: false),
      ),
    );

    expect(find.text('Location is off'), findsOneWidget);
  });

  testWidgets('errors and loading', (tester) async {
    await pumpCard(
      tester,
      const AsyncError<LocationStatus>(
        LocationException('NO_GNSS', 'This device has no GPS receiver.'),
        StackTrace.empty,
      ),
    );
    expect(find.text('GPS unavailable'), findsOneWidget);
    expect(find.text('This device has no GPS receiver.'), findsOneWidget);

    await pumpCard(
      tester,
      AsyncError<LocationStatus>(StateError('boom'), StackTrace.empty),
    );
    expect(find.textContaining('boom'), findsOneWidget);

    await pumpCard(tester, const AsyncLoading<LocationStatus>());
    expect(find.text('Starting GPS...'), findsOneWidget);
  });
}
