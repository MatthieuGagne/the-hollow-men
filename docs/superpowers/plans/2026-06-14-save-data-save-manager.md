# SaveData + SaveManager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or the project's `/executing-plans` skill to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a versioned, Resource-based save system (`SaveData` + `SaveManager` autoload) that persists narrative flags and world location, with a new-game reset and a validated `known_flags` manifest.

**Architecture:** `SaveData extends Resource` is a plain versioned data container. `SaveManager` is an autoload that snapshots `GameState._flags` wholesale (which also captures Yarn vars, since the live `GameStateVariableStorage` C# bridge addresses `$foo` ≡ `GameState` flag `foo`), saves/loads it via `ResourceSaver`/`ResourceLoader` (`CACHE_MODE_IGNORE`), and drives `SceneManager` for navigation. State restoration is decomposed from navigation so logic is unit-testable without real scene transitions. A `KnownFlags` manifest (static GDScript) validates flag names/types.

**Tech Stack:** Godot 4.6 / GDScript, GUT for tests, Resource serialization (`.tres`).

**Source issue:** #122 (part of epic #129, Phase 3 — Persistence). Independently mergeable. Depends only on already-merged work (#119/#120/#121).

---

## Key Design Decisions (settled before this plan)

- **One snapshot captures everything.** `GameState._flags` is the single store; the C# Yarn bridge writes there too. So `flags = GameState.snapshot_flags()` captures narrative progress including Yarn-set vars. (No separate Yarn snapshot.)
- **Bridge `Clear()` is a no-op** (see `scripts/autoload/GameStateVariableStorage.cs:44`). Therefore `new_game()` must clear `GameState._flags` directly — `GameState.clear_flags()`.
- **State vs navigation split.** `apply(data, navigate)` and `new_game(navigate)` take a `navigate` flag. Production paths pass `navigate = true` (real `SceneManager.change_scene`); tests pass `navigate = false` to assert flag/state effects without swapping the scene tree (the codebase already avoids calling `change_scene` in unit tests — see `tests/test_scene_manager.gd:32-37`).
- **Tolerant load is inherent.** Every field is an `@export` with a default, so a `.tres` missing a newer field loads with that default. `save_version` is reserved to gate *non-additive* migrations later; only v1 exists now.
- **Manifest seed.** The only flags currently in use are Yarn completion markers (`$intro_complete`, `$case_1_beat3_complete`, `$case_1_beat4_complete`), all booleans. The manifest is seeded with these and is expected to grow.

## File Structure

| File | Responsibility |
|---|---|
| `scripts/save/save_data.gd` (new) | `SaveData extends Resource` — versioned data container only. |
| `scripts/save/known_flags.gd` (new) | `KnownFlags` — static manifest (flag→type) + `validate()`. |
| `scripts/autoload/save_manager.gd` (new) | `SaveManager` autoload — `save`/`read`/`apply`/`load`/`new_game`, signals. |
| `scripts/autoload/game_state.gd` (modify) | Add `clear_flags`/`snapshot_flags`/`restore_flags` helpers. |
| `project.godot` (modify) | Register `SaveManager` autoload after `PartyManager`. |
| `tests/test_save_data.gd` (new) | SaveData defaults + version tolerance round-trip. |
| `tests/test_known_flags.gd` (new) | Manifest validate: ok / unknown→warn / mismatch→fail. |
| `tests/test_save_manager.gd` (new) | save/read round-trip, restore, new_game, missing-slot. |

## How to run GUT (used throughout)

Single file (fast, during TDD):
```
godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit
```
Full suite (before PR):
```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

---

## Task 0: Worktree setup

**Files:** none (environment only)

- [ ] **Step 1: Create the worktree and branch**

```bash
git worktree add .worktrees/feat-issue-122-save-system -b feat/issue-122-save-system
```

- [ ] **Step 2: Initialize build artifacts (required — copies gitignored assets + reimports)**

```bash
cd .worktrees/feat-issue-122-save-system && make worktree-init
```
Expected: completes without error; headless reimport runs. (Skipping this makes maps render empty and tests flaky.)

- [ ] **Step 3: Baseline the test suite**

Run (from the worktree root):
```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```
Expected: suite runs. Note any pre-existing failures now so they aren't blamed on this work (the memory notes a known SceneManager cross-test flake guarded by an empty-path early return).

---

## Task 1: `SaveData` resource

**Files:**
- Create: `scripts/save/save_data.gd`
- Test: `tests/test_save_data.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_save_data.gd`:
```gdscript
extends GutTest


func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 1)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")


