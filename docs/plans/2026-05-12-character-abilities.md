# Character Abilities Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give Reid and Iris a signature second battle action (Piercing Strike / Static Touch), backed by a PP cost, with a two-row ActionMenu the player can navigate.

**Architecture:** Introduce `class_name Ability extends Resource` (`ability_name`, `pp_cost`). `Combatant` gains `@export var ability: Ability`. Two static damage formulas live on `Combatant`. `ActionMenu.setup(combatant)` populates Row1 with the ability name, greys it out if PP is insufficient, and silently blocks confirm if PP is too low. `BattleScene.execute_action("ability")` calls `spend_pp` then dispatches to `_resolve_ability` which branches on `_active.character_name`.

**Tech Stack:** GDScript, GUT (headless), Godot 4

## Open questions (must resolve before starting)

- none

---

## Batch 1 — Combatant foundation

### Task 1: Create `Ability` resource class

**Files:**
- Create: `scripts/battle/ability.gd`

**Depends on:** none
**Parallelizable with:** none — defines the `Ability` type used by Tasks 2, 3, and 4. Must finish first.

**Step 1: Write the content**

Create `scripts/battle/ability.gd`:

```gdscript
class_name Ability
extends Resource

@export var ability_name: String = ""
@export var pp_cost: int = 0
```

**Step 2: Verify**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All existing tests pass (new file adds no regressions).

**Step 3: Commit**

```bash
git add scripts/battle/ability.gd
git commit -m "feat: add Ability resource class"
```

---

### Task 2: Add `ability` field to Combatant + GUT tests for formula methods

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Modify: `tests/test_combatant.gd`

**Depends on:** Task 1
**Parallelizable with:** Task 3 — different output files (.tres vs .gd + tests)

**Step 1: Write the failing GUT tests**

Append to `tests/test_combatant.gd`:

```gdscript
func test_piercing_strike_uses_str_only() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.str_stat = 45
	var damage: int = Combatant.calculate_piercing_strike(attacker)
	# floor(45 * 0.9) = 40, floor(45 * 1.1) = 49
	assert_gte(damage, 40, "piercing strike with str=45 must be at least 40")
	assert_lte(damage, 50, "piercing strike with str=45 must be at most 50")


func test_static_touch_uses_psy_minus_res() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.psy_stat = 50
	var target: Combatant = Combatant.new()
	target.res_stat = 10
	var damage: int = Combatant.calculate_static_touch(attacker, target)
	# floor((50-10) * 0.9) = 36, floor((50-10) * 1.1) = 44
	assert_gte(damage, 36, "static touch with psy=50, res=10 must be at least 36")
	assert_lte(damage, 44, "static touch with psy=50, res=10 must be at most 44")


func test_piercing_strike_minimum_1() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.str_stat = 0
	assert_eq(Combatant.calculate_piercing_strike(attacker), 1,
		"piercing strike minimum damage must be 1")


func test_static_touch_minimum_1() -> void:
	var attacker: Combatant = Combatant.new()
	attacker.psy_stat = 5
	var target: Combatant = Combatant.new()
	target.res_stat = 100
	assert_eq(Combatant.calculate_static_touch(attacker, target), 1,
		"static touch minimum damage must be 1 when PSY < RES")
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: FAIL — `calculate_piercing_strike` and `calculate_static_touch` do not exist yet.

**Step 3: Write minimal implementation**

In `scripts/battle/combatant.gd`, add after the `# Identity` block:

```gdscript
@export var ability: Ability = null
```

Append the two static formulas after `calculate_damage`:

```gdscript
static func calculate_piercing_strike(attacker: Combatant) -> int:
	return maxi(1, floori(attacker.str_stat * randf_range(0.9, 1.1)))


static func calculate_static_touch(attacker: Combatant, target: Combatant) -> int:
	return maxi(1, floori((attacker.psy_stat - target.res_stat) * randf_range(0.9, 1.1)))
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: PASS — all four new tests green, existing tests unaffected.

**Step 5: Refactor checkpoint**

Ask: "Do these formulas generalize beyond Reid and Iris?" Yes — both are pure stat functions with no character-name branching. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add ability field and damage formula methods to Combatant"
```

