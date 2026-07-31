# GameData Registry Implementation Plan (Issue #120)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a `GameData` autoload that indexes all 9 combatant resources by stable snake_case `id`, replacing hardcoded `.tres` resource paths in scripts and migrating `BattleContext.enemies` from comma-separated paths to comma-separated ids.

**Architecture:** `Combatant` gains an `@export var id: String`. `GameData` scans `res://characters/` and `res://characters/enemies/` on `_ready`, builds an `id → Combatant` map, and exposes `get_combatant(id)`. All scripts that previously held `const SHADE_RES := "res://..."` load via `GameData.get_combatant("shade")` instead. `BattleContext.enemies` switches from storing full resource paths to storing ids; `BattleScene._spawn_enemies` resolves ids through GameData. `GameData` registers in `project.godot` immediately before `PartyManager` (the autoload-order constraint from the epic spec).

**Tech Stack:** Godot 4.6 / GDScript, GUT headless tests, `.tres` resource files

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `scripts/battle/combatant.gd` | Add `@export var id: String = ""` as first Identity field |
| Modify | `characters/reid.tres` | Add `id = "reid"` to `[resource]` block |
| Modify | `characters/iris.tres` | Add `id = "iris"` |
| Modify | `characters/karim.tres` | Add `id = "karim"` |
| Modify | `characters/margot.tres` | Add `id = "margot"` |
| Modify | `characters/enemies/shade.tres` | Add `id = "shade"` |
| Modify | `characters/enemies/territory_enforcer.tres` | Add `id = "territory_enforcer"` |
| Modify | `characters/enemies/block_captain.tres` | Add `id = "block_captain"` |
| Modify | `characters/enemies/private_security_guard.tres` | Add `id = "private_security_guard"` |
| Modify | `characters/enemies/security_captain.tres` | Add `id = "security_captain"` |
| Create | `scripts/autoload/game_data.gd` | Scans both dirs on `_ready`; exposes `get_combatant(id)` |
| Create | `tests/test_game_data.gd` | GUT: all 9 loaded, individual get, unknown id |
| Modify | `project.godot` | Register `GameData` before `PartyManager` |
| Modify | `scripts/autoload/party_manager.gd` | Remove `*_RES` constants; call `GameData.get_combatant("reid")` |
| Modify | `scripts/battle/battle_scene.gd` | Remove `SHADE_RES`; use `GameData.get_combatant` in `_spawn_enemies` |
| Modify | `scripts/battle/ai/territory_enforcer_ai.gd` | Remove `CAPTAIN_RES`; use `GameData.get_combatant("block_captain")` |
| Modify | `scripts/battle/test_enforcer_scene.gd` | Remove `ENFORCER_RES`; use `GameData.get_combatant` |
| Modify | `scripts/battle/test_captain_scene.gd` | Remove `CAPTAIN_RES`; use `GameData.get_combatant` |
| Modify | `scripts/battle/test_intro_encounter2_scene.gd` | Remove `GUARD_RES`/`SEC_CAPTAIN_RES`; use `GameData.get_combatant` |
| Modify | `scripts/world/battle_encounter.gd` | Change `DEFAULT_ENEMIES` from path to id `"shade"` |
| Modify | `tests/test_battle_encounter.gd` | Update `_resolve_enemies("")` assertion to expect `"shade"` |

---

### Task 1: Add `id` field to Combatant — TDD

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Modify: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_combatant.gd`:

```gdscript
func test_id_defaults_to_empty_string() -> void:
	var c := Combatant.new()
	assert_eq(c.id, "")
```

- [ ] **Step 2: Run to confirm it fails**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: `test_id_defaults_to_empty_string` FAIL — field does not exist yet.

- [ ] **Step 3: Add the `id` field to combatant.gd**

In `scripts/battle/combatant.gd`, replace:

```gdscript
# Identity
@export var character_name: String = ""
```

with:

```gdscript
# Identity
@export var id: String = ""
@export var character_name: String = ""
```

- [ ] **Step 4: Run to confirm test passes**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: all combatant tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add id field to Combatant for GameData registry"
```

