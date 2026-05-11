# Battle Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wire Reid, Iris, and Shade as Combatant `.tres` resources into a standalone BattleScene with signal-driven HUD and live ATB ticking.

**Architecture:** `battle_scene.gd` loads three `.tres` files on `_ready()`, calls `reset_runtime_state()` on each (needed because `_init()` runs before exported vars are populated during deserialization), populates `party`/`enemies`, emits `combatant_updated(combatant)` every ATB tick, and calls `$UI/HUD.setup(party, self)`. `hud.gd` (refactored from `extends CanvasLayer` to `extends Control`, attached to `UI/HUD`) builds panel nodes in code inside `setup()`, connects to the signal, and updates only on emit — no `_process()` polling.

**Tech Stack:** Godot 4.6 / GDScript, GUT testing, `.tres` resource files

## Open questions

None — resolved in grill-me session.

---

## Setup (run once before any task)

Initialize the worktree build artifacts and reimport:

```bash
make worktree-init
```

Expected: build artifacts copied, headless reimport completes, no errors.

---

## Batch 1 — Combatant Foundation

### Task 1: Add `reset_runtime_state()` to `combatant.gd`

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd`

**Depends on:** none
**Parallelizable with:** Task 2

**Step 1: Write the failing GUT test**

Create `tests/test_combatant.gd`:

```gdscript
extends GutTest


func test_reset_runtime_state_restores_hp_and_pp() -> void:
	var c := Combatant.new()
	c.max_hp = 100
	c.max_pp = 50
	c.current_hp = 0
	c.current_pp = 0
	c.atb = 99.0
	c.limit_gauge = 50.0
	c.reset_runtime_state()
	assert_eq(c.current_hp, 100)
	assert_eq(c.current_pp, 50)
	assert_eq(c.atb, 0.0)
	assert_eq(c.limit_gauge, 0.0)
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: FAIL — `reset_runtime_state` is not yet defined.

**Step 3: Write minimal implementation**

Add to `scripts/battle/combatant.gd` after `_init()`:

```gdscript
func reset_runtime_state() -> void:
	current_hp = max_hp
	current_pp = max_pp
	atb = 0.0
	limit_gauge = 0.0
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: PASS.

**Step 5: Refactor checkpoint**

Reads `max_hp`/`max_pp` directly — generalizes correctly for any Combatant. No hard-coding.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add Combatant.reset_runtime_state() to init HP/PP after .tres load"
```

---

### Task 2: Create `.tres` resource files

**Files:**
- Create: `characters/reid.tres`
- Create: `characters/iris.tres`
- Create: `characters/enemies/shade.tres`

**Depends on:** none
**Parallelizable with:** Task 1

**Step 1: Create directories and files**

```bash
mkdir -p characters/enemies
```

Create `characters/reid.tres`:

```
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]

[resource]
script = ExtResource("1_combatant")
character_name = "Reid"
is_player_controlled = true
max_hp = 350
max_pp = 20
str_stat = 45
def_stat = 30
psy_stat = 15
res_stat = 25
spd_stat = 30
sigil_type = 0
```

Create `characters/iris.tres`:

```
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]

[resource]
script = ExtResource("1_combatant")
character_name = "Iris"
is_player_controlled = true
max_hp = 270
max_pp = 60
str_stat = 30
def_stat = 20
psy_stat = 50
res_stat = 20
spd_stat = 50
sigil_type = 0
```

Create `characters/enemies/shade.tres`:

```
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]

[resource]
script = ExtResource("1_combatant")
character_name = "Shade"
is_player_controlled = false
max_hp = 200
max_pp = 0
str_stat = 28
def_stat = 15
psy_stat = 10
res_stat = 10
spd_stat = 25
sigil_type = 0
```

Note: `max_pp = 0` for Shade is intentional. `pp_ratio()` is never called for enemies (HUD only covers party), so the divide-by-zero is not triggered in this PRD.

**Step 2: Verify**

```bash
godot --headless -e --quit --path . 2>&1 | grep -i "error\|combatant\|reid\|iris\|shade"
```
Expected: no errors mentioning the new files.

**Step 3: Commit**

```bash
git add characters/
git commit -m "feat: add Combatant .tres resource files for Reid, Iris, and Shade"
```

---

### Task 3: Write resource-loading + ATB tick GUT tests

**Files:**
- Modify: `tests/test_combatant.gd`

**Depends on:** Task 1, Task 2
**Parallelizable with:** none — requires `reset_runtime_state()` (Task 1) and the `.tres` files (Task 2).

**Step 1: Write the failing GUT tests**

