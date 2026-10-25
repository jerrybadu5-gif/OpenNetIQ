import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/local/drift_cell_store.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/services/cell_layer_builder.dart';
import 'package:opennetiq_mobile/features/recording/application/storage_providers.dart';

final cellStoreProvider = Provider<DriftCellStore>(
  (ref) => DriftCellStore(ref.watch(appDatabaseProvider)),
);

/// Cell scan + estimated sites for one session, or all sessions (null).
/// Sites always use every session, so positions improve with each drive.
final cellLayerProvider = FutureProvider.autoDispose.family<CellLayer, String?>(
  (ref, sessionId) async {
    final store = ref.watch(cellStoreProvider);
    final all = CellLayerBuilder.build(await store.loadSightings());
    if (sessionId == null) return all;
    final own = CellLayerBuilder.build(
      await store.loadSightings(sessionId: sessionId),
    );
    final keys = {for (final c in own.cells) c.siteKey};
    return CellLayer(
      cells: own.cells,
      sites: [
        for (final s in all.sites)
          if (keys.contains(s.key)) s,
      ],
      servingSiteByMeasurement: own.servingSiteByMeasurement,
    );
  },
);
