import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/domain/repositories/radio_repository.dart';
import 'package:opennetiq_mobile/data/mappers/radio_snapshot_mapper.dart';

Map<String, Object?> lteCell({
  bool serving = true,
  int? rsrp = -95,
  int pci = 301,
  String? qualityFlag,
}) => <String, Object?>{
  'is_serving': serving,
  'rat': 'LTE',
  'mcc': '537',
  'mnc': '03',
  'lac_tac': 1201,
  'cell_id': 27439044,
  'enb_id': 107183,
  'gnb_id': null,
  'local_cell_id': 196,
  'pci_psc_bsic': pci,
  'arfcn': 9410,
  'band': 'B28',
  'bandwidth_khz': 10000,
  'rssi_dbm': -65,
  'rscp_dbm': null,
  'ecno_db': null,
  'rsrp_dbm': rsrp,
  'rsrq_db': -11,
  'sinr_db': 12,
  'cqi': 9,
  'timing_advance': 4,
  'csi_rsrp_dbm': null,
  'csi_rsrq_db': null,
  'csi_sinr_db': null,
  'quality_flag': qualityFlag,
};

Map<String, Object?> nrCell({bool serving = false, int ssRsrp = -101}) =>
    <String, Object?>{
      'is_serving': serving,
      'rat': 'NR',
      'mcc': '537',
      'mnc': '03',
      'lac_tac': 70000,
      'cell_id': 46118400291,
      'gnb_id': 11259375,
      'pci_psc_bsic': 900,
      'arfcn': 640000,
      'band': 'n78',
      'rsrp_dbm': ssRsrp,
      'rsrq_db': -12,
      'sinr_db': 8,
      'csi_rsrp_dbm': -99,
    };

Map<String, Object?> snapshotPayload({
  String networkType = 'LTE',
  List<Map<String, Object?>>? cells,
  String? qualityFlag,
  String timestamp = '2026-10-08T01:00:00.000Z',
}) => <String, Object?>{
  'timestamp': timestamp,
  'radio_timestamp': '2026-10-08T00:59:59.800Z',
  'operator': 'Digicel PNG',
  'mcc': '537',
  'mnc': '03',
  'sim_operator': 'Digicel',
  'network_type': networkType,
  'data_state': 'CONNECTED',
  'is_roaming': false,
  'quality_flag': qualityFlag,
  'cells': cells ?? [lteCell(), lteCell(serving: false, rsrp: -108, pci: 12)],
};

RadioSnapshot snapshot({
  String networkType = 'LTE',
  List<Map<String, Object?>>? cells,
  String? qualityFlag,
  String timestamp = '2026-10-08T01:00:00.000Z',
}) => RadioSnapshotMapper.fromChannel(
  snapshotPayload(
    networkType: networkType,
    cells: cells,
    qualityFlag: qualityFlag,
    timestamp: timestamp,
  ),
);

/// Snapshot taken [seconds] after 2026-10-08T01:00:00Z.
RadioSnapshot snapshotAt(int seconds) => snapshot(
  timestamp: formatUtc(
    DateTime.utc(2026, 10, 8, 1).add(Duration(seconds: seconds)),
  ),
);

const grantedPermissions = RadioPermissions(
  location: true,
  phoneState: true,
  hasTelephony: true,
  apiLevel: 34,
);

const deniedPermissions = RadioPermissions(
  location: false,
  phoneState: false,
  hasTelephony: true,
  apiLevel: 34,
);

class FakeRadioRepository implements RadioRepository {
  FakeRadioRepository({
    required this.permissions,
    this.afterRequest,
    this.snapshots = const [],
    this.streamError,
  });

  RadioPermissions permissions;
  final RadioPermissions? afterRequest;
  final List<RadioSnapshot> snapshots;
  final RadioException? streamError;
  int requestCount = 0;
  int watchCount = 0;

  @override
  Stream<RadioSnapshot> watchSnapshots({
    Duration interval = const Duration(seconds: 1),
  }) {
    watchCount++;
    final error = streamError;
    if (error != null) return Stream<RadioSnapshot>.error(error);
    return Stream<RadioSnapshot>.fromIterable(snapshots);
  }

  @override
  Future<RadioPermissions> getPermissions() async => permissions;

  @override
  Future<RadioPermissions> requestPermissions() async {
    requestCount++;
    permissions = afterRequest ?? permissions;
    return permissions;
  }
}