func test_holds_assigned_values() -> void:
	var data := SaveData.new()
	data.flags = {"intro_complete": true}
	data.current_scene = "res://scenes/world/Rooftop.tscn"
	data.spawn_point = "rooftop_start"
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.current_scene, "res://scenes/world/Rooftop.tscn")
	assert_eq(data.spawn_point, "rooftop_start")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd -gexit`
Expected: FAIL — `SaveData` is not a known class (parse/identifier error).

- [ ] **Step 3: Write minimal implementation**

`scripts/save/save_data.gd`:
```gdscript
class_name SaveData
extends Resource

## Versioned save container. Party runtime is added in PRD G (#123).

@export var save_version: int = 1
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/save/save_data.gd tests/test_save_data.gd
git commit -m "feat: add SaveData versioned resource (#122)"
```

---

## Task 2: `GameState` flag helpers

**Files:**
- Modify: `scripts/autoload/game_state.gd`
- Test: `tests/test_game_state.gd` (append)

- [ ] **Step 1: Write the failing tests** (append to `tests/test_game_state.gd`)

```gdscript
func test_clear_flags_empties_store() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.clear_flags()
	assert_eq(GameState._flags, {})


func test_snapshot_returns_independent_copy() -> void:
	GameState.set_flag("intro_complete", true)
	var snap := GameState.snapshot_flags()
	GameState.set_flag("intro_complete", false)
	assert_eq(snap["intro_complete"], true,
		"snapshot must not reflect later mutations")


func test_restore_replaces_flags_with_copy() -> void:
	GameState.set_flag("stale", true)
	var source := {"intro_complete": true}
	GameState.restore_flags(source)
	assert_false(GameState.has_flag("stale"))
	assert_eq(GameState.get_flag("intro_complete"), true)
	source["intro_complete"] = false
	assert_eq(GameState.get_flag("intro_complete"), true,
		"restore must deep-copy, not alias the source dict")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_state.gd -gexit`
Expected: FAIL — `clear_flags`/`snapshot_flags`/`restore_flags` not found on GameState.

- [ ] **Step 3: Write minimal implementation** (append to `scripts/autoload/game_state.gd`)

```gdscript
func clear_flags() -> void:
	_flags.clear()


func snapshot_flags() -> Dictionary:
	return _flags.duplicate(true)


func restore_flags(flags: Dictionary) -> void:
	_flags = flags.duplicate(true)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_state.gd -gexit`
Expected: PASS (all existing + 3 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/game_state.gd tests/test_game_state.gd
git commit -m "feat: add GameState clear/snapshot/restore flag helpers (#122)"
```

---

## Task 3: `KnownFlags` manifest + validation

**Files:**
- Create: `scripts/save/known_flags.gd`
- Test: `tests/test_known_flags.gd`

- [ ] **Step 1: Write the failing test**

`tests/test_known_flags.gd`:
```gdscript
extends GutTest


func test_all_known_flags_correct_type_no_issues() -> void:
	var result := KnownFlags.validate({
		"intro_complete": true,
		"case_1_beat3_complete": false,
	})
	assert_eq(result["warnings"], [])
	assert_eq(result["errors"], [])


func test_unknown_flag_warns_not_errors() -> void:
	var result := KnownFlags.validate({"not_in_manifest": true})
	assert_eq(result["warnings"].size(), 1)
	assert_eq(result["errors"], [])


func test_type_mismatch_is_error() -> void:
	# intro_complete is declared TYPE_BOOL in the manifest; feed a String.
	var result := KnownFlags.validate({"intro_complete": "yes"})
	assert_eq(result["errors"].size(), 1)
	assert_eq(result["warnings"], [])


func test_empty_flags_clean() -> void:
	var result := KnownFlags.validate({})
	assert_eq(result["warnings"], [])
	assert_eq(result["errors"], [])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_known_flags.gd -gexit`
Expected: FAIL — `KnownFlags` not a known class.

- [ ] **Step 3: Write minimal implementation**

