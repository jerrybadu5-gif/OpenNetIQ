import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/data/repositories/platform_location_repository.dart';
import 'package:opennetiq_mobile/domain/entities/location_status.dart';
import 'package:opennetiq_mobile/domain/repositories/location_repository.dart';
import 'package:opennetiq_mobile/features/signal_monitor/application/signal_monitor_providers.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => const PlatformLocationRepository(),
);

/// Live GNSS status at the measurement interval. Starts only once precise
/// location is granted; auto-disposed so GPS stops with the screen.
final locationStatusProvider = StreamProvider<LocationStatus>(
  (ref) {
    final permissions = ref.watch(radioPermissionsProvider);
    if (permissions case AsyncData(:final value) when value.location) {
      return ref
          .watch(locationRepositoryProvider)
          .watchLocation(interval: ref.watch(radioIntervalProvider));
    }
    return const Stream<LocationStatus>.empty();
  },
  isAutoDispose: true,
  retry: (retryCount, error) => null,
);