Add to `tests/test_combatant.gd`:

```gdscript
func test_reid_loads_with_correct_stats() -> void:
	var reid: Combatant = load("res://characters/reid.tres")
	reid.reset_runtime_state()
	assert_eq(reid.character_name, "Reid")
	assert_eq(reid.max_hp, 350)
	assert_eq(reid.max_pp, 20)
	assert_eq(reid.spd_stat, 30)
	assert_eq(reid.current_hp, 350)
	assert_true(reid.is_player_controlled)


func test_iris_loads_with_correct_stats() -> void:
	var iris: Combatant = load("res://characters/iris.tres")
	iris.reset_runtime_state()
	assert_eq(iris.character_name, "Iris")
	assert_eq(iris.max_hp, 270)
	assert_eq(iris.spd_stat, 50)
	assert_eq(iris.current_hp, 270)
	assert_true(iris.is_player_controlled)


func test_shade_loads_with_correct_stats() -> void:
	var shade: Combatant = load("res://characters/enemies/shade.tres")
	shade.reset_runtime_state()
	assert_eq(shade.character_name, "Shade")
	assert_eq(shade.max_hp, 200)
	assert_eq(shade.spd_stat, 25)
	assert_false(shade.is_player_controlled)


func test_tick_atb_proportional_to_spd() -> void:
	var fast := Combatant.new()
	fast.spd_stat = 50
	fast.reset_runtime_state()

	var slow := Combatant.new()
	slow.spd_stat = 25
	slow.reset_runtime_state()

	fast.tick_atb(0.1)
	slow.tick_atb(0.1)

	assert_gt(fast.atb, slow.atb)
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: if Tasks 1 and 2 are complete, all 5 tests should PASS immediately. If any fail, re-check the `.tres` stat values against the table in the PRD.

**Step 3: Run all GUT tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: all tests pass, zero failures.

**Step 4: Refactor checkpoint**

Stats are hardcoded to match the PRD spec table — correct for resource tests. No generalization needed.

**Step 5: Commit**

```bash
git add tests/test_combatant.gd
git commit -m "test: GUT tests for Combatant resource loading and ATB proportionality"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2 | Different output files, no shared state |
| B (sequential) | Task 3 | Writes same test file as Task 1; requires `.tres` files from Task 2 |

### Smoketest Checkpoint 1 — GUT tests pass

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**

No visual check — Batch 1 is logic only. Proceed.

**Step 4: Confirm with user**

Tell the user: "All 5 combatant GUT tests pass (reset_runtime_state, reid/iris/shade loading, ATB proportionality). Ready to proceed to Batch 2 — HUD refactor and scene wiring."

---

## Batch 2 — HUD Refactor + Scene Wiring

### Task 4: Refactor `hud.gd` — signal-driven, builds panels in code

**Files:**
- Modify: `scripts/ui/hud.gd`

**Depends on:** none
**Parallelizable with:** Task 5 — different output file (`hud.gd` vs `battle_scene.gd`).

**Step 1: Replace `scripts/ui/hud.gd` with the signal-driven version**

