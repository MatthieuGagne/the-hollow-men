# BattleContext (replaces BattleParams) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the untyped, destructively-consumed `BattleParams` autoload with a typed `BattleContext` autoload that is read non-destructively and fully populated by each encounter trigger — fixing the defeat→retry bug and eliminating stale-field carryover.

**Architecture:** `BattleContext` is a Node autoload (must stay an autoload to survive `change_scene_to_file`, which frees the world scene). It carries four String fields and exposes one method, `configure(...)`, that overwrites **all four** fields in a single call. Each encounter trigger (`CutsceneZone`, `BattleEncounter`, legacy `World`) calls `configure()` to build a *fresh* context before transitioning. `BattleScene` reads the fields without clearing them, so a defeat→retry reload (which re-enters `BattleScene` without re-triggering) reuses the same encounter instead of falling back to a default Shade.

**Tech Stack:** Godot 4.6 / GDScript, GUT for tests. Mobile (GL Compatibility) renderer — no renderer concerns in this slice.

**GitHub issue:** #119 (part of epic #129, Phase 1).

---

## Conventions & Settled Decisions

Read these before starting — they resolve ambiguity in the spec.

- **Indentation:** every file in this plan uses **TABS** *except* `scripts/world/battle_encounter.gd`, which uses **4 SPACES**. Match the file you are editing. The code blocks below already use the correct whitespace for their target file.
- **No `class_name`** on `BattleContext`. A `class_name` matching the autoload name collides in Godot 4 ("hides an autoload singleton"). Access is via the autoload global `BattleContext`, exactly like the old `BattleParams`. The "typed" requirement (R1) is satisfied by typed fields + the typed `configure()` signature.
- **`enemies` stays a comma-separated String** of resource paths. Converting to ids is explicitly out of scope (epic PRD #120/#121).
- **R6 default world scene = `res://scenes/world/Rooftop.tscn`** — the project's configured `run/main_scene`. This fallback is now defensive only: every trigger populates `return_scene`, so it is rarely hit. The old `RoomPOC.tscn` is the stale proof-of-concept scene.
- **CutsceneZone populates a fresh context unconditionally** on dialogue close (R3). A narrative-only cutscene simply writes an empty context — harmless, and it actively clears stale battle state. CutsceneZone has no background override export, so it passes `background_id = ""` (→ BattleScene's "default"), preserving current behavior.
- **Victory does NOT clear the context** (R5 says clearing is *optional*). The next encounter's `configure()` overwrites it. Keeping it simple avoids a clear-vs-retry ordering hazard.
- **Incremental commits are work-in-progress.** Between Task 2 and Task 6 a cutscene-triggered battle is temporarily misconfigured (one side migrated, the other not). The *slice* (the whole PR) is the unit that must leave the game running; full functional integration is verified in Task 7. This is normal for a rename refactor on a feature branch.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `scripts/autoload/battle_context.gd` | Typed battle-setup transport + `configure()` | Create (replaces `battle_params.gd`) |
| `scripts/autoload/battle_params.gd` | Old untyped transport | Delete (Task 6) |
| `project.godot` | Autoload registry | Modify (add BattleContext; remove BattleParams) |
| `scripts/battle/battle_scene.gd` | Reads context non-destructively; victory return; WORLD_SCENE | Modify |
| `scripts/world/cutscene_zone.gd` | Fully populates fresh context on dialogue close | Modify |
| `scripts/world/battle_encounter.gd` | Sets enemy table explicitly + fresh context (4-SPACE indent) | Modify |
| `scripts/world/world.gd` | Legacy random-encounter trigger populates context | Modify |
| `tests/test_battle_context.gd` | Unit tests for context + non-destructive reads (AC4) | Create |
| `tests/test_battle_encounter.gd` | Unit tests for explicit enemy resolution | Create |
| `tests/test_battle_scene.gd` | Migrate to BattleContext; invert destructive-clear test | Modify |
| `tests/test_cutscene_zone.gd` | Migrate to BattleContext; invert no-overwrite tests | Modify |

---

## Task 1: Create the BattleContext autoload

Add the new autoload **alongside** the existing `BattleParams` (we remove `BattleParams` in Task 6). This keeps every prior consumer working between tasks.

**Files:**
- Create: `scripts/autoload/battle_context.gd`
- Create: `tests/test_battle_context.gd`
- Modify: `project.godot:18-27` (autoload section)

- [ ] **Step 1: Write the failing test** (TABS)

Create `tests/test_battle_context.gd`:

```gdscript
extends GutTest


func before_each() -> void:
	BattleContext.configure()  # reset to defaults between tests


func after_all() -> void:
	BattleContext.configure()


func test_defaults_are_empty() -> void:
	assert_eq(BattleContext.enemies, "")
	assert_eq(BattleContext.background_id, "")
	assert_eq(BattleContext.return_scene, "")
	assert_eq(BattleContext.return_spawn, "")


func test_configure_sets_all_fields() -> void:
	BattleContext.configure("a.tres,b.tres", "alley",
		"res://scenes/world/FourWindsBar.tscn", "door")
	assert_eq(BattleContext.enemies, "a.tres,b.tres")
	assert_eq(BattleContext.background_id, "alley")
	assert_eq(BattleContext.return_scene, "res://scenes/world/FourWindsBar.tscn")
	assert_eq(BattleContext.return_spawn, "door")


func test_reads_are_non_destructive() -> void:
	BattleContext.configure("shade.tres", "alley", "res://world.tscn", "spawn")
	# First read — as BattleScene._spawn_enemies / _load_background would do
	assert_eq(BattleContext.enemies, "shade.tres")
	assert_eq(BattleContext.background_id, "alley")
	# Second read — a retry reload re-enters BattleScene and reads again
	assert_eq(BattleContext.enemies, "shade.tres")
	assert_eq(BattleContext.background_id, "alley")


func test_retry_path_preserves_enemy_list() -> void:
	BattleContext.configure("a.tres,b.tres", "alley", "res://world.tscn", "spawn")
	var first_read := BattleContext.enemies
	var retry_read := BattleContext.enemies  # no trigger repopulates on retry
	assert_eq(first_read, "a.tres,b.tres")
	assert_eq(retry_read, "a.tres,b.tres",
		"retry must reuse the same enemy list (AC2)")


func test_second_configure_overwrites_with_no_leftover() -> void:
	BattleContext.configure("a.tres", "alley", "res://a.tscn", "spawnA")
	BattleContext.configure("b.tres", "rooftop", "res://b.tscn", "spawnB")
	assert_eq(BattleContext.enemies, "b.tres")
	assert_eq(BattleContext.background_id, "rooftop")
	assert_eq(BattleContext.return_scene, "res://b.tscn")
	assert_eq(BattleContext.return_spawn, "spawnB")


func test_configure_no_args_clears_all_fields() -> void:
	BattleContext.configure("a.tres", "alley", "res://a.tscn", "spawnA")
	BattleContext.configure()
	assert_eq(BattleContext.enemies, "")
	assert_eq(BattleContext.background_id, "")
	assert_eq(BattleContext.return_scene, "")
	assert_eq(BattleContext.return_spawn, "")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_context.gd`
Expected: FAIL / load error — `BattleContext` is not a declared identifier (autoload does not exist yet).

- [ ] **Step 3: Create the BattleContext script** (TABS)

Create `scripts/autoload/battle_context.gd`:

```gdscript
extends Node
## Typed transport carrying battle setup across the transition into BattleScene.
## Registered as the BattleContext autoload (/root/BattleContext) so it survives
## change_scene_to_file, which frees the world scene.
##
## An encounter trigger fully populates a FRESH context via configure() before
## SceneManager.change_scene. BattleScene reads these fields NON-DESTRUCTIVELY,
## so a defeat→retry reload (which re-enters BattleScene without re-triggering)
## reuses the same encounter instead of falling back to a default Shade.

## Comma-separated enemy resource paths. "" → BattleScene spawns its default Shade.
var enemies: String = ""
## Battle background id (file stem under assets/battle_backgrounds/). "" → "default".
var background_id: String = ""
## World scene to return to on victory. "" → BattleScene.WORLD_SCENE fallback.
var return_scene: String = ""
## Spawn point name within return_scene.
var return_spawn: String = ""


## Fully populate a fresh context, overwriting every field. Because all four
## fields are always assigned, nothing carries over from a previous encounter.
func configure(p_enemies: String = "", p_background_id: String = "",
		p_return_scene: String = "", p_return_spawn: String = "") -> void:
	enemies = p_enemies
	background_id = p_background_id
	return_scene = p_return_scene
	return_spawn = p_return_spawn
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, the `[autoload]` section currently reads (lines 18-27):

```
[autoload]

CellRegistry="*res://scripts/autoload/cell_registry.gd"
SceneManager="*res://scripts/autoload/scene_manager.gd"
BattleParams="*res://scripts/autoload/battle_params.gd"
AudioManager="*res://scripts/autoload/audio_manager.gd"
GameState="*res://scripts/autoload/game_state.gd"
PartyManager="*res://scripts/autoload/party_manager.gd"
DialogueManager="*res://scenes/autoload/DialogueManager.tscn"
DebugOverlay="*res://scripts/autoload/debug_overlay.gd"
```

Add the `BattleContext` line immediately after the `BattleParams` line (keep `BattleParams` for now):

```
BattleParams="*res://scripts/autoload/battle_params.gd"
BattleContext="*res://scripts/autoload/battle_context.gd"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_context.gd`
Expected: PASS — 7 passing tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/battle_context.gd tests/test_battle_context.gd project.godot
git commit -m "feat: add BattleContext autoload with non-destructive configure()"
```

---

## Task 2: Migrate BattleScene to BattleContext (non-destructive reads + WORLD_SCENE fix)

Remove the two destructive clears (`battle_scene.gd:94`, `:107`), rename all `BattleParams` references to `BattleContext`, and fix the stale `WORLD_SCENE` default. This is the core retry fix.

**Files:**
- Modify: `scripts/battle/battle_scene.gd` (`WORLD_SCENE` const, `_spawn_enemies`, `_load_background`, `_on_battle_ended`)
- Modify: `tests/test_battle_scene.gd` (`before_each` + 6 tests)

- [ ] **Step 1: Update the destructive-clear test to assert non-destructive behavior (RED)** (TABS)

In `tests/test_battle_scene.gd`, replace the existing test at lines 1009-1014:

```gdscript
func test_spawn_enemies_clears_battle_params_enemies_after_use() -> void:
	BattleParams.enemies = "res://characters/enemies/territory_enforcer.tres"
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(BattleParams.enemies, "",
		"BattleParams.enemies must be cleared after _spawn_enemies consumes it")
```

with the inverted test:

```gdscript
func test_spawn_enemies_does_not_clear_context_enemies() -> void:
	BattleContext.enemies = "res://characters/enemies/territory_enforcer.tres"
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(BattleContext.enemies, "res://characters/enemies/territory_enforcer.tres",
		"BattleContext.enemies must survive a read so defeat→retry reuses it (AC2)")
```

- [ ] **Step 2: Migrate the remaining `BattleParams` references in the test file** (TABS)

In `tests/test_battle_scene.gd` make these edits:

`before_each` (lines 9-10) — replace:
```gdscript
	BattleParams.return_scene = ""
	BattleParams.enemies = ""
```
with a single full reset:
```gdscript
	BattleContext.configure()
```

Rename test + symbols at lines 18-19:
```gdscript
func test_battle_params_return_scene_defaults_to_empty() -> void:
	assert_eq(BattleParams.return_scene, "", "return_scene should default to empty string")
```
→
```gdscript
func test_battle_context_return_scene_defaults_to_empty() -> void:
	assert_eq(BattleContext.return_scene, "", "return_scene should default to empty string")
```

Rename test + symbols at lines 22-23:
```gdscript
func test_battle_params_return_spawn_defaults_to_empty() -> void:
	assert_eq(BattleParams.return_spawn, "", "return_spawn should default to empty string")
```
→
```gdscript
func test_battle_context_return_spawn_defaults_to_empty() -> void:
	assert_eq(BattleContext.return_spawn, "", "return_spawn should default to empty string")
```

Lines 686-687 (`test_victory_uses_return_scene_when_set`) — replace `BattleParams` with `BattleContext` on both lines:
```gdscript
	BattleContext.return_scene = "res://scenes/world/FourWindsBar.tscn"
	assert_eq(BattleContext.return_scene, "res://scenes/world/FourWindsBar.tscn")
```

Line 996 — the comment string, change `BattleParams.enemies` → `BattleContext.enemies`:
```gdscript
		"default enemy must be a Shade when BattleContext.enemies is empty")
```

Lines 1000-1004 (`test_spawn_enemies_uses_battle_params_enemies_when_set`) — replace `BattleParams` with `BattleContext` (line 1000 assignment and line 1004 comment string). Leave the test name as-is or rename to `..._context_...`; renaming is optional and not required for AC5 (test *names* are not references). For consistency, rename:
```gdscript
func test_spawn_enemies_uses_context_enemies_when_set() -> void:
	BattleContext.enemies = "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres"
	var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(scene2.enemies.size(), 2,
		"must spawn 2 enemies when BattleContext.enemies has 2 paths")
	assert_eq(scene2.enemies[0].character_name, "Territory Enforcer")
	assert_eq(scene2.enemies[1].character_name, "Territory Enforcer")
```

- [ ] **Step 3: Run the migrated tests to verify the failure is the new assertion (RED)**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_scene.gd`
Expected: FAIL — `test_spawn_enemies_does_not_clear_context_enemies` fails because `BattleScene` still reads `BattleParams` (so `BattleContext.enemies` is never consumed but the scene under test still clears `BattleParams`, and `_spawn_enemies` does not yet read `BattleContext`). Other migrated tests may also fail until Step 4.

- [ ] **Step 4: Rewrite the three BattleScene functions + the WORLD_SCENE const** (TABS)

In `scripts/battle/battle_scene.gd`:

Line 55 — change the default world scene:
```gdscript
const WORLD_SCENE:   String = "res://scenes/world/RoomPOC.tscn"
```
→
```gdscript
const WORLD_SCENE:   String = "res://scenes/world/Rooftop.tscn"
```

Replace `_spawn_enemies` (lines 91-102) — drop the local `paths` var and the destructive clear:
```gdscript
func _spawn_enemies() -> void:
	if BattleContext.enemies != "":
		for path: String in BattleContext.enemies.split(","):
			var c: Combatant = (load(path.strip_edges()) as Combatant).duplicate()
			c.reset_runtime_state()
			add_enemy(c)
	else:
		var shade: Combatant = load(SHADE_RES).duplicate()
		shade.reset_runtime_state()
		add_enemy(shade)
```

Replace `_load_background` (lines 105-111) — drop the destructive clear:
```gdscript
func _load_background() -> void:
	var id := BattleContext.background_id if BattleContext.background_id != "" else "default"
	var path := "res://assets/battle_backgrounds/%s.png" % id
	if not ResourceLoader.exists(path):
		path = "res://assets/battle_backgrounds/default.png"
	_background.texture = load(path)
```

In `_on_battle_ended`, replace the victory-return lines (lines 554-555):
```gdscript
			var target := BattleParams.return_scene if BattleParams.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target, BattleParams.return_spawn)
```
→
```gdscript
			var target := BattleContext.return_scene if BattleContext.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target, BattleContext.return_spawn)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_scene.gd`
Expected: PASS — all `test_battle_scene.gd` tests pass, including `test_spawn_enemies_does_not_clear_context_enemies`.

- [ ] **Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "fix: BattleScene reads BattleContext non-destructively; fix retry + WORLD_SCENE default"
```

