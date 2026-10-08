/// Formats [t] as ISO 8601 UTC with millisecond precision, always ending in `Z`
/// (e.g. `2026-10-07T14:36:00.000Z`), matching the Kotlin `UtcTime` output.
String formatUtc(DateTime t) {
  final utc = t.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    utc.millisecondsSinceEpoch,
    isUtc: true,
  ).toIso8601String();
}

/// Parses an ISO 8601 UTC timestamp. Returns null unless it ends in `Z`.
DateTime? parseUtc(String? value) {
  if (value == null || !value.endsWith('Z')) return null;
  return DateTime.tryParse(value);
}

/// Current time as an ISO 8601 UTC string.
String nowUtc() => formatUtc(DateTime.now());
