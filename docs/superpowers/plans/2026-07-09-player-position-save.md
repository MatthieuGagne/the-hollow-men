# Save Exact Player Position & Facing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or the project's `executing-plans` skill to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This is a Godot 4.6 / GDScript project — every GDScript task is TDD with GUT and ends green.

**Goal:** Saving the game restores the player to the exact position and facing they had at save time, instead of resetting to the room's default spawn point.

**Architecture:** `SaveData` grows three v4 fields (`player_position`, `player_facing`, `has_player_position`). `SaveManager.save()` gains a `BaseRoom` allowlist guard and captures the live `$Player.position`/`facing`. `SaveManager.apply()` pushes the saved position/facing into three new `SceneManager` "pending" fields, which `BaseRoom._resolve_spawn()` consumes ahead of the existing named-`SpawnPoint`/`default_spawn` lookup. Legacy saves (`has_player_position = false`) fall through to today's behavior unchanged.

**Tech Stack:** Godot 4.6, GDScript (runtime), GUT (unit tests), `Resource`-based versioned save files (`.tres`).

## Global Constraints

- Engine: **Godot 4.6 / GDScript only** for runtime. Static typing preferred (`var foo: int = 0`).
- **Bump `save_version` to 4** — single version bump covering the whole feature. `SaveData.save_version` default and `SaveManager.CURRENT_VERSION` must both become `4`.
- **No new autoload signals.** `game_saved`/`game_loaded` (SaveManager) and `pre_scene_change` (SceneManager) are untouched.
- **`SceneManager.pending_position`/`pending_facing`/`has_pending_position` are set ONLY by `SaveManager.apply()`** — never by door transitions (AC4).
- `player_facing` default is `Vector2i(0, 1)` (facing down), matching `Player`'s existing default.
- **No runtime validation** of saved position against map geometry — restore unconditionally (R7), matching the existing `assert()`-based trust level of the `spawn_id` lookup.
- Run the full GUT suite with: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- Run a single test file with: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_<name>.gd`
- Only one production caller of `SaveManager.save()` exists (`DebugOverlay._debug_save()`, F5). **`debug_overlay.gd` needs no change** — it already prints `"OK"`/`"FAILED"` from `save()`'s bool return (AC2).

---

## File Structure

**Production files (all exist — modify in place):**
- `scripts/world/player.gd` — rename private `_facing` → public `facing`; add `set_facing(dir)`.
- `scripts/autoload/scene_manager.gd` — add `pending_position`, `pending_facing`, `has_pending_position`.
- `scripts/save/save_data.gd` — add `player_position`, `player_facing`, `has_player_position`; bump default `save_version` to 4.
- `scripts/autoload/save_manager.gd` — `CURRENT_VERSION = 4`; `BaseRoom` guard + position/facing capture in `save()`; pending-field passthrough in `apply()`.
- `scripts/world/base_room.gd` — `_resolve_spawn()` checks `has_pending_position` first.

**Test files:**
- `tests/test_player.gd` — modify: `_facing` refs → `facing`; add `set_facing` test.
- `tests/test_scene_manager.gd` — modify: add pending-field default/assignment tests.
- `tests/test_save_data.gd` — modify: version-bump assertion; new-field defaults; legacy-load defaults.
- `tests/test_save_manager.gd` — modify: version-bump assertion; **install a `BaseRoom` `current_scene` so existing `save()` tests satisfy the new guard**; add save-rejected-when-not-a-room test; add capture + apply-passthrough tests.
- `tests/test_party_save.gd` — modify: **install a `BaseRoom` `current_scene`** so its 7 `save()` tests satisfy the new guard.
- `tests/test_base_room.gd` — modify: add `_resolve_spawn` pending-position tests.
- `tests/test_player_position_save.gd` — **create**: end-to-end round-trip (save → read → apply → destination room resolves position/facing).

### Critical cross-cutting note — the guard breaks existing tests

`SaveManager.save()` gains an unconditional guard: it returns `false` unless `get_tree().current_scene is BaseRoom`. In GUT, `get_tree().current_scene` is the test runner — **not** a `BaseRoom`. So **every existing test that calls `save()` will start returning `false` and fail** unless a real `BaseRoom` is installed as `current_scene`.

The reusable pattern (repeated verbatim in Task 4 and Task 7 — GUT tests each `extend GutTest`, so a small duplicated helper is the established idiom here, mirroring the already-duplicated `_remove_slot`):

```gdscript
var _room: BaseRoom = null
var _prev_scene: Node = null

