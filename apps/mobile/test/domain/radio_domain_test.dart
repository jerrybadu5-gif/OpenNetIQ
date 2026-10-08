import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/errors/radio_exception.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

import '../fixtures/radio_fixtures.dart';

void main() {
  group('NetworkType', () {
    test('covers every data-dictionary value', () {
      expect(NetworkType.values.map((t) => t.wireValue), [
        'GSM', 'GPRS', 'EDGE', 'UMTS', 'HSPA', 'HSPAP', 'LTE', 'LTE_CA', //
        'NR_NSA', 'NR_NSA_MMWAVE', 'NR_SA', 'UNKNOWN', 'NONE',
      ]);
    });

    test('NSA flag and generations', () {
      expect(NetworkType.nrNsa.isNsa, isTrue);
      expect(NetworkType.nrNsaMmwave.isNsa, isTrue);
      expect(NetworkType.nrSa.isNsa, isFalse);
      expect(NetworkType.nrSa.generation, RadioGeneration.g5);
      expect(NetworkType.hspap.generation.label, '3G');
      expect(NetworkType.lteCa.label, 'LTE-A');
    });
  });

  group('Rat', () {
    test('round-trips wire values and rejects unknown', () {
      for (final r in Rat.values) {
        expect(Rat.fromWire(r.wireValue), r);
      }
      expect(Rat.fromWire('6G'), isNull);
    });
  });

  group('CellObservation labels', () {
    test('primary level per RAT', () {
      const lte = CellObservation(isServing: true, rat: Rat.lte, rsrpDbm: -90);
      const nr = CellObservation(isServing: true, rat: Rat.nr, rsrpDbm: -100);
      const wcdma = CellObservation(
        isServing: true,
        rat: Rat.wcdma,
        rscpDbm: -85,
      );
      const gsm = CellObservation(isServing: true, rat: Rat.gsm, rssiDbm: -70);
      const cdma = CellObservation(
        isServing: true,
        rat: Rat.cdma,
        rssiDbm: -80,
      );
      expect(
        [lte.levelDbm, nr.levelDbm, wcdma.levelDbm, gsm.levelDbm],
        [-90, -100, -85, -70],
      );
      expect(cdma.levelDbm, -80);
      expect(
        [lte.levelLabel, nr.levelLabel, wcdma.levelLabel, gsm.levelLabel],
        ['RSRP', 'SS-RSRP', 'RSCP', 'RSSI'],
      );
      expect(cdma.levelLabel, 'Level');
      expect(
        [lte.physicalIdLabel, wcdma.physicalIdLabel, gsm.physicalIdLabel],
        ['PCI', 'PSC', 'BSIC'],
      );
      expect(cdma.physicalIdLabel, 'ID');
      expect(
        [
          lte.channelLabel,
          nr.channelLabel,
          wcdma.channelLabel,
          gsm.channelLabel,
        ],
        ['EARFCN', 'NR-ARFCN', 'UARFCN', 'ARFCN'],
      );
      expect([nr.areaLabel, gsm.areaLabel], ['TAC', 'LAC']);
    });
  });

  group('RadioSnapshot', () {
    test('LTE: primary is the serving cell, neighbours listed', () {
      final s = snapshot();
      expect(s.primaryCell?.pciPscBsic, 301);
      expect(s.nrLeg, isNull);
      expect(s.neighbourCells.single.pciPscBsic, 12);
      expect(s.neighbourCellsExcludingNrLeg, hasLength(1));
      expect(s.plmn, '537-03');
      expect(s.isStale, isFalse);
    });

    test('NSA: LTE anchor is primary, unregistered NR cell is the leg', () {
      final s = snapshot(
        networkType: 'NR_NSA',
        cells: [nrCell(), lteCell(), lteCell(serving: false, pci: 7)],
      );
      expect(s.primaryCell?.rat, Rat.lte);
      expect(s.nrLeg?.rat, Rat.nr);
      expect(s.neighbourCellsExcludingNrLeg.map((c) => c.pciPscBsic), [7]);
    });

    test('NSA: registered NR cell is preferred as the leg', () {
      final s = snapshot(
        networkType: 'NR_NSA',
        cells: [lteCell(), nrCell(serving: true, ssRsrp: -90)],
      );
      expect(s.nrLeg?.rsrpDbm, -90);
    });

    test('SA: NR cell is primary and there is no leg', () {
      final s = snapshot(networkType: 'NR_SA', cells: [nrCell(serving: true)]);
      expect(s.primaryCell?.rat, Rat.nr);
      expect(s.nrLeg, isNull);
    });

    test('no serving cell', () {
      final s = snapshot(cells: [lteCell(serving: false)]);
      expect(s.primaryCell, isNull);
    });

    test('flags', () {
      final s = snapshot(qualityFlag: 'CACHED|STALE');
      expect(s.isStale, isTrue);
      expect(s.hasFlag('CACHED'), isTrue);
      expect(s.hasFlag('NO_PHONE_STATE'), isFalse);
    });
  });

  group('SignalQuality', () {
    test('LTE/NR RSRP boundaries', () {
      expect(SignalQuality.fromLevel(Rat.lte, -80), SignalQuality.excellent);
      expect(SignalQuality.fromLevel(Rat.lte, -80.5), SignalQuality.good);
      expect(SignalQuality.fromLevel(Rat.nr, -90), SignalQuality.good);
      expect(SignalQuality.fromLevel(Rat.lte, -100), SignalQuality.fair);
      expect(SignalQuality.fromLevel(Rat.lte, -110), SignalQuality.poor);
      expect(SignalQuality.fromLevel(Rat.lte, -111), SignalQuality.noService);
    });

    test('WCDMA RSCP and GSM RSSI use their own scales', () {
      expect(SignalQuality.fromLevel(Rat.wcdma, -75), SignalQuality.excellent);
      expect(SignalQuality.fromLevel(Rat.wcdma, -106), SignalQuality.noService);
      expect(SignalQuality.fromLevel(Rat.gsm, -80), SignalQuality.good);
      expect(SignalQuality.fromLevel(Rat.gsm, -95), SignalQuality.poor);
    });

    test('SINR boundaries', () {
      expect(SignalQuality.fromSinr(20), SignalQuality.excellent);
      expect(SignalQuality.fromSinr(13), SignalQuality.good);
      expect(SignalQuality.fromSinr(0), SignalQuality.fair);
      expect(SignalQuality.fromSinr(-1), SignalQuality.poor);
      expect(SignalQuality.noService.label, 'No service');
    });
  });

  group('RadioPermissions', () {
    test('monitoring and NSA detection requirements', () {
      expect(grantedPermissions.canMonitor, isTrue);
      expect(grantedPermissions.canDetectNsa, isTrue);
      expect(deniedPermissions.canMonitor, isFalse);
      const api29 = RadioPermissions(
        location: true,
        phoneState: true,
        hasTelephony: true,
        apiLevel: 29,
      );
      expect(api29.canDetectNsa, isFalse);
      const noRadio = RadioPermissions(
        location: true,
        phoneState: true,
        hasTelephony: false,
      );
      expect(noRadio.canMonitor, isFalse);
    });
  });

  test('RadioException is readable', () {
    expect(
      const RadioException('NO_TELEPHONY', 'none').toString(),
      'RadioException(NO_TELEPHONY): none',
    );
  });
}
