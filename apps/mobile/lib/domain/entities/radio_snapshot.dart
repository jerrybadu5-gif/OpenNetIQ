import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

/// Network context plus all visible cells at one sampling tick.
class RadioSnapshot {
  const RadioSnapshot({
    required this.timestamp,
    required this.networkType,
    required this.cells,
    this.radioTimestamp,
    this.operatorName,
    this.mcc,
    this.mnc,
    this.simOperator,
    this.dataState,
    this.isRoaming,
    this.qualityFlag,
  });

  static const String flagStale = 'STALE';
  static const String flagNoPhoneState = 'NO_PHONE_STATE';
  static const String flagCached = 'CACHED';

  final DateTime timestamp;
  final DateTime? radioTimestamp;
  final String? operatorName;
  final String? mcc;
  final String? mnc;
  final String? simOperator;
  final NetworkType networkType;
  final String? dataState;
  final bool? isRoaming;
  final String? qualityFlag;
  final List<CellObservation> cells;

  List<CellObservation> get servingCells =>
      cells.where((c) => c.isServing).toList(growable: false);

  List<CellObservation> get neighbourCells =>
      cells.where((c) => !c.isServing).toList(growable: false);

  /// Primary serving cell. In 5G NSA this is the LTE anchor.
  CellObservation? get primaryCell {
    final serving = servingCells;
    if (serving.isEmpty) return null;
    if (networkType.isNsa) {
      for (final c in serving) {
        if (c.rat == Rat.lte) return c;
      }
    }
    return serving.first;
  }

  /// NR secondary leg in 5G NSA. Many modems report it as unregistered,
  /// so the first NR cell is used when no serving NR cell exists.
  CellObservation? get nrLeg {
    if (!networkType.isNsa) return null;
    final primary = primaryCell;
    for (final c in servingCells) {
      if (c.rat == Rat.nr && !identical(c, primary)) return c;
    }
    for (final c in cells) {
      if (c.rat == Rat.nr) return c;
    }
    return null;
  }

  /// Neighbours excluding a reported NR leg.
  List<CellObservation> get neighbourCellsExcludingNrLeg {
    final leg = nrLeg;
    return neighbourCells
        .where((c) => !identical(c, leg))
        .toList(growable: false);
  }

  String? get plmn => (mcc != null && mnc != null) ? '$mcc-$mnc' : null;

  bool hasFlag(String flag) => qualityFlag?.split('|').contains(flag) ?? false;

  bool get isStale => hasFlag(flagStale);
}
