import 'dart:async';

import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/repositories/qoe_repository.dart';
import 'package:opennetiq_mobile/features/recording/application/test_context.dart';

QoeResult qoeOk(QoeKind kind, String label, {double totalMs = 1000}) =>
    QoeResult(
      kind: kind,
      label: label,
      target: 'https://$label.test/',
      status: TestStatus.ok,
      totalMs: totalMs,
    );

/// Records calls; [gate] lets a test hold a call open.
class FakeQoeEngine implements QoeEngine {
  final calls = <String>[];
  Completer<void>? gate;
  int cancels = 0;

  Future<void> _wait() async => gate?.future;

  @override
  Future<QoeResult> web(QoeTarget t, {required Duration timeout}) async {
    calls.add('web:${t.name}:${timeout.inSeconds}');
    await _wait();
    return qoeOk(QoeKind.web, t.name);
  }

  @override
  Future<QoeResult> video(QoeTarget t, {required Duration duration}) async {
    calls.add('video:${t.name}:${duration.inSeconds}');
    await _wait();
    return QoeResult(
      kind: QoeKind.video,
      label: t.name,
      target: t.url,
      status: TestStatus.ok,
      startDelayMs: 900,
      rebufferCount: 1,
      resolution: '720p',
    );
  }

  @override
  Future<QoeResult> app(QoeTarget t) async {
    calls.add('app:${t.name}');
    await _wait();
    return qoeOk(QoeKind.app, t.name, totalMs: 250);
  }

  @override
  Future<QoeResult> file({
    required String serverUrl,
    required int sizeMib,
    required bool upload,
  }) async {
    calls.add('file:$sizeMib:${upload ? 'up' : 'down'}:$serverUrl');
    await _wait();
    return QoeResult(
      kind: QoeKind.file,
      label: '$sizeMib MB ${upload ? 'upload' : 'download'}',
      target: serverUrl,
      status: TestStatus.ok,
      totalMs: 2000,
      rateMbps: 21,
      direction: upload ? 'upload' : 'download',
    );
  }

  @override
  Future<void> cancel() async => cancels++;
}

class FakeTestContext extends TestContextService {
  FakeTestContext(super.ref);

  final links = <String>[];
  Object? linkError;

  @override
  DateTime now() => DateTime.utc(2026, 10, 25, 1);

  @override
  Future<RadioSnapshot?> awaitRadio(bool Function() stillRunning) async => null;

  @override
  LocationStatus? latestLocation() => null;

  @override
  Future<TestLink> link({
    required String label,
    required DateTime startedAt,
    required RadioSnapshot? radio,
    required LocationStatus? location,
  }) async {
    final e = linkError;
    if (e != null) throw e;
    links.add(label);
    return (sessionId: null, measurementId: null);
  }
}

const smallSettings = QoeSettings(
  web: [QoeTarget('Google', 'https://www.google.com/')],
  apps: [
    QoeTarget('WhatsApp', 'https://web.whatsapp.com/'),
    QoeTarget('BSP', 'https://www.bsp.com.pg/'),
  ],
  videos: [
    QoeTarget('YouTube clip', 'https://youtu.be/x', mode: VideoMode.page),
  ],
  fileSizeMib: 2,
  videoSeconds: 20,
);