---

### Task 3: Set `ability` sub-resource in reid.tres and iris.tres

**Files:**
- Modify: `characters/reid.tres`
- Modify: `characters/iris.tres`

**Depends on:** Task 1
**Parallelizable with:** Task 2 — writes different files (.tres vs .gd + tests)

**Step 1: Update reid.tres**

Replace the contents of `characters/reid.tres` with:

```
[gd_resource type="Resource" script_class="Combatant" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_reid"]
script = ExtResource("2_ability")
ability_name = "Piercing Strike"
pp_cost = 3

[resource]
script = ExtResource("1_combatant")
character_name = "Reid"
is_player_controlled = true
ability = SubResource("ability_reid")
max_hp = 350
max_pp = 20
str_stat = 45
def_stat = 30
psy_stat = 15
res_stat = 25
spd_stat = 30
sigil_type = 0
```

**Step 2: Update iris.tres**

Replace the contents of `characters/iris.tres` with:

```
[gd_resource type="Resource" script_class="Combatant" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_iris"]
script = ExtResource("2_ability")
ability_name = "Static Touch"
pp_cost = 8

[resource]
script = ExtResource("1_combatant")
character_name = "Iris"
is_player_controlled = true
ability = SubResource("ability_iris")
max_hp = 270
max_pp = 60
str_stat = 30
def_stat = 20
psy_stat = 50
res_stat = 20
spd_stat = 50
sigil_type = 0
```

**Step 3: Verify**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd
```
Expected: all tests pass (resource loading exercises reid.tres / iris.tres in `before_each`).

**Step 4: Commit**

```bash
git add characters/reid.tres characters/iris.tres
git commit -m "feat: assign Ability sub-resource to Reid and Iris"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | No dependencies — defines the Ability type |
| B (parallel) | Task 2, Task 3 | Both depend on Task 1; write different files |

### Smoketest Checkpoint 1 — formula tests pass

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
```bash
godot
```
No visible change yet — action menu still shows only one row. That's correct at this stage.

**Step 4: Confirm with user**
Confirm GUT output shows the four new formula tests passing before proceeding to Batch 2.

---

## Batch 2 — UI and integration

### Task 4: Update ActionMenu — setup(), navigation, grey-out, _confirm_selection()

**Files:**
- Modify: `scripts/ui/action_menu.gd`
- Create: `tests/test_action_menu.gd`

**Depends on:** Task 2 (Combatant.ability type used in setup() signature)
**Parallelizable with:** none — Task 5 calls `_action_menu.setup()`; must run after this task so the method exists.

**Step 1: Write the failing GUT tests**

Create `tests/test_action_menu.gd`:

```gdscript
extends GutTest

const GREY_ALPHA: float = 0.4

var _menu: ActionMenu


func before_each() -> void:
	_menu = load("res://scenes/ui/ActionMenu.tscn").instantiate()
	add_child_autofree(_menu)


func _make_combatant(pp_cost: int, current_pp: int) -> Combatant:
	var ab: Ability = Ability.new()
	ab.ability_name = "Test Ability"
	ab.pp_cost = pp_cost
	var c: Combatant = Combatant.new()
	c.ability = ab
	c.max_pp = 100
	c.current_pp = current_pp
	return c


func test_setup_sets_ability_row_text() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].text, "Test Ability",
		"Row1 must show ability_name after setup()")


func test_setup_hides_extra_rows() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	for i in range(2, _menu._rows.size()):
		assert_false(_menu._rows[i].visible, "Row %d must be hidden after setup()" % i)


func test_setup_greys_out_row_when_pp_insufficient() -> void:
	var c: Combatant = _make_combatant(10, 5)
	_menu.setup(c)
	assert_eq(_menu._rows[1].modulate.a, GREY_ALPHA,
		"Row1 alpha must be GREY_ALPHA when current_pp < pp_cost")


func test_setup_full_alpha_when_pp_sufficient() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].modulate.a, 1.0,
		"Row1 alpha must be 1.0 when current_pp >= pp_cost")


func test_confirm_emits_attack_at_row_0() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["attack"])


func test_confirm_emits_ability_at_row_1_when_pp_sufficient() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_emitted_with_parameters(_menu, "action_selected", ["ability"])


func test_confirm_blocks_silently_at_row_1_when_pp_insufficient() -> void:
	var c: Combatant = _make_combatant(10, 5)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_not_emitted(_menu, "action_selected",
		"must not emit action_selected when PP is insufficient")


func test_navigate_down_increments_selected_idx() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1)


func test_navigate_clamps_at_last_row() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	_menu._navigate(1)
	assert_eq(_menu._selected_idx, 1, "must not exceed last row index")


func test_navigate_clamps_at_first_row() -> void:
	var c: Combatant = _make_combatant(5, 10)
	_menu.setup(c)
	_menu._selected_idx = 0
	_menu._navigate(-1)
	assert_eq(_menu._selected_idx, 0, "must not go below row 0")
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_action_menu.gd
```
Expected: FAIL — `setup`, `_confirm_selection`, `_navigate`, `_selected_idx` do not exist yet.