# Installs a real BaseRoom as the tree's current_scene so SaveManager.save()'s
# BaseRoom guard passes. default_spawn="" makes _resolve_spawn() return early
# (no SpawnPoint assert). The room must be a DIRECT child of root — the
# current_scene setter requires parent == root.
func _install_base_room() -> BaseRoom:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""  # set BEFORE add: _ready() runs on entering the tree
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_room = room
	return room

# Restore current_scene BEFORE freeing (freeing the current scene mid-test is unsafe).
func _teardown_base_room() -> void:
	if _room == null:
		return
	get_tree().current_scene = _prev_scene
	_room.free()
	_room = null
```

---

## Task 1: `Player.facing` public field + `set_facing()`

**Files:**
- Modify: `scripts/world/player.gd:12` (rename `_facing`), `:66` (assignment), `:87` (read); add `set_facing()`.
- Modify: `tests/test_player.gd:114` (comment), `:127` (`player._facing` → `player.facing`); add a `set_facing` test.

**Interfaces:**
- Produces: `Player.facing: Vector2i` (public, default `Vector2i(0, 1)`); `Player.set_facing(dir: Vector2i) -> void`. Consumed by SaveManager (Task 4) and BaseRoom (Task 5).

- [ ] **Step 1: Update the failing test references and add a `set_facing` test**

In `tests/test_player.gd`, change the comment on line 114 from `default _facing is (0,1)` to `default facing is (0,1)`, and change line 127 from:

```gdscript
	var facing_cell: Vector2i = layer.local_to_map(player.position) + player._facing
```
to:
```gdscript
	var facing_cell: Vector2i = layer.local_to_map(player.position) + player.facing
```

Then append this new test at the end of `tests/test_player.gd`:

```gdscript
func test_set_facing_updates_public_field() -> void:
	var player := Player.new()
	assert_eq(player.facing, Vector2i(0, 1), "facing defaults to down")
	player.set_facing(Vector2i(-1, 0))
	assert_eq(player.facing, Vector2i(-1, 0), "set_facing updates the public field")
	player.free()
```

- [ ] **Step 2: Run the player tests to verify the new test fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd`
Expected: FAIL — `test_set_facing_updates_public_field` errors on unknown property `facing` / missing method `set_facing`; `test_interact_with_no_dialogue_does_not_block_input` errors on unknown property `facing`.

- [ ] **Step 3: Rename `_facing` → `facing` and add the setter in `player.gd`**

Line 12 — change:
```gdscript
var _facing: Vector2i = Vector2i(0, 1)  # default: facing down
```
to:
```gdscript
## Public so external code (SaveManager, BaseRoom) can read/write it — mirrors
## how `position` is already externally read/written. Default: facing down.
var facing: Vector2i = Vector2i(0, 1)
```

Line 66 — inside `_try_move`, change `_facing = offset` to:
```gdscript
	facing = offset
```

Line 87 — inside `get_facing_cell`, change `+ _facing` to:
```gdscript
	return _world_layer.local_to_map(position) + facing
```

Add this setter (place it just after `get_facing_cell()`):
```gdscript
func set_facing(dir: Vector2i) -> void:
	facing = dir
```

- [ ] **Step 4: Run the player tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd`
Expected: PASS — all tests green.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/player.gd tests/test_player.gd
git commit -m "feat: make Player.facing public with set_facing() setter (#146)"
```

---

## Task 2: `SceneManager` pending position/facing fields

