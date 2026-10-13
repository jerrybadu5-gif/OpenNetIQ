import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/domain/entities/test_server.dart';

void main() {
  test('build default comes first as own server', () {
    final presets = testServerPresets(buildDefault: ' http://10.0.0.5/b/ ');
    expect(presets.first.kind, TestServerKind.own);
    expect(presets.first.url, 'http://10.0.0.5/b/');
    expect(presets.length, publicTestServers.length + 1);
  });

  test('no build default: public servers only', () {
    expect(testServerPresets(), publicTestServers);
  });

  test('public presets are https base URLs with a trailing slash', () {
    for (final s in publicTestServers) {
      final uri = Uri.parse(s.url);
      expect(uri.isScheme('https'), isTrue, reason: s.name);
      expect(s.url.endsWith('/'), isTrue, reason: s.name);
      expect(s.kind, TestServerKind.public);
    }
  });

  test('matching ignores case and trailing slash', () {
    final presets = testServerPresets();
    expect(
      presetFor(presets, 'HTTPS://ams.speedtest.clouvider.net/backend')?.name,
      'LibreSpeed: Amsterdam, NL (Clouvider)',
    );
    expect(presetFor(presets, 'http://192.168.1.10:8080/'), isNull);
    expect(presetFor(presets, null), isNull);
  });
}