**Step 3: Write minimal implementation**

Replace `scripts/ui/action_menu.gd` entirely with:

```gdscript
class_name ActionMenu
extends Control

signal action_selected(action_name: String)

const CURSOR_INDENT: int = 10
const GREY_ALPHA: float = 0.4

var _cursor: Label
var _rows: Array[Label] = []
var _selected_idx: int = 0
var _row_count: int = 1
var _ability_affordable: bool = true


func _ready() -> void:
	_cursor = Label.new()
	_cursor.text = "▶"
	_cursor.add_theme_font_size_override("font_size", 6)
	_cursor.modulate.a = 0.0
	add_child(_cursor)

	for child in $VBoxContainer.get_children():
		if child is Label:
			_rows.append(child)


func setup(combatant: Combatant) -> void:
	_selected_idx = 0
	_row_count = 1

	if combatant.ability != null:
		_rows[1].text = combatant.ability.ability_name
		_ability_affordable = combatant.current_pp >= combatant.ability.pp_cost
		_rows[1].modulate.a = 1.0 if _ability_affordable else GREY_ALPHA
		_row_count = 2

	for i in range(_rows.size()):
		_rows[i].visible = i < _row_count


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_selected_idx = 0
		_move_cursor_to(0)


func _move_cursor_to(idx: int) -> void:
	if _rows.is_empty():
		return
	await get_tree().process_frame
	var row: Label = _rows[idx]
	var vbox_pos: Vector2 = $VBoxContainer.position
	var row_rect: Rect2 = row.get_rect()
	_cursor.position = Vector2(
		vbox_pos.x - CURSOR_INDENT,
		vbox_pos.y + row_rect.position.y + (row_rect.size.y - _cursor.size.y) * 0.5
	)
	_cursor.modulate.a = 1.0


func _navigate(delta: int) -> void:
	_selected_idx = clampi(_selected_idx + delta, 0, _row_count - 1)
	_move_cursor_to(_selected_idx)


func _confirm_selection() -> void:
	if _selected_idx == 0:
		action_selected.emit("attack")
	elif _ability_affordable:
		action_selected.emit("ability")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_up"):
		_navigate(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_navigate(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_confirm_selection()
		get_viewport().set_input_as_handled()
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_action_menu.gd
```
Expected: PASS — all 10 new tests green.

Run full suite:

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: all tests pass.

**Step 5: Refactor checkpoint**

Ask: "Does `_navigate` generalize to more than 2 rows?" Yes — clamps to `_row_count` which `setup()` sets. No hardcoding. Proceed.

**Step 6: Commit**

```bash
git add scripts/ui/action_menu.gd tests/test_action_menu.gd
git commit -m "feat: ActionMenu setup(), navigation, PP grey-out, and ability emit"
```

---

### Task 5: Wire BattleScene — setup() call + ability resolution + GUT tests

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Modify: `tests/test_battle_scene.gd`

**Depends on:** Task 2 (formula methods), Task 4 (ActionMenu.setup() method)
**Parallelizable with:** none — only task in this batch.

**Step 1: Write the failing GUT tests**

