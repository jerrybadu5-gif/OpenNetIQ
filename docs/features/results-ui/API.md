# API: results UI (#22)

No platform channel, database or HTTP changes.

## Dart

| Symbol | Contract |
|---|---|
| `TestServer({name, url, kind})` | `url` is a LibreSpeed-compatible base URL (engine appends `garbage.php` / `empty.php`). |
| `TestServer.matches(url)` | Case-insensitive, trailing slash ignored. |
| `publicTestServers` | Volunteer LibreSpeed backends; `kind = public`. |
| `testServerPresets({buildDefault})` | `own` build default first (if non-empty), then public servers. |
| `presetFor(presets, url)` | Matching preset or `null` (custom server). |
| `testServerPresetsProvider` | `Provider<List<TestServer>>`. |
| `ThroughputChart({download, upload})` | Lists of `SpeedTestProgress`; renders nothing when both are empty. |
| `RttChart({rttsMs})` | One entry per probe, `null` = lost; renders nothing when empty. |