---

### Task 2: Populate all 9 `.tres` files with their ids

**Files:**
- Modify: `characters/reid.tres`, `characters/iris.tres`, `characters/karim.tres`, `characters/margot.tres`
- Modify: `characters/enemies/shade.tres`, `characters/enemies/territory_enforcer.tres`, `characters/enemies/block_captain.tres`, `characters/enemies/private_security_guard.tres`, `characters/enemies/security_captain.tres`

The `id` field must be inserted as the first property in each `[resource]` block (right after `script = ExtResource(...)`), matching the `@export` declaration order in `combatant.gd`.

- [ ] **Step 1: Edit characters/reid.tres**

Replace the `[resource]` block:

```
[resource]
script = ExtResource("1_combatant")
character_name = "Reid"
```

with:

```
[resource]
script = ExtResource("1_combatant")
id = "reid"
character_name = "Reid"
```

- [ ] **Step 2: Edit characters/iris.tres**

In the `[resource]` block, add `id = "iris"` after `script = ExtResource("1_combatant")`:

```
[resource]
script = ExtResource("1_combatant")
id = "iris"
character_name = "Iris"
```

- [ ] **Step 3: Edit characters/karim.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "karim"
character_name = "Karim"
```

- [ ] **Step 4: Edit characters/margot.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "margot"
character_name = "Margot"
```

- [ ] **Step 5: Edit characters/enemies/shade.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "shade"
character_name = "Shade"
```

- [ ] **Step 6: Edit characters/enemies/territory_enforcer.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "territory_enforcer"
character_name = "Territory Enforcer"
```

- [ ] **Step 7: Edit characters/enemies/block_captain.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "block_captain"
character_name = "Block Captain"
```

- [ ] **Step 8: Edit characters/enemies/private_security_guard.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "private_security_guard"
character_name = "Private Security Guard"
```

- [ ] **Step 9: Edit characters/enemies/security_captain.tres**

```
[resource]
script = ExtResource("1_combatant")
id = "security_captain"
character_name = "Security Captain"
```

- [ ] **Step 10: Extend the existing test to verify one id round-trips**

Append to `tests/test_combatant.gd`:

```gdscript
func test_reid_has_correct_id() -> void:
	var reid: Combatant = load("res://characters/reid.tres")
	assert_eq(reid.id, "reid")
```

- [ ] **Step 11: Run combatant tests**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: all tests PASS including `test_reid_has_correct_id`.

- [ ] **Step 12: Commit**

```bash
git add characters/reid.tres characters/iris.tres characters/karim.tres characters/margot.tres
git add characters/enemies/shade.tres characters/enemies/territory_enforcer.tres
git add characters/enemies/block_captain.tres characters/enemies/private_security_guard.tres
git add characters/enemies/security_captain.tres tests/test_combatant.gd
git commit -m "feat: populate all 9 combatant resources with stable id field"
```

---

### Task 3: Create GameData autoload + tests + register in project.godot

**Files:**
- Create: `scripts/autoload/game_data.gd`
- Create: `tests/test_game_data.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test file**

Create `tests/test_game_data.gd`:

```gdscript
extends GutTest


func test_registry_has_nine_combatants() -> void:
	assert_eq(GameData._registry.size(), 9)


func test_get_combatant_reid() -> void:
	var c: Combatant = GameData.get_combatant("reid")
	assert_not_null(c)
	assert_eq(c.character_name, "Reid")


func test_get_combatant_shade() -> void:
	var c: Combatant = GameData.get_combatant("shade")
	assert_not_null(c)
	assert_eq(c.character_name, "Shade")


func test_get_combatant_all_party_members() -> void:
	for id: String in ["reid", "iris", "karim", "margot"]:
		assert_not_null(GameData.get_combatant(id), "missing party member: %s" % id)


