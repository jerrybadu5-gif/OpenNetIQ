import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:opennetiq_mobile/core/uuid7.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/features/scripts/application/script_store.dart';

/// Create or edit a test script (issue #28). [scriptId] null = new script.
class ScriptEditorScreen extends ConsumerWidget {
  const ScriptEditorScreen({this.scriptId, super.key});

  final String? scriptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptStoreProvider);
    return switch (scripts) {
      AsyncData(:final value) => ScriptEditor(
        initial:
            value.where((s) => s.id == scriptId).firstOrNull ??
            TestScript(id: uuid7(), name: '', steps: const []),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not load scripts: $error')),
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class ScriptEditor extends ConsumerStatefulWidget {
  const ScriptEditor({required this.initial, super.key});

  final TestScript initial;

  @override
  ConsumerState<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends ConsumerState<ScriptEditor> {
  /// Fixed at open so a provider rebuild cannot change the script id.
  late final TestScript _base = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);
  late final _cycles = TextEditingController(text: '${widget.initial.cycles}');
  late final _interval = TextEditingController(
    text: widget.initial.cycleIntervalSeconds == null
        ? '2'
        : '${widget.initial.cycleIntervalSeconds! / 60}'.replaceAll(
            RegExp(r'\.0$'),
            '',
          ),
  );
  late List<ScriptStep> _steps = [...widget.initial.steps];
  late bool _useInterval = widget.initial.cycleIntervalSeconds != null;
  List<String> _problems = const [];

  @override
  void dispose() {
    _name.dispose();
    _cycles.dispose();
    _interval.dispose();
    super.dispose();
  }

  TestScript _current() {
    final minutes = double.tryParse(_interval.text.trim());
    return _base.copyWith(
      name: _name.text.trim(),
      steps: _steps,
      cycles: int.tryParse(_cycles.text.trim()) ?? -1,
      cycleIntervalSeconds: () => !_useInterval
          ? null
          : minutes == null
          ? 0
          : (minutes * 60).round(),
    );
  }

  Future<void> _addStep(StepType type) async {
    var step = ScriptStep(type);
    if (type == StepType.wait) {
      final seconds = await _askSeconds();
      if (seconds == null) return;
      step = ScriptStep(type, seconds: seconds);
    }
    setState(() => _steps = [..._steps, step]);
  }

  Future<int?> _askSeconds() {
    final controller = TextEditingController(text: '60');
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wait (seconds)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(int.tryParse(controller.text)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _move(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _steps.length) return;
    setState(() {
      final list = [..._steps];
      final s = list.removeAt(i);
      list.insert(j, s);
      _steps = list;
    });
  }

  Future<void> _save() async {
    final script = _current();
    final problems = script.validate();
    setState(() => _problems = problems);
    if (problems.isNotEmpty) return;
    await ref.read(scriptStoreProvider.notifier).save(script);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_base.name.isEmpty ? 'New script' : 'Edit script'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Script name'),
          ),
          const SizedBox(height: 16),
          Text('Steps', style: theme.textTheme.titleMedium),
          if (_steps.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No steps yet.'),
            ),
          for (var i = 0; i < _steps.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(_steps[i].label),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: i == 0 ? null : () => _move(i, -1),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: i == _steps.length - 1
                        ? null
                        : () => _move(i, 1),
                  ),
                  IconButton(
                    tooltip: 'Remove step',
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _steps = [..._steps]..removeAt(i)),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<StepType>(
              tooltip: 'Add step',
              onSelected: _addStep,
              itemBuilder: (context) => [
                for (final t in StepType.values)
                  PopupMenuItem(
                    value: t,
                    enabled: t.available,
                    child: Text(t.available ? t.label : '${t.label} (coming)'),
                  ),
              ],
              child: const Chip(
                avatar: Icon(Icons.add),
                label: Text('Add step'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Repeat', style: theme.textTheme.titleMedium),
          TextField(
            controller: _cycles,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Cycles',
              helperText: '0 = until stopped',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start each cycle on a fixed interval'),
            value: _useInterval,
            onChanged: (on) => setState(() => _useInterval = on),
          ),
          if (_useInterval)
            TextField(
              controller: _interval,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Interval (minutes)',
              ),
            ),
          for (final p in _problems)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p, style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
