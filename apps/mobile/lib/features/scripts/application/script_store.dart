import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opennetiq_mobile/domain/entities/test_script.dart';
import 'package:opennetiq_mobile/domain/repositories/speed_test_repository.dart';
import 'package:opennetiq_mobile/features/speed_test/application/speed_test_providers.dart';

/// `app_settings` key holding the saved scripts as a JSON array.
const String scriptsKey = 'scripts.v1';

/// Saved scripts (presets until the user saves one).
class ScriptStore extends AsyncNotifier<List<TestScript>> {
  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  @override
  Future<List<TestScript>> build() async {
    final raw = await ref
        .watch(settingsRepositoryProvider)
        .getSetting(scriptsKey);
    if (raw == null || raw.isEmpty) return presetScripts;
    try {
      return [
        for (final s in jsonDecode(raw) as List)
          TestScript.fromJson((s as Map).cast<String, Object?>()),
      ];
    } on Object {
      return presetScripts; // unreadable: offer presets, keep the raw value
    }
  }

  Future<void> save(TestScript script) async {
    final list = [...await future];
    final i = list.indexWhere((s) => s.id == script.id);
    if (i >= 0) {
      list[i] = script;
    } else {
      list.add(script);
    }
    await _write(list);
  }

  Future<void> delete(String id) async {
    await _write([
      for (final s in await future)
        if (s.id != id) s,
    ]);
  }

  Future<void> _write(List<TestScript> list) async {
    await _settings.setSetting(
      scriptsKey,
      jsonEncode([for (final s in list) s.toJson()]),
    );
    state = AsyncData(List.unmodifiable(list));
  }
}

final scriptStoreProvider =
    AsyncNotifierProvider<ScriptStore, List<TestScript>>(ScriptStore.new);