---

## Task 3: Migrate CutsceneZone to populate a fresh context

Replace the conditional per-field `BattleParams` writes with a single `BattleContext.configure(...)` call that fully populates a fresh context (R3). Invert the two "does not overwrite" tests to assert no-carryover.

**Files:**
- Modify: `scripts/world/cutscene_zone.gd` (`_on_dialogue_closed`, lines 73-87)
- Modify: `tests/test_cutscene_zone.gd` (`before_each` + 6 battle-param tests)

- [ ] **Step 1: Update the CutsceneZone tests (RED)** (TABS)

In `tests/test_cutscene_zone.gd`:

`before_each` (lines 11-12) — replace:
```gdscript
	BattleParams.return_scene = ""
	BattleParams.enemies = ""
```
with:
```gdscript
	BattleContext.configure()
```

Replace the test at lines 152-155:
```gdscript
func test_battle_return_scene_sets_battle_params() -> void:
	_zone.battle_return_scene = "res://scenes/world/SprawlSafehouse.tscn"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_scene, "res://scenes/world/SprawlSafehouse.tscn")
```
→
```gdscript
func test_battle_return_scene_sets_context() -> void:
	_zone.battle_return_scene = "res://scenes/world/SprawlSafehouse.tscn"
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.return_scene, "res://scenes/world/SprawlSafehouse.tscn")
```

