import 'package:flutter/services.dart';
import 'package:opennetiq_mobile/data/mappers/qoe_mapper.dart';
import 'package:opennetiq_mobile/domain/entities/qoe_test.dart';
import 'package:opennetiq_mobile/domain/repositories/qoe_repository.dart';

class PlatformQoeEngine implements QoeEngine {
  const PlatformQoeEngine({MethodChannel channel = qoeChannel})
    : this._(channel);

  const PlatformQoeEngine._(this._channel);

  static const MethodChannel qoeChannel = MethodChannel('org.opennetiq/qoe');

  final MethodChannel _channel;

  Future<QoeResult> _call(
    String method,
    Map<String, Object?> args,
    QoeKind kind,
    String label,
    String target,
  ) async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>(method, args);
      return QoeMapper.fromMap(kind, label, target, m ?? const {});
    } on PlatformException catch (e) {
      return QoeMapper.fromMap(kind, label, target, {
        'error': e.message ?? e.code,
      });
    }
  }

  @override
  Future<QoeResult> web(QoeTarget t, {required Duration timeout}) => _call(
    'web',
    {'url': t.url, 'timeout_ms': timeout.inMilliseconds},
    QoeKind.web,
    t.name,
    t.url,
  );

  @override
  Future<QoeResult> video(QoeTarget t, {required Duration duration}) => _call(
    'video',
    {
      'url': t.url,
      'mode': t.mode.wireValue,
      'duration_ms': duration.inMilliseconds,
    },
    QoeKind.video,
    t.name,
    t.url,
  );

  @override
  Future<QoeResult> app(QoeTarget t) =>
      _call('app', {'url': t.url}, QoeKind.app, t.name, t.url);

  @override
  Future<QoeResult> file({
    required String serverUrl,
    required int sizeMib,
    required bool upload,
  }) => _call(
    'file',
    {
      'server_url': serverUrl,
      'size_mib': sizeMib,
      'direction': upload ? 'upload' : 'download',
    },
    QoeKind.file,
    '$sizeMib MB ${upload ? 'upload' : 'download'}',
    serverUrl,
  );

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}
