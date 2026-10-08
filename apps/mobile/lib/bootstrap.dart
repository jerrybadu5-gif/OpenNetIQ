import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/app.dart';
import 'package:opennetiq_mobile/core/flavor.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_pipeline.dart';

/// Shared entrypoint body. The container is created outside the widget tree
/// so the recording runtime does not depend on any screen (ADR-014).
void bootstrap(Flavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [flavorProvider.overrideWithValue(flavor)],
  );
  startRecordingRuntime(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OpenNetIqApp(),
    ),
  );
}