Replace the test at lines 158-162 (invert — fresh context clears stale value):
```gdscript
func test_battle_return_scene_empty_does_not_overwrite_battle_params() -> void:
	BattleParams.return_scene = "res://scenes/world/SomeOtherScene.tscn"
	_zone.battle_return_scene = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_scene, "res://scenes/world/SomeOtherScene.tscn")
```
→
```gdscript
func test_empty_battle_return_scene_yields_fresh_empty_context() -> void:
	BattleContext.return_scene = "res://scenes/world/SomeOtherScene.tscn"
	_zone.battle_return_scene = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.return_scene, "",
		"a fresh context must clear a stale return_scene — no carryover")
```

Replace the test at lines 169-172:
```gdscript
func test_battle_return_spawn_point_sets_battle_params_return_spawn() -> void:
	_zone.battle_return_spawn_point = "battle_return"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.return_spawn, "battle_return")
```
→
```gdscript
func test_battle_return_spawn_point_sets_context_return_spawn() -> void:
	_zone.battle_return_spawn_point = "battle_return"
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.return_spawn, "battle_return")
```

Replace the test at lines 175-178:
```gdscript
func test_pre_battle_enemies_empty_does_not_set_battle_params() -> void:
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "")
```
→
```gdscript
func test_pre_battle_enemies_empty_yields_empty_context() -> void:
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.enemies, "")
```

