import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/core/flavor.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [flavorProvider.overrideWithValue(Flavor.dev)],
      child: const OpenNetIqApp(),
    ),
  );
}
