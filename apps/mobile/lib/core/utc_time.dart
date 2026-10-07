/// Formats [t] as ISO 8601 UTC with millisecond precision, always ending in `Z`.
String formatUtc(DateTime t) {
  final s = t.toUtc().toIso8601String();
  return s.endsWith('Z') ? s : '${s}Z';
}

/// Parses an ISO 8601 UTC timestamp. Returns null unless it ends in `Z`.
DateTime? parseUtc(String? value) {
  if (value == null || !value.endsWith('Z')) return null;
  return DateTime.tryParse(value);
}

/// Current time as an ISO 8601 UTC string.
String nowUtc() => formatUtc(DateTime.now());
