/// Customer-experience (QoE) tests, method `qoe-1.0` (issue #29,
/// MEASUREMENT-METHODOLOGY.md §6b).
library;

import 'package:opennetiq_mobile/domain/entities/network_type.dart';
import 'package:opennetiq_mobile/domain/entities/test_status.dart';

export 'package:opennetiq_mobile/domain/entities/test_status.dart';

const String qoeMethod = 'qoe-1.0';

enum QoeKind {
  web('web', 'Web browsing'),
  video('video', 'Video streaming'),
  app('app', 'App reachability'),
  file('file', 'File transfer');

  const QoeKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static QoeKind? fromWire(String? v) {
    for (final k in values) {
      if (k.wireValue == v) return k;
    }
    return null;
  }
}

enum VideoMode {
  /// Direct HLS / DASH / MP4 stream (ExoPlayer).
  stream('stream', 'Direct stream'),

  /// Web page with an HTML5 video (YouTube, Facebook, game streams).
  page('page', 'Video on a web page');

  const VideoMode(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static VideoMode fromWire(String? v) => v == page.wireValue ? page : stream;

  static final _media = RegExp(
    r'(\.(m3u8|mpd|mp4|m4v|webm|mkv|mov|ts|mp3|aac)$)|(/manifest)|(\.ism)',
  );

  /// Media files and manifests are direct streams; anything else (YouTube,
  /// Facebook, game sites) is a web page with a video on it.
  static VideoMode detect(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return _media.hasMatch(path) ? stream : page;
  }
}

/// A named URL (web site, app endpoint or video source).
class QoeTarget {
  const QoeTarget(this.name, this.url, {this.mode = VideoMode.stream});

  factory QoeTarget.fromJson(Map<String, Object?> j) => QoeTarget(
    j['name']! as String,
    j['url']! as String,
    mode: VideoMode.fromWire(j['mode'] as String?),
  );

  final String name;
  final String url;

  /// Video sources only.
  final VideoMode mode;

  Map<String, Object?> toJson() => {
    'name': name,
    'url': url,
    'mode': mode.wireValue,
  };

  /// One target per line: `Name | URL` (video: `Name | URL | page|stream`).
  static String toLines(List<QoeTarget> list, {bool video = false}) => [
    for (final t in list)
      video
          ? '${t.name} | ${t.url} | ${t.mode.wireValue}'
          : '${t.name} | ${t.url}',
  ].join('\n');

  /// Parses [toLines] text; a bare URL uses its host as the name. Video
  /// lines without a mode are detected from the URL ([VideoMode.detect]).
  static (List<QoeTarget>, List<String>) parseLines(
    String text, {
    bool video = false,
  }) {
    final targets = <QoeTarget>[];
    final errors = <String>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = [for (final p in line.split('|')) p.trim()];
      final url = parts.length == 1 ? parts[0] : parts[1];
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !(uri.isScheme('http') || uri.isScheme('https')) ||
          uri.host.isEmpty) {
        errors.add('Line ${i + 1}: not an http(s) URL');
        continue;
      }
      final name = parts.length == 1 || parts[0].isEmpty ? uri.host : parts[0];
      final given = parts.length > 2 ? parts[2].toLowerCase() : '';
      final mode = !video
          ? VideoMode.stream
          : given == 'page'
          ? VideoMode.page
          : given == 'stream'
          ? VideoMode.stream
          : VideoMode.detect(url);
      targets.add(QoeTarget(name, url, mode: mode));
    }
    return (targets, errors);
  }
}

/// What the QoE tests measure; editable on the QoE screen, stored as JSON.
/// Transport of the file-transfer test.
enum FileProtocol {
  /// Fixed-size HTTP transfer to the speed-test server (`qoe-1.0`).
  http('http', 'HTTP (speed-test server)'),

  /// FTP to the campaign FTP server (NICTA QoS Rule 2022 Schedule 2 G8).
  ftp('ftp', 'FTP');

  const FileProtocol(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static FileProtocol fromWire(String? value) =>
      value == 'ftp' ? FileProtocol.ftp : FileProtocol.http;
}

class QoeSettings {
  const QoeSettings({
    this.web = defaultWeb,
    this.apps = defaultApps,
    this.videos = defaultVideos,
    this.fileSizeMib = 5,
    this.videoSeconds = 30,
    this.pageTimeoutSeconds = 30,
    this.fileProtocol = FileProtocol.http,
    this.ftpUrl = '',
    this.ftpUser = 'onq',
    this.ftpPassword = '',
    this.ftpSizeAuto = true,
    this.ftpDownloadMib = 100,
    this.ftpUploadMib = 10,
    this.ftpMaxSeconds = 600,
  });

  /// File sizes the OpenNetIQ FTP server offers (MB = MiB).
  static const ftpSizes = [5, 10, 20, 50, 100];

  /// Rule Schedule 2 G9: 100 MB on LTE (and 5G), 50 MB on 3G; 5 MB on 2G.
  static int ftpSizeFor(NetworkType? type) => switch (type?.generation) {
    RadioGeneration.g3 => 50,
    RadioGeneration.g2 => 5,
    _ => 100,
  };