**Files:**
- Modify: `scripts/autoload/scene_manager.gd:8` (add fields after `pending_spawn_point`).
- Modify: `tests/test_scene_manager.gd` (add default + assignment tests).

**Interfaces:**
- Produces: `SceneManager.pending_position: Vector2` (default `Vector2.ZERO`), `SceneManager.pending_facing: Vector2i` (default `Vector2i(0, 1)`), `SceneManager.has_pending_position: bool` (default `false`). Written by SaveManager.apply (Task 4), read/reset by BaseRoom._resolve_spawn (Task 5).

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_scene_manager.gd`:

```gdscript
func test_pending_position_defaults_to_zero() -> void:
	SceneManager.pending_position = Vector2.ZERO
	assert_eq(SceneManager.pending_position, Vector2.ZERO)


func test_pending_facing_defaults_to_down() -> void:
	SceneManager.pending_facing = Vector2i(0, 1)
	assert_eq(SceneManager.pending_facing, Vector2i(0, 1))


func test_has_pending_position_defaults_false() -> void:
	SceneManager.has_pending_position = false
	assert_false(SceneManager.has_pending_position)


func test_pending_fields_are_assignable() -> void:
	SceneManager.pending_position = Vector2(200, 120)
	SceneManager.pending_facing = Vector2i(-1, 0)
	SceneManager.has_pending_position = true
	assert_eq(SceneManager.pending_position, Vector2(200, 120))
	assert_eq(SceneManager.pending_facing, Vector2i(-1, 0))
	assert_true(SceneManager.has_pending_position)
	# Reset so this test does not leak state into others.
	SceneManager.has_pending_position = false
```

- [ ] **Step 2: Run the scene-manager tests to verify they fail**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_scene_manager.gd`
Expected: FAIL — unknown properties `pending_position` / `pending_facing` / `has_pending_position`.

- [ ] **Step 3: Add the fields in `scene_manager.gd`**

Change line 8 from:
```gdscript
var pending_spawn_point: String = ""
```
to:
```gdscript
var pending_spawn_point: String = ""
## Set ONLY by SaveManager.apply() before change_scene(); consumed + reset by
## BaseRoom._resolve_spawn(). Never touched by door transitions (#146).
var pending_position: Vector2 = Vector2.ZERO
var pending_facing: Vector2i = Vector2i(0, 1)
var has_pending_position: bool = false
```

- [ ] **Step 4: Run the scene-manager tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_scene_manager.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/autoload/scene_manager.gd tests/test_scene_manager.gd
git commit -m "feat: add SceneManager pending_position/pending_facing fields (#146)"
```

---

## Task 3: `SaveData` v4 fields

**Files:**
- Modify: `scripts/save/save_data.gd` (add 3 fields, bump default `save_version` to 4, update doc comment).
- Modify: `tests/test_save_data.gd` (version-bump assertion; new-field defaults; legacy-load defaults).

**Interfaces:**
- Produces: `SaveData.player_position: Vector2` (default `Vector2.ZERO`), `SaveData.player_facing: Vector2i` (default `Vector2i(0, 1)`), `SaveData.has_player_position: bool` (default `false`), `SaveData.save_version` default `4`. Consumed by SaveManager (Task 4).

- [ ] **Step 1: Update the defaults test and add new-field tests**

In `tests/test_save_data.gd`, change `test_defaults` — update the version assertion and add the three new-field assertions:

```gdscript
func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 4)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")
	assert_eq(data.roster, [])
	assert_eq(data.progression, {})
	assert_eq(data.party_runtime, [])
	assert_eq(data.player_position, Vector2.ZERO)
	assert_eq(data.player_facing, Vector2i(0, 1))
	assert_false(data.has_player_position)
