import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/qoe_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';

void main() {
  test('settings JSON round trip and defaults', () {
    const s = QoeSettings(
      web: [QoeTarget('A', 'https://a/')],
      videos: [QoeTarget('V', 'https://v/', mode: VideoMode.page)],
      fileSizeMib: 10,
      videoSeconds: 45,
    );
    final back = QoeSettings.fromJson(
      (jsonDecode(jsonEncode(s.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.web.single.name, 'A');
    expect(back.videos.single.mode, VideoMode.page);
    expect(
      back.apps.map((t) => t.name),
      QoeSettings.defaultApps.map((t) => t.name),
    );
    expect(back.fileSizeMib, 10);
    expect(back.videoSeconds, 45);
    final empty = QoeSettings.fromJson(const {});
    expect(empty.web.length, QoeSettings.defaultWeb.length);
    expect(empty.pageTimeoutSeconds, 30);
    expect(const QoeSettings().targets(QoeKind.file), isEmpty);
    expect(QoeKind.fromWire('video'), QoeKind.video);
    expect(QoeKind.fromWire('x'), isNull);
    expect(VideoMode.fromWire('nope'), VideoMode.stream);
  });

  test('target lines parse and print', () {
    final (targets, errors) = QoeTarget.parseLines(
      'YouTube | https://www.youtube.com/watch?v=abc | page\n'
      '\n'
      'https://cdn.example.org/live.m3u8\n'
      'Bad | ftp://x\n',
      video: true,
    );
    expect(errors, ['Line 4: not an http(s) URL']);
    expect(targets.first.mode, VideoMode.page);
    expect(targets.last.name, 'cdn.example.org');
    expect(targets.last.mode, VideoMode.stream);
    expect(
      QoeTarget.toLines(targets, video: true),
      'YouTube | https://www.youtube.com/watch?v=abc | page\n'
      'cdn.example.org | https://cdn.example.org/live.m3u8',
    );
    final (web, _) = QoeTarget.parseLines('G | https://g/ | page');
    expect(web.single.mode, VideoMode.stream); // page only for videos
  });

  test('mapper: status rules and summaries', () {
    final web = QoeMapper.fromMap(QoeKind.web, 'G', 'u', {
      'dns_ms': 10,
      'connect_ms': 20.5,
      'ttfb_ms': 200,
      'total_ms': 1800,
      'http_status': 200,
      'error': null,
    });
    expect(web.status, TestStatus.ok);
    expect(web.connectMs, 20.5);
    expect(web.summary, 'load 1.8 s');
    final failed = QoeMapper.fromMap(QoeKind.app, 'G', 'u', {
      'error': 'timeout',
    });
    expect(failed.status, TestStatus.failed);
    expect(failed.summary, 'failed: timeout');
    final partialVideo = QoeMapper.fromMap(QoeKind.video, 'V', 'u', {
      'start_delay_ms': 1200,
      'rebuffer_count': 2,
      'resolution': '1080p',
      'error': 'ERROR_CODE_IO',
    });
    expect(partialVideo.status, TestStatus.partial);
    expect(partialVideo.summary, 'start 1.2 s · 2 rebuffers · 1080p');
    final noStart = QoeMapper.fromMap(QoeKind.video, 'V', 'u', {});
    expect(noStart.status, TestStatus.failed);
    final file = QoeMapper.fromMap(QoeKind.file, 'F', 'u', {
      'total_ms': 2000,
      'rate_mbps': 20.97,
      'direction': 'download',
      'bytes': 5242880,
    });
    expect(file.summary, 'download 21.0 Mbps · 2.0 s');
    expect(file.bytes, 5242880);
    final app = QoeMapper.fromMap(QoeKind.app, 'A', 'u', {'total_ms': 249.6});
    expect(app.summary, 'response 250 ms');
    const oneRebuffer = QoeResult(
      kind: QoeKind.video,
      label: 'v',
      target: 'u',
      status: TestStatus.ok,
      startDelayMs: 500,
      rebufferCount: 1,
    );
    expect(oneRebuffer.summary, 'start 0.5 s · 1 rebuffer');
  });
}