Replace the test at lines 181-184:
```gdscript
func test_pre_battle_enemies_sets_battle_params_enemies() -> void:
	_zone.pre_battle_enemies = "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres"
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres")
```
→
```gdscript
func test_pre_battle_enemies_sets_context_enemies() -> void:
	_zone.pre_battle_enemies = "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres"
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.enemies, "res://characters/enemies/territory_enforcer.tres,res://characters/enemies/territory_enforcer.tres")
```

Replace the test at lines 187-191 (invert — fresh context clears stale enemies, the AC1 mechanism):
```gdscript
func test_pre_battle_enemies_empty_does_not_overwrite_existing_battle_params() -> void:
	BattleParams.enemies = "res://characters/enemies/shade.tres"
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleParams.enemies, "res://characters/enemies/shade.tres")
```
→
```gdscript
func test_fresh_context_clears_stale_enemies() -> void:
	BattleContext.enemies = "res://characters/enemies/shade.tres"
	_zone.pre_battle_enemies = ""
	_zone._on_dialogue_closed()
	assert_eq(BattleContext.enemies, "",
		"a fresh context must clear a stale enemy table — no carryover (AC1)")
```

- [ ] **Step 2: Run the CutsceneZone tests to verify they fail (RED)**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_cutscene_zone.gd`
Expected: FAIL — the inverted tests fail because `_on_dialogue_closed` still writes `BattleParams` conditionally (stale values are preserved, not cleared).

- [ ] **Step 3: Rewrite `_on_dialogue_closed`** (TABS)

In `scripts/world/cutscene_zone.gd`, replace the function (lines 73-87):
```gdscript
func _on_dialogue_closed() -> void:
	if pre_battle_guests != "":
		for path: String in pre_battle_guests.split(","):
			var c: Combatant = (load(path.strip_edges()) as Combatant).duplicate()
			c.reset_runtime_state()
			PartyManager.add_temporary(c)
	if pre_battle_enemies != "":
		BattleParams.enemies = pre_battle_enemies
	if battle_return_scene != "":
		BattleParams.return_scene = battle_return_scene
	if battle_return_spawn_point != "":
		BattleParams.return_spawn = battle_return_spawn_point
	if next_scene.is_empty():
		return
	SceneManager.change_scene(next_scene)