`scripts/save/known_flags.gd`:
```gdscript
class_name KnownFlags
extends RefCounted

## Manifest of every narrative flag the game uses, with its expected type.
## Seeded from the Yarn completion markers currently in dialogue/*.yarn.
## Grows as new flags are introduced. Numeric flags should use TYPE_FLOAT
## (Yarn numbers arrive as floats through the GameStateVariableStorage bridge).
const MANIFEST: Dictionary = {
	"intro_complete": TYPE_BOOL,
	"case_1_beat3_complete": TYPE_BOOL,
	"case_1_beat4_complete": TYPE_BOOL,
}


## Returns {"warnings": Array[String], "errors": Array[String]}.
## Unknown flag (used but not in manifest) -> warning.
## Known flag with wrong value type -> error.
static func validate(flags: Dictionary) -> Dictionary:
	var warnings: Array[String] = []
	var errors: Array[String] = []
	for key: String in flags:
		if not MANIFEST.has(key):
			warnings.append("Unknown flag '%s' not in KnownFlags.MANIFEST" % key)
			continue
		var expected: int = MANIFEST[key]
		var actual: int = typeof(flags[key])
		if actual != expected:
			errors.append(
				"Flag '%s' type mismatch: expected %d, got %d" % [key, expected, actual]
			)
	return {"warnings": warnings, "errors": errors}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_known_flags.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/save/known_flags.gd tests/test_known_flags.gd
git commit -m "feat: add KnownFlags manifest + validate (#122)"
```

---

## Task 4: `SaveManager` autoload — register + save/read round-trip

**Files:**
- Create: `scripts/autoload/save_manager.gd`
- Modify: `project.godot` (autoload entry)
- Test: `tests/test_save_manager.gd`

- [ ] **Step 1: Create the stub autoload so the `SaveManager` global resolves**

`scripts/autoload/save_manager.gd`:
```gdscript
extends Node

## Versioned save/load. Snapshots GameState flags (Yarn vars included via the
## C# bridge) + world location. State restore is split from navigation so logic
## is unit-testable without real scene transitions.

signal game_saved(slot: int)
signal game_loaded(slot: int)  ## slot == -1 means a fresh new_game()

const CURRENT_VERSION: int = 1
const STARTING_SCENE: String = "res://scenes/world/Rooftop.tscn"
const STARTING_SPAWN: String = ""


func _save_path(slot: int) -> String:
	return "user://hollow_men_save_%d.tres" % slot
```

- [ ] **Step 2: Register the autoload in `project.godot`**

In the `[autoload]` section, insert the `SaveManager` line immediately after the `PartyManager` line (satisfies R2: loads after `GameState` + `PartyManager` + `GameData`):
```
PartyManager="*res://scripts/autoload/party_manager.gd"
SaveManager="*res://scripts/autoload/save_manager.gd"
DialogueManager="*res://scenes/autoload/DialogueManager.tscn"
```

- [ ] **Step 3: Write the failing test**

`tests/test_save_manager.gd`:
```gdscript
extends GutTest

const SLOT: int = 0


func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)


func after_each() -> void:
	_remove_slot(SLOT)
	GameState.clear_flags()


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_save_then_read_round_trips_flags_and_location() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.set_flag("case_1_beat3_complete", false)
	var ok := SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	assert_true(ok, "save() should return true on success")

	# Simulate a restart: wipe in-memory flags, then read from disk.
	GameState.clear_flags()
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.flags["case_1_beat3_complete"], false)
	assert_eq(data.current_scene, "res://scenes/world/Rooftop.tscn")
	assert_eq(data.spawn_point, "rooftop_start")
	assert_eq(data.save_version, SaveManager.CURRENT_VERSION)


func test_read_missing_slot_returns_null() -> void:
	assert_null(SaveManager.read(SLOT))


func test_save_emits_game_saved() -> void:
	watch_signals(SaveManager)
	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	assert_signal_emitted_with_parameters(SaveManager, "game_saved", [SLOT])
```

- [ ] **Step 4: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: FAIL — `save`/`read` not found on SaveManager.

- [ ] **Step 5: Implement `save` and `read`** (append to `scripts/autoload/save_manager.gd`)

