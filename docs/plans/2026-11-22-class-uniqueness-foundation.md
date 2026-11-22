# Class Uniqueness Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the project `executing-plans` skill (NOT superpowers:executing-plans) to implement this plan task-by-task.

**Goal:** Make the battle data model capable of per-character unique verbs — multiple abilities per character, HP-costed abilities, per-combatant ATB fill modifiers, zero-PP characters — and prove it by rebuilding Reid with Pressure stacks.

**Architecture:** `CharacterDefinition` gains `abilities: Array[Ability]` replacing the single `ability` slot; `BattleScene` tracks which ability the player selected instead of reading `_active.ability`; `ActionMenu` builds its rows from that array. Cost payment moves behind `Combatant.can_pay()` / `pay_cost()` so PP, HP and free abilities share one path. ATB fill gains a data-driven multiplier (`CharacterDefinition.atb_desperation`) so Reid accelerates as he bleeds without hardcoding his id. Pressure is a dedicated integer on `Combatant` — not a `StatusEffect` — because it stacks, never expires during a battle, and must reduce the target's DEF and RES for *every* attacker.

**Tech Stack:** Godot 4.7, GDScript, GUT (headless), Godot `Resource` `.tres` data files.

**Issue:** #167

## Open questions (must resolve before starting)

- None. All design decisions are settled in `docs/design/mechanics.md` § Character Abilities and issue #167.

## Design constants (no magic values anywhere in this plan)

| Constant | Location | Value | Meaning |
|---|---|---|---|
| `MAX_PRESSURE_STACKS` | `combatant.gd` | `5` | Hard cap on Pressure stacks |
| `PRESSURE_REDUCTION_PER_STACK` | `combatant.gd` | `0.2` | Fraction of DEF/RES removed per stack |
| `MAX_DEFENSE_REDUCTION` | `combatant.gd` | `1.0` | Additive cap — defenses can never be reduced by more than 100% |
| `ActionMenu` row count | `scenes/ui/ActionMenu.tscn` | 5 (`Row0`–`Row4`) | Attack + up to 4 abilities |

---

## Batch 1 — Multi-ability data model

### Task 1: `CharacterDefinition.abilities` array

**Files:**
- Modify: `scripts/battle/character_definition.gd`
- Modify: `scripts/battle/combatant.gd`
- Modify: `characters/reid.tres`, `characters/iris.tres`, `characters/margot.tres`, `characters/karim.tres`
- Test: `tests/test_combatant.gd`

**Depends on:** none
**Parallelizable with:** none — Tasks 2 and 3 both consume the symbol this task defines (`Combatant.abilities`), and the game does not compile between this task and Task 2.

**Step 1: Write the failing GUT test**

Append to `tests/test_combatant.gd`:

```gdscript
func test_abilities_returns_empty_array_for_enemy_definition() -> void:
	var d := EnemyDefinition.new()
	var c := Combatant.from_definition(d)
	assert_eq(c.abilities.size(), 0,
		"Enemies have no CharacterDefinition, so abilities must be empty")


func test_abilities_returns_all_character_abilities() -> void:
	var a1 := Ability.new()
	a1.ability_name = "First"
	var a2 := Ability.new()
	a2.ability_name = "Second"
	var d := CharacterDefinition.new()
	d.abilities = [a1, a2] as Array[Ability]
	var c := Combatant.from_definition(d)
	assert_eq(c.abilities.size(), 2, "Both abilities must be exposed")
	assert_eq(c.abilities[1].ability_name, "Second", "Order must be preserved")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: FAIL — `Invalid set index 'abilities'` / `Invalid get index 'abilities'`.

**Step 3: Write minimal implementation**

`scripts/battle/character_definition.gd` — replace the singular export:

```gdscript
class_name CharacterDefinition
extends CombatantDefinition

@export var abilities: Array[Ability] = []
```

(leave the growth exports below it untouched)

`scripts/battle/combatant.gd` — replace the `ability` getter (currently around line 98):

```gdscript
var abilities: Array[Ability]:
	get:
		var cd := _char_def()
		return cd.abilities if cd != null else ([] as Array[Ability])