```
with:
```gdscript
func _on_dialogue_closed() -> void:
	if pre_battle_guests != "":
		for path: String in pre_battle_guests.split(","):
			var c: Combatant = (load(path.strip_edges()) as Combatant).duplicate()
			c.reset_runtime_state()
			PartyManager.add_temporary(c)
	# Fully populate a FRESH battle context so nothing carries over from a
	# previous encounter (stale enemy table, background, or return scene).
	# CutsceneZone has no background override, so background_id stays "" → default.
	BattleContext.configure(pre_battle_enemies, "", battle_return_scene, battle_return_spawn_point)
	if next_scene.is_empty():
		return
	SceneManager.change_scene(next_scene)
```

- [ ] **Step 4: Run the CutsceneZone tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_cutscene_zone.gd`
Expected: PASS — all `test_cutscene_zone.gd` tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/cutscene_zone.gd tests/test_cutscene_zone.gd
git commit -m "feat: CutsceneZone populates a fresh BattleContext (no carryover)"
```

---

## Task 4: BattleEncounter sets its enemy table explicitly

Add an explicit enemy table (R3 — no read-side fallback) and populate a fresh context including the current scene as `return_scene`. **This file uses 4-SPACE indentation** — the code block below is already spaced; do not convert to tabs.

**Files:**
- Modify: `scripts/world/battle_encounter.gd` (full rewrite, 4-SPACE indent)
- Create: `tests/test_battle_encounter.gd` (TABS — test files use tabs)

- [ ] **Step 1: Write the failing test for explicit enemy resolution** (TABS)

Create `tests/test_battle_encounter.gd`:

```gdscript
extends GutTest