```gdscript
## Snapshot current state to a slot. scene/spawn default to the live scene tree
## + SceneManager's pending spawn when omitted (so production callers pass nothing).
func save(slot: int, scene: String = "", spawn: String = "") -> bool:
	var data := SaveData.new()
	data.save_version = CURRENT_VERSION
	data.flags = GameState.snapshot_flags()
	data.current_scene = scene if not scene.is_empty() else _current_scene_path()
	data.spawn_point = spawn if not spawn.is_empty() else SceneManager.pending_spawn_point

	var validation := KnownFlags.validate(data.flags)
	for w: String in validation["warnings"]:
		push_warning("SaveManager: %s" % w)
	for e: String in validation["errors"]:
		push_error("SaveManager: %s" % e)

	var err := ResourceSaver.save(data, _save_path(slot))
	if err != OK:
		push_error("SaveManager.save failed (err %d)" % err)
		return false
	game_saved.emit(slot)
	return true


## Read a slot from disk. Returns null if absent or unreadable. Uses
## CACHE_MODE_IGNORE so each read reflects on-disk bytes, not a cached resource.
func read(slot: int) -> SaveData:
	var path := _save_path(slot)
	if not ResourceLoader.exists(path):
		return null
	var data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if data == null or not data is SaveData:
		push_error("SaveManager.read: %s is not a SaveData" % path)
		return null
	if data.save_version > CURRENT_VERSION:
		push_warning(
			"SaveManager.read: save_version %d newer than CURRENT_VERSION %d"
			% [data.save_version, CURRENT_VERSION]
		)
	return data


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current else ""
```

- [ ] **Step 6: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/save_manager.gd project.godot tests/test_save_manager.gd
git commit -m "feat: SaveManager autoload with save/read round-trip (#122)"
```

---

## Task 5: `apply` / `load` — restore flags + navigate

**Files:**
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_save_manager.gd` (append)

- [ ] **Step 1: Write the failing tests** (append to `tests/test_save_manager.gd`)

```gdscript
func test_apply_restores_flags_without_navigating() -> void:
	var data := SaveData.new()
	data.flags = {"intro_complete": true}
	data.current_scene = "res://scenes/world/Rooftop.tscn"
	SaveManager.apply(data, false)  # navigate = false: no scene swap in tests
	assert_eq(GameState.get_flag("intro_complete"), true)


func test_load_round_trip_restores_into_game_state() -> void:
	GameState.set_flag("intro_complete", true)
	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	GameState.clear_flags()

	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	SaveManager.apply(data, false)
	assert_eq(GameState.get_flag("intro_complete"), true)


func test_load_missing_slot_returns_false() -> void:
	assert_false(SaveManager.load(SLOT))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: FAIL — `apply`/`load` not found.

- [ ] **Step 3: Implement `apply` and `load`** (append to `scripts/autoload/save_manager.gd`)

```gdscript
## Restore a SaveData into the running game. navigate=false (tests) skips the
## scene transition so flag effects are observable without swapping the tree.
func apply(data: SaveData, navigate: bool = true) -> void:
	GameState.restore_flags(data.flags)
	if navigate:
		SceneManager.change_scene(data.current_scene, data.spawn_point)


## Convenience: read a slot and apply it. Returns false if the slot is absent.
func load(slot: int) -> bool:
	var data := read(slot)
	if data == null:
		return false
	apply(data)
	game_loaded.emit(slot)
	return true
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd
git commit -m "feat: SaveManager apply/load flag restoration (#122)"
```

---

## Task 6: `new_game` — clear flags + reset location

**Files:**
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_save_manager.gd` (append)

- [ ] **Step 1: Write the failing tests** (append to `tests/test_save_manager.gd`)

```gdscript
func test_new_game_clears_all_flags() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.set_flag("case_1_beat3_complete", true)
	SaveManager.new_game(false)  # navigate = false: assert state only
	assert_eq(GameState._flags, {})


func test_new_game_emits_game_loaded_sentinel() -> void:
	watch_signals(SaveManager)
	SaveManager.new_game(false)
	assert_signal_emitted_with_parameters(SaveManager, "game_loaded", [-1])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: FAIL — `new_game` not found.

- [ ] **Step 3: Implement `new_game`** (append to `scripts/autoload/save_manager.gd`)

```gdscript
## Start a fresh game: clear flags directly (the Yarn bridge's Clear() is a
## no-op) and reset to the starting scene. navigate=false (tests) skips travel.
func new_game(navigate: bool = true) -> void:
	GameState.clear_flags()
	game_loaded.emit(-1)
	if navigate:
		SceneManager.change_scene(STARTING_SCENE, STARTING_SPAWN)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd
git commit -m "feat: SaveManager new_game flag reset (#122)"
```

---

## Task 7: Version tolerance (AC3) — load a `.tres` missing a newer field

**Files:**
- Test: `tests/test_save_data.gd` (append)

This proves R6/AC3: a save written by an older schema (lacking `current_scene`/`spawn_point`) loads with those fields defaulted, because every field is an `@export` with a default.

- [ ] **Step 1: Write the failing test** (append to `tests/test_save_data.gd`)

```gdscript
const _LEGACY_PATH: String = "user://test_legacy_save.tres"

