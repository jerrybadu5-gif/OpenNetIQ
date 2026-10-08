import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/radio_snapshot_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';

import '../fixtures/radio_fixtures.dart';

void main() {
  group('RadioSnapshotMapper.fromChannel', () {
    test('maps network context and every LTE field', () {
      final s = RadioSnapshotMapper.fromChannel(snapshotPayload());

      expect(s.timestamp, DateTime.utc(2026, 10, 8, 1));
      expect(s.radioTimestamp, DateTime.utc(2026, 10, 8, 0, 59, 59, 800));
      expect(s.operatorName, 'Digicel PNG');
      expect(s.simOperator, 'Digicel');
      expect(s.networkType, NetworkType.lte);
      expect(s.dataState, 'CONNECTED');
      expect(s.isRoaming, isFalse);
      expect(s.cells, hasLength(2));

      final c = s.cells.first;
      expect(c.isServing, isTrue);
      expect(c.rat, Rat.lte);
      expect(c.mcc, '537');
      expect(c.mnc, '03');
      expect(c.lacTac, 1201);
      expect(c.cellId, 27439044);
      expect(c.enbId, 107183);
      expect(c.localCellId, 196);
      expect(c.pciPscBsic, 301);
      expect(c.arfcn, 9410);
      expect(c.band, 'B28');
      expect(c.bandwidthKhz, 10000);
      expect(c.rsrpDbm, -95.0);
      expect(c.rsrqDb, -11.0);
      expect(c.sinrDb, 12.0);
      expect(c.rssiDbm, -65.0);
      expect(c.cqi, 9);
      expect(c.timingAdvance, 4);
      expect(c.gnbId, isNull);
      expect(c.csiSinrDb, isNull);
      expect(c.qualityFlag, isNull);
    });

    test('maps NR SS and CSI metrics', () {
      final s = RadioSnapshotMapper.fromChannel(
        snapshotPayload(networkType: 'NR_SA', cells: [nrCell(serving: true)]),
      );
      final c = s.cells.single;
      expect(c.rat, Rat.nr);
      expect(c.gnbId, 11259375);
      expect(c.cellId, 46118400291);
      expect(c.csiRsrpDbm, -99.0);
      expect(s.networkType, NetworkType.nrSa);
    });

    test('unknown network type maps to unknown, unknown RAT is skipped', () {
      final s = RadioSnapshotMapper.fromChannel(
        snapshotPayload(
          networkType: 'IWLAN',
          cells: [
            lteCell(),
            <String, Object?>{'is_serving': false, 'rat': 'SATELLITE'},
          ],
        ),
      );
      expect(s.networkType, NetworkType.unknown);
      expect(s.cells, hasLength(1));
    });

    test('missing cells list gives an empty list', () {
      final payload = snapshotPayload()..remove('cells');
      expect(RadioSnapshotMapper.fromChannel(payload).cells, isEmpty);
    });

    test('rejects non-map payloads', () {
      expect(
        () => RadioSnapshotMapper.fromChannel('nope'),
        throwsFormatException,
      );
      expect(
        () => RadioSnapshotMapper.fromChannel(null),
        throwsFormatException,
      );
    });

    test('rejects missing or non-UTC timestamp', () {
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload()..remove('timestamp'),
        ),
        throwsFormatException,
      );
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload(timestamp: '2026-10-08T11:00:00+10:00'),
        ),
        throwsFormatException,
      );
    });

    test('rejects wrong types instead of guessing', () {
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload(cells: [lteCell()..['pci_psc_bsic'] = '301']),
        ),
        throwsFormatException,
      );
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload(cells: [lteCell()..['rsrp_dbm'] = 'strong']),
        ),
        throwsFormatException,
      );
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload()..['cells'] = 'none',
        ),
        throwsFormatException,
      );
      expect(
        () => RadioSnapshotMapper.fromChannel(
          snapshotPayload(cells: [lteCell()..remove('is_serving')]),
        ),
        throwsFormatException,
      );
    });
  });

  group('permissionsFromChannel', () {
    test('maps flags with safe defaults', () {
      final p = RadioSnapshotMapper.permissionsFromChannel(<String, Object?>{
        'location': true,
        'api_level': 33,
      });
      expect(p.location, isTrue);
      expect(p.phoneState, isFalse);
      expect(p.hasTelephony, isFalse);
      expect(p.apiLevel, 33);
    });
  });
}
