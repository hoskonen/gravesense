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
- Removes repair kits and bandages by default; potion removal is implemented
  but disabled until its rule receives a dedicated gameplay test.
- Owns cancellable heartbeat/combat timers and pauses them during Game Over and
  SkipTime (sleep/wait) UI sequences.

Settings are in `Data/Scripts/GraveSense/Config.lua`. The settings table is kept
independent from the runtime so a Mod Configuration Menu adapter can be added
without changing inventory logic.

## Mod Configuration Menu

When MCM is installed, GraveSense registers a `General` category containing an
`Enable Grave Sense` toggle. It applies immediately and persists through the
global KCDUtils LuaDB namespace `gravesense`. A missing or invalid saved value falls
back to `Config.lua`; with MCM absent, GraveSense continues using the persisted
value and `Config.lua` normally.

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