# A hand-authored save resource that predates current_scene/spawn_point.
const _LEGACY_TRES: String = """[gd_resource type="Resource" script_class="SaveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/save/save_data.gd" id="1"]

[resource]
script = ExtResource("1")
save_version = 1
flags = {
"intro_complete": true
}
"""


func _cleanup_legacy() -> void:
	if FileAccess.file_exists(_LEGACY_PATH):
		DirAccess.remove_absolute(_LEGACY_PATH)


func test_loads_legacy_save_missing_newer_fields_with_defaults() -> void:
	_cleanup_legacy()
	var f := FileAccess.open(_LEGACY_PATH, FileAccess.WRITE)
	f.store_string(_LEGACY_TRES)
	f.close()

	var data: SaveData = ResourceLoader.load(
		_LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(data)
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.current_scene, "", "missing field must default to \"\"")
	assert_eq(data.spawn_point, "", "missing field must default to \"\"")
	_cleanup_legacy()
```

- [ ] **Step 2: Run test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd -gexit`
Expected: PASS. (No implementation change needed — this verifies the inherent `@export`-default tolerance. If it fails, the defaults or the script path in `_LEGACY_TRES` are wrong.)

- [ ] **Step 3: Commit**

```bash
git add tests/test_save_data.gd
git commit -m "test: SaveData version tolerance for legacy saves (#122)"
```

---

## Task 8: Full suite + visual smoketest

**Files:** none (verification)

- [ ] **Step 1: Run the entire GUT suite**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`
Expected: all new tests pass; no regressions beyond the pre-existing failures recorded in Task 0 Step 3.

- [ ] **Step 2: Visual smoketest the game still boots**

Use `/run` to launch the game. Confirm the Rooftop scene loads and is playable (the autoload addition must not break startup). Close after confirming.

- [ ] **Step 3: Commit any fixes** (only if Step 1/2 surfaced issues)

```bash
git add -A
git commit -m "fix: address save-system smoketest findings (#122)"
```

---

## Task 9: Finish the branch

- [ ] **Step 1:** Invoke the project's `/finishing-a-development-branch` skill — it re-runs GUT headlessly, runs the visual smoketest, and presents PR/keep/discard options (PR-only integration; never merge locally to master). PR should reference issue #122 and the epic #129.

---

## Self-Review (against #122 spec)

**Requirement coverage:**
- R1 SaveData fields + version → Task 1.
- R2 SaveManager autoload `save`/`load`/`new_game`, loads after GameState/PartyManager/GameData → Tasks 4–6, autoload position Task 4 Step 2.
- R3 wholesale `_flags` snapshot (captures Yarn vars) → `save()` uses `snapshot_flags()`, Task 4.
- R4 load restores flags + transitions via SceneManager → `apply()`/`load()`, Task 5.
- R5 `new_game()` clears `_flags` directly + resets scene → Task 6 (uses `clear_flags`, not the no-op bridge `Clear()`).
- R6 tolerant load + version gating → Task 7 (defaults) + `read()` version check, Task 4.
- R7 `known_flags` manifest, unknown→WARN, mismatch→FAIL, GUT-validated → Task 3.

**Acceptance criteria:**
- AC1 set flags+scene→save→restart→load restores → `test_load_round_trip_restores_into_game_state` (Task 5) + round-trip read (Task 4).
- AC2 `new_game()` clears flags → `test_new_game_clears_all_flags` (Task 6).
- AC3 missing newer field defaults → `test_loads_legacy_save_missing_newer_fields_with_defaults` (Task 7).
- AC4 `ResourceSaver`/`ResourceLoader` `CACHE_MODE_IGNORE` round-trip → Task 4 (`save`/`read`).
- AC5 GUT: round-trip / new-game / version tolerance / manifest warn+fail → Tasks 3–7.

**Placeholder scan:** none — every code/test step shows full content.
**Type consistency:** `SaveData` fields, `KnownFlags.MANIFEST`/`validate`, `SaveManager.save/read/apply/load/new_game/_save_path/CURRENT_VERSION/STARTING_SCENE`, and `GameState.clear_flags/snapshot_flags/restore_flags` are named identically everywhere they appear.

**Out of scope (not implemented here):** party persistence (#123), party seeding (#124), title/save-select UI, inventory.