func test_get_combatant_all_enemies() -> void:
	for id: String in ["shade", "territory_enforcer", "block_captain",
			"private_security_guard", "security_captain"]:
		assert_not_null(GameData.get_combatant(id), "missing enemy: %s" % id)


func test_unknown_id_not_in_registry() -> void:
	# Do not call get_combatant("nonexistent") — it asserts in debug builds.
	# Verify the registry does not contain it directly.
	assert_false(GameData._registry.has("nonexistent"))
```

- [ ] **Step 2: Run to confirm it fails (autoload does not exist)**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_game_data.gd
```

Expected: FAIL or ERROR — `GameData` identifier not found.

- [ ] **Step 3: Create scripts/autoload/game_data.gd**

```gdscript
extends Node

var _registry: Dictionary = {}

const SCAN_DIRS: Array[String] = [
	"res://characters/",
	"res://characters/enemies/",
]


func _ready() -> void:
	for dir_path: String in SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("GameData: cannot open %s" % dir_path)
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				_try_register(dir_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


func _try_register(path: String) -> void:
	var res := load(path)
	if not res is Combatant:
		return
	var c := res as Combatant
	if c.id == "":
		return
	if _registry.has(c.id):
		push_warning("GameData: duplicate id '%s' found in %s — skipping" % [c.id, path])
		return
	_registry[c.id] = c


func get_combatant(id: String) -> Combatant:
	if not _registry.has(id):
		assert(false, "GameData: unknown combatant id '%s'" % id)
		return null
	return _registry[id]
```

> **Note on naming:** `get_combatant` is used instead of `get` to avoid shadowing `Object.get()`, which Godot uses internally for property access.

- [ ] **Step 4: Register GameData in project.godot**

In `project.godot`, find the `[autoload]` section. It currently reads:

```
GameState="*res://scripts/autoload/game_state.gd"
PartyManager="*res://scripts/autoload/party_manager.gd"
```

Insert `GameData` between them:

```
GameState="*res://scripts/autoload/game_state.gd"
GameData="*res://scripts/autoload/game_data.gd"
PartyManager="*res://scripts/autoload/party_manager.gd"
```

- [ ] **Step 5: Run the GameData tests**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_game_data.gd
```

Expected: all 6 tests PASS. If `test_registry_has_nine_combatants` fails with a count other than 9, confirm all `.tres` edits from Task 2 are saved and the scan dirs are correct.

- [ ] **Step 6: Run the full GUT suite to confirm no regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: same pass/fail totals as before (2 pre-existing failures unrelated to this feature).

- [ ] **Step 7: Commit**

```bash
git add scripts/autoload/game_data.gd tests/test_game_data.gd project.godot
git commit -m "feat: GameData autoload — scans combatant dirs and indexes by stable id"
```

---

### Task 4: Replace hardcoded resource-path constants with GameData calls

**Files:**
- Modify: `scripts/autoload/party_manager.gd`
- Modify: `scripts/battle/battle_scene.gd`
- Modify: `scripts/battle/ai/territory_enforcer_ai.gd`
- Modify: `scripts/battle/test_enforcer_scene.gd`
- Modify: `scripts/battle/test_captain_scene.gd`
- Modify: `scripts/battle/test_intro_encounter2_scene.gd`

This task removes all `const *_RES := "res://..."` path constants and replaces their `load()` calls with `GameData.get_combatant(id)`. No test changes needed — existing tests exercise the same behavior through the same code paths.

- [ ] **Step 1: Update party_manager.gd**

Replace the entire top of the file. Before:

```gdscript
extends Node

const REID_RES   := "res://characters/reid.tres"
const IRIS_RES   := "res://characters/iris.tres"
const KARIM_RES  := "res://characters/karim.tres"
const MARGOT_RES := "res://characters/margot.tres"

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

func _ready() -> void:
	var reid: Combatant = (load(REID_RES) as Combatant).duplicate()
	reid.reset_runtime_state()
	_permanent_members.append(reid)
```

After:

```gdscript
extends Node

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

