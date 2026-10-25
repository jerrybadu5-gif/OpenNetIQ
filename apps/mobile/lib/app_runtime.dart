import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/features/latency_test/application/latency_test_controller.dart';
import 'package:opennetiq_mobile/features/qoe/application/qoe_controller.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_pipeline.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_controller.dart';
import 'package:opennetiq_mobile/features/voice_sms/application/voice_sms_controller.dart';

/// Screen-independent background work of the app-wide container (ADR-014):
/// recording pipeline, crash recovery, radio capture for active tests.
void startAppRuntime(ProviderContainer container) {
  startRecordingRuntime(container);
  container
    ..listen<void>(speedTestPipelineProvider, (previous, next) {})
    ..listen<void>(latencyTestPipelineProvider, (previous, next) {})
    ..listen<void>(qoeTestPipelineProvider, (previous, next) {})
    ..listen<void>(voiceSmsPipelineProvider, (previous, next) {});
}