```

Then append a legacy-load test (the existing `_LEGACY_TRES` / `_LEGACY_PATH` / `_cleanup_legacy()` helpers are already in the file):

```gdscript
func test_loads_legacy_save_defaults_player_position_fields() -> void:
	_cleanup_legacy()
	var f := FileAccess.open(_LEGACY_PATH, FileAccess.WRITE)
	f.store_string(_LEGACY_TRES)
	f.close()

	var data: SaveData = ResourceLoader.load(
		_LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(data)
	assert_eq(data.player_position, Vector2.ZERO, "missing field defaults to Vector2.ZERO")
	assert_eq(data.player_facing, Vector2i(0, 1), "missing field defaults to facing-down")
	assert_false(data.has_player_position, "legacy save has no player position")
	_cleanup_legacy()
```

- [ ] **Step 2: Run the save-data tests to verify they fail**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: FAIL — `test_defaults` fails on `save_version` (4 vs 3) and unknown properties; new legacy test fails on unknown properties.

- [ ] **Step 3: Add the fields and bump the version in `save_data.gd`**

Update the doc comment block (lines 4-6) to add a v4 line:
```gdscript
## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.
## v3 (#123): adds party_runtime — per-member volatile state (HP/PP/limit/status).
## v4 (#146): adds player_position/player_facing/has_player_position — exact restore.
```

Change line 8 from `@export var save_version: int = 3` to:
```gdscript
@export var save_version: int = 4
```

After the `party_runtime` export (line 18), append:
```gdscript
## Exact player location at save time (#146). has_player_position is false for
## legacy saves (v3 and earlier) → BaseRoom falls back to default_spawn.
@export var player_position: Vector2 = Vector2.ZERO
@export var player_facing: Vector2i = Vector2i(0, 1)
@export var has_player_position: bool = false
```

- [ ] **Step 4: Run the save-data tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/save/save_data.gd tests/test_save_data.gd
git commit -m "feat: add SaveData player_position/facing fields, bump save to v4 (#146)"
```

---

## Task 4: `SaveManager` guard, capture, and pending-field passthrough

**Files:**
- Modify: `scripts/autoload/save_manager.gd:10` (`CURRENT_VERSION = 4`), `save()` (guard + capture), `apply()` (pending passthrough).
- Modify: `tests/test_save_manager.gd` (install `BaseRoom` current_scene for existing tests; version assertion; rejection test; capture test; apply-passthrough test).
- Modify: `tests/test_party_save.gd` (install `BaseRoom` current_scene so its `save()` tests pass the guard).

**Interfaces:**
- Consumes: `SaveData.player_position`/`player_facing`/`has_player_position` (Task 3); `Player.facing` (Task 1); `SceneManager.pending_position`/`pending_facing`/`has_pending_position` (Task 2).
- Produces: `SaveManager.save()` returns `false` (writes no file) unless `get_tree().current_scene is BaseRoom`; on success writes `player_position`/`player_facing` and `has_player_position = true`. `SaveManager.apply()` sets the three `SceneManager` pending fields when `data.has_player_position`. `SaveManager.CURRENT_VERSION == 4`. Consumed by BaseRoom (Task 5) and the round-trip test (Task 7).

- [ ] **Step 1: Add the room-install helper + before/after hooks to `test_save_manager.gd`**

At the top of `tests/test_save_manager.gd` (after `const SLOT: int = 0`), add the member vars and helper from the "Critical cross-cutting note" section:

```gdscript
var _room: BaseRoom = null
var _prev_scene: Node = null


func _install_base_room() -> BaseRoom:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""  # set BEFORE add: _ready() runs on entering the tree
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_room = room
	return room


func _teardown_base_room() -> void:
	if _room == null:
		return
	get_tree().current_scene = _prev_scene
	_room.free()
	_room = null
```

Then extend the EXISTING `before_each` / `after_each` to install/teardown the room (keep every line already there):

```gdscript
func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
	_install_base_room()


func after_each() -> void:
	_teardown_base_room()
	_remove_slot(SLOT)
	GameState.clear_flags()
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
```

- [ ] **Step 2: Update the version assertion + add guard/capture/passthrough tests in `test_save_manager.gd`**

Replace `test_current_version_is_three`:
```gdscript
func test_current_version_is_four() -> void:
	assert_eq(SaveManager.CURRENT_VERSION, 4)
```

Append these tests:

```gdscript
func test_save_rejected_when_current_scene_not_base_room() -> void:
	# Swap the before_each room for a non-room scene; save must refuse.
	_teardown_base_room()
	var plain := Node2D.new()
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(plain)
	get_tree().current_scene = plain
	_remove_slot(SLOT)

	assert_false(SaveManager.save(SLOT), "save must fail when not in a BaseRoom")
	assert_false(
		FileAccess.file_exists(SaveManager._save_path(SLOT)),
		"no file may be written when the guard rejects the save"
	)

	get_tree().current_scene = _prev_scene
	plain.free()


func test_save_captures_player_position_and_facing() -> void:
	var player := _room.get_node("Player") as Player
	player.position = Vector2(120, 88)
	player.set_facing(Vector2i(-1, 0))

	assert_true(SaveManager.save(SLOT), "save succeeds inside a BaseRoom")
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_eq(data.player_position, Vector2(120, 88))
	assert_eq(data.player_facing, Vector2i(-1, 0))
	assert_true(data.has_player_position)


func test_apply_sets_scene_manager_pending_fields_when_position_saved() -> void:
	var data := SaveData.new()
	data.player_position = Vector2(64, 48)
	data.player_facing = Vector2i(1, 0)
	data.has_player_position = true

	SaveManager.apply(data, false)  # navigate=false: no scene swap in tests

	assert_eq(SceneManager.pending_position, Vector2(64, 48))
	assert_eq(SceneManager.pending_facing, Vector2i(1, 0))
	assert_true(SceneManager.has_pending_position)
	SceneManager.has_pending_position = false  # avoid leaking into other tests


func test_apply_leaves_pending_position_flag_false_for_legacy_save() -> void:
	SceneManager.has_pending_position = false
	var data := SaveData.new()  # has_player_position defaults false (legacy shape)

	SaveManager.apply(data, false)

	assert_false(
		SceneManager.has_pending_position,
		"legacy save must not arm the pending-position path"
	)
```

- [ ] **Step 3: Add the room-install helper + before/after hooks to `test_party_save.gd`**

Apply the identical treatment to `tests/test_party_save.gd`: add the `_room`/`_prev_scene` vars and the `_install_base_room()` / `_teardown_base_room()` helpers (verbatim from Step 1), then extend its existing `before_each` to call `_install_base_room()` at the end and its `after_each` to call `_teardown_base_room()` first:

```gdscript
func before_each() -> void:
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
	_install_base_room()


func after_each() -> void:
	_teardown_base_room()
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
```

- [ ] **Step 4: Run both affected suites to verify the new expectations fail**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd,res://tests/test_party_save.gd`
Expected: FAIL — `test_current_version_is_four` fails (still 3); the guard/capture/passthrough tests fail (no guard, no capture, no passthrough yet). Existing tests may error because `save()` has no guard yet but the room is installed (that is fine — they still pass on the old code path).

- [ ] **Step 5: Bump the version and implement the guard + capture in `save_manager.gd`**

Change line 10 from `const CURRENT_VERSION: int = 3` to:
```gdscript
const CURRENT_VERSION: int = 4
```

Replace the `save()` function (lines 19-42) with:
```gdscript
## Snapshot current state to a slot. scene/spawn default to the live scene tree
## + SceneManager's pending spawn when omitted (so production callers pass nothing).
## Only succeeds inside a BaseRoom — mid-battle (or any non-room screen) saves are
## rejected with no file written (#146).
func save(slot: int, scene: String = "", spawn: String = "") -> bool:
	var room := get_tree().current_scene
	if not (room is BaseRoom):
		return false

	var data := SaveData.new()
	data.save_version = CURRENT_VERSION
	data.flags = GameState.snapshot_flags()
	data.current_scene = scene if not scene.is_empty() else _current_scene_path()
	data.spawn_point = spawn if not spawn.is_empty() else SceneManager.pending_spawn_point
	data.roster = PartyManager.snapshot_roster()
	data.progression = PartyManager.snapshot_progression()
	data.party_runtime = PartyManager.snapshot_party_runtime()

	var player := room.get_node("Player") as Player
	data.player_position = player.position
	data.player_facing = player.facing
	data.has_player_position = true

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
```

- [ ] **Step 6: Implement the pending-field passthrough in `apply()`**

Replace `apply()` (lines 65-71) with:
```gdscript
## Restore a SaveData into the running game. navigate=false (tests) skips the
## scene transition so flag effects are observable without swapping the tree.
func apply(data: SaveData, navigate: bool = true) -> void:
	GameState.restore_flags(data.flags)
	PartyManager.restore_progression(data.progression)
	PartyManager.restore_roster(data.roster)
	PartyManager.restore_party_runtime(data.party_runtime)
	if data.has_player_position:
		SceneManager.pending_position = data.player_position
		SceneManager.pending_facing = data.player_facing
		SceneManager.has_pending_position = true
	if navigate:
		SceneManager.change_scene(data.current_scene, data.spawn_point)
```

- [ ] **Step 7: Run both affected suites to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd,res://tests/test_party_save.gd`
Expected: PASS — all tests green, including the existing flag/party round-trips (now saving from the installed `BaseRoom`).

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd tests/test_party_save.gd
git commit -m "feat: guard save on BaseRoom + capture player position/facing (#146)"
```

---

## Task 5: `BaseRoom._resolve_spawn()` consumes pending position

**Files:**
- Modify: `scripts/world/base_room.gd:29-39` (`_resolve_spawn`).
- Modify: `tests/test_base_room.gd` (pending-position resolution tests).

**Interfaces:**
- Consumes: `SceneManager.has_pending_position`/`pending_position`/`pending_facing` (Task 2); `Player.set_facing`/`Player.snap_to_grid` (Task 1).
- Produces: When `has_pending_position` is true, `_resolve_spawn()` snaps `$Player.position` to `pending_position`, calls `$Player.set_facing(pending_facing)`, resets `has_pending_position = false`, and skips the `SpawnPoint`/`default_spawn` lookup. When false, existing resolution is unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_base_room.gd`:

```gdscript
func test_resolve_spawn_uses_pending_position_when_armed() -> void:
	# (120, 88) is already a tile center → snap_to_grid is identity here.
	SceneManager.pending_position = Vector2(120, 88)
	SceneManager.pending_facing = Vector2i(-1, 0)
	SceneManager.has_pending_position = true

	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "unused"  # must be ignored while pending is armed (no SpawnPoint here)
	add_child(room)  # _ready() → _resolve_spawn()

	var player := room.get_node("Player") as Player
	assert_eq(player.position, Player.snap_to_grid(Vector2(120, 88), 16))
	assert_eq(player.facing, Vector2i(-1, 0))
	assert_false(SceneManager.has_pending_position, "flag is consumed after resolve")
	room.queue_free()


func test_resolve_spawn_ignores_pending_position_when_not_armed() -> void:
	SceneManager.has_pending_position = false
	SceneManager.pending_position = Vector2(999, 999)  # must be ignored

	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "default"
	var sp := SpawnPoint.new()
	sp.spawn_id = "default"
	sp.position = Vector2(128, 144)
	room.add_child(sp)
	add_child(room)

	var player := room.get_node("Player") as Player
	assert_eq(player.position, Player.snap_to_grid(Vector2(128, 144), 16),
		"unarmed pending falls back to default_spawn, not pending_position")
	room.queue_free()
```

- [ ] **Step 2: Run the base-room tests to verify the new tests fail**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_base_room.gd`
Expected: FAIL — `test_resolve_spawn_uses_pending_position_when_armed` fails (pending branch not implemented; player lands at default/early-return position, or asserts on `default_spawn="unused"` having no SpawnPoint).

- [ ] **Step 3: Implement the pending branch in `_resolve_spawn`**

Replace `_resolve_spawn()` (lines 29-39) with:
```gdscript
func _resolve_spawn() -> void:
	# A load restores the exact saved position/facing ahead of any SpawnPoint
	# lookup (#146). SaveManager.apply() is the only writer of these fields.
	if SceneManager.has_pending_position:
		$Player.position = Player.snap_to_grid(SceneManager.pending_position, 16)
		$Player.set_facing(SceneManager.pending_facing)
		SceneManager.has_pending_position = false
		return
	var target_id: String = SceneManager.pending_spawn_point
	if target_id == "":
		target_id = default_spawn
	SceneManager.pending_spawn_point = ""
	if target_id == "":
		return
	var sp := _find_spawn_point(target_id)
	assert(sp != null, "BaseRoom: no SpawnPoint with spawn_id='%s' in scene '%s'" % [target_id, name])
	$Player.position = Player.snap_to_grid(sp.position, 16)
```

- [ ] **Step 4: Run the base-room tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_base_room.gd`
Expected: PASS — including the existing `test_resolve_spawn_snaps_to_tile_center` (unarmed path unchanged).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/base_room.gd tests/test_base_room.gd
git commit -m "feat: BaseRoom restores exact pending position/facing on load (#146)"
```

---

## Task 6: End-to-end round-trip test

**Files:**
- Create: `tests/test_player_position_save.gd`.

**Interfaces:**
- Consumes: the full feature — `SaveManager.save()`/`read()`/`apply()`, `SceneManager` pending fields, `BaseRoom._resolve_spawn()`, `Player.facing`/`set_facing`.

- [ ] **Step 1: Write the round-trip test**

Create `tests/test_player_position_save.gd`:

```gdscript
extends GutTest

const SLOT: int = 0

var _room: BaseRoom = null
var _prev_scene: Node = null


func before_each() -> void:
	_remove_slot(SLOT)
	SceneManager.has_pending_position = false


func after_each() -> void:
	_teardown_base_room()
	_remove_slot(SLOT)
	SceneManager.has_pending_position = false


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _install_base_room() -> BaseRoom:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""  # set BEFORE add: _ready() runs on entering the tree
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_room = room
	return room


func _teardown_base_room() -> void:
	if _room == null:
		return
	get_tree().current_scene = _prev_scene
	_room.free()
	_room = null


func test_position_and_facing_survive_save_read_apply_and_reroom() -> void:
	# 1. Save from a room with the player at a non-default position/facing (AC1).
	var room := _install_base_room()
	var player := room.get_node("Player") as Player
	player.position = Vector2(120, 88)  # already a tile center
	player.set_facing(Vector2i(-1, 0))
	assert_true(SaveManager.save(SLOT))
	_teardown_base_room()

	# 2. Read + apply (navigate=false): arms SceneManager's pending fields.
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_true(data.has_player_position)
	SaveManager.apply(data, false)
	assert_eq(SceneManager.pending_position, Vector2(120, 88))
	assert_eq(SceneManager.pending_facing, Vector2i(-1, 0))
	assert_true(SceneManager.has_pending_position)

	# 3. A fresh destination room resolves spawn from the armed pending fields.
	var dest := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	dest.default_spawn = "unused"  # must be skipped while pending is armed
	add_child(dest)  # _ready() → _resolve_spawn()
	var restored := dest.get_node("Player") as Player
	assert_eq(restored.position, Player.snap_to_grid(Vector2(120, 88), 16))
	assert_eq(restored.facing, Vector2i(-1, 0))
	assert_false(SceneManager.has_pending_position, "pending flag consumed by the destination room")
	dest.queue_free()


func test_legacy_save_without_position_falls_back_to_default_spawn() -> void:
	# AC3: a save with has_player_position=false spawns at default_spawn, unchanged.
	SceneManager.has_pending_position = false
	var data := SaveData.new()  # has_player_position defaults false
	SaveManager.apply(data, false)
	assert_false(SceneManager.has_pending_position, "legacy save leaves pending disarmed")

	var dest := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	dest.default_spawn = "default"
	var sp := SpawnPoint.new()
	sp.spawn_id = "default"
	sp.position = Vector2(64, 48)
	dest.add_child(sp)
	add_child(dest)
	var restored := dest.get_node("Player") as Player
	assert_eq(restored.position, Player.snap_to_grid(Vector2(64, 48), 16),
		"legacy load resolves default_spawn, not a restored position")
	dest.queue_free()
```

- [ ] **Step 2: Run the new test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player_position_save.gd`
Expected: PASS — both round-trip and legacy-fallback tests green.

- [ ] **Step 3: Commit**

```bash
git add tests/test_player_position_save.gd
git commit -m "test: end-to-end player position/facing save round-trip (#146)"
```

---

## Task 7: Full-suite gate + manual smoketest

**Files:** none (verification only).

- [ ] **Step 1: Run the full GUT suite**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: All tests pass (allow for any documented pre-existing failures — none are expected in the touched areas). If anything in `test_save_manager`, `test_party_save`, `test_base_room`, `test_scene_manager`, `test_save_data`, or `test_player` is red, fix before proceeding.

- [ ] **Step 2: Manual smoketest via `/run` (AC1–AC4)**

Launch the game with `/run` and verify:
- **AC1:** Walk to an arbitrary (non-default-spawn) tile, face a non-default direction, press **F5** (save), then **F9** (load) — player is restored to that exact tile and facing.
- **AC2:** Enter a battle, press **F5** — the debug overlay prints `FAILED`, no crash, and no save file is written/overwritten.
- **AC3:** With a pre-v4 save (or any save where `has_player_position` is false), load — player spawns at the room's `default_spawn`, unchanged.
- **AC4:** Walk through a door (`ExitDoor` → named `SpawnPoint`) — destination spawn is unaffected; `pending_position` is never set outside `SaveManager.apply()`.

- [ ] **Step 3: Finish the branch**

Use the project's `finishing-a-development-branch` skill: it re-runs GUT headlessly, runs the visual smoketest, and opens the PR (PR-only integration — never merge locally to master).

---

## Self-Review

**1. Spec coverage:**
- R1 (SaveData fields + v4) → Task 3. ✅
- R2 (BaseRoom allowlist guard, no file on reject) → Task 4 (guard + rejection test). ✅
- R3 (capture `$Player.position`/`facing`, `has_player_position=true`) → Task 4 (capture test). ✅
- R4 (`Player.facing` public + `set_facing`) → Task 1. ✅
- R5 (SceneManager pending fields, set only by apply) → Task 2 (fields) + Task 4 (apply passthrough). ✅
- R6 (`_resolve_spawn` checks pending first, snaps + set_facing + reset) → Task 5. ✅
- R7 (no position validation) → honored: `_resolve_spawn` restores unconditionally. ✅
- R8 (legacy `has_player_position=false` → default_spawn) → Task 5 (`test_resolve_spawn_ignores_pending...`) + Task 6 (legacy-fallback). ✅
- AC1 → Task 6 round-trip + Task 7 manual. AC2 → Task 4 rejection test + Task 7 manual. AC3 → Task 5/6 legacy tests + Task 7 manual. AC4 → Task 7 manual (Global Constraint: pending set only by apply). ✅
- All impacted files from the issue are covered; `debug_overlay.gd` intentionally unchanged (documented in Global Constraints).

**2. Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N" — all code is spelled out. ✅

**3. Type consistency:** `facing: Vector2i`, `set_facing(dir: Vector2i)`, `pending_position: Vector2`, `pending_facing: Vector2i`, `has_pending_position: bool`, `player_position: Vector2`, `player_facing: Vector2i`, `has_player_position: bool`, `CURRENT_VERSION == 4` / `save_version == 4` — used identically across all tasks and tests. `snap_to_grid(pos, 16)` and `set_facing(...)` signatures match Task 1. ✅
