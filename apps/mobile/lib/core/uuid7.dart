import 'dart:math';

/// RFC 9562 UUIDv7 generator, monotonic within a process
/// (12-bit counter in rand_a, method 1).
class Uuid7Generator {
  Uuid7Generator({int Function()? nowMs, Random? random})
    : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
      _random = random ?? Random.secure();

  final int Function() _nowMs;
  final Random _random;
  int _lastMs = -1;
  int _counter = 0;

  String next() {
    var ms = _nowMs();
    if (ms > _lastMs) {
      _counter = _random.nextInt(0x800);
    } else {
      ms = _lastMs;
      _counter++;
      if (_counter > 0xFFF) {
        ms++;
        _counter = 0;
      }
    }
    _lastMs = ms;

    final b = List<int>.filled(16, 0);
    for (var i = 0; i < 6; i++) {
      b[i] = (ms >> (8 * (5 - i))) & 0xFF;
    }
    b[6] = 0x70 | (_counter >> 8);
    b[7] = _counter & 0xFF;
    for (var i = 8; i < 16; i++) {
      b[i] = _random.nextInt(256);
    }
    b[8] = (b[8] & 0x3F) | 0x80;

    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

final Uuid7Generator _default = Uuid7Generator();

/// Generates a new monotonic UUIDv7 string.
String uuid7() => _default.next();