  static int _size(Object? v, int fallback) {
    final n = (v as num?)?.toInt();
    return n != null && ftpSizes.contains(n) ? n : fallback;
  }

  factory QoeSettings.fromJson(Map<String, Object?> j) {
    List<QoeTarget> list(String key, List<QoeTarget> fallback) {
      final raw = j[key];
      if (raw is! List) return fallback;
      return [
        for (final t in raw)
          QoeTarget.fromJson((t as Map).cast<String, Object?>()),
      ];
    }

    // Format 1 (no 'version') had no explicit stream mode: re-detect.
    final legacy = j['version'] == null;
    return QoeSettings(
      web: list('web', defaultWeb),
      apps: list('apps', defaultApps),
      videos: [
        for (final t in list('videos', defaultVideos))
          legacy && t.mode == VideoMode.stream
              ? QoeTarget(t.name, t.url, mode: VideoMode.detect(t.url))
              : t,
      ],
      fileSizeMib: (j['file_size_mib'] as num?)?.toInt() ?? 5,
      videoSeconds: (j['video_s'] as num?)?.toInt() ?? 30,
      pageTimeoutSeconds: (j['page_timeout_s'] as num?)?.toInt() ?? 30,
      fileProtocol: FileProtocol.fromWire(j['file_protocol'] as String?),
      ftpUrl: j['ftp_url'] as String? ?? '',
      ftpUser: j['ftp_user'] as String? ?? 'onq',
      ftpPassword: j['ftp_password'] as String? ?? '',
      ftpSizeAuto: j['ftp_size_auto'] as bool? ?? true,
      ftpDownloadMib: _size(j['ftp_download_mib'], 100),
      ftpUploadMib: _size(j['ftp_upload_mib'], 10),
      ftpMaxSeconds: (j['ftp_max_s'] as num?)?.toInt() ?? 600,
    );
  }

  static const defaultWeb = [
    QoeTarget('Google', 'https://www.google.com/'),
    QoeTarget('Facebook', 'https://www.facebook.com/'),
    QoeTarget('Wikipedia', 'https://www.wikipedia.org/'),
    QoeTarget('NICTA', 'https://www.nicta.gov.pg/'),
    QoeTarget('BSP', 'https://www.bsp.com.pg/'),
  ];

  static const defaultApps = [
    QoeTarget('Google', 'https://www.google.com/generate_204'),
    QoeTarget('Facebook', 'https://www.facebook.com/'),
    QoeTarget('WhatsApp', 'https://web.whatsapp.com/'),
    QoeTarget('YouTube', 'https://www.youtube.com/'),
    QoeTarget('TikTok', 'https://www.tiktok.com/'),
    QoeTarget('BSP', 'https://www.bsp.com.pg/'),
  ];

  /// Public HLS test stream; NICTA adds YouTube, Facebook or own sources.
  static const defaultVideos = [
    QoeTarget(
      'Public HLS test stream',
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    ),
  ];

  final List<QoeTarget> web;
  final List<QoeTarget> apps;
  final List<QoeTarget> videos;
  final int fileSizeMib;
  final int videoSeconds;
  final int pageTimeoutSeconds;
  final FileProtocol fileProtocol;

  /// `ftp://host[:port][/base/]` of the campaign FTP server.
  final String ftpUrl;
  final String ftpUser;

  /// Test account password; kept in local settings only, never exported.
  final String ftpPassword;

  /// Download size by network ([ftpSizeFor]) instead of [ftpDownloadMib].
  final bool ftpSizeAuto;
  final int ftpDownloadMib;
  final int ftpUploadMib;

  /// A transfer still running after this is cut off (failed).
  final int ftpMaxSeconds;

  bool get ftpConfigured =>
      ftpUrl.trim().toLowerCase().startsWith('ftp://') &&
      ftpUser.trim().isNotEmpty &&
      ftpPassword.isNotEmpty;

  List<QoeTarget> targets(QoeKind kind) => switch (kind) {
    QoeKind.web => web,
    QoeKind.app => apps,
    QoeKind.video => videos,
    QoeKind.file => const [],
  };

  QoeSettings copyWith({
    List<QoeTarget>? web,
    List<QoeTarget>? apps,
    List<QoeTarget>? videos,
    int? fileSizeMib,
    int? videoSeconds,
    FileProtocol? fileProtocol,
    String? ftpUrl,
    String? ftpUser,
    String? ftpPassword,
    bool? ftpSizeAuto,
    int? ftpDownloadMib,
    int? ftpUploadMib,
    int? ftpMaxSeconds,
  }) => QoeSettings(
    web: web ?? this.web,
    apps: apps ?? this.apps,
    videos: videos ?? this.videos,
    fileSizeMib: fileSizeMib ?? this.fileSizeMib,
    videoSeconds: videoSeconds ?? this.videoSeconds,
    pageTimeoutSeconds: pageTimeoutSeconds,
    fileProtocol: fileProtocol ?? this.fileProtocol,
    ftpUrl: ftpUrl ?? this.ftpUrl,
    ftpUser: ftpUser ?? this.ftpUser,
    ftpPassword: ftpPassword ?? this.ftpPassword,
    ftpSizeAuto: ftpSizeAuto ?? this.ftpSizeAuto,
    ftpDownloadMib: ftpDownloadMib ?? this.ftpDownloadMib,
    ftpUploadMib: ftpUploadMib ?? this.ftpUploadMib,
    ftpMaxSeconds: ftpMaxSeconds ?? this.ftpMaxSeconds,
  );