Append to `tests/test_battle_scene.gd`:

```gdscript
func test_ability_damages_enemy_as_reid() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Piercing Strike must deal damage to Shade")


func test_ability_damages_enemy_as_iris() -> void:
	var iris: Combatant = _scene.party[1]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(iris)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Static Touch must deal damage to Shade")


func test_ability_spends_pp() -> void:
	var reid: Combatant = _scene.party[0]
	var pp_before: int = reid.current_pp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_lt(reid.current_pp, pp_before, "Piercing Strike must spend PP")


func test_ability_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.TICKING)
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd
```
Expected: FAIL — `execute_action("ability")` currently does nothing for damage or PP.

**Step 3: Write minimal implementation**

In `scripts/battle/battle_scene.gd`:

1. Update `_begin_player_turn` to call `setup` before `show`:

```gdscript
func _begin_player_turn(combatant: Combatant) -> void:
	_active = combatant
	_state = BattleState.AWAITING_INPUT
	_action_menu.setup(_active)
	_action_menu.show()
	player_turn_started.emit(combatant)
```

2. Replace `execute_action` with:

```gdscript
func execute_action(action_name: String) -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_action_menu.hide()
	if not enemies.is_empty():
		var target: Combatant = enemies[0]
		var damage: int = 0
		match action_name:
			"attack":
				damage = Combatant.calculate_damage(_active, target)
			"ability":
				damage = _resolve_ability(_active, target)
		if damage > 0:
			target.take_damage(damage)
			_spawn_damage_number(damage, $EnemyContainer)
	_end_turn()
	_check_win_loss()
```

3. Add `_resolve_ability` after `execute_action`:

```gdscript
func _resolve_ability(attacker: Combatant, target: Combatant) -> int:
	if attacker.ability == null:
		return 0
	attacker.spend_pp(attacker.ability.pp_cost)
	match attacker.character_name:
		"Reid":
			return Combatant.calculate_piercing_strike(attacker)
		"Iris":
			return Combatant.calculate_static_touch(attacker, target)
	return 0
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd
```
Expected: PASS — all four new tests green, all existing tests unaffected.

**Step 5: Refactor checkpoint**

Ask: "Does `_resolve_ability` generalize beyond Reid and Iris?" The `match` returns 0 for unknown characters; `if damage > 0` in `execute_action` prevents phantom hits; `spend_pp` is called before the formula so PP is always deducted for any future character. Adding a new character = one new `match` branch. Acceptable for now. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: wire ability resolution and PP spend in BattleScene"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 4 | Depends on Batch 1; no peer task to parallelize |
| B (sequential) | Task 5 | Depends on Task 4 — must run after A |

### Smoketest Checkpoint 2 — full playtest

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
```bash
godot
```

Ask the user to verify:

1. **AC1 — Two-row menu:** Wait for Reid's turn. Confirm the action panel shows "Attack" (cursor on it) and "Piercing Strike" below.
2. **AC2 — Iris ability name:** Wait for Iris's turn. Confirm the panel shows "Attack" and "Static Touch".
3. **AC3 — Navigation:** Press ↓ to move cursor to the ability row, ↑ to return to Attack. Interact (E) confirms the selected action.
4. **AC4 — Piercing Strike damage:** Use Piercing Strike on Reid's turn. Note the damage number. Compare to Reid's basic Attack on a later turn. Piercing Strike ignores DEF (45 × 0.9–1.1 = 40–50) vs Attack which subtracts DEF (45 − 15 = 30 base). Piercing Strike should deal visibly more.
5. **AC5 — Static Touch damage:** Use Static Touch on Iris's turn. Damage should be ~36–44 (PSY 50 − RES 10 = 40 base). Compare to Iris's basic Attack (~13–16). Static Touch should deal significantly more.
6. **AC6 — PP depletion grey-out:** Run a battle until Reid's PP drops below 3 (use ability repeatedly, or reduce max_pp temporarily for testing). When Reid's PP is too low, "Piercing Strike" should appear greyed out, and pressing E on it should do nothing (menu stays open).

**Step 4: Confirm with user**
Wait for the user to confirm all six acceptance criteria before marking the branch ready.
