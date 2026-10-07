import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/result.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';

void main() {
  group('Result', () {
    test('ok folds to ok branch', () {
      const r = Result<int>.ok(2);
      expect(r.isOk, isTrue);
      expect(r.when(ok: (v) => v * 2, err: (_, _) => -1), 4);
    });

    test('err folds to err branch', () {
      const r = Result<int>.err('boom');
      expect(r.isOk, isFalse);
      expect(
        r.when(ok: (v) => v.toString(), err: (e, _) => e.toString()),
        'boom',
      );
    });
  });

  group('NetworkType', () {
    test('round-trips wire values', () {
      for (final t in NetworkType.values) {
        expect(NetworkType.fromWire(t.wireValue), t);
      }
    });

    test('unknown or null wire value is null, never a default', () {
      expect(NetworkType.fromWire('6G'), isNull);
      expect(NetworkType.fromWire(null), isNull);
    });
  });
}
