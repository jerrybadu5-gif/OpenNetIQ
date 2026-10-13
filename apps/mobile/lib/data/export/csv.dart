/// RFC 4180 CSV: comma, CRLF, fields quoted when they contain a comma,
/// quote, CR or LF. Null is an empty field (never 0, never "null").
library;

String csvField(Object? value) {
  final s = switch (value) {
    null => '',
    final bool b => b ? 'true' : 'false',
    final double d when d.isNaN || d.isInfinite => '',
    _ => value.toString(),
  };
  if (s.contains(RegExp('[",\r\n]'))) return '"${s.replaceAll('"', '""')}"';
  return s;
}

String csvRow(Iterable<Object?> values) => values.map(csvField).join(',');

/// Header + rows, CRLF-terminated.
String csvDocument(List<String> header, Iterable<List<Object?>> rows) {
  final b = StringBuffer()
    ..write(csvRow(header))
    ..write('\r\n');
  for (final r in rows) {
    assert(r.length == header.length, 'row width != header width');
    b
      ..write(csvRow(r))
      ..write('\r\n');
  }
  return b.toString();
}
