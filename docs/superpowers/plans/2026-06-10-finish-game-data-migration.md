# Finish GameData Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the two remaining path-based combatant loads left over from PR #131 so every combatant lookup goes through `GameData.get_combatant(id)`.

**Architecture:** Two independent cleanup sites — (1) a debug battle scene that still uses a hardcoded `const GUARD_RES` path, and (2) `CutsceneZone._on_dialogue_closed` that still resolves `pre_battle_guests` via `load(path)`. Both are swapped to id-based lookups matching the pattern already established across all other battle scenes. The TMX property and its GUT tests are updated in lockstep.

**Tech Stack:** GDScript, GUT (headless test runner), Tiled TMX XML

---

### Task 1: Replace `GUARD_RES` in `test_intro_encounter1_scene.gd`

**Files:**
- Modify: `scripts/battle/test_intro_encounter1_scene.gd`

Context: `test_intro_encounter2_scene.gd` already uses the id pattern — this is the only remaining outlier.

- [ ] **Step 1: Update the file**

Replace the entire file content:

```gdscript
extends BattleScene


func _spawn_enemies() -> void:
	for _i in range(2):
		var guard: Combatant = GameData.get_combatant("private_security_guard").duplicate()
		guard.reset_runtime_state()
		add_enemy(guard)
```

- [ ] **Step 2: Run the full GUT suite to confirm no regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: same pass/fail counts as before this change (no new failures).

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/test_intro_encounter1_scene.gd
git commit -m "chore: replace GUARD_RES path with GameData.get_combatant in test_intro_encounter1_scene"
```

---

### Task 2: Migrate `CutsceneZone.pre_battle_guests` from path to id

**Files:**
- Modify: `scripts/world/cutscene_zone.gd:74-77`
- Modify: `tests/test_cutscene_zone.gd:139,146`
- Modify: `maps/sprawl_safehouse.tmx:89`

Context: `cutscene_zone.gd` splits `pre_battle_guests` on commas and loads each entry as a resource path. Replace the `load(path)` call with `GameData.get_combatant(id)`. The three existing tests that pass `"res://characters/iris.tres"` must be updated to pass `"iris"` (the id defined in `characters/iris.tres`). The TMX property must also change so the live map is consistent.

- [ ] **Step 1: Update the failing test values first (write the tests to expect the new contract)**

In `tests/test_cutscene_zone.gd`, change the three `pre_battle_guests` test assignments from the resource path to the combatant id:

```gdscript
# line 139 — was: _zone.pre_battle_guests = "res://characters/iris.tres"
func test_pre_battle_guests_adds_iris_to_party() -> void:
	_zone.pre_battle_guests = "iris"
	_zone._on_dialogue_closed()
	assert_true(PartyManager.has_member("Iris"))


# line 145-147 — was: _zone.pre_battle_guests = "res://characters/iris.tres"
func test_pre_battle_guests_does_not_modify_permanent_members() -> void:
	var before_count: int = PartyManager._permanent_members.size()
	_zone.pre_battle_guests = "iris"
	_zone._on_dialogue_closed()
	assert_eq(PartyManager._permanent_members.size(), before_count)
```

(`test_pre_battle_guests_empty_does_not_add_temporary_members` at line 132 uses `""` and needs no change.)

- [ ] **Step 2: Run the two affected tests to confirm they now fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=test_pre_battle_guests_adds_iris_to_party,test_pre_battle_guests_does_not_modify_permanent_members
```

Expected: FAIL — `cutscene_zone.gd` still calls `load("iris")` which is not a valid path.

- [ ] **Step 3: Update `_on_dialogue_closed` in `cutscene_zone.gd`**

Replace lines 74–77 (the `pre_battle_guests` loop):

```gdscript
	if pre_battle_guests != "":
		for id: String in pre_battle_guests.split(","):
			var c: Combatant = GameData.get_combatant(id.strip_edges()).duplicate()
			c.reset_runtime_state()
			PartyManager.add_temporary(c)
```

- [ ] **Step 4: Run the full GUT suite to confirm all tests pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests pass, including the two that were failing in Step 2.

- [ ] **Step 5: Update the TMX property**

In `maps/sprawl_safehouse.tmx`, change line 89:

```xml
    <property name="pre_battle_guests" value="iris"/>
```

(was `value="res://characters/iris.tres"`)

- [ ] **Step 6: Reimport the map**

The `.godot/imported/` TSCN for `sprawl_safehouse.tmx` is stale. Delete it and reimport:

```
godot_console --headless --editor --quit --path .
```

- [ ] **Step 7: Run the full GUT suite again to confirm the reimport didn't break anything**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add scripts/world/cutscene_zone.gd tests/test_cutscene_zone.gd maps/sprawl_safehouse.tmx
git commit -m "chore: migrate pre_battle_guests to combatant ids; update CutsceneZone, tests, TMX"
```
