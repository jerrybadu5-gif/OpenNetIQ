import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Flavor {
  dev,
  prod;

  String get label => switch (this) {
    Flavor.dev => 'OpenNetIQ Dev',
    Flavor.prod => 'OpenNetIQ',
  };
}

/// Overridden at startup by the flavor entrypoint.
final flavorProvider = Provider<Flavor>((ref) => Flavor.dev);
