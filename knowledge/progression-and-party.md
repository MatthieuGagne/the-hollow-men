---
summary: Progression XP math (xp_to_next, apply_xp, grown_stat, level curve BASE_XP 100 exponent 1.5) and PartyManager progression store — award_xp, add_member_at_level, snapshot/restore roster and progression, reset_to_new_game (issue #141 Tasks 1, 6, 17)
tags: [progression, party, xp, godot, gdscript, autoload]
---

# Progression & PartyManager

## Progression Utility (issue #141, Task 1, 2026-06-15)

- `Progression` (`scripts/battle/progression.gd`) — `class_name`, extends RefCounted; pure static math, no autoload/engine state. `const BASE_XP=100`, `CURVE_EXPONENT=1.5`, `MAX_LEVEL=99`
- `xp_to_next(level) -> int`: `roundi(BASE_XP * pow(level, 1.5))`; returns 0 at/after MAX_LEVEL. L1→100, L2→283
- `apply_xp(level, xp, gain) -> {"level","xp"}`: loops crossing thresholds, carries remainder, zeroes xp at cap
- `grown_stat(base, growth, level) -> base + growth * (level - 1)` (base at L1)
- Confirms the stale-class-registry rule (see [[scene-and-resource-serialization]]): GUT showed `Identifier "Progression" not declared` on FIRST run AND the post-implement run until `godot_console --headless --import` registered the class (look for "update_scripts_classes | Progression"). Always reimport after adding a new `class_name` before re-running GUT

## PartyManager progression store (issue #141, Task 6, 2026-06-15)

- `PartyManager` (`scripts/autoload/party_manager.gd`, plain autoload Node, no `class_name`) holds `_progression: Dictionary` keyed by id → `{"level":int,"xp":int}` for ALL player characters (even non-party). `_ready` calls `_seed_progression()` (iterates `GameData.get_player_character_ids()`, only fills missing ids) THEN seeds Reid combatant
- Methods: `get_level/get_xp(id)` (default `{level:1,xp:0}`), `set_progression(id,level,xp)`, `award_xp(members:Array[Combatant], amount) -> Array[Dictionary]` (per member: `Progression.apply_xp`, store result, `set_level` + append `{name,to}` on level-up else `m.level = result.level`), `add_member_at_level(id,level)` (seed + from_definition + set_level + append), `snapshot_progression()` (deep dup), `restore_progression(data)` (re-seed baseline then overwrite), `snapshot_roster() -> Array[String]` (permanent ids only), `restore_roster(ids)` (clears both arrays, empty→`["reid"]` legacy fallback, from_definition + set_level(get_level(id)))
- GUT before_each must reset progression too: `_progression.clear()` + `_seed_progression()` (alongside the two member-array clears) — see [[gut-testing]]
- No reimport needed (plain autoload, not a class_name surface change). Full suite at the time: 479 tests, 479 pass, 0 fail

## PartyManager.reset_to_new_game + new_game wiring (issue #141, Task 17, 2026-06-15)

- `PartyManager.reset_to_new_game()` is the single clean-party source: clears `_permanent_members`/`_temporary_members`/`_progression`, `_seed_progression()`, then appends Reid combatant. `_ready()` now just calls it (a fresh boot IS a new game — DRY, identical behavior since boot dicts are already empty)
- `SaveManager.new_game()` calls `PartyManager.reset_to_new_game()` after `GameState.clear_flags()`, before `game_loaded.emit(-1)`. Fixes the review bug: loading a Lv5/Iris save then New Game previously left Reid Lv5 + Iris in party (new_game only cleared flags) — see [[save-system]]
- Plain autoload (no `class_name`) → no reimport needed. test_party_manager.gd before_each does NOT add Reid, so existing empty-roster tests still hold; do not change before_each

## Related

- [[combatants-and-definitions]] — growth fields consumed by `grown_stat`, `set_level`
- [[battle-scene-state-machine]] — victory XP award calls `award_xp`
- [[save-system]] — roster/progression persistence, runtime snapshot
- [[battle-context-and-world-triggers]] — BossTrigger's `add_member_at_level("iris", ...)`