const ENCOUNTER := preload("res://scripts/world/battle_encounter.gd")


func test_resolve_enemies_uses_custom_when_set() -> void:
	assert_eq(ENCOUNTER._resolve_enemies("a.tres,b.tres"), "a.tres,b.tres")


func test_resolve_enemies_falls_back_to_shade_when_empty() -> void:
	assert_eq(ENCOUNTER._resolve_enemies(""),
		"res://characters/enemies/shade.tres",
		"empty enemy table must resolve to a Shade explicitly, not via a read-side default")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_encounter.gd`
Expected: FAIL — `_resolve_enemies` does not exist on `battle_encounter.gd` yet.

- [ ] **Step 3: Rewrite `battle_encounter.gd`** (4-SPACE INDENT)

Replace the entire contents of `scripts/world/battle_encounter.gd` with:

```gdscript
extends Area2D

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const DEFAULT_ENEMIES := "res://characters/enemies/shade.tres"

@export var battle_background_override: String = ""
## Comma-separated enemy resource paths for this encounter. Empty falls back to a
## single Shade — set explicitly here, never via BattleScene's read-side default.
@export var enemies: String = ""


func _ready() -> void:
    body_entered.connect(_on_body_entered)


static func _resolve_background_id(override: String, room_bg: String) -> String:
    if override != "":
        return override
    if room_bg != "":
        return room_bg
    return "default"


