---
summary: BattleContext autoload handoff, BattleEncounter, RandomEncounterController random encounters, BossTrigger, TestRoom return bookkeeping, TestRoom.tscn assembly, Player.stepped signal (issues #119, #141 Tasks 11-16)
tags: [battle, world, godot, gdscript, encounters, autoload]
---

# BattleContext & World Triggers

How the overworld hands off into battles and books the results on return.

## BattleContext Handoff (issue #119)

- `BattleContext` autoload (`scripts/autoload/battle_context.gd`), no `class_name` (would collide with the autoload name in Godot 4)
- `configure(p_enemies, p_background_id, p_return_scene, p_return_spawn)` — all default `""`; always overwrites all four fields, so `configure()` with no args is the GUT `before_each` reset
- `enemies` is a comma-separated string of **combatant ids** resolved via `GameData.get_definition(id)` (not .tres paths)
- Non-destructive read design: BattleScene reads fields without clearing them, so defeat→retry reload reuses the same encounter. The producer (CutsceneZone/BattleEncounter) owns clearing by always fully configuring a fresh context — a narrative-only zone CLEARS stale enemy tables rather than preserving them
- `BattleScene._spawn_enemies()` falls back to `GameData.get_definition("shade")` when `BattleContext.enemies` is empty; `BattleEncounter` (`scripts/world/battle_encounter.gd`) has the same explicit producer-side fallback (`static _resolve_enemies(custom)` → `DEFAULT_ENEMIES` "shade"), reads `scene.scene_file_path` for return_scene, then one atomic `configure(...)`
- Static methods callable via instance OR via `const C := preload(...)` in GUT tests

## Player.stepped signal (issue #141, Task 11, 2026-06-15)

- `Player` (`scripts/world/player.gd`) emits `signal stepped(cell: Vector2i)` after a committed grid move: one `stepped.emit(target_cell)` line appended to the successful-move block in `_try_move` (after the wall/blocked early-return, so blocked moves never emit). `target_cell` already computed at top of `_try_move`; reused, not recomputed
- **Test gotcha:** `_is_wall()` treats an EMPTY cell (null `get_cell_tile_data`) as a wall → a bare `TileMapLayer` with just a TileSet blocks every move and `_try_move` early-returns BEFORE the emit. To test a committed move you MUST place a non-wall floor tile at the target: `TileSetAtlasSource` + `PlaceholderTexture2D(16×16)` + `atlas.create_tile((0,0))` + `tile_set.add_source(atlas)` + `layer.set_cell(target_cell, source_id, (0,0))`. The tile has no `class=="wall"` meta so `_is_wall` returns false
- Adding a `signal` to a `class_name` is a registry-surface change BUT did not require reimport here — the first post-impl run already saw the signal (error went from "does not have the signal" to "did not emit", which was the wall-block issue, not stale registry). See [[scene-and-resource-serialization]]

## RandomEncounterController (issue #141, Task 13, 2026-06-15)

- `RandomEncounterController` (`scripts/world/random_encounter_controller.gd`) — `class_name`, extends Node; placed as sibling of `Player`. `_ready()` resolves `get_parent().get_node_or_null("Player")` and connects to its `stepped` signal (guarded by `has_signal`)
- PURE static testables: `should_trigger(steps, grace, chance, roll) -> bool` (false within grace `steps <= grace`, else `roll < chance`); `build_comp(a, b) -> String` ("a,b" comma-joined for BattleContext)
- `_on_stepped`: early-returns once `GameState.get_flag(WINS_FLAG,0) >= required_wins` (boss phase); else increments `_steps`, rolls `randf()`, on trigger resets `_steps=0`, builds comp from `POOL[randi()%size]` ×2, sets `test_room_pending_random` flag, `BattleContext.configure(comp, bg, return_scene, return_spawn)`, `SceneManager.change_scene`
- Consts (post-Task 18): POOL=["security_rookie"] (Shade + guard dropped from harness), GRACE_STEPS=3, TRIGGER_CHANCE=0.25, WINS_FLAG="test_room_random_wins", PENDING_FLAG="test_room_pending_random". Exports: battle_background="alley", return_scene/return_spawn, required_wins=3
- Confirmed stale-registry rule again: new `class_name` → GUT `Identifier "RandomEncounterController" not declared` until `--import` (saw update_scripts_classes). Full suite 497/497 after

## BossTrigger (issue #141, Task 14, 2026-06-15)

- `BossTrigger` (`scripts/world/boss_trigger.gd`) — `class_name`, extends Area2D; gated test-room boss zone. `_ready` connects `body_entered`
- PURE static testable: `can_trigger(wins, required, complete) -> bool` (false if complete, else `wins >= required`) — the only unit-tested part (2 tests, no engine state, before_each just `GameState.clear_flags()`)
- `_on_body_entered`: guard `_fired or not body is Player` → read WINS_FLAG/COMPLETE_FLAG → `can_trigger` gate → `_fired=true` → if `not PartyManager.has_member("Iris")` add `add_member_at_level("iris", get_level("reid"))` (note: has_member takes character_name "Iris", add_member_at_level takes id "iris") → set PENDING_BOSS_FLAG → `BattleContext.configure(boss_enemies, bg, return_scene, return_spawn)` → `SceneManager.change_scene`
- Task 18: boss enemy is now `@export var boss_enemies: String = "security_captain,security_rookie"` (was hardcoded "territory_enforcer"). TestRoom.tscn BossTrigger node sets it explicitly for documentation
- Consts: WINS_FLAG/PENDING_BOSS_FLAG/COMPLETE_FLAG = the Task 12 harness flags (see [[save-system]] for KnownFlags). Exports: required_wins=3, battle_background="alley", return_scene="", return_spawn="default"
- Stale-registry rule again: new `class_name` → GUT parse error "Identifier BossTrigger not declared" until `--import` (saw update_scripts_classes | BossTrigger). Full suite 499/499 after

## TestRoom return bookkeeping (issue #141, Task 15, 2026-06-15)

- `TestRoom` (`scripts/world/test_room.gd`) — `class_name TestRoom extends BaseRoom`; `_ready()` calls `resolve_return_bookkeeping()` THEN `super._ready()`
- `static func resolve_return_bookkeeping()` (static so tests skip scene instantiation): pending_random → clear it + bump WINS_FLAG (int); pending_boss → clear it + set COMPLETE_FLAG true. Victory is the only path back to the room, so a set pending flag means a win
- Consts: WINS_FLAG/PENDING_RANDOM_FLAG/PENDING_BOSS_FLAG/COMPLETE_FLAG = the Task 12 harness flags
- Stale-registry rule again: new `class_name` → GUT parse error "Identifier TestRoom not declared" until `--import` (saw update_scripts_classes | TestRoom). Full suite 503/503 after (4 new tests)

## TestRoom.tscn assembly (issue #141, Task 16, 2026-06-15)

- `scenes/world/TestRoom.tscn` mirrors `RoomPOC.tscn`: root instances `BaseRoom.tscn` + `script=test_room.gd`, instances map `res://maps/room_poc.tmx` (uid `uid://cqsd50e1c7p52`, node name `room_poc`, `world_layer_path=NodePath("room_poc/World")`), a `DefaultSpawn` (SpawnPoint.tscn, spawn_id "default" @ (120,88)). Adds `RandomEncounters` (Node, random_encounter_controller.gd) + `BossTrigger` (Area2D, boss_trigger.gd @ (56,88) with ColorRect marker + CollisionShape2D RectangleShape2D 16×16). RandomEncounters/BossTrigger return_scene="res://scenes/world/TestRoom.tscn", required_wins=3
- `load_steps=8` = 6 ext_resources + 1 sub_resource + 1. Godot recomputes on save anyway
- Headless scene-load check (`--quit-after 3 res://scenes/world/TestRoom.tscn`) is clean: the only TestRoom line is a benign recoverable "invalid UID … using text path instead: res://maps/room_poc.tmx" WARNING (resource_format_text.cpp:500) — same class as the DialogueManager/GUT UID warnings, NOT an ERROR. Map still loads. Interactive walk/fight/save-load smoketest is headless-impossible — defer to a human
- Beware the instanced-scene script-override gotcha and the stale-uid `.tmx` reference wart when editing room scenes — see [[scene-and-resource-serialization]]

## Related

- [[battle-scene-state-machine]] — the battle these triggers configure
- [[dialogue-and-cutscenes]] — CutsceneZone as the other BattleContext producer
- [[save-system]] — KnownFlags manifest for the harness flags
- [[progression-and-party]] — `add_member_at_level`, win-loop XP