```gdscript
extends Control

const PANEL_WIDTH: int = 76
const COLOR_HP_FULL          := Color(0.25, 0.85, 0.35)
const COLOR_HP_LOW           := Color(0.85, 0.20, 0.20)
const COLOR_PP               := Color(0.55, 0.20, 0.85)
const COLOR_ATB              := Color(1.00, 1.00, 1.00)
const COLOR_LIMIT_BUREAU     := Color(0.55, 0.55, 0.55)
const COLOR_LIMIT_JAILBROKEN := Color(1.00, 0.80, 0.10)

var _party: Array[Combatant] = []
var _panels: Array[Control] = []


func setup(party: Array[Combatant], battle: Node) -> void:
	_party = party
	battle.combatant_updated.connect(_on_combatant_updated)
	_build_panels()


func _build_panels() -> void:
	var container: HBoxContainer = $PartyPanel
	for combatant in _party:
		var panel := _make_panel(combatant)
		container.add_child(panel)
		_panels.append(panel)


func _make_panel(combatant: Combatant) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.name = combatant.character_name + "Panel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name
	panel.add_child(name_label)

	for bar_name: String in ["HPBar", "PPBar", "ATBBar", "LimitBar"]:
		var bar := ProgressBar.new()
		bar.name = bar_name
		bar.max_value = 100.0
		bar.value = 100.0
		bar.show_percentage = false
		panel.add_child(bar)

	return panel


func _on_combatant_updated(combatant: Combatant) -> void:
	var i := _party.find(combatant)
	if i < 0 or i >= _panels.size():
		return
	_update_panel(_panels[i], combatant)


func _update_panel(panel: Control, combatant: Combatant) -> void:
	var hp_bar: ProgressBar    = panel.get_node("HPBar")
	var pp_bar: ProgressBar    = panel.get_node("PPBar")
	var atb_bar: ProgressBar   = panel.get_node("ATBBar")
	var limit_bar: ProgressBar = panel.get_node("LimitBar")
	var name_label: Label      = panel.get_node("NameLabel")

	name_label.text = combatant.character_name

	hp_bar.value = combatant.hp_ratio() * 100.0
	hp_bar.modulate = COLOR_HP_FULL.lerp(COLOR_HP_LOW, 1.0 - combatant.hp_ratio())

	pp_bar.value = combatant.pp_ratio() * 100.0
	pp_bar.modulate = COLOR_PP

	atb_bar.value = combatant.atb_ratio() * 100.0
	atb_bar.modulate = COLOR_ATB

	limit_bar.max_value = combatant.limit_cap()
	limit_bar.value = combatant.limit_gauge
	match combatant.sigil_type:
		Combatant.SigilType.BUREAU:
			limit_bar.modulate = COLOR_LIMIT_BUREAU
		Combatant.SigilType.JAILBROKEN:
			limit_bar.modulate = COLOR_LIMIT_JAILBROKEN
		_:
			limit_bar.modulate = COLOR_ATB

	name_label.modulate.a = 1.0 if not combatant.atb_full() else \
		(0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006))
```

No GUT test — per PRD scope, HUD layout is verified by smoketest.

**Step 2: Verify no parse errors**

```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -10
```
Expected: existing GUT tests still pass, no parse errors reported.

**Step 3: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "refactor: hud.gd — signal-driven via combatant_updated, builds panels in code"
```

---

### Task 5: Update `battle_scene.gd`

**Files:**
- Modify: `scripts/battle/battle_scene.gd`

**Depends on:** Task 1 (`reset_runtime_state` exists), Task 2 (`.tres` files exist)
**Parallelizable with:** Task 4 — different output file.

**Step 1: Replace `scripts/battle/battle_scene.gd`**

```gdscript
extends Node2D

signal battle_ended(victory: bool)
signal combatant_updated(combatant: Combatant)

enum BattleState { TICKING, AWAITING_INPUT, ANIMATING, ENDED }

const REID_RES  := "res://characters/reid.tres"
const IRIS_RES  := "res://characters/iris.tres"
const SHADE_RES := "res://characters/enemies/shade.tres"
const REID_TEX  := "res://assets/sprites/characters/reid.png"
const IRIS_TEX  := "res://assets/sprites/characters/iris.png"

var party: Array[Combatant] = []
var enemies: Array[Combatant] = []
var _state: BattleState = BattleState.TICKING
var _active: Combatant = null


func _ready() -> void:
	var reid: Combatant = load(REID_RES)
	reid.reset_runtime_state()

	var iris: Combatant = load(IRIS_RES)
	iris.reset_runtime_state()

	var shade: Combatant = load(SHADE_RES)
	shade.reset_runtime_state()

	party = [reid, iris]
	enemies = [shade]

	_setup_sprites()
	$UI/HUD.setup(party, self)


func _setup_sprites() -> void:
	var reid_sprite := Sprite2D.new()
	reid_sprite.texture = load(REID_TEX)
	reid_sprite.flip_h = true
	reid_sprite.position = Vector2(0, -16)
	$PartyContainer.add_child(reid_sprite)

	var iris_sprite := Sprite2D.new()
	iris_sprite.texture = load(IRIS_TEX)
	iris_sprite.flip_h = true
	iris_sprite.position = Vector2(0, 16)
	$PartyContainer.add_child(iris_sprite)

	var shade_rect := ColorRect.new()
	shade_rect.color = Color(0.5, 0.5, 0.5)
	shade_rect.size = Vector2(32, 32)
	shade_rect.position = Vector2(-16, -16)
	$EnemyContainer.add_child(shade_rect)

	var shade_label := Label.new()
	shade_label.text = "Shade"
	shade_label.position = Vector2(-16, 18)
	$EnemyContainer.add_child(shade_label)


func _process(delta: float) -> void:
	if _state != BattleState.TICKING:
		return
	_tick_atb(delta)
	_check_win_loss()


