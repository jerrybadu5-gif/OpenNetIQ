import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/app_routes.dart';
import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/features/recording/application/recording_controller.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_runner.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_store.dart';

/// Test scripts (issue #28): saved scripts, run status and log.
class ScriptsScreen extends ConsumerWidget {
  const ScriptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptStoreProvider);
    final run = ref.watch(scriptRunnerProvider);
    final recording = ref.watch(recordingControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Test scripts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.scriptEditor()),
        icon: const Icon(Icons.add),
        label: const Text('New script'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                recording.isActive
                    ? Icons.fiber_manual_record
                    : Icons.info_outline,
              ),
              title: Text(
                recording.isActive
                    ? 'Results link to recording '
                          '"${recording.sessionName ?? ''}"'
                    : 'No recording open',
              ),
              subtitle: Text(
                recording.isActive
                    ? 'Each test is tagged with the drive position at its start.'
                    : 'Start a drive test first to map script results.',
              ),
            ),
          ),
          if (run.script != null) RunCard(run: run),
          const SizedBox(height: 8),
          switch (scripts) {
            AsyncData(:final value) => Column(
              children: [
                for (final s in value)
                  ScriptTile(script: s, canRun: !run.running),
              ],
            ),
            AsyncError(:final error) => Text('Could not load scripts: $error'),
            _ => const LinearProgressIndicator(),
          },
        ],
      ),
    );
  }
}

class ScriptTile extends ConsumerWidget {
  const ScriptTile({required this.script, required this.canRun, super.key});

  final TestScript script;
  final bool canRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      title: Text(script.name),
      subtitle: Text(script.summary),
      onTap: () => context.push(AppRoutes.scriptEditor(script.id)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Run ${script.name}',
            icon: const Icon(Icons.play_arrow),
            onPressed: canRun
                ? () => ref.read(scriptRunnerProvider.notifier).start(script)
                : null,
          ),
          IconButton(
            tooltip: 'Delete ${script.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: canRun
                ? () => ref.read(scriptStoreProvider.notifier).delete(script.id)
                : null,
          ),
        ],
      ),
    ),
  );
}

class RunCard extends ConsumerWidget {
  const RunCard({required this.run, super.key});

  final ScriptRunState run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = run.script!;
    final theme = Theme.of(context);
    final cycles = script.unlimited ? '∞' : '${script.cycles}';
    final waiting = run.waitingUntil;
    final message = run.message;
    return Card(
      color: run.running ? theme.colorScheme.secondaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(script.name, style: theme.textTheme.titleMedium),
                ),
                if (run.running)
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(scriptRunnerProvider.notifier).stop(),
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
              ],
            ),
            if (run.running) ...[
              Text('Cycle ${run.cycle} of $cycles'),
              Text(
                waiting == null
                    ? 'Now: ${run.stepLabel}'
                    : 'Next cycle at ${formatLocalDateTime(waiting)}',
              ),
              const SizedBox(height: 6),
              const LinearProgressIndicator(),
            ],
            if (message != null) Text(message),
            if (run.log.isNotEmpty) ...[
              const Divider(),
              for (final e in run.log.reversed.take(30))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e.ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: e.ok ? null : theme.colorScheme.error,
                  ),
                  title: Text('${e.cycle}. ${e.step}'),
                  subtitle: Text(
                    '${formatLocalDateTime(e.time)} · ${e.summary}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
