# ADR-017: Share exports with share_plus

## Context
Phase 1 exports (#23) must reach Excel/QGIS without a backend. Options:
Storage Access Framework "save as" (native code per file), writing to shared
storage (needs care with scoped storage, leaves copies behind), or the
Android share sheet.

## Decision
Write files to the app cache (`exports/`, replaced on each export) and hand
them to the share sheet with `share_plus` (BSD-3-Clause, Flutter Community),
behind the `FileSharer` interface.

## Consequences
- One code path covers Drive, e-mail, Files ("save to device"), Bluetooth.
- No storage permission; nothing is left in public storage.
- The user picks the destination each time; batch/automatic upload is Phase
  2 (sync API).
- Replaceable: a SAF-based `FileSharer` can be added without UI changes.