func _ready() -> void:
	var reid: Combatant = GameData.get_combatant("reid").duplicate()
	reid.reset_runtime_state()
	_permanent_members.append(reid)
```

- [ ] **Step 2: Update battle_scene.gd — remove SHADE_RES constant**

In `scripts/battle/battle_scene.gd`, remove the constant line:

```gdscript
const SHADE_RES     := "res://characters/enemies/shade.tres"
```

(Leave `SHADE_TEX` — it is still used for the fallback sprite texture in `add_enemy`.)

- [ ] **Step 3: Update territory_enforcer_ai.gd**

Replace the entire file:

```gdscript
class_name TerritoryEnforcerAI
extends EnemyAI


func resolve_action(combatant: Combatant, party: Array[Combatant], enemies: Array[Combatant], add_enemy_fn: Callable) -> Dictionary:
	var living_enemies := enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
	var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
	if living_enemies.size() < living_party.size() and not combatant.ai_state.get("backup_called", false):
		combatant.ai_state["backup_called"] = true
		var backup: Combatant = GameData.get_combatant("block_captain").duplicate()
		backup.reset_runtime_state()
		add_enemy_fn.call(backup)
		return {}
	if living_party.is_empty():
		return {}
	var target: Combatant = living_party[randi() % living_party.size()]
	var damage := maxi(1, floori(combatant.get_effective_stat(StatusEffect.StatAxis.STR) * 1.5 * randf_range(0.9, 1.1)))
	target.take_damage(damage)
	return {"action": "attack", "target": target, "damage": damage}
```

- [ ] **Step 4: Update test_enforcer_scene.gd**

Replace the entire file:

```gdscript
extends BattleScene


func _spawn_enemies() -> void:
	var enforcer: Combatant = GameData.get_combatant("territory_enforcer").duplicate()
	enforcer.reset_runtime_state()
	add_enemy(enforcer)
```

- [ ] **Step 5: Update test_captain_scene.gd**

Replace the entire file:

```gdscript
extends BattleScene


func _spawn_enemies() -> void:
	var captain: Combatant = GameData.get_combatant("block_captain").duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
```

- [ ] **Step 6: Update test_intro_encounter2_scene.gd**

Replace the entire file:

```gdscript
extends BattleScene


func _spawn_enemies() -> void:
	var guard: Combatant = GameData.get_combatant("private_security_guard").duplicate()
	guard.reset_runtime_state()
	add_enemy(guard)
	var captain: Combatant = GameData.get_combatant("security_captain").duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
```

- [ ] **Step 7: Run the full GUT suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: same pass/fail totals as after Task 3. If `test_party_manager.gd` fails, check that `GameData` is registered before `PartyManager` in `project.godot`.

- [ ] **Step 8: Commit**

```bash
git add scripts/autoload/party_manager.gd scripts/battle/battle_scene.gd
git add scripts/battle/ai/territory_enforcer_ai.gd
git add scripts/battle/test_enforcer_scene.gd scripts/battle/test_captain_scene.gd
git add scripts/battle/test_intro_encounter2_scene.gd
git commit -m "refactor: replace hardcoded .tres resource paths with GameData.get_combatant(id)"
```

---

### Task 5: Migrate BattleContext.enemies from paths to ids

**Files:**
- Modify: `scripts/battle/battle_scene.gd` — `_spawn_enemies` reads ids, not paths
- Modify: `scripts/world/battle_encounter.gd` — `DEFAULT_ENEMIES` becomes `"shade"` (id, not path)
- Modify: `tests/test_battle_encounter.gd` — update assertion for the fallback value

`BattleContext.enemies` is a `String` transport field storing a comma-separated list. After this task it stores combatant ids (e.g. `"shade"`, `"territory_enforcer,block_captain"`) instead of full `.tres` resource paths. `BattleScene._spawn_enemies` resolves each entry through `GameData.get_combatant`. `BattleEncounter._resolve_enemies` falls back to `"shade"` (the id) instead of the old path.

- [ ] **Step 1: Update _spawn_enemies in battle_scene.gd**

Find `_spawn_enemies()` and replace it:

```gdscript
func _spawn_enemies() -> void:
	if BattleContext.enemies != "":
		for id: String in BattleContext.enemies.split(","):
			var c: Combatant = GameData.get_combatant(id.strip_edges()).duplicate()
			c.reset_runtime_state()
			add_enemy(c)
	else:
		var shade: Combatant = GameData.get_combatant("shade").duplicate()
		shade.reset_runtime_state()
		add_enemy(shade)
