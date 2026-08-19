---
summary: Save system — SaveData versioning (v1-v4), SaveManager save/read/load/apply/new_game, KnownFlags manifest validation, PartyMemberSave runtime snapshot/restore, exact player position/facing restore, BaseRoom guard, debug save driver F5/F9/F10 (issues #122, #123, #141, #146, #93)
tags: [save, persistence, godot, gdscript, autoload, flags]
---

# Save System

## SaveData (issue #122; v2 fields from #141 Task 8)

- `SaveData` (`scripts/save/save_data.gd`) — `class_name`, extends Resource; `@export` fields (v2, #141 Task 8): `save_version:int=2`, `flags:Dictionary`, `current_scene:String`, `spawn_point:String`, `roster:Array[String]=[]` (active permanent ids in order), `progression:Dictionary={}` (`{id:{level,xp}}`). Legacy v1 .tres loads default roster→[]/progression→{}. Editing this class_name surface hit the stale-registry pitfall — reimport before re-running GUT (see [[scene-and-resource-serialization]])
- SaveData default save_version=2 did NOT break `test_save_manager.gd:36` (`data.save_version == SaveManager.CURRENT_VERSION`, still 1 at the time): `SaveManager.save()` explicitly sets `data.save_version = CURRENT_VERSION` before writing, so the round-trip asserts 1==1. CURRENT_VERSION bump + migration was Task 9

## KnownFlags (issue #122)

- `KnownFlags` (`scripts/save/known_flags.gd`) — `class_name`, RefCounted; `const MANIFEST` flag→TYPE_* map; static `validate(flags) -> {"warnings":Array[String], "errors":Array[String]}` (unknown flag = warning, type mismatch = error). Numeric flags use TYPE_FLOAT (Yarn bridge)
- Harness flags (issue #141, Task 12): `test_room_random_wins`=TYPE_INT, `test_room_pending_random`/`test_room_pending_boss`/`test_room_harness_complete`=TYPE_BOOL. The INT one is the only non-FLOAT numeric flag (set in GDScript, not via the Yarn bridge, so TYPE_INT is correct — Yarn numerics still need TYPE_FLOAT)
- Narrative flags (issue #93, Task 2, 2026-07-25): 7 new `TYPE_BOOL` entries — 5 Intro Beats 1-2 flags (`rooftop_beat_complete`, `beat2_vera_spoken`, `heights_notice_examined`, `heights_shopfront_examined`, `ley_terminal_noticed`) + 2 `CutsceneZone` `fire_on_scene_load` auto-flags (`zone_played_rooftop_surveillance`, `zone_played_sprawl_aftermath_beat4`)
- `zone_played_sprawl_aftermath_beat4` was a live bug fix, not new work: the existing `sprawl_safehouse.tmx` zone had generated this auto-flag (`"zone_played_" + dialogue_node`, see `scripts/world/cutscene_zone.gd` and [[dialogue-and-cutscenes]]) since before that task, unregistered, warning on every save
- Scaling concern (established Task 12/#141, reconfirmed #93 Task 2): each new `fire_on_scene_load` zone requires a hand-added manifest entry; prefix/wildcard matching in `validate()` is explicitly out of scope until a 3rd zone-family flag lands — do not add it preemptively
- Editing only the `const MANIFEST` dictionary body of a `class_name` script did NOT hit the stale-registry pitfall (confirmed twice: #141 Task 12 and #93 Task 2) — no reimport needed. (Reimport is only needed for exported-property / method / signal surface changes.)

## GameState flag helpers

- `GameState` has `snapshot_flags()` (deep dup), `restore_flags(d)` (deep dup), `clear_flags()` — use these for save round-trips

## SaveManager (issue #122)

- `SaveManager` (`scripts/autoload/save_manager.gd`) — autoload registered AFTER PartyManager, BEFORE DialogueManager. No `class_name` (autoload name is the global). `_save_path(slot) -> "user://hollow_men_save_%d.tres"`; `save(slot, scene="", spawn="") -> bool` snapshots flags + scene/spawn (default to live `get_tree().current_scene.scene_file_path` + `SceneManager.pending_spawn_point`), runs KnownFlags.validate (push_warning/push_error), `ResourceSaver.save`, emits `game_saved(slot)`; `read(slot) -> SaveData` uses `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` (fresh on-disk bytes, not cached), returns null if absent/wrong-type. Signal `game_loaded(slot)` (slot -1 = new_game)
- `apply(data, navigate=true)` (v2, #141 Task 9) restores flags via `GameState.restore_flags`, THEN `PartyManager.restore_progression(data.progression)` THEN `PartyManager.restore_roster(data.roster)`, then `SceneManager.change_scene(...)` when navigate; tests pass `navigate=false`. Order matters: restore_progression seeds levels FIRST so restore_roster's `from_definition + set_level(get_level(id))` picks them up. `load(slot) -> bool` = `read()` + `apply()` + `game_loaded.emit(slot)`; returns false on missing slot. Method named `load` shadows global `load()` intentionally — internally use `read()` only
- `new_game(navigate=true)` (Task 6, #122): `GameState.clear_flags()` (the C# Yarn bridge's Clear() is a deliberate no-op, so wiping the dict is the only real reset) → `game_loaded.emit(-1)` (the -1 sentinel) → if navigate, `SceneManager.change_scene(STARTING_SCENE, STARTING_SPAWN)`. Tests pass `navigate=false`. Post-#141 Task 17, `new_game()` also calls `PartyManager.reset_to_new_game()` after `GameState.clear_flags()`, before `game_loaded.emit(-1)` — fixed the review bug where loading a Lv5/Iris save then New Game left Reid Lv5 + Iris in party (see [[progression-and-party]])
> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-gdscript-gotchas.md (`not (data is SaveData)` operator-precedence gotcha)

- Test isolation: `before_each`/`after_each` call `GameState.clear_flags()` + remove the slot file via `DirAccess.remove_absolute(SaveManager._save_path(slot))`

## SaveManager v2 migration (issue #141, Task 9, 2026-06-15)

- `CURRENT_VERSION` bumped 1→2. `save()` now also writes `data.roster = PartyManager.snapshot_roster()` + `data.progression = PartyManager.snapshot_progression()` (right after spawn_point, before KnownFlags.validate). No new SaveManager method.
- Legacy v1 migration is IMPLICIT (no version branch): a v1 SaveData has `roster=[]`/`progression={}`; `restore_progression({})` re-seeds the L1 baseline and `restore_roster([])` falls back to Reid. So `apply()` on legacy data → Reid at level 1, no special-casing.
- `read()` already only warns when `save_version > CURRENT_VERSION`; with CURRENT_VERSION=2 a v1 file (older) passes silently.
- test_save_manager.gd grew to 12 tests. before_each/after_each MUST also reset PartyManager (`_permanent_members`/`_temporary_members`/`_progression` clear + `_seed_progression()`) or party state leaks across tests.

## SaveData Versioning Pattern (issue #123, Task 2)

- `SaveData` bump pattern: add `@export var <field>: <Type> = <safe_default>`, bump `save_version` int, add a one-line `## vN (#issue): ...` doc comment above the exports. `.tres` deserialization defaults missing fields automatically (legacy-save tests just assert the new field == its default) — no manual migration code needed for additive fields
- Typed `Array[Resource-subclass]` export (e.g. `Array[PartyMemberSave]`) worked immediately in the same PR that both defines `PartyMemberSave` (`class_name`) and references it from `SaveData` — no stale-class-cache reimport was needed here (contrast the `.tres` sub-resource stale-cache gotcha in [[scene-and-resource-serialization]], which is about scene/resource files referencing a *just-added* class_name, not script-to-script references)

## PartyManager runtime snapshot/restore (issue #123, Tasks 1 & 3, 2026-07-08)

- `PartyMemberSave` (`scripts/save/party_member_save.gd`, Task 1) — `class_name`, extends Resource: `definition_id:String`, `current_hp:int`, `current_pp:int`, `limit_gauge:float`, `active_effects:Array[StatusEffect]`. Deliberately excludes ephemeral fields (atb, skip_cooldown, ai_state)
- `PartyManager.snapshot_party_runtime() -> Array[PartyMemberSave]` iterates `_permanent_members` only (temporary/guest members excluded); `active_effects = m.active_effects.duplicate()` (shallow dup of the array, NOT deep — decouples the array reference so later appends to the live member don't leak into the snapshot, but existing StatusEffect elements are shared. No test currently mutates a shared element's fields post-snapshot, so this is unverified beyond array-identity decoupling)
- `PartyManager.restore_party_runtime(runtime: Array)` — call AFTER `restore_roster()` (roster must already be rebuilt). Matches each `PartyMemberSave` entry to a live member by `m.id == entry.definition_id` (nested loop, order-independent); unmatched entries are silently skipped (member keeps its full-HP rebuilt state — handles legacy saves with no runtime data)
- No stale-registry issue this time: `PartyMemberSave` class_name already existed from a prior concurrent task in the same worktree, so no reimport was needed before GUT picked it up

## Exact player position/facing save restore (issue #146, 2026-07-09)

- `Player.facing: Vector2i` is now PUBLIC (was `_facing`), default `Vector2i(0,1)` (down); `Player.set_facing(dir)` setter added. Consumed by SaveManager (capture) and BaseRoom (restore)
- `SceneManager` gained `pending_position: Vector2`, `pending_facing: Vector2i`, `has_pending_position: bool` — set ONLY by `SaveManager.apply()`, never by door transitions. `BaseRoom._resolve_spawn()` checks `has_pending_position` FIRST (snaps position, sets facing, resets flag, returns early) before the existing `SpawnPoint`/`default_spawn` lookup
- `SaveData` v4 (#146): `player_position:Vector2`, `player_facing:Vector2i`, `has_player_position:bool=false` (false = legacy save, BaseRoom falls back to default_spawn — no migration code needed, same additive-field pattern as v2/v3)
- `SaveManager.save()` gained an unconditional guard: `if not (get_tree().current_scene is BaseRoom): return false` (no file written). This broke **every existing test calling `save()`** across the whole suite, not just the ones a plan's file-structure list happens to name — the `godot-plan-writing-guard-changes` memory has the process lesson (issue #147). The fix pattern used everywhere: a `_install_base_room()`/`_teardown_base_room()` GUT helper pair that loads `BaseRoom.tscn`, sets `default_spawn = ""` BEFORE `add_child` (so `_ready()`'s `_resolve_spawn()` early-returns with no SpawnPoint needed), adds it as a DIRECT child of `get_tree().root`, and sets it as `current_scene` (the `current_scene` setter requires `parent == root`). Now centralized in the `BaseRoomTest` shared fixture — see [[gut-testing]]
- Full-suite run (Task 7's gate) is what caught the guard breaking `tests/test_debug_overlay.gd::test_debug_save_emits_and_writes_slot` (exercises `DebugOverlay._debug_save()` → `SaveManager.save()`) — individual per-task test runs never touched that file. Always run the full GUT suite as a final gate even when every individual task's targeted tests were green

## DEV debug save driver (issue #141)

- DebugOverlay autoload: `_debug_save/_debug_load/_debug_new_game` call `SaveManager.save/load/new_game` on `const SAVE_SLOT = 0`; wired in `_unhandled_input` to actions `debug_save` (F5, physical_keycode 4194336), `debug_load` (F9, 4194340), `debug_new_game` (F10, 4194341). New-game/load navigate via SceneManager.change_scene — flake-safe test recipe: test load on the no-file path (returns false before navigating), and after `_debug_new_game()` kill `get_tree().get_processed_tweens()` so the leaked fade coroutine never swaps the runner scene (flags already cleared synchronously). Slot-0 file is `user://hollow_men_save_0.tres`. See [[gut-testing]] for the leaked-coroutine flake class

## Related

- [[progression-and-party]] — roster/progression stores serialized here
- [[dialogue-and-cutscenes]] — Yarn variable storage over GameState flags
- [[gut-testing]] — test isolation for autoload persistence
- [[development-environment]] — DebugOverlay basics