static func _resolve_enemies(custom: String) -> String:
    return custom if custom != "" else DEFAULT_ENEMIES


func _get_background_id() -> String:
    var room_bg := ""
    var scene := get_tree().current_scene
    if "battle_background" in scene:
        room_bg = scene.battle_background
    return _resolve_background_id(battle_background_override, room_bg)


func _on_body_entered(_body: Node2D) -> void:
    var return_scene := ""
    var scene := get_tree().current_scene
    if scene != null:
        return_scene = scene.scene_file_path
    BattleContext.configure(_resolve_enemies(enemies), _get_background_id(), return_scene, "")
    SceneManager.change_scene(BATTLE_SCENE)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gselect=test_battle_encounter.gd`
Expected: PASS — both `_resolve_enemies` tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/battle_encounter.gd tests/test_battle_encounter.gd
git commit -m "feat: BattleEncounter sets enemy table + fresh BattleContext explicitly"
```

---

## Task 5: Legacy World random-encounter populates the context

The `World._load_battle_scene` stub must populate a fresh context too (R3), instead of leaving the TODO that relied on the read-side default.

**Files:**
- Modify: `scripts/world/world.gd` (`_load_battle_scene`, lines 49-51)

- [ ] **Step 1: Rewrite `_load_battle_scene`** (TABS)

In `scripts/world/world.gd`, replace (lines 49-51):
```gdscript
func _load_battle_scene() -> void:
	# TODO: pass current enemy table to BattleScene
	SceneManager.change_scene("res://scenes/battle/BattleScene.tscn")
```
with:
```gdscript
func _load_battle_scene() -> void:
	# Populate a fresh context explicitly — never rely on BattleScene's read-side
	# default. Random world encounters return to the current scene.
	var return_scene := ""
	var scene := get_tree().current_scene
	if scene != null:
		return_scene = scene.scene_file_path
	BattleContext.configure("res://characters/enemies/shade.tres", "default", return_scene, "")
	SceneManager.change_scene("res://scenes/battle/BattleScene.tscn")
```

- [ ] **Step 2: Verify the project parses (no test — encounter rate is 0 in INVESTIGATION; this path is a stub)**

Run: `godot_console --headless --editor --quit --path .`
Expected: editor opens, imports, and quits with no script/parse errors mentioning `world.gd`.

- [ ] **Step 3: Commit**

```bash
git add scripts/world/world.gd
git commit -m "feat: legacy World encounter populates a fresh BattleContext"
```

---

## Task 6: Remove BattleParams (AC5)

Delete the old autoload and its script. Confirm there are zero remaining references.

**Files:**
- Delete: `scripts/autoload/battle_params.gd`
- Modify: `project.godot` (remove the `BattleParams` autoload line)

- [ ] **Step 1: Remove the autoload registration**

In `project.godot`, delete the line:
```
BattleParams="*res://scripts/autoload/battle_params.gd"
```
(Leave the `BattleContext` line added in Task 1.)

- [ ] **Step 2: Delete the old script**

```bash
git rm scripts/autoload/battle_params.gd
```

- [ ] **Step 3: Confirm no remaining references (AC5)**

Use the Grep tool (or): `git grep -n "BattleParams" -- ":!docs/"`
Expected: **no matches** in `scripts/`, `tests/`, `scenes/`, `project.godot`. (Matches under `docs/` — historical plan notes and `docs/architecture.html` — are documentation, not code references, and are acceptable; update `docs/architecture.html` only if the team treats it as living spec — out of scope here.)

- [ ] **Step 4: Commit**

