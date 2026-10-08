import 'package:opennetiq_mobile/domain/entities/location_status.dart';

abstract interface class LocationRepository {
  /// One [LocationStatus] per interval. Errors are [LocationException]s.
  Stream<LocationStatus> watchLocation({
    Duration interval = const Duration(seconds: 1),
  });
}
