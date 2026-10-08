import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';

/// App-bar control: start/stop recording and live sample counter.
class RecordButton extends ConsumerWidget {
  const RecordButton({super.key});

  static const Color recordColor = Color(0xFFC62828);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordingControllerProvider);
    final controller = ref.read(recordingControllerProvider.notifier);
    switch (state.phase) {
      case RecordingPhase.idle:
        return IconButton(
          tooltip: 'Start recording',
          icon: const Icon(Icons.fiber_manual_record_outlined),
          onPressed: controller.start,
        );
      case RecordingPhase.starting:
      case RecordingPhase.stopping:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case RecordingPhase.recording:
        final count = switch (ref.watch(activeSessionProvider)) {
          AsyncData(:final value) => value?.sampleCount ?? 0,
          _ => 0,
        };
        return TextButton.icon(
          onPressed: controller.stop,
          icon: const Icon(Icons.stop_circle, color: recordColor),
          label: Text('REC $count', style: const TextStyle(color: recordColor)),
        );
    }
  }
}