```bash
git add project.godot
git commit -m "refactor: remove BattleParams autoload (replaced by BattleContext)"
```

---

## Task 7: Full-suite verification

- [ ] **Step 1: Reimport (autoload + script changes)**

Run: `godot_console --headless --editor --quit --path .`
Expected: clean import, no parse errors.

- [ ] **Step 2: Run the entire GUT suite**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: all tests pass **except** any pre-existing failures already documented in memory (`godot-expert.md` notes known pre-existing failures unrelated to this slice). Confirm the four touched suites are green: `test_battle_context.gd`, `test_battle_scene.gd`, `test_cutscene_zone.gd`, `test_battle_encounter.gd`. If a failure appears that is NOT pre-existing, stop and fix before proceeding.

- [ ] **Step 3: Manual smoketest (AC1, AC2, AC3) — use the `/run` skill**

With the game running:
- AC2 (the headline fix): trigger a battle, lose it, choose **Retry** → the **same** enemies and background load, not a fallback Shade.
- AC3: win a battle triggered from a CutsceneZone with `battle_return_scene` set → return to that scene/spawn.
- AC1: walk into a `BattleEncounter`, then a different encounter → each starts with the correct (non-carried-over) enemies. *(If no two distinct `BattleEncounter` instances exist to walk between, this is covered at unit level by `test_second_configure_overwrites_with_no_leftover`; note that in the smoketest write-up.)*

- [ ] **Step 4: Done** — proceed to `finishing-a-development-branch` (tests, smoketest record, PR against `master`, worktree cleanup).

---

## Self-Review

**Spec coverage (R1-R6, AC1-AC5):**

- R1 (typed BattleContext autoload, four fields) → Task 1.
- R2 (non-destructive reads) → Task 2 (clears removed at `_spawn_enemies`/`_load_background`); proven by `test_spawn_enemies_does_not_clear_context_enemies` + `test_reads_are_non_destructive`.
- R3 (every trigger fully populates a fresh context; BattleEncounter explicit enemies) → Tasks 3 (CutsceneZone), 4 (BattleEncounter `_resolve_enemies` + `configure`), 5 (World).
- R4 (context persists across retry) → Task 2 + `test_retry_path_preserves_enemy_list`.
- R5 (overwritten only on next encounter; victory-clear optional/skipped) → decision documented; `configure()` is the only writer.
- R6 (WORLD_SCENE → correct default) → Task 2, `Rooftop.tscn`.
- AC1 (no carryover between encounters) → `test_fresh_context_clears_stale_enemies` (CutsceneZone) + `test_second_configure_overwrites_with_no_leftover` + smoketest Step 3.
- AC2 (retry reuses same encounter) → `test_spawn_enemies_does_not_clear_context_enemies` + `test_retry_path_preserves_enemy_list` + smoketest.
- AC3 (victory returns from context) → existing `test_victory_uses_return_scene_when_set` (migrated) + smoketest.
- AC4 (configure → two reads preserve; retry preserves; second config overwrites cleanly) → `test_battle_context.gd` (all four scenarios present).
- AC5 (no BattleParams references) → Task 6 Step 3 grep.

**Placeholder scan:** No TBD/TODO left in delivered code (the `world.gd` TODO is removed in Task 5). Every code step shows full code.

**Type/name consistency:** `configure(p_enemies, p_background_id, p_return_scene, p_return_spawn)` signature is used identically in Tasks 1, 3, 4, 5. Field names `enemies` / `background_id` / `return_scene` / `return_spawn` match across the autoload, BattleScene reads, and all triggers. `_resolve_enemies` defined in Task 4 Step 3 and called in the same file + tested in Task 4 Step 1. `DEFAULT_ENEMIES` = `res://characters/enemies/shade.tres` is consistent between `battle_encounter.gd` and `world.gd`.

**Whitespace:** `battle_encounter.gd` block is 4-space; all other code/test blocks are tabbed — flagged in Conventions and at each task.
