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
- Removes all enabled, non-equipped item classes with the verified
  `DeleteItemOfClass(classId, count)` inventory API.
- Recounts every mutated class and reports a compact verification summary.
- Removes repair kits and bandages by default; potion removal is implemented
  but disabled until its rule receives a dedicated gameplay test.
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
  Bandages
  Potions
  Repair Kits
Debug
  Enable
```

All controls apply immediately and persist through the global KCDUtils LuaDB
namespace `gravesense`. Records created by the earlier master-toggle-only build
remain valid; missing fields fall back to `Config.lua` until the next MCM change
writes the complete settings record.

## Diagnostic output

A successful mutation produces one line per affected NPC:

```text
[GraveSense][INFO] tneb_kozlik processed: repairKits=1 potions=0 bandages=3 removed=4 failed=0 verified=true
```

Set `logging.debug` and `logging.itemDetails` to `true` for development details.

Lifecycle transitions are intentionally visible without per-tick spam:

```text
[GraveSense][INFO] polling paused: gameover
[GraveSense][INFO] polling resumed: gameover
[GraveSense][INFO] polling paused: skiptime
[GraveSense][INFO] polling resumed: skiptime
```
