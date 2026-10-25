import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';

/// Native QoE probes (MethodChannel `org.opennetiq/qoe`).
abstract interface class QoeEngine {
  Future<QoeResult> web(QoeTarget target, {required Duration timeout});

  Future<QoeResult> video(QoeTarget target, {required Duration duration});

  Future<QoeResult> app(QoeTarget target);

  Future<QoeResult> file({
    required String serverUrl,
    required int sizeMib,
    required bool upload,
  });

  /// FTP download ([upload] false) or upload of [sizeMib] MiB (M14).
  Future<QoeResult> ftp({
    required String url,
    required String user,
    required String password,
    required int sizeMib,
    required bool upload,
    required Duration maxDuration,
  });

  Future<void> cancel();
}

abstract interface class QoeStore {
  Future<void> saveQoeTests(List<QoeRecord> records);

  Stream<List<QoeRecord>> watchQoeTests({int limit = 50});
}
