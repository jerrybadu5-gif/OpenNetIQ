import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/features/location/application/location_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';
import 'package:opennetiq_mobile/features/signal_monitor/presentation/signal_monitor_screen.dart';

import '../fixtures/location_fixtures.dart';
import '../fixtures/radio_fixtures.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  FakeRadioRepository repo, {
  FakeLocationRepository? location,
}) async {
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        radioRepositoryProvider.overrideWithValue(repo),
        locationRepositoryProvider.overrideWithValue(
          location ?? FakeLocationRepository(statuses: [locationStatus()]),
        ),
      ],
      child: const MaterialApp(home: SignalMonitorScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for permission, then shows live LTE data', (tester) async {
    final repo = FakeRadioRepository(
      permissions: deniedPermissions,
      afterRequest: grantedPermissions,
      snapshots: [snapshot()],
    );
    await pumpScreen(tester, repo);

    expect(find.text('Grant access'), findsOneWidget);
    expect(repo.watchCount, 0, reason: 'no radio access before permission');

    await tester.tap(find.text('Grant access'));
    await tester.pumpAndSettle();

    expect(repo.requestCount, 1);
    expect(find.text('Digicel PNG'), findsOneWidget);
    expect(find.text('LTE (4G)'), findsOneWidget);
    expect(find.text('Serving cell'), findsOneWidget);
    expect(find.text('-95 dBm'), findsOneWidget);
    expect(find.text('RSRP - Fair'), findsOneWidget);
    expect(find.text('LTE B28'), findsOneWidget);
    expect(find.text('107183'), findsOneWidget); // eNB ID
    expect(find.text('Neighbour cells (1)'), findsOneWidget);
    expect(find.text('RSRP -108 dBm'), findsOneWidget);
    expect(find.text('Collecting samples...'), findsOneWidget);
    expect(find.text('-9.443800, 147.180300'), findsOneWidget);
  });

  testWidgets('GPS starts only with location permission', (tester) async {
    final location = FakeLocationRepository(statuses: [locationStatus()]);
    final repo = FakeRadioRepository(
      permissions: deniedPermissions,
      afterRequest: grantedPermissions,
      snapshots: [snapshot()],
    );
    await pumpScreen(tester, repo, location: location);
    expect(location.watchCount, 0);

    await tester.tap(find.text('Grant access'));
    await tester.pumpAndSettle();
    expect(location.watchCount, 1);
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('shows LTE anchor, NR leg and the trend chart in 5G NSA', (
    tester,
  ) async {
    RadioSnapshot nsa() => snapshot(
      networkType: 'NR_NSA',
      cells: [lteCell(), nrCell(), lteCell(serving: false, pci: 7)],
    );
    final repo = FakeRadioRepository(
      permissions: grantedPermissions,
      snapshots: [nsa(), nsa()],
    );
    await pumpScreen(tester, repo);

    expect(find.text('5G NSA (5G)'), findsOneWidget);
    expect(find.text('LTE anchor'), findsOneWidget);
    expect(find.text('5G NR leg'), findsOneWidget);
    expect(find.text('NR n78'), findsOneWidget);
    expect(find.text('11259375'), findsOneWidget); // gNB ID
    expect(find.text('Neighbour cells (1)'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('warns about stale data and missing NSA detection', (
    tester,
  ) async {
    final repo = FakeRadioRepository(
      permissions: const RadioPermissions(
        location: true,
        phoneState: false,
        hasTelephony: true,
        apiLevel: 34,
      ),
      snapshots: [snapshot(qualityFlag: 'CACHED|STALE')],
    );
    await pumpScreen(tester, repo);

    expect(find.textContaining('stale'), findsOneWidget);
    expect(find.textContaining('cached cell info'), findsOneWidget);
    expect(find.textContaining('5G NSA detection needs'), findsOneWidget);
  });

  testWidgets('shows no-serving-cell and empty-neighbour states', (
    tester,
  ) async {
    final repo = FakeRadioRepository(
      permissions: grantedPermissions,
      snapshots: [snapshot(cells: [])],
    );
    await pumpScreen(tester, repo);

    expect(find.text('No serving cell'), findsOneWidget);
    expect(find.text('No neighbour cells reported.'), findsOneWidget);
  });

  testWidgets('explains devices without a cellular radio', (tester) async {
    final repo = FakeRadioRepository(
      permissions: const RadioPermissions(
        location: true,
        phoneState: true,
        hasTelephony: false,
      ),
    );
    await pumpScreen(tester, repo);

    expect(find.text('No cellular radio'), findsOneWidget);
    expect(repo.watchCount, 0);
  });

  testWidgets('shows radio errors', (tester) async {
    final repo = FakeRadioRepository(
      permissions: grantedPermissions,
      streamError: const RadioException(
        RadioException.permissionDenied,
        'Precise location permission is required.',
      ),
    );
    await pumpScreen(tester, repo);

    expect(find.text('Permission required'), findsOneWidget);
    expect(
      find.text('Precise location permission is required.'),
      findsOneWidget,
    );
  });

  testWidgets('home screen opens the signal monitor', (tester) async {
    final repo = FakeRadioRepository(
      permissions: grantedPermissions,
      snapshots: [snapshot()],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          radioRepositoryProvider.overrideWithValue(repo),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(statuses: [locationStatus()]),
          ),
        ],
        child: const OpenNetIqApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Signal monitor'));
    await tester.pumpAndSettle();

    expect(find.byType(SignalMonitorScreen), findsOneWidget);
    expect(find.text('Digicel PNG'), findsOneWidget);
  });
}
