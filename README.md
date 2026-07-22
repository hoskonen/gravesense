# GraveSense

GraveSense makes enemy loot scarcer by tracking damaged NPCs during combat and
applying configurable rules immediately after they die, before the corpse
inventory UI is available.

## Current 2026 runtime

- Scans nearby actors only while the player is in combat.
- Selects damaged actors using health threshold/change detection, including
  lethal transitions between combat scans.
- Retains selected entity/WUID references through death and briefly after combat.
- Uses a lightweight 100 ms watcher only while selected actors remain alive.
- Processes each dead actor WUID once per loaded gameplay session.
- Applies an independent, configurable 0-100% removal chance to each eligible
  item without changing the game's global random state.
- Removes selected, non-equipped item quantities with the verified
  `DeleteItemOfClass(classId, count)` inventory API.
- Recounts every mutated class and reports a compact verification summary.
- Repair kits, potions, and bandages default to 100%; setting a category to 0%
  disables it.
- Owns cancellable heartbeat/combat timers and pauses them during Game Over and
  SkipTime (sleep/wait) UI sequences.

Settings are in `Data/Scripts/GraveSense/Config.lua`. The settings table is kept
independent from the runtime so a Mod Configuration Menu adapter can be added
without changing inventory logic.

## Mod Configuration Menu

When MCM is installed, GraveSense provides this layout:

```text
General
  Enable
Item Categories
  Bandages       0-100%
  Potions        0-100%
  Repair Kits    0-100%
Debug
  Enable
```

All controls apply immediately and persist through the global KCDUtils LuaDB
namespace `gravesense`. Earlier category checkboxes migrate directly to 0% or
100%, and records created by the master-toggle-only build remain valid. Missing
fields fall back to `Config.lua` until the next MCM change writes the complete
settings record.

## Diagnostic output

A successful mutation produces one line per affected NPC:

```text
[GraveSense][INFO] tneb_kozlik processed: repairKits=1 potions=0 bandages=3 removed=4 failed=0 verified=true
```

Enable Debug in MCM (or set `logging.debug` to `true`) for per-item probability
and mutation details.

Lifecycle transitions are intentionally visible without per-tick spam:

```text
[GraveSense][INFO] polling paused: gameover
[GraveSense][INFO] polling resumed: gameover
[GraveSense][INFO] polling paused: skiptime
[GraveSense][INFO] polling resumed: skiptime
```
