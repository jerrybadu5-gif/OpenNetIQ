import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/repositories/platform_location_repository.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/errors/measurement_exception.dart';
import 'package:opennetiq_mobile/platform/measurement_channels.dart';

import '../fixtures/location_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const repository = PlatformLocationRepository();

  tearDown(
    () => messenger.setMockStreamHandler(MeasurementChannels.location, null),
  );

  test('passes the interval and maps events', () async {
    Object? listenArguments;
    messenger.setMockStreamHandler(
      MeasurementChannels.location,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          listenArguments = arguments;
          events.success(locationPayload());
          events.success(locationPayload(quality: 'NONE', withFix: false));
          events.endOfStream();
        },
      ),
    );

    final statuses = await repository
        .watchLocation(interval: const Duration(seconds: 2))
        .toList();

    expect(listenArguments, {'interval_ms': 2000});
    expect(statuses.map((s) => s.quality), [GpsQuality.good, GpsQuality.none]);
    expect(statuses.first.fix?.lat, -9.4438);
  });

  test('translates native errors to LocationException', () async {
    messenger.setMockStreamHandler(
      MeasurementChannels.location,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.error(
            code: LocationException.noGnss,
            message: 'This device has no GPS receiver.',
          );
          events.endOfStream();
        },
      ),
    );

    await expectLater(
      repository.watchLocation(),
      emitsError(
        isA<LocationException>()
            .having((e) => e.code, 'code', LocationException.noGnss)
            .having((e) => e.toString(), 'toString', contains('NO_GNSS')),
      ),
    );
  });

  test('malformed payloads surface as FormatException', () async {
    messenger.setMockStreamHandler(
      MeasurementChannels.location,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events.success(<String, Object?>{'provider_enabled': true});
          events.endOfStream();
        },
      ),
    );

    await expectLater(
      repository.watchLocation(),
      emitsError(isA<FormatException>()),
    );
  });

  test('MeasurementException is readable', () {
    expect(
      const MeasurementException('X', 'y').toString(),
      'MeasurementException(X): y',
    );
  });
}
