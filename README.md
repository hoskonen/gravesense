# GraveSense

GraveSense makes enemy loot scarcer by applying configurable rules to a living
NPC's inventory during combat, before the corpse inventory UI is available.

## Current 2026 runtime

- Scans nearby living actors only while the player is in combat.
- Selects damaged actors using health threshold/change detection.
- Processes each actor WUID once per loaded gameplay session.
- Removes all enabled, non-equipped item classes with the verified
  `DeleteItemOfClass(classId, count)` inventory API.
- Recounts every mutated class and reports a compact verification summary.
- Removes repair kits by default; potion removal is implemented but disabled.

Settings are in `Data/Scripts/GraveSense/Config.lua`. The settings table is kept
independent from the runtime so a Mod Configuration Menu adapter can be added
without changing inventory logic.

## Diagnostic output

A successful mutation produces one line per affected NPC:

```text
[GraveSense][INFO] tneb_kozlik processed: repairKits=1 potions=0 removed=1 failed=0 verified=true
```

Set `logging.debug` and `logging.itemDetails` to `true` for development details.
