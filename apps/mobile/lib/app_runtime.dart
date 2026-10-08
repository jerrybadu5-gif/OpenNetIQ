import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_pipeline.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';

/// Screen-independent background work of the app-wide container (ADR-014):
/// recording pipeline, crash recovery, speed-test radio capture.
void startAppRuntime(ProviderContainer container) {
  startRecordingRuntime(container);
  container.listen<void>(speedTestPipelineProvider, (previous, next) {});
}
