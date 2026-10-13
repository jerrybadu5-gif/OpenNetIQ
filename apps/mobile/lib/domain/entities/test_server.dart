/// Speed/latency test servers offered as presets (issue #22).
library;

enum TestServerKind {
  /// Controlled server (infra/test-server); valid for benchmarking.
  own,

  /// Volunteer LibreSpeed backend; development and spot checks only.
  public,
}

class TestServer {
  const TestServer({required this.name, required this.url, required this.kind});

  final String name;

  /// Base URL of LibreSpeed-compatible endpoints, trailing slash.
  final String url;
  final TestServerKind kind;

  /// Same server, ignoring case and a trailing slash.
  bool matches(String? other) {
    if (other == null) return false;
    String norm(String u) {
      final t = u.trim().toLowerCase();
      return t.endsWith('/') ? t : '$t/';
    }

    return norm(url) == norm(other);
  }
}

/// Public LibreSpeed backends (librespeed.org server list, 2026-10).
/// Volunteer-run: results measure the international path, not the
/// operator network, and the servers may change without notice.
const List<TestServer> publicTestServers = [
  TestServer(
    name: 'LibreSpeed: Tokyo, Japan (A573)',
    url: 'https://librespeed.a573.net/backend/',
    kind: TestServerKind.public,
  ),
  TestServer(
    name: 'LibreSpeed: Amsterdam, NL (Clouvider)',
    url: 'https://ams.speedtest.clouvider.net/backend/',
    kind: TestServerKind.public,
  ),
];

/// Build-time own server first (if set), then the public servers.
List<TestServer> testServerPresets({String buildDefault = ''}) => [
  if (buildDefault.trim().isNotEmpty)
    TestServer(
      name: 'OpenNetIQ server (build default)',
      url: buildDefault.trim(),
      kind: TestServerKind.own,
    ),
  ...publicTestServers,
];

/// The preset matching [url], or null for a custom server.
TestServer? presetFor(List<TestServer> presets, String? url) {
  for (final p in presets) {
    if (p.matches(url)) return p;
  }
  return null;
}