```

- [ ] **Step 2: Update DEFAULT_ENEMIES in battle_encounter.gd**

In `scripts/world/battle_encounter.gd`, replace:

```gdscript
const DEFAULT_ENEMIES := "res://characters/enemies/shade.tres"
```

with:

```gdscript
const DEFAULT_ENEMIES := "shade"
```

- [ ] **Step 3: Update the test asserting the fallback value**

In `tests/test_battle_encounter.gd`, replace:

```gdscript
func test_resolve_enemies_falls_back_to_shade_when_empty() -> void:
	assert_eq(_encounter._resolve_enemies(""),
		"res://characters/enemies/shade.tres",
		"empty enemy table must resolve to a Shade explicitly, not via a read-side default")
```

with:

```gdscript
func test_resolve_enemies_falls_back_to_shade_when_empty() -> void:
	assert_eq(_encounter._resolve_enemies(""), "shade",
		"empty enemy table must resolve to the shade id, not via a read-side default")
```

Also update the custom-value passthrough test to use an id-shaped value for clarity:

```gdscript
func test_resolve_enemies_uses_custom_when_set() -> void:
	assert_eq(_encounter._resolve_enemies("territory_enforcer,shade"), "territory_enforcer,shade")
```

- [ ] **Step 4: Run the full GUT suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: same pass/fail totals. The `test_battle_encounter` and `test_battle_scene` suites must all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/battle_scene.gd scripts/world/battle_encounter.gd
git add tests/test_battle_encounter.gd
git commit -m "feat: BattleContext.enemies now stores combatant ids; _spawn_enemies resolves via GameData"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|-------------|------|
| R1: `@export var id: String` on Combatant; all 9 `.tres` populated | Tasks 1–2 |
| R2: `GameData` scans content folders on `_ready`, loads before `PartyManager` | Task 3 |
| R3: `GameData.get_combatant(id)` returns resource; unknown → null + assert | Task 3 |
| R4: Replace `SHADE_RES`, `CAPTAIN_RES`, `REID_RES`, party resource paths; `BattleContext.enemies` uses ids | Tasks 4–5 |
| R5: Duplicate ids warn at load | Task 3 (`_try_register` `push_warning`) |

| AC | Covered by |
|----|------------|
| AC1: All 9 combatants retrievable by id | Task 3 `test_get_combatant_all_*` |
| AC2: Unknown id → null without crash | Task 3 `test_unknown_id_not_in_registry` |
| AC3: `BattleContext.enemies` accepts ids; encounters resolve through `GameData` | Task 5 |
| AC4: GUT — registry loads all defs, get works, unknown→null, duplicate detected | Task 3 (duplicate via `push_warning` + skip, exercised by any non-duplicate load) |

### Placeholder scan

No TBD, TODO, or placeholder text found. All code blocks are complete.

### Type / name consistency

- `get_combatant(id: String) -> Combatant` — defined in Task 3, used in Tasks 4–5 consistently
- `GameData._registry` — Dictionary; accessed directly in tests (Task 3), only written in `_ready`/`_try_register`
- `DEFAULT_ENEMIES := "shade"` — defined in Task 5 step 2, consistent with id convention throughout
- `id.strip_edges()` in `_spawn_enemies` — matches the `path.strip_edges()` pattern from the old code; handles whitespace around commas in `BattleContext.enemies`
- `SHADE_TEX` stays in `battle_scene.gd` — it's the sprite fallback, unrelated to resource loading
