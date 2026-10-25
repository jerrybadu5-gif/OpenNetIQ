import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/mappers/qoe_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/network_type.dart';
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

  test('FTP settings, sizes by network and file results', () {
    expect(QoeSettings.ftpSizeFor(NetworkType.lte), 100);
    expect(QoeSettings.ftpSizeFor(NetworkType.nrSa), 100);
    expect(QoeSettings.ftpSizeFor(NetworkType.hspap), 50);
    expect(QoeSettings.ftpSizeFor(NetworkType.edge), 5);
    expect(QoeSettings.ftpSizeFor(null), 100);
    const d = QoeSettings();
    expect(d.fileProtocol, FileProtocol.http);
    expect(d.ftpConfigured, isFalse);
    final s = d.copyWith(
      fileProtocol: FileProtocol.ftp,
      ftpUrl: 'ftp://h/',
      ftpUser: 'u',
      ftpPassword: 'p',
      ftpSizeAuto: false,
      ftpDownloadMib: 20,
      ftpUploadMib: 5,
      ftpMaxSeconds: 120,
    );
    expect(s.ftpConfigured, isTrue);
    final back = QoeSettings.fromJson(s.toJson());
    expect(back.fileProtocol, FileProtocol.ftp);
    expect(back.ftpUrl, 'ftp://h/');
    expect(back.ftpSizeAuto, isFalse);
    expect(back.ftpDownloadMib, 20);
    expect(back.ftpUploadMib, 5);
    expect(back.ftpMaxSeconds, 120);
    final odd = QoeSettings.fromJson(const {'ftp_download_mib': 7});
    expect(odd.ftpDownloadMib, 100); // not offered by the server
    expect(FileProtocol.fromWire('x'), FileProtocol.http);
    const r = QoeResult(
      kind: QoeKind.file,
      label: 'FTP',
      target: 'ftp://h/',
      status: TestStatus.ok,
      totalMs: 40000,
      rateMbps: 20,
      direction: 'download',
      protocol: 'ftp',
    );
    final withLevel = r.withLevel(-101.5, 'LTE');
    expect(withLevel.servingLevelDbm, -101.5);
    expect(withLevel.servingRat, 'LTE');
    expect(withLevel.summary, 'FTP download 20.0 Mbps · 40.0 s');
    expect(
      QoeMapper.fromMap(QoeKind.file, 'f', 'u', const {}).protocol,
      'http',
    );
    expect(QoeMapper.fromMap(QoeKind.web, 'w', 'u', const {}).protocol, isNull);
    expect(
      QoeMapper.fromMap(QoeKind.file, 'f', 'u', const {
        'protocol': 'ftp',
      }).protocol,
      'ftp',
    );
  });

  test('format 1 settings re-detect page videos saved as streams', () {
    final legacy = QoeSettings.fromJson({
      'videos': [
        {
          'name': 'YT',
          'url': 'https://m.youtube.com/watch?v=x',
          'mode': 'stream',
        },
        {'name': 'HLS', 'url': 'https://cdn/a.m3u8', 'mode': 'stream'},
      ],
    });
    expect(legacy.videos.map((t) => t.mode), [
      VideoMode.page,
      VideoMode.stream,
    ]);
    final current = QoeSettings.fromJson({
      'version': 2,
      'videos': [
        {'name': 'Live', 'url': 'https://srv/live', 'mode': 'stream'},
      ],
    });
    expect(current.videos.single.mode, VideoMode.stream);
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
      'cdn.example.org | https://cdn.example.org/live.m3u8 | stream',
    );
    final (auto, _) = QoeTarget.parseLines(
      'm.youtube.com | https://m.youtube.com/watch?v=4U71uoW4oec&pp=0gcJCbgCo7VqN5tDiggCQAE%3D\n'
      'Own | https://srv/live | stream\n'
      'Clip | https://cdn/x.MP4\n'
      'Dash | https://cdn/v/manifest(format=mpd)\n'
      'Twitch | https://www.twitch.tv/somechannel',
      video: true,
    );
    expect(auto.map((t) => t.mode), [
      VideoMode.page,
      VideoMode.stream,
      VideoMode.stream,
      VideoMode.stream,
      VideoMode.page,
    ]);
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