  Map<String, Object?> toJson() => {
    'version': 3,
    'web': [for (final t in web) t.toJson()],
    'apps': [for (final t in apps) t.toJson()],
    'videos': [for (final t in videos) t.toJson()],
    'file_size_mib': fileSizeMib,
    'video_s': videoSeconds,
    'page_timeout_s': pageTimeoutSeconds,
    'file_protocol': fileProtocol.wireValue,
    'ftp_url': ftpUrl,
    'ftp_user': ftpUser,
    'ftp_password': ftpPassword,
    'ftp_size_auto': ftpSizeAuto,
    'ftp_download_mib': ftpDownloadMib,
    'ftp_upload_mib': ftpUploadMib,
    'ftp_max_s': ftpMaxSeconds,
  };
}

/// One measured target.
class QoeResult {
  const QoeResult({
    required this.kind,
    required this.label,
    required this.target,
    required this.status,
    this.error,
    this.totalMs,
    this.dnsMs,
    this.connectMs,
    this.tlsMs,
    this.ttfbMs,
    this.domMs,
    this.httpStatus,
    this.startDelayMs,
    this.rebufferCount,
    this.rebufferMs,
    this.playedMs,
    this.bitrateKbps,
    this.resolution,
    this.bytes,
    this.rateMbps,
    this.direction,
    this.protocol,
    this.servingLevelDbm,
    this.servingRat,
  });

  final QoeKind kind;
  final String label;
  final String target;
  final TestStatus status;
  final String? error;
  final double? totalMs;
  final double? dnsMs;
  final double? connectMs;
  final double? tlsMs;
  final double? ttfbMs;
  final double? domMs;
  final int? httpStatus;
  final double? startDelayMs;
  final int? rebufferCount;
  final double? rebufferMs;
  final double? playedMs;
  final double? bitrateKbps;
  final String? resolution;
  final int? bytes;
  final double? rateMbps;
  final String? direction;

  /// File transfer: `http` or `ftp`.
  final String? protocol;

  /// File transfer: mean serving RSRP / RSCP / RSSI during the transfer.
  final double? servingLevelDbm;

  /// RAT of [servingLevelDbm] (`LTE`, `NR`, `WCDMA`, `GSM`).
  final String? servingRat;

  QoeResult withLevel(double? levelDbm, String? rat) => QoeResult(
    kind: kind,
    label: label,
    target: target,
    status: status,
    error: error,
    totalMs: totalMs,
    dnsMs: dnsMs,
    connectMs: connectMs,
    tlsMs: tlsMs,
    ttfbMs: ttfbMs,
    domMs: domMs,
    httpStatus: httpStatus,
    startDelayMs: startDelayMs,
    rebufferCount: rebufferCount,
    rebufferMs: rebufferMs,
    playedMs: playedMs,
    bitrateKbps: bitrateKbps,
    resolution: resolution,
    bytes: bytes,
    rateMbps: rateMbps,
    direction: direction,
    protocol: protocol,
    servingLevelDbm: levelDbm,
    servingRat: rat,
  );

  /// One-line result, e.g. "1.8 s" or "start 1.2 s · 1 rebuffer".
  String get summary {
    String s(double? ms) =>
        ms == null ? '-' : '${(ms / 1000).toStringAsFixed(1)} s';
    if (status == TestStatus.failed) return 'failed: ${error ?? 'unknown'}';
    return switch (kind) {
      QoeKind.web => 'load ${s(totalMs)}',
      QoeKind.app =>
        'response ${totalMs == null ? '-' : '${totalMs!.round()} ms'}',
      QoeKind.video =>
        'start ${s(startDelayMs)} · ${rebufferCount ?? 0} rebuffer'
            '${(rebufferCount ?? 0) == 1 ? '' : 's'}'
            '${resolution == null ? '' : ' · $resolution'}',
      QoeKind.file =>
        '${protocol == 'ftp' ? 'FTP ' : ''}$direction ${rateMbps == null ? '-' : '${rateMbps!.toStringAsFixed(1)} Mbps'}'
            ' · ${s(totalMs)}',
    };
  }
}

class QoeRecord {
  const QoeRecord({
    required this.id,
    required this.timestamp,
    required this.methodologyVersion,
    required this.result,
    this.sessionId,
    this.measurementId,
  });

  final String id;
  final DateTime timestamp;
  final String methodologyVersion;
  final QoeResult result;
  final String? sessionId;
  final String? measurementId;
}
