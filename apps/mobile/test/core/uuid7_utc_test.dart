import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';

void main() {
  group('uuid7', () {
    test('has version 7 and RFC variant', () {
      final id = uuid7();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('is strictly monotonic even with a frozen clock', () {
      final gen = Uuid7Generator(nowMs: () => 1700000000000);
      final ids = List.generate(10000, (_) => gen.next());
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i].compareTo(ids[i - 1]), greaterThan(0));
      }
    });

    test('is monotonic when the clock goes backwards', () {
      var t = 2000;
      final gen = Uuid7Generator(nowMs: () => t);
      final a = gen.next();
      t = 1000;
      expect(gen.next().compareTo(a), greaterThan(0));
    });

    test('encodes the timestamp in the first 48 bits', () {
      final gen = Uuid7Generator(nowMs: () => 0x0123456789AB);
      expect(gen.next().startsWith('01234567-89ab-7'), isTrue);
    });
  });

  group('utc time', () {
    test('formatUtc always ends in Z', () {
      expect(
        formatUtc(DateTime.parse('2026-10-07T14:36:00+10:00')),
        endsWith('Z'),
      );
      expect(formatUtc(DateTime(2026, 10, 7, 14, 36)), endsWith('Z'));
      expect(nowUtc(), endsWith('Z'));
    });

    test('parseUtc round-trips and rejects non-UTC', () {
      final t = DateTime.utc(2026, 10, 7, 14, 36);
      expect(parseUtc(formatUtc(t)), t);
      expect(parseUtc('2026-10-07T14:36:00+10:00'), isNull);
      expect(parseUtc(null), isNull);
    });
  });
}
