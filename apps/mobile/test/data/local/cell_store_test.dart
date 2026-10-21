import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/data/local/drift_cell_store.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/features/cells/application/cell_layer_providers.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

import '../../fixtures/db_fixtures.dart';
import '../../fixtures/export_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = memoryDatabase();
    await seedExportSession(db);
  });
  tearDown(() => db.close());

  test('sightings carry sample position, level and identity', () async {
    final store = DriftCellStore(db);
    final list = await store.loadSightings(sessionId: exportSessionId);
    expect(list, hasLength(4));
    // Time order: m1 cells first.
    expect(list.first.measurementId, 'm1');
    final nr = list.firstWhere((s) => s.rat == Rat.nr);
    expect(nr.gnbId, 777);
    expect(nr.levelDbm, -95);
    expect(nr.lat, -9.45);
    expect(nr.goodFix, isTrue);
    final neighbour = list.firstWhere((s) => !s.isServing);
    expect(neighbour.pci, 102);
    expect(await store.loadSightings(sessionId: 'nope'), isEmpty);
    expect(await store.loadSightings(), hasLength(4));
  });

  test('provider: session cells, sites from every drive', () async {
    await db.customStatement(
      "UPDATE cell_observations SET cell_id = 21505, mcc = '537', mnc = '03' "
      "WHERE rat = 'LTE' AND is_serving = 1",
    );
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    final own = await c.read(cellLayerProvider(exportSessionId).future);
    final all = await c.read(cellLayerProvider(null).future);
    expect(own.cells.length, all.cells.length);
    expect(own.servingSiteByMeasurement['m1'], 'LTE:537-03:enb12345');
    expect(own.sites.map((s) => s.key), all.sites.map((s) => s.key));
    final none = await c.read(cellLayerProvider('nope').future);
    expect(none.cells, isEmpty);
    expect(none.sites, isEmpty);
  });

  test('no-fix and mock samples keep the cell but lose the position', () async {
    await db.customStatement(
      "UPDATE samples SET quality_flag = 'MOCK_LOCATION' WHERE measurement_id = 'm2'",
    );
    final list = await DriftCellStore(db).loadSightings();
    final m2 = list.firstWhere((s) => s.measurementId == 'm2');
    expect(m2.hasFix, isFalse);
    expect(m2.levelDbm, -112);
  });
}