func _tick_atb(delta: float) -> void:
	for combatant in party + enemies:
		combatant.tick_atb(delta)
		combatant_updated.emit(combatant)

	for combatant in party:
		if combatant.atb_full() and not combatant.is_dead():
			_begin_player_turn(combatant)
			return

	for combatant in enemies:
		if combatant.atb_full() and not combatant.is_dead():
			_begin_enemy_turn(combatant)
			return


func _begin_player_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.AWAITING_INPUT


func _begin_enemy_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.ANIMATING
	_end_turn()


func execute_action(action: Dictionary) -> void:
	_state = BattleState.ANIMATING
	_end_turn()


func _end_turn() -> void:
	if _active:
		_active.consume_atb()
		_active = null
	_state = BattleState.TICKING


func _check_win_loss() -> void:
	var all_enemies_dead := enemies.all(func(e): return e.is_dead())
	var all_party_dead := party.all(func(p): return p.is_dead())

	if all_enemies_dead:
		_state = BattleState.ENDED
		battle_ended.emit(true)
	elif all_party_dead:
		_state = BattleState.ENDED
		battle_ended.emit(false)
```

**Step 2: Verify no parse errors**

```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -10
```
Expected: all existing GUT tests still pass.

**Step 3: Commit**

```bash
git add scripts/battle/battle_scene.gd
git commit -m "feat: battle_scene loads resources, emits combatant_updated, wires HUD"
```

---

### Task 6: Fix `BattleScene.tscn`

**Files:**
- Modify: `scenes/battle/BattleScene.tscn`

**Depends on:** Task 4 (hud.gd is now a Control script), Task 5 (battle_scene.gd updated)
**Parallelizable with:** none — depends on both Task 4 and Task 5.

**Step 1: Replace `scenes/battle/BattleScene.tscn`**

```
[gd_scene load_steps=3 format=3 uid="uid://battle_main"]

[ext_resource type="Script" path="res://scripts/battle/battle_scene.gd" id="1_battle"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="2_hud"]

[node name="BattleScene" type="Node2D"]
script = ExtResource("1_battle")

[node name="Background" type="ColorRect" parent="."]
color = Color(0.05, 0.05, 0.08)
size = Vector2(320, 180)

[node name="EnemyContainer" type="Node2D" parent="."]
position = Vector2(60, 90)

[node name="PartyContainer" type="Node2D" parent="."]
position = Vector2(230, 90)

[node name="UI" type="CanvasLayer" parent="."]

[node name="HUD" type="Control" parent="UI"]
script = ExtResource("2_hud")
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="PartyPanel" type="HBoxContainer" parent="UI/HUD"]
layout_mode = 1
anchors_preset = 12
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -72.0

[node name="FlashOverlay" type="ColorRect" parent="UI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(1, 1, 1, 0)
mouse_filter = 2
```

Changes from original:
- `Background` changed from `Sprite2D` (no texture, silent) to `ColorRect` (dark bg)
- `EnemyContainer` moved from `Vector2(220, 70)` to `Vector2(60, 90)` — left side
- `PartyContainer` moved from `Vector2(80, 110)` to `Vector2(230, 90)` — right side
- `hud.gd` attached to `UI/HUD` Control node
- `PartyPanel` `offset_top` increased from `-48` to `-72` to fit 5 elements per panel

**Step 2: Verify**

```bash
godot --headless -e --quit --path . 2>&1 | grep -i error
```
Expected: no errors.

**Step 3: Commit**

```bash
git add scenes/battle/BattleScene.tscn
git commit -m "feat: fix FF6 layout — enemies left, party right; attach hud.gd to UI/HUD"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 4, Task 5 | Different output files (`hud.gd` vs `battle_scene.gd`) |
| B (sequential) | Task 6 | Requires Task 4 (hud.gd is now Control) and Task 5 (battle_scene.gd complete) |

### Smoketest Checkpoint 2 — Visual verification

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures.

**Step 3: Launch scene standalone**

Open `scenes/battle/BattleScene.tscn` in the Godot editor and press **F6** (Run Current Scene).

Verify all acceptance criteria:

| AC | What to check |
|----|--------------|
| AC3 | Reid and Iris sprites appear on the **right** side, facing left. Grey "Shade" ColorRect + label on the **left**. |
| AC4 | HUD at bottom shows two columns (Reid, Iris) with HP/PP/ATB/Limit bars. After ~5 seconds, ATB bars visibly fill — Iris (SPD 50) fills faster than Reid (SPD 30). |
| AC5 | Godot Output panel shows **no errors** on scene load. |

**Step 4: Confirm with user**

Tell the user what you observed for AC3, AC4, AC5. Wait for explicit confirmation before proceeding to `finishing-a-development-branch`.