```

Migrate each `.tres`. In `characters/karim.tres`, `characters/reid.tres`, `characters/iris.tres`, `characters/margot.tres`, change the resource line:

```
ability = SubResource("ability_karim")
```

to:

```
abilities = Array[Ability]([SubResource("ability_karim")])
```

(substituting each file's own SubResource id — `ability_karim`, `ability_iris`, `ability_margot`, and reid's existing id.)

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: PASS. Other suites will still fail — Tasks 2 and 3 fix them.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize, or did I hard-code something that breaks when N > 1?" The getter must not assume `abilities.size() == 1` anywhere.

**Step 6: Commit**

```bash
git add scripts/battle/character_definition.gd scripts/battle/combatant.gd characters/*.tres tests/test_combatant.gd
git commit -m "refactor: CharacterDefinition holds an abilities array (#167)"
```

---

### Task 2: BattleScene resolves the selected ability

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd`

**Depends on:** Task 1
**Parallelizable with:** none — it rewrites every `_active.ability` call site, which Task 3's menu index feeds.

**Step 1: Write the failing GUT test**

Append to `tests/test_battle_scene.gd`. That file already builds a live scene in `before_each()` into the member var `_scene` — use it, do not add a new helper.

```gdscript
func test_selected_ability_defaults_to_null_between_turns() -> void:
	assert_null(_scene._selected_ability,
		"No ability is selected before the player picks one")


func test_select_ability_by_index_picks_from_the_array() -> void:
	var a1 := Ability.new()
	a1.ability_name = "First"
	var a2 := Ability.new()
	a2.ability_name = "Second"
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.abilities = [a1, a2] as Array[Ability]
	_scene._active = Combatant.from_definition(d)

	_scene.select_ability(1)
	assert_eq(_scene._selected_ability.ability_name, "Second",
		"select_ability(i) must pick abilities[i]")


func test_select_ability_out_of_range_selects_nothing() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.abilities = [] as Array[Ability]
	_scene._active = Combatant.from_definition(d)

	_scene.select_ability(3)
	assert_null(_scene._selected_ability,
		"An out-of-range index must not crash and must select nothing")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd`
Expected: FAIL — `_selected_ability` / `select_ability` do not exist.

**Step 3: Write minimal implementation**

In `scripts/battle/battle_scene.gd`, add the field beside the other battle state vars:

```gdscript
var _selected_ability: Ability = null
```

Add the selector:

```gdscript
# Picks which of the active combatant's abilities the pending action uses.
# Out-of-range indices select nothing rather than crashing.
func select_ability(index: int) -> void:
	_selected_ability = null
	if _active == null:
		return
	var list: Array[Ability] = _active.abilities
	if index >= 0 and index < list.size():
		_selected_ability = list[index]
```

In `execute_action()` (around line 339), replace the ability branch:

```gdscript
	if action_name == "ability":
		select_ability(_action_menu.selected_ability_index)
		if _selected_ability == null:
			return
		var ab := _selected_ability
		if ab.target_mode == Ability.TargetMode.SELF:
			_cast_self()
			return
		if ab.targets_party_side():
			_begin_party_targeting()
			return
		_begin_enemy_targeting("ability")
		return
```

Replace every remaining `_active.ability` with `_selected_ability` in this file. The call sites are at approximately lines 358, 366, 381, 388, 401, 405, 441, 456, 471, 499, 501, 505, 515, 531, 564, 567, 606, 611 — verify with:

```bash
grep -n "_active\.ability" scripts/battle/battle_scene.gd
```

which must return **zero** matches when the task is done.

In `_end_turn()`, clear the selection so it never leaks into the next turn:

```gdscript
	_selected_ability = null
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: `test_battle_scene.gd` PASS. `test_action_menu.gd` still fails — Task 3.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" Every path that reads an ability must go through `_selected_ability`; nothing may assume index 0.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: BattleScene resolves the player-selected ability (#167)"
```

---

### Task 3: ActionMenu lists N abilities

**Files:**
- Modify: `scripts/ui/action_menu.gd`
- Test: `tests/test_action_menu.gd`

**Depends on:** Task 1, Task 2
**Parallelizable with:** none — it is the last piece of the compile-break started in Task 1 and must land before the game runs again.

**Step 1: Write the failing GUT test**

Rewrite the helper and add cases in `tests/test_action_menu.gd`:

```gdscript
func _make_combatant_with(costs: Array, current_pp: int) -> Combatant:
	var list: Array[Ability] = []
	for i in range(costs.size()):
		var ab := Ability.new()
		ab.ability_name = "Ability %d" % i
		ab.pp_cost = costs[i]
		list.append(ab)
	var d := CharacterDefinition.new()
	d.max_pp = 100
	d.abilities = list
	var c := Combatant.from_definition(d)
	c.current_pp = current_pp
	return c


func test_setup_shows_one_row_per_ability() -> void:
	var c: Combatant = _make_combatant_with([5, 5, 5], 100)
	_menu.setup(c)
	assert_eq(_menu._row_count, 4, "Attack row plus three ability rows")
	assert_eq(_menu._rows[3].text, "Ability 2", "Row 3 shows the third ability")
	assert_false(_menu._rows[4].visible, "Unused rows stay hidden")


func test_setup_greys_only_unaffordable_rows() -> void:
	var c: Combatant = _make_combatant_with([5, 90], 10)
	_menu.setup(c)
	assert_eq(_menu._rows[1].modulate.a, 1.0, "Affordable ability is full alpha")
	assert_almost_eq(_menu._rows[2].modulate.a, GREY_ALPHA, 0.001,
		"Unaffordable ability is greyed")


func test_selected_ability_index_is_row_minus_one() -> void:
	var c: Combatant = _make_combatant_with([5, 5], 100)
	_menu.setup(c)
	_menu._selected_idx = 2
	assert_eq(_menu.selected_ability_index, 1,
		"Row 2 maps to abilities[1]")


func test_confirm_on_unaffordable_row_emits_nothing() -> void:
	var c: Combatant = _make_combatant_with([90], 10)
	_menu.setup(c)
	_menu._selected_idx = 1
	watch_signals(_menu)
	_menu._confirm_selection()
	assert_signal_not_emitted(_menu, "action_selected",
		"An unaffordable ability must not be selectable")
```

Delete the obsolete single-ability tests in this file (`test_setup_sets_ability_row_text`, `test_setup_hides_extra_rows`, `test_setup_greys_out_row_when_pp_insufficient`, `test_setup_full_alpha_when_pp_sufficient`) — they pin the one-ability contract this task replaces. **Ask the user before deleting if any of them look like they cover behaviour not reproduced above.**

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_action_menu.gd`
Expected: FAIL — `selected_ability_index` does not exist; `_row_count` is 2.

**Step 3: Write minimal implementation**

`scripts/ui/action_menu.gd`:

```gdscript
var _row_affordable: Array[bool] = []

# Maps the cursor row to an index into the combatant's abilities array.
# Row 0 is Attack, so ability i lives on row i + 1.
var selected_ability_index: int:
	get: return _selected_idx - 1


func setup(combatant: Combatant) -> void:
	_selected_idx = 0
	_row_count = 1
	_row_affordable = [true]

	var list: Array[Ability] = combatant.abilities
	var usable: int = mini(list.size(), _rows.size() - 1)
	for i in range(usable):
		var ab: Ability = list[i]
		var row: Label = _rows[i + 1]
		row.text = ab.ability_name
		var affordable: bool = combatant.current_pp >= ab.pp_cost
		_row_affordable.append(affordable)
		row.modulate.a = 1.0 if affordable else GREY_ALPHA
		_row_count += 1

	for i in range(_rows.size()):
		_rows[i].visible = i < _row_count


func _confirm_selection() -> void:
	if _selected_idx == 0:
		action_selected.emit("attack")
	elif _row_affordable[_selected_idx]:
		action_selected.emit("ability")
```

Delete the now-unused `_ability_affordable` field.

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: all suites PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this break when N > 1?" `usable` must clamp to the scene's five rows (`Row0`–`Row4`); a character with five abilities must not index past the end.

**Step 6: Commit**

```bash
git add scripts/ui/action_menu.gd tests/test_action_menu.gd
git commit -m "feat: ActionMenu lists every ability a character owns (#167)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Defines `Combatant.abilities`; game does not compile until Task 3 lands |
| B (sequential) | Task 2 | Depends on Task 1's symbol; rewrites `battle_scene.gd` |
| C (sequential) | Task 3 | Depends on Task 2's `selected_ability_index` contract |

No parallelism in this batch: all three tasks are one atomic refactor of the ability contract.

### Smoketest Checkpoint 1 — the battle still plays with the new data model

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process (& ./scripts/godot_path.ps1)
```
(Or use the `run` skill — it handles worktree pre-flight and cache invalidation.)

**Step 4: Confirm with user**
Tell the user to start a battle and confirm: the action menu still shows Attack plus each character's single existing ability, selecting it still works, and Karim's Field Suture still heals. Nothing should look different yet — this batch is a refactor. Wait for confirmation.

---

## Batch 2 — Costs and the ATB hook

### Task 4: `Ability.hp_cost` and unified cost payment

**Files:**
- Modify: `scripts/battle/ability.gd`
- Modify: `scripts/battle/combatant.gd`
- Modify: `scripts/battle/battle_scene.gd`
- Modify: `scripts/ui/action_menu.gd`
- Test: `tests/test_combatant.gd`, `tests/test_ability.gd`

**Depends on:** Task 3
**Parallelizable with:** Task 5 — different files except `combatant.gd`; if run in parallel, Task 5 must be rebased onto this task's `combatant.gd` change.

**Step 1: Write the failing GUT test**

Append to `tests/test_combatant.gd`:

```gdscript
func _ability_costing(pp: int, hp: int) -> Ability:
	var ab := Ability.new()
	ab.pp_cost = pp
	ab.hp_cost = hp
	return ab


func test_can_pay_rejects_insufficient_pp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 10
	var c := Combatant.from_definition(d)
	assert_false(c.can_pay(_ability_costing(20, 0)), "20 PP is unaffordable at 10 PP")


func test_can_pay_rejects_lethal_hp_cost() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 30
	var c := Combatant.from_definition(d)
	assert_false(c.can_pay(_ability_costing(0, 30)),
		"An HP cost that would reduce the user to 0 is not payable")
	assert_true(c.can_pay(_ability_costing(0, 29)),
		"An HP cost leaving 1 HP is payable")


func test_pay_cost_deducts_hp_not_pp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_true(c.pay_cost(_ability_costing(0, 10)), "Payment succeeds")
	assert_eq(c.current_hp, 90, "HP is deducted")
	assert_eq(c.current_pp, 50, "PP is untouched")


func test_pay_cost_of_free_ability_changes_nothing() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 50
	var c := Combatant.from_definition(d)
	assert_true(c.pay_cost(_ability_costing(0, 0)), "Free abilities are always payable")
	assert_eq(c.current_hp, 100, "HP unchanged")
	assert_eq(c.current_pp, 50, "PP unchanged")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: FAIL — `hp_cost`, `can_pay`, `pay_cost` do not exist.

**Step 3: Write minimal implementation**

`scripts/battle/ability.gd` — add beside `pp_cost`:

```gdscript
@export var hp_cost: int = 0
```

`scripts/battle/combatant.gd` — add beside `spend_pp`:

```gdscript
# True when the user can pay both costs. An HP cost is never allowed to kill
# the user — Reid bleeds for his abilities, he does not die for them.
func can_pay(ability: Ability) -> bool:
	if ability == null:
		return false
	if current_pp < ability.pp_cost:
		return false
	if ability.hp_cost > 0 and current_hp - ability.hp_cost < 1:
		return false
	return true


# Deducts both costs atomically. Returns false and changes nothing when the
# cost cannot be met.
func pay_cost(ability: Ability) -> bool:
	if not can_pay(ability):
		return false
	current_pp -= ability.pp_cost
	current_hp -= ability.hp_cost
	return true
```

`scripts/battle/battle_scene.gd` — replace all three `spend_pp(_selected_ability.pp_cost)` guards (in `_cast_self`, `_perform_ability_on`, and the party-target path) with `pay_cost(_selected_ability)`:

```gdscript
	if not _active.pay_cost(_selected_ability):
```

Verify with `grep -n "spend_pp" scripts/battle/battle_scene.gd` → zero matches.

The cost damage number currently spawns `-_selected_ability.pp_cost`. Keep that for PP, and spawn the HP cost too when non-zero, using the existing `_spawn_damage_number` call with the HP colour already used for damage.

`scripts/ui/action_menu.gd` — swap the affordability check in `setup()`:

```gdscript
		var affordable: bool = combatant.can_pay(ab)
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" There must be exactly one place that deducts an ability's cost. `spend_pp` may remain for non-ability callers, but no ability path may use it.

**Step 6: Commit**

```bash
git add scripts/battle/ability.gd scripts/battle/combatant.gd scripts/battle/battle_scene.gd scripts/ui/action_menu.gd tests/test_combatant.gd
git commit -m "feat: abilities can cost HP; unified cost payment (#167)"
```

---

### Task 5: Data-driven ATB fill multiplier

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Modify: `scripts/battle/character_definition.gd`
- Test: `tests/test_combatant.gd`

**Depends on:** Task 4 (shares `combatant.gd`)
**Parallelizable with:** none — same file as Task 4 and Task 8.

**Step 1: Write the failing GUT test**

```gdscript
func test_atb_fill_multiplier_is_one_by_default() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	var c := Combatant.from_definition(d)
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001,
		"Characters fill at base rate unless configured otherwise")


func test_atb_fill_multiplier_scales_with_missing_hp() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.atb_desperation = 1.0
	var c := Combatant.from_definition(d)
	assert_almost_eq(c.atb_fill_multiplier(), 1.0, 0.001, "Full HP means no bonus")
	c.current_hp = 25
	assert_almost_eq(c.atb_fill_multiplier(), 1.75, 0.001,
		"75% missing HP at desperation 1.0 means a 1.75x fill rate")


func test_tick_atb_honours_the_multiplier() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.spd_stat = 10
	d.atb_desperation = 1.0
	var fast := Combatant.from_definition(d)
	fast.current_hp = 25
	var slow := Combatant.from_definition(d)

	fast.tick_atb(0.1)
	slow.tick_atb(0.1)
	assert_gt(fast.atb, slow.atb,
		"The wounded combatant must gain more ATB over the same delta")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: FAIL — `atb_desperation` / `atb_fill_multiplier` do not exist.

**Step 3: Write minimal implementation**

`scripts/battle/character_definition.gd` — add beside the growth exports:

```gdscript
# How strongly missing HP accelerates the ATB gauge. 0.0 = no effect (everyone
# except Reid). 1.0 = at 0 HP the gauge would fill at 2x. Data-driven so no
# character id is ever hardcoded in combat logic.
@export var atb_desperation: float = 0.0
```

`scripts/battle/combatant.gd` — add and wire into `tick_atb`:

```gdscript
# Composed ATB fill multiplier. Currently only the desperation rule contributes;
# future sources (Paz's Uptempo, Aio's Forms) multiply in here.
func atb_fill_multiplier() -> float:
	var cd := _char_def()
	if cd == null or is_equal_approx(cd.atb_desperation, 0.0):
		return 1.0
	return 1.0 + cd.atb_desperation * (1.0 - hp_ratio())


func tick_atb(delta: float) -> void:
	if is_dead():
		return
	var gain: float = float(spd_stat) * delta * ATB_FILL_RATE * atb_fill_multiplier()
	atb = minf(atb + gain, ATB_MAX)
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" `atb_fill_multiplier()` must be the single composition point — nothing else may touch the fill rate directly.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd scripts/battle/character_definition.gd tests/test_combatant.gd
git commit -m "feat: data-driven ATB fill multiplier (#167)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 4 | Modifies `combatant.gd`, `ability.gd`, `battle_scene.gd`, `action_menu.gd` |
| B (sequential) | Task 5 | Same file as Task 4 (`combatant.gd`) — must follow it |

### Smoketest Checkpoint 2 — costs and gauge behaviour unchanged for existing characters

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process (& ./scripts/godot_path.ps1)
```

**Step 4: Confirm with user**
Ask the user to confirm in a battle: ability PP still deducts correctly, unaffordable abilities still grey out, and turn order feels unchanged (no character has `atb_desperation` set yet, so nothing should differ). Wait for confirmation.

---

## Batch 3 — Zero-PP characters and Psychic Drain

### Task 6: Zero-PP character support

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Modify: `scripts/ui/hud.gd`
- Test: `tests/test_combatant.gd`, `tests/test_hud.gd` (**new file** — there is no HUD test suite yet)

**Depends on:** Task 5
**Parallelizable with:** none — `combatant.gd` is also touched by Task 7.

**Step 1: Write the failing GUT test**

```gdscript
func test_pp_ratio_is_zero_for_a_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	assert_eq(c.pp_ratio(), 0.0,
		"A character with no PP bar must report 0.0, never NaN or INF")


func test_uses_pp_is_false_for_a_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	assert_false(c.uses_pp(), "max_pp 0 means the character has no PP bar")
```

Create `tests/test_hud.gd`. The HUD is **not a standalone scene** — it is the `UI/HUD` node inside `scenes/battle/BattleScene.tscn`, and `HUD.setup()` requires a battle node to connect signals to. Instantiate the battle scene and reach into it, mirroring the pattern in `tests/test_battle_scene.gd`:

```gdscript
extends GutTest

var _scene: Node2D
var _hud: Control


func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager._permanent_members.append(reid)
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)
	_hud = _scene.get_node("UI/HUD")


func test_panel_hides_pp_label_for_zero_pp_character() -> void:
	var d := CharacterDefinition.new()
	d.character_name = "NoPP"
	d.max_hp = 100
	d.max_pp = 0
	var c := Combatant.from_definition(d)
	var panel: Control = _hud._make_panel(c)
	assert_false(panel.get_node("PPLabel").visible,
		"A character with no PP bar shows no PP value")


func test_panel_shows_pp_label_for_a_normal_character() -> void:
	var d := CharacterDefinition.new()
	d.character_name = "HasPP"
	d.max_hp = 100
	d.max_pp = 40
	var c := Combatant.from_definition(d)
	var panel: Control = _hud._make_panel(c)
	assert_true(panel.get_node("PPLabel").visible,
		"A character with a PP bar still shows its PP value")
```

(`_make_panel` and `_make_enemy_panel` are the real builder names in `hud.gd`; `_build_panels()` calls the former.)

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: FAIL — `uses_pp` missing; `pp_ratio()` divides by zero.

**Step 3: Write minimal implementation**

`scripts/battle/combatant.gd`:

```gdscript
func uses_pp() -> bool:
	return max_pp > 0


func pp_ratio() -> float:
	return float(current_pp) / float(max_pp) if uses_pp() else 0.0
```

`scripts/ui/hud.gd` — in `_make_panel` after creating `pp_label`, and again in `_update_panel`:

```gdscript
	pp_label.visible = combatant.uses_pp()
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" Any future divide by `max_pp` must route through `uses_pp()`.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd scripts/ui/hud.gd tests/test_combatant.gd tests/test_hud.gd
git commit -m "feat: support characters with no PP bar (#167)"
```

---

### Task 7: Psychic Drain routes to HP for zero-PP combatants

**Files:**
- Create: `scripts/battle/drain_effect.gd`
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_drain_effect.gd`

**Depends on:** Task 6
**Parallelizable with:** none — it extends the behaviour Task 6 introduces and edits `battle_scene.gd`, which Task 9 also touches.

**Step 1: Write the failing GUT test**

Create `tests/test_drain_effect.gd`:

```gdscript
extends GutTest


func _combatant(max_hp: int, max_pp: int, def_stat: int) -> Combatant:
	var d := CharacterDefinition.new()
	d.max_hp = max_hp
	d.max_pp = max_pp
	d.def_stat = def_stat
	return Combatant.from_definition(d)


func _caster(psy: int) -> Combatant:
	var d := EnemyDefinition.new()
	d.max_hp = 100
	d.psy_stat = psy
	return Combatant.from_definition(d)


func test_drain_reduces_pp_on_a_normal_character() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 40, 10)
	e.resolve(_caster(0), target)
	assert_eq(target.current_pp, 25, "PP is drained")
	assert_eq(target.current_hp, 100, "HP is untouched")


func test_drain_hits_hp_when_the_target_has_no_pp_bar() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var target: Combatant = _combatant(100, 0, 999)
	e.resolve(_caster(0), target)
	assert_eq(target.current_hp, 85,
		"A zero-PP target bleeds for the drain instead of going dry")


func test_drain_against_a_zero_pp_target_ignores_def() -> void:
	var e := DrainEffect.new()
	e.amount = 15
	var armoured: Combatant = _combatant(100, 0, 999)
	var naked: Combatant = _combatant(100, 0, 0)
	e.resolve(_caster(0), armoured)
	e.resolve(_caster(0), naked)
	assert_eq(armoured.current_hp, naked.current_hp,
		"DEF must not reduce rerouted drain damage")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_drain_effect.gd`
Expected: FAIL — `DrainEffect` does not exist.

**Step 3: Write minimal implementation**

Create `scripts/battle/drain_effect.gd`:

```gdscript
# scripts/battle/drain_effect.gd
class_name DrainEffect
extends AbilityEffect

# Psychic Drain — the entity's damage type. Normally eats PP. Against a target
# with no PP bar there is nothing to skim, so it takes the same amount out of
# HP and ignores DEF: they bleed for it instead of going dry.
@export var amount: int = 0


func resolve(_user: Combatant, target: Combatant) -> void:
	if target.uses_pp():
		target.drain_pp(amount)
	else:
		target.take_damage(amount)
```

In `scripts/battle/battle_scene.gd`, handle it in `_apply_nondamage_effects_to`:

```gdscript
		elif effect is DrainEffect:
			effect.resolve(_active, recipient)
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" The zero-PP branch must key off `uses_pp()`, never off a character id.

**Step 6: Commit**

```bash
git add scripts/battle/drain_effect.gd scripts/battle/battle_scene.gd tests/test_drain_effect.gd
git commit -m "feat: Psychic Drain reroutes to HP for zero-PP combatants (#167)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 6 | `combatant.gd` + `hud.gd` |
| B (sequential) | Task 7 | Depends on `uses_pp()` from Task 6 |

### Smoketest Checkpoint 3 — the HUD survives a character with no PP

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process (& ./scripts/godot_path.ps1)
```

**Step 4: Confirm with user**
Reid still has PP at this point, so the HUD should look unchanged. Ask the user to confirm the party panel renders normally and no errors appear in the Godot output panel. Wait for confirmation.

---

## Batch 4 — Reid and Pressure

### Task 8: Pressure stacks on Combatant

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Create: `scripts/battle/pressure_effect.gd`
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_combatant.gd`, `tests/test_pressure_effect.gd`

**Depends on:** Task 7
**Parallelizable with:** none — `combatant.gd` and `battle_scene.gd` are shared with Tasks 7 and 9.

**Step 1: Write the failing GUT test**

Append to `tests/test_combatant.gd`:

```gdscript
func test_pressure_starts_at_zero() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	assert_eq(c.pressure, 0, "Enemies start unpressured")


func test_add_pressure_caps_at_max_stacks() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(99)
	assert_eq(c.pressure, Combatant.MAX_PRESSURE_STACKS,
		"Pressure never exceeds the stack cap")


func test_pressure_reduces_def_and_res() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	d.res_stat = 100
	var c := Combatant.from_definition(d)
	c.add_pressure(1)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 80,
		"One stack removes 20% of DEF")
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.RES), 80,
		"One stack removes 20% of RES")


func test_pressure_reduction_never_exceeds_the_cap() -> void:
	var d := EnemyDefinition.new()
	d.def_stat = 100
	var c := Combatant.from_definition(d)
	c.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0,
		"Full stacks remove at most 100% of DEF, never more")


func test_pressure_does_not_affect_other_stats() -> void:
	var d := EnemyDefinition.new()
	d.str_stat = 50
	var c := Combatant.from_definition(d)
	c.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	assert_eq(c.get_effective_stat(StatusEffect.StatAxis.STR), 50,
		"Pressure erodes defences only")


func test_consume_pressure_returns_and_clears_the_stack() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(3)
	assert_eq(c.consume_pressure(), 3, "Returns the stack that was held")
	assert_eq(c.pressure, 0, "Stack is cleared")


func test_pressure_survives_tick_effects() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(2)
	c.tick_effects()
	c.tick_effects()
	assert_eq(c.pressure, 2, "Pressure persists for the whole battle")


func test_reset_runtime_state_clears_pressure() -> void:
	var c := Combatant.from_definition(EnemyDefinition.new())
	c.add_pressure(2)
	c.reset_runtime_state()
	assert_eq(c.pressure, 0, "Pressure does not leak between battles")
```

Create `tests/test_pressure_effect.gd`:

```gdscript
extends GutTest


func test_effect_adds_its_configured_stacks() -> void:
	var e := PressureEffect.new()
	e.stacks = 2
	var target := Combatant.from_definition(EnemyDefinition.new())
	e.resolve(target)
	assert_eq(target.pressure, 2, "Applies the configured stack count")


func test_consuming_effect_clears_the_stack() -> void:
	var e := PressureEffect.new()
	e.consumes = true
	var target := Combatant.from_definition(EnemyDefinition.new())
	target.add_pressure(4)
	e.resolve(target)
	assert_eq(target.pressure, 0, "A consuming effect spends the whole stack")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: FAIL — `pressure`, `add_pressure`, `PressureEffect` do not exist.

**Step 3: Write minimal implementation**

`scripts/battle/combatant.gd` — constants beside `ATB_FILL_RATE`:

```gdscript
# Pressure — Reid's verb. Stacks erode the target's defences for every
# attacker, not just Reid, and persist for the whole battle.
const MAX_PRESSURE_STACKS: int = 5
const PRESSURE_REDUCTION_PER_STACK: float = 0.2
# Additive cap: defences can never be reduced by more than 100%.
const MAX_DEFENSE_REDUCTION: float = 1.0
```

Runtime field beside `active_effects`:

```gdscript
var pressure: int = 0
```

Methods:

```gdscript
func add_pressure(stacks: int) -> void:
	pressure = mini(pressure + stacks, MAX_PRESSURE_STACKS)


func consume_pressure() -> int:
	var held := pressure
	pressure = 0
	return held


# Fraction of DEF/RES removed by the current stack, clamped to the additive cap.
func defense_reduction() -> float:
	return minf(float(pressure) * PRESSURE_REDUCTION_PER_STACK, MAX_DEFENSE_REDUCTION)
```

Wire into `get_effective_stat` — after the status-effect loop, before the clamp:

```gdscript
func get_effective_stat(stat: StatusEffect.StatAxis) -> int:
	var base := _base_stat(stat)
	for effect in active_effects:
		if effect.stat == stat:
			base += effect.modifier
	if pressure > 0 and stat in [StatusEffect.StatAxis.DEF, StatusEffect.StatAxis.RES]:
		base = int(round(float(base) * (1.0 - defense_reduction())))
	return maxi(0, base)
```

Add `pressure = 0` to `reset_runtime_state()`.

Create `scripts/battle/pressure_effect.gd`:

```gdscript
# scripts/battle/pressure_effect.gd
class_name PressureEffect
extends AbilityEffect

# Adds stacks, or spends the whole stack when `consumes` is set (Close the Case).
@export var stacks: int = 1
@export var consumes: bool = false


func resolve(target: Combatant) -> void:
	if consumes:
		target.consume_pressure()
	else:
		target.add_pressure(stacks)
```

In `scripts/battle/battle_scene.gd`, `_apply_nondamage_effects_to`:

```gdscript
		elif effect is PressureEffect:
			effect.resolve(recipient)
```

Order matters: Close the Case's damage must be computed *before* its PressureEffect clears the stack. `_compute_damage_for()` already runs before `_apply_nondamage_effects_to()` in `_perform_ability_on` — confirm this ordering holds and do not change it.

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" `defense_reduction()` must be the single clamp point; no caller may apply the per-stack fraction itself.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd scripts/battle/pressure_effect.gd scripts/battle/battle_scene.gd tests/test_combatant.gd tests/test_pressure_effect.gd
git commit -m "feat: Pressure stacks erode defences for the whole party (#167)"
```

---

### Task 9: Pressure-scaling damage for Close the Case

**Files:**
- Modify: `scripts/battle/damage_effect.gd`
- Test: `tests/test_damage_effect.gd`

**Depends on:** Task 8
**Parallelizable with:** Task 10 — different files (`damage_effect.gd` vs `hud.gd`), no shared symbols.

**Step 1: Write the failing GUT test**

Append to `tests/test_damage_effect.gd`:

```gdscript
func test_pressure_scaled_damage_grows_with_the_stack() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	e.pressure_scaling = 0.5

	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100

	var unpressured := Combatant.from_definition(EnemyDefinition.new())
	var pressured := Combatant.from_definition(EnemyDefinition.new())
	pressured.add_pressure(2)

	assert_gt(e.compute(user, pressured), e.compute(user, unpressured),
		"Consumed Pressure must increase the finisher's damage")


func test_pressure_scaling_defaults_to_no_effect() -> void:
	var e := DamageEffect.new()
	e.kind = DamageEffect.Kind.PIERCING
	var user := Combatant.from_definition(CharacterDefinition.new())
	user.def.str_stat = 100
	var pressured := Combatant.from_definition(EnemyDefinition.new())
	pressured.add_pressure(Combatant.MAX_PRESSURE_STACKS)
	var plain := Combatant.from_definition(EnemyDefinition.new())
	assert_eq(e.compute(user, pressured), e.compute(user, plain),
		"Abilities without pressure_scaling are unaffected by the stack")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_damage_effect.gd`
Expected: FAIL — `pressure_scaling` does not exist.

**Step 3: Write minimal implementation**

`scripts/battle/damage_effect.gd`:

```gdscript
# Extra damage per Pressure stack on the target, as a fraction of base damage.
# 0.0 for every ability except Reid's finisher.
@export var pressure_scaling: float = 0.0
```

and at the end of `compute()`, wrap the returned base:

```gdscript
func compute(user: Combatant, target: Combatant) -> int:
	var base: int = _base_damage(user, target)
	if is_equal_approx(pressure_scaling, 0.0) or target.pressure <= 0:
		return base
	return int(round(float(base) * (1.0 + pressure_scaling * float(target.pressure))))
```

Move the existing `match kind:` body into a private `_base_damage(user, target) -> int`.

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" `pressure_scaling` must stay data-driven per ability — no `if ability_name == "Close the Case"` anywhere.

**Step 6: Commit**

```bash
git add scripts/battle/damage_effect.gd tests/test_damage_effect.gd
git commit -m "feat: damage can scale with the target's Pressure stack (#167)"
```

---

### Task 10: HUD shows Pressure on enemy panels

**Files:**
- Modify: `scripts/ui/hud.gd`
- Test: `tests/test_hud.gd`

**Depends on:** Task 8
**Parallelizable with:** Task 9 — different files, no shared symbols.

**Step 1: Write the failing GUT test**

Append to `tests/test_hud.gd` (created in Task 6 — reuse its `before_each` and `_hud`):

```gdscript
func test_enemy_panel_shows_pressure_stacks() -> void:
	var enemy := Combatant.from_definition(EnemyDefinition.new())
	enemy.add_pressure(3)
	var panel: Control = _hud._make_enemy_panel(enemy)
	add_child_autofree(panel)
	_hud._update_enemy_panel(panel, enemy)
	assert_true(panel.get_node("EffectsLabel").text.contains("PRESSURE 3"),
		"The enemy panel must show the current Pressure stack")


func test_enemy_panel_omits_pressure_when_unpressured() -> void:
	var enemy := Combatant.from_definition(EnemyDefinition.new())
	var panel: Control = _hud._make_enemy_panel(enemy)
	add_child_autofree(panel)
	_hud._update_enemy_panel(panel, enemy)
	assert_false(panel.get_node("EffectsLabel").text.contains("PRESSURE"),
		"No Pressure line when the stack is empty")
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_hud.gd`
Expected: FAIL — the label has no Pressure line.

**Step 3: Write minimal implementation**

`scripts/ui/hud.gd` — in `_format_effects`, prepend the Pressure line:

```gdscript
func _format_effects(combatant: Combatant) -> String:
	var parts: Array = []
	if combatant.pressure > 0:
		parts.append("PRESSURE %d" % combatant.pressure)
	for effect in combatant.active_effects:
		var axis_name: String = StatusEffect.StatAxis.keys()[effect.stat]
		var sign: String = "+" if effect.modifier >= 0 else ""
		parts.append("%s %s%s%d (%dt)" % [effect.effect_name, axis_name, sign, effect.modifier, effect.duration])
	return "\n".join(parts)
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize?" The Pressure line must come from `combatant.pressure`, never from a cached copy.

**Step 6: Commit**

```bash
git add scripts/ui/hud.gd tests/test_hud.gd
git commit -m "feat: enemy panels display Pressure stacks (#167)"
```

---

### Task 11: Reid's ability set

**Files:**
- Modify: `characters/reid.tres`

**Depends on:** Task 9, Task 10
**Parallelizable with:** none — it is the integration point that exercises every prior task.

**Step 1: Write the content**

Rewrite `characters/reid.tres` so Reid has `max_pp = 0`, `atb_desperation = 1.0`, and four abilities. Keep his existing stat and growth values; only the listed fields change.

Sub-resources to define (matching the existing `.tres` header style — add `DamageEffect` and `PressureEffect` to `ext_resource` and raise `load_steps` accordingly):

| Ability | `hp_cost` | `pp_cost` | Effects |
|---|---|---|---|
| Piercing Strike | 6 | 0 | `DamageEffect(kind = PIERCING)`, `PressureEffect(stacks = 1)` |
| Work the Body | 0 | 0 | `DamageEffect(kind = PHYSICAL)`, `PressureEffect(stacks = 2)` |
| Heavy Blow | 12 | 0 | `DamageEffect(kind = PHYSICAL)`, `PressureEffect(stacks = 2)` |
| Close the Case | 18 | 0 | `DamageEffect(kind = PIERCING, pressure_scaling = 0.5)`, `PressureEffect(consumes = true)` |

All four use `target_mode = 3` (`ONE_ENEMY`).

Resource block changes:

```
max_pp = 0
atb_desperation = 1.0
pp_growth = 0
abilities = Array[Ability]([SubResource("ability_piercing_strike"), SubResource("ability_work_the_body"), SubResource("ability_heavy_blow"), SubResource("ability_close_the_case")])
```

**Step 2: Verify**

```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: all tests pass (resource parse errors surface here).

Then open the project in the Godot editor, select `characters/reid.tres` in the FileSystem dock, and confirm the Inspector shows four entries under Abilities and a Max Pp of 0 with no import errors.

**Step 3: Commit**

```bash
git add characters/reid.tres
git commit -m "feat: Reid's Pressure ability set, zero PP, desperation gauge (#167)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 8 | `combatant.gd` + `battle_scene.gd` + new `pressure_effect.gd` |
| B (parallel) | Task 9, Task 10 | `damage_effect.gd` and `hud.gd` — disjoint files, both depend only on Task 8 |
| C (sequential) | Task 11 | Data file consuming every symbol above |

### Smoketest Checkpoint 4 — Reid plays his verb end to end

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process (& ./scripts/godot_path.ps1)
```

**Step 4: Confirm with user**
Ask the user to start the opening battle and verify all of the following:

1. Reid's action menu shows **five rows**: Attack, Piercing Strike, Work the Body, Heavy Blow, Close the Case.
2. Reid's HUD panel shows **no PP value**.
3. Using Piercing Strike deducts **HP**, not PP, and the enemy panel shows `PRESSURE 1`.
4. Stacking to `PRESSURE 3`, then attacking with **another party member**, deals visibly more damage than the same attack at `PRESSURE 0`.
5. Close the Case hits hard and the enemy's `PRESSURE` line disappears afterwards.
6. As Reid's HP drops, his ATB bar visibly fills faster than at full health.
7. Unaffordable abilities grey out when Reid is too low on HP to pay.

Wait for confirmation before closing the batch.

---

## Final verification

```bash
git fetch origin && git merge origin/master
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
grep -rn "_active\.ability\b" scripts/   # must return nothing
grep -rn "\.ability\b" characters/*.tres # must return nothing
```

Then follow the `finishing-a-development-branch` skill to open the PR against `master`, referencing #167.
