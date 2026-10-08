/// Typed, strict reads from platform-channel maps.
/// Missing keys and nulls return null; wrong types throw [FormatException].
class ChannelReader {
  ChannelReader(Object? value, String context)
    : _map = value is Map<Object?, Object?>
          ? value
          : throw FormatException('Expected a map for $context'),
      _context = context;

  final Map<Object?, Object?> _map;
  final String _context;

  String? string(String key) => _typed<String>(key);

  bool? boolean(String key) => _typed<bool>(key);

  int? integer(String key) => _typed<int>(key);

  double? decimal(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    throw _invalid(key, 'number');
  }

  List<Object?> list(String key) {
    final value = _map[key];
    if (value == null) return const <Object?>[];
    if (value is List<Object?>) return value;
    throw _invalid(key, 'list');
  }

  String requireString(String key) =>
      string(key) ?? (throw FormatException('Missing "$key" in $_context'));

  bool requireBool(String key) =>
      boolean(key) ?? (throw FormatException('Missing "$key" in $_context'));

  T? _typed<T extends Object>(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is T) return value;
    throw _invalid(key, '$T');
  }

  FormatException _invalid(String key, String expected) =>
      FormatException('Invalid "$key" in $_context: expected $expected');
}
