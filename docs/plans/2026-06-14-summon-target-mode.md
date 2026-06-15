# SummonEffect + Full target_mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the project `executing-plans` skill (NOT superpowers:executing-plans) to implement this plan task-by-task.

**Goal:** Complete the data-driven ability system by adding a `SummonEffect` (data-driven enemy reinforcement) and a unified, per-ability `target_mode` (SELF / ONE_ALLY / ALL_ALLIES / ONE_ENEMY / ALL_ENEMIES) with an FF-style single↔all switchable cursor, resolving every mode in battle.

**Architecture:**
- `target_mode` lives on `Ability` (per-ability, all effects share the resolved recipients) and **replaces** `Ability.targets_party`. An optional `switchable` flag lets a `ONE_*` ability expand to its matching `ALL_*` live during target selection.
- `battle_scene` collapses its two divergent effect loops (`_resolve_ability` for enemies, `confirm_party_target` for heals) into **one** path: resolve a recipient *list* from `target_mode` (+ toggle state), then apply every effect to every recipient. AoE animates as one lunge with simultaneous flash + per-target damage numbers.
- `SummonEffect` joins the effect family (`DamageEffect`/`HealEffect`/`ApplyStatusEffect`). The Territory Enforcer's backup-call is migrated to a `SummonEffect` authored on its `EnemyDefinition` (`.tres`), read by the AI — zero enemy ids in GDScript.

**Tech Stack:** Godot 4.6, GDScript, GUT (headless tests), Mobile (GL Compatibility) renderer.

## Open questions (must resolve before starting)

The per-ability `target_mode` decision **requires editing existing tests and fixtures** that the prior slices (#125/#127) shipped. Per the project rule "always ask the user before modifying existing tests," these need explicit sign-off — they are unavoidable consequences of replacing `targets_party` and removing `ApplyStatusEffect.TargetMode`:

1. **`tests/test_combatant.gd`** — `test_ability_targets_party_defaults_false` (L148-150), and the karim/margot `targets_party` asserts (L182, L194) reference the removed `targets_party` property. They must be rewritten against `target_mode`.
2. **`tests/test_heal_effect.gd`** — L61 asserts `a.targets_party`; rewrite against `target_mode == Ability.TargetMode.ONE_ALLY`.
3. **`tests/test_apply_status_effect.gd`** — `test_resolve_recipient_target_returns_target` / `test_resolve_recipient_self_returns_user` (L24-38) and the `_make_effect(mode, status)` helper test the removed `ApplyStatusEffect.TargetMode`/`resolve_recipient`. The two `resolve_recipient` tests are **deleted** (capability moves to the ability level); the `make_instance` tests are kept but the helper is simplified to drop the `mode` argument.
4. **Fixture migration** — `characters/karim.tres`, `characters/margot.tres`, `tests/fixtures/test_suppressor.tres` set `targets_party`; they must be re-authored to `target_mode`.

> **Author's note:** the executor must NOT start Batch 1 until the user confirms these test/fixture edits are approved.

---

## Mode → ability mapping (reference for fixture migration)

| Ability (file) | Old | New `target_mode` | `switchable` |
|---|---|---|---|
| Reid — Piercing Strike (`characters/reid.tres`) | `targets_party=false` | `ONE_ENEMY` | false |
| Iris — Static Touch (`characters/iris.tres`) | `targets_party=false` | `ONE_ENEMY` | false |
| Margot — Void Calculus (`characters/margot.tres`) | `targets_party=false` | `ONE_ENEMY` | false |
| Karim — Field Suture (`characters/karim.tres`) | `targets_party=true` | `ONE_ALLY` | false |
| Suppressor fixture (`tests/fixtures/test_suppressor.tres`) | `targets_party=false`, status `target_mode=0` | `ONE_ENEMY` | false |

`TargetMode` enum order (used as `.tres` integer values): `SELF=0, ONE_ALLY=1, ALL_ALLIES=2, ONE_ENEMY=3, ALL_ENEMIES=4`.

---

## Batch 1 — Data model: `target_mode` on `Ability`, fixture migration

### Task 1: `Ability.target_mode` + `switchable` + side helpers

**Files:**
- Modify: `scripts/battle/ability.gd`
- Test: `tests/test_ability.gd` (new)

**Depends on:** none
**Parallelizable with:** none — Task 2 edits the same conceptual surface (the fixtures) and must read the final enum; serialize for safety.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_ability.gd
extends GutTest

func test_target_mode_defaults_one_enemy() -> void:
	var a := Ability.new()
	assert_eq(a.target_mode, Ability.TargetMode.ONE_ENEMY,
		"default target_mode must be ONE_ENEMY (preserves old targets_party=false default)")

func test_switchable_defaults_false() -> void:
	assert_false(Ability.new().switchable, "switchable must default to false")

func test_party_side_modes() -> void:
	var a := Ability.new()
	for m in [Ability.TargetMode.SELF, Ability.TargetMode.ONE_ALLY, Ability.TargetMode.ALL_ALLIES]:
		a.target_mode = m
		assert_true(a.targets_party_side(), "mode %d must be party-side" % m)
		assert_false(a.targets_enemy_side(), "mode %d must not be enemy-side" % m)

func test_enemy_side_modes() -> void:
	var a := Ability.new()
	for m in [Ability.TargetMode.ONE_ENEMY, Ability.TargetMode.ALL_ENEMIES]:
		a.target_mode = m
		assert_true(a.targets_enemy_side(), "mode %d must be enemy-side" % m)
		assert_false(a.targets_party_side(), "mode %d must not be party-side" % m)

func test_is_all() -> void:
	var a := Ability.new()
	a.target_mode = Ability.TargetMode.ALL_ENEMIES
	assert_true(a.is_all())
	a.target_mode = Ability.TargetMode.ONE_ENEMY
	assert_false(a.is_all())

func test_no_targets_party_property() -> void:
	# Regression: the boolean must be gone (capability replaced by target_mode).
	assert_false("targets_party" in Ability.new(),
		"targets_party must be removed in favor of target_mode")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_ability.gd`
Expected: FAIL (no `target_mode`/`switchable`/helpers).

**Step 3: Write minimal implementation**

```gdscript
# scripts/battle/ability.gd
class_name Ability
extends Resource

enum TargetMode { SELF, ONE_ALLY, ALL_ALLIES, ONE_ENEMY, ALL_ENEMIES }

@export var ability_name: String = ""
@export var pp_cost: int = 0
@export var target_mode: TargetMode = TargetMode.ONE_ENEMY
@export var switchable: bool = false
@export var effects: Array[AbilityEffect] = []


func targets_party_side() -> bool:
	return target_mode in [TargetMode.SELF, TargetMode.ONE_ALLY, TargetMode.ALL_ALLIES]


func targets_enemy_side() -> bool:
	return target_mode in [TargetMode.ONE_ENEMY, TargetMode.ALL_ENEMIES]


func is_all() -> bool:
	return target_mode in [TargetMode.ALL_ALLIES, TargetMode.ALL_ENEMIES]
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_ability.gd`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Do the `in [...]` membership checks generalize to all 5 modes?" — yes; the SELF/ONE/ALL split is exhaustive. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/ability.gd tests/test_ability.gd
git commit -m "feat: add Ability.target_mode + switchable, replace targets_party (#128)"
```

---

### Task 2: Migrate ability fixtures + repair existing tests (GATED)

**Files:**
- Modify: `characters/reid.tres`, `characters/iris.tres`, `characters/margot.tres`, `characters/karim.tres`, `tests/fixtures/test_suppressor.tres`
- Modify: `tests/test_combatant.gd`, `tests/test_heal_effect.gd`
- Modify: `scripts/battle/apply_status_effect.gd`, `tests/test_apply_status_effect.gd`

**Depends on:** Task 1
**Parallelizable with:** none — touches many shared fixtures + the same enum Task 1 defines; must run after Task 1 and before any battle_scene work.

> **GATE:** Do not begin until the user has approved the test/fixture edits in "Open questions."

**Step 1: Migrate `.tres` fixtures**

In each character `.tres`, **remove** the `targets_party = ...` line from the `ability_*` sub_resource and **add** `target_mode`:
- `reid.tres`, `iris.tres`, `margot.tres`: add `target_mode = 3` (ONE_ENEMY). (For files that had no `targets_party` line, e.g. reid/iris, just add `target_mode = 3`.)
- `karim.tres`: replace `targets_party = true` with `target_mode = 1` (ONE_ALLY).

In `tests/fixtures/test_suppressor.tres`:
- In `ability_supp`: replace `targets_party = false` with `target_mode = 3` (ONE_ENEMY).
- In `apply_supp` (the `ApplyStatusEffect` sub_resource): **remove** the `target_mode = 0` line (the per-effect mode no longer exists).

**Step 2: Simplify `ApplyStatusEffect`** (remove per-effect targeting)

```gdscript
# scripts/battle/apply_status_effect.gd
class_name ApplyStatusEffect
extends AbilityEffect

@export var status: StatusEffect


func make_instance() -> StatusEffect:
	return status.duplicate(true) if status != null else null
```

**Step 3: Repair the existing tests**

- `tests/test_apply_status_effect.gd`:
  - **Delete** `test_resolve_recipient_target_returns_target` and `test_resolve_recipient_self_returns_user`.
  - Change the `_make_effect` helper to drop the mode arg:
    ```gdscript
    func _make_effect(status: StatusEffect) -> ApplyStatusEffect:
        var ae := ApplyStatusEffect.new()
        ae.status = status
        return ae
    ```
  - Update the `make_instance`/aliasing tests to call `_make_effect(_make_status(...))` (no mode arg).
  - The integration tests (`test_offensive_ability_*`, `test_status_ability_spends_pp`) stay — `test_suppressor` now resolves via `target_mode = ONE_ENEMY`; behavior (damage + suppress on the struck enemy, PP spent once) is unchanged.
- `tests/test_combatant.gd`:
  - `test_ability_targets_party_defaults_false` → rename to `test_ability_target_mode_defaults_one_enemy`, assert `ab.target_mode == Ability.TargetMode.ONE_ENEMY`.
  - L182 `assert_true(karim.ability.targets_party)` → `assert_eq(karim.ability.target_mode, Ability.TargetMode.ONE_ALLY)`.
  - L194 `assert_false(margot.ability.targets_party)` → `assert_eq(margot.ability.target_mode, Ability.TargetMode.ONE_ENEMY)`.
- `tests/test_heal_effect.gd` L61: `assert_eq(a.target_mode, Ability.TargetMode.ONE_ALLY, "Field Suture targets one ally")`.

**Step 4: Run the full suite**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS, zero failures. (battle_scene's `_resolve_ability`/`confirm_party_target` still read `targets_party`? No — see Step 5.)

**Step 5: Keep battle_scene compiling**

`battle_scene.gd:261` references `_active.ability.targets_party`. Replace with `_active.ability.targets_party_side()` as a **temporary** shim so the project still loads and tests pass at this checkpoint. (Batch 2 rewrites this path entirely.)

**Step 6: Commit**

```bash
git add characters tests scripts/battle/apply_status_effect.gd scripts/battle/battle_scene.gd
git commit -m "refactor: migrate fixtures + tests to Ability.target_mode (#128)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Defines the enum everything else reads |
| B (sequential) | Task 2 | Depends on Task 1; rewrites shared fixtures + tests + ApplyStatusEffect |

### Smoketest Checkpoint 1 — existing battles still play through `target_mode`

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process godot_console
```
(Or use the `/run` skill — it handles worktree pre-flight and cache invalidation. If the worktree was just created, run `make worktree-init` first.)

**Step 4: Confirm with user**
Open `scenes/battle/StatusEffectTest_KarimHeal.tscn` (Karim heal = `ONE_ALLY`) and `StatusEffectTest_Suppressor.tscn` (damage + suppress = `ONE_ENEMY`). Verify: Karim's heal still routes to the ally picker and heals; the Suppressor still damages + debuffs the enemy. Nothing should look different yet — this batch is data-model only. Wait for confirmation.

---

## Batch 2 — Unified recipient resolution + apply (single-target parity)

This batch makes `battle_scene` resolve recipients from `target_mode` through **one** path, preserving today's single-target behavior (no AoE yet). It deletes the `targets_party_side()` shim.

### Task 3: Pure recipient resolver

**Files:**
- Modify: `scripts/battle/battle_scene.gd` (add `static func resolve_recipients`)
- Test: `tests/test_target_resolution.gd` (new)

**Depends on:** Task 2
**Parallelizable with:** none — first edit to `battle_scene.gd`; Tasks 4–8 all build on this function.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_target_resolution.gd
extends GutTest

func _c() -> Combatant:
	return Combatant.from_definition(CombatantDefinition.new())

func test_self_returns_user() -> void:
	var u := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.SELF, false, u, null, [], []), [u])

func test_one_ally_returns_picked() -> void:
	var u := _c(); var p := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ALLY, false, u, p, [u, p], []), [p])

func test_all_allies_returns_living_party() -> void:
	var u := _c(); var p := _c(); var party: Array[Combatant] = [u, p]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ALL_ALLIES, false, u, null, party, []), party)

func test_one_enemy_returns_picked() -> void:
	var u := _c(); var e := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ENEMY, false, u, e, [], [e]), [e])

func test_all_enemies_returns_living_enemies() -> void:
	var u := _c(); var e := _c(); var foes: Array[Combatant] = [e, _c()]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ALL_ENEMIES, false, u, e, [], foes), foes)

func test_switchable_one_enemy_expanded_returns_all() -> void:
	var u := _c(); var e := _c(); var foes: Array[Combatant] = [e, _c()]
	# expanded=true simulates the player toggling single -> all
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ENEMY, true, u, e, [], foes), foes)

func test_switchable_one_ally_expanded_returns_all() -> void:
	var u := _c(); var party: Array[Combatant] = [u, _c()]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ALLY, true, u, party[0], party, []), party)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_target_resolution.gd`
Expected: FAIL (no `resolve_recipients`).

**Step 3: Write minimal implementation** (add to `battle_scene.gd`)

```gdscript
# Pure: maps target_mode (+ live toggle) to the recipient list. No mutation.
# `expanded` only matters for switchable ONE_* abilities (player toggled single->all).
static func resolve_recipients(mode: int, expanded: bool, user: Combatant, picked: Combatant,
		living_party: Array[Combatant], living_enemies: Array[Combatant]) -> Array[Combatant]:
	match mode:
		Ability.TargetMode.SELF:
			return [user]
		Ability.TargetMode.ONE_ALLY:
			return living_party if expanded else [picked]
		Ability.TargetMode.ALL_ALLIES:
			return living_party
		Ability.TargetMode.ONE_ENEMY:
			return living_enemies if expanded else [picked]
		Ability.TargetMode.ALL_ENEMIES:
			return living_enemies
	return []
```

**Step 4: Run tests to verify they pass**

Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this break when `picked` is null for an ALL/SELF mode?" — no; those branches ignore `picked`. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_target_resolution.gd
git commit -m "feat: pure resolve_recipients for all target_modes (#128)"
```

---

### Task 4: Unified effect application + route existing single-target paths through it

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd` (existing — additions only; do not change existing assertions)

**Depends on:** Task 3
**Parallelizable with:** none — large surgery on `battle_scene.gd`, same file as Task 3.

**Step 1: Write the failing GUT test** (add to `tests/test_battle_scene.gd`)

```gdscript
func test_self_buff_ability_applies_to_caster() -> void:
	# A SELF ability (status on self) resolves with no target picker.
	var s := _make_scene_with_self_buffer()  # helper builds a fixture caster, see note
	var caster: Combatant = s.party[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_true(caster.active_effects.any(func(e): return e.effect_name == "guard"),
		"SELF ability must apply its status to the caster with no selection step")
```

> Note: add a tiny fixture `tests/fixtures/test_self_buffer.tres` — a `CharacterDefinition` whose ability has `target_mode = 0` (SELF) and one `ApplyStatusEffect` with a "guard" `StatusEffect` (DEF +N). Mirror `test_suppressor.tres`'s structure.

**Step 2: Run test to verify it fails**

Expected: FAIL (SELF routes nowhere yet).

**Step 3: Write minimal implementation**

Add the apply helpers and rewire `execute_action`/`confirm_*`. Key new functions:

```gdscript
# Compute deterministic damage this recipient will take (pre-await; dead-safe).
func _compute_damage_for(recipient: Combatant) -> int:
	var dmg := 0
	for effect in _active.ability.effects:
		if effect is DamageEffect:
			dmg += Combatant.apply_damage_variance(effect.compute(_active, recipient))
	return dmg

# Apply non-damage effects (heal/status/summon) to a recipient. Called at impact peak.
func _apply_nondamage_effects_to(recipient: Combatant) -> void:
	for effect in _active.ability.effects:
		if effect is HealEffect:
			recipient.heal(effect.compute_heal(_active, recipient))
		elif effect is ApplyStatusEffect:
			var inst: StatusEffect = effect.make_instance()
			if inst != null:
				recipient.apply_effect(inst)
		elif effect is SummonEffect:
			var summoned: Combatant = effect.make_summon()
			if summoned != null:
				add_enemy(summoned)
```

Rewire `execute_action(action_name)` so the **ability** branch routes by `target_mode` (attack path unchanged):

```gdscript
	if action_name == "ability" and _active != null and _active.ability != null:
		var ab := _active.ability
		if ab.target_mode == Ability.TargetMode.SELF:
			_cast_self()
			return
		if ab.targets_party_side():
			_begin_party_targeting()
			return
		# enemy-side
		var living := enemies.filter(func(e): return e.is_alive())
		if not ab.is_all() and not ab.switchable and living.size() == 1:
			_perform_ability_on([living[0]])   # auto-target single enemy (preserves old behavior)
			return
		_begin_enemy_targeting("ability")
		return
	# ... existing "attack" path below, unchanged ...
```

`_cast_self()` — no selection, no lunge:

```gdscript
func _cast_self() -> void:
	if not _active.spend_pp(_active.ability.pp_cost):
		_end_turn(); return
	_apply_nondamage_effects_to(_active)
	combatant_updated.emit(_active)
	var idx := party.find(_active)
	if idx >= 0:
		_spawn_damage_number(-_active.ability.pp_cost, $PartyContainer.get_child(idx), PP_COST_COLOR)
	_end_turn()
	_check_win_loss()
```

Refactor `confirm_party_target(target)` to compute recipients from `target_mode` and apply via the helpers (preserving its non-animated, straight-to-TICKING behavior the existing tests assert):

```gdscript
func confirm_party_target(target: Combatant) -> void:
	if not target.is_alive(): return
	if _active == null or _active.ability == null: return
	if not _active.spend_pp(_active.ability.pp_cost): return
	var living_party := party.filter(func(p): return p.is_alive())
	var recipients := resolve_recipients(_active.ability.target_mode, _target_all, _active, target, living_party, [])
	for r in recipients:
		_apply_nondamage_effects_to(r)
		combatant_updated.emit(r)
	combatant_updated.emit(_active)
	var attacker_idx := party.find(_active)
	if attacker_idx >= 0:
		_spawn_damage_number(-_active.ability.pp_cost, $PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
	_end_turn()
	_check_win_loss()
```

Add `var _target_all: bool = false` to the state vars (defaults false; set/reset in Batch 4). For Batch 2, `_target_all` stays false everywhere, so `ONE_ALLY`/`ONE_ENEMY` behave exactly as today.

Replace the enemy-side resolution inside `confirm_enemy_target()` and the single-enemy `execute_action` path with a shared `_perform_ability_on(recipients)` that keeps the existing lunge/flash animation for a **single** recipient (AoE handling is added in Batch 3). For now `_perform_ability_on` asserts `recipients.size() == 1` and runs the current single-target animation using `_compute_damage_for` + `take_damage` at peak + `_apply_nondamage_effects_to`.

> The executor should preserve every existing assertion in `tests/test_battle_scene.gd` (heal goes straight to TICKING, PP spent once, ANIMATING during attacks, etc.). Run them continuously while refactoring.

**Step 4: Run tests to verify they pass**

Run the full suite: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
Expected: PASS — existing battle_scene tests + the new SELF test.

**Step 5: Refactor checkpoint**

Ask: "Is `_perform_ability_on` ready for N>1?" — not yet (asserts size 1). That's deliberate; Batch 3 generalizes it. Leave a `# TODO(Batch 3): AoE` marker, no follow-up issue needed (next batch).

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd tests/fixtures/test_self_buffer.tres
git commit -m "refactor: unify ability resolution through target_mode (single-target) (#128)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 3 | Adds `resolve_recipients` |
| B (sequential) | Task 4 | Depends on Task 3; same file, large rewire |

### Smoketest Checkpoint 2 — single-target parity + SELF

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```
**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process godot_console
```
**Step 4: Confirm with user**
Play `StatusEffectTest_Suppressor.tscn` (ONE_ENEMY damage+status) and `StatusEffectTest_KarimHeal.tscn` (ONE_ALLY heal). Both must behave identically to before. Confirm the multi-enemy picker still appears when >1 enemy is alive. Wait for confirmation.

---

## Batch 3 — AoE: group cursor + all-target resolution + animation

### Task 5: HUD group-cursor highlight

**Files:**
- Modify: `scripts/battle/battle_scene.gd` (2 new signals), `scripts/ui/hud.gd` (handlers)
- Test: `tests/test_hud_group_cursor.gd` (new)

**Depends on:** Task 4
**Parallelizable with:** none — adds signals to `battle_scene.gd` (shared file).

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_hud_group_cursor.gd
extends GutTest

# Instantiate the real BattleScene so HUD.setup wires the signals, then assert
# every enemy panel's cursor lights when the group-target signal fires.
func _scene() -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	PartyManager._permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

func test_enemy_group_signal_lights_all_enemy_cursors() -> void:
	var s := _scene()
	await wait_frames(2)
	s.enemy_group_target_changed.emit(true)
	var rows := s.get_node("UI/HUD/EnemyWindow/EnemyRows")
	for row in rows.get_children():
		if row.has_node("CursorLabel"):
			assert_almost_eq(row.get_node("CursorLabel").modulate.a, 1.0, 0.01,
				"every enemy cursor must light under group targeting")
```

**Step 2: Run test to verify it fails**

Expected: FAIL (no `enemy_group_target_changed` signal).

**Step 3: Write minimal implementation**

In `battle_scene.gd` add:
```gdscript
signal enemy_group_target_changed(active: bool)
signal party_group_target_changed(active: bool)
```

In `hud.gd` `setup()` connect them, and add handlers that set every cursor's alpha:
```gdscript
	battle.enemy_group_target_changed.connect(_on_enemy_group_target_changed)
	battle.party_group_target_changed.connect(_on_party_group_target_changed)

func _on_enemy_group_target_changed(active: bool) -> void:
	for panel in _enemy_panels:
		if panel.has_node("CursorLabel"):
			panel.get_node("CursorLabel").modulate.a = 1.0 if active else 0.0

func _on_party_group_target_changed(active: bool) -> void:
	for i in range(mini(_party.size(), _panels.size())):
		if _panels[i].has_node("CursorLabel"):
			_panels[i].get_node("CursorLabel").modulate.a = 1.0 if active else 0.0
```

**Step 4: Run tests to verify they pass** — Expected: PASS.

**Step 5: Refactor checkpoint** — group highlight reuses the per-panel `CursorLabel`; consistent with single-target. Proceed.

**Step 6: Commit**
```bash
git add scripts/battle/battle_scene.gd scripts/ui/hud.gd tests/test_hud_group_cursor.gd
git commit -m "feat: HUD group-cursor highlight signals (#128)"
```

---

### Task 6: AoE resolution + animation (ALL_ENEMIES / ALL_ALLIES)

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene_aoe.gd` (new)

**Depends on:** Task 5
**Parallelizable with:** none — same file.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_battle_scene_aoe.gd
extends GutTest

func _scene_with(caster_path: String, enemy_ids: Array) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = ",".join(enemy_ids)
	PartyManager._permanent_members.append(Combatant.from_definition(load(caster_path)))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

const AOE_CASTER := "res://tests/fixtures/test_aoe_caster.tres"  # ALL_ENEMIES damage

func test_all_enemies_damages_every_living_enemy() -> void:
	var s := _scene_with(AOE_CASTER, ["shade", "shade"])
	var caster: Combatant = s.party[0]
	var hp_before := s.enemies.map(func(e): return e.current_hp)
	s._begin_player_turn(caster)
	s.execute_action("ability")          # ALL_ENEMIES -> group selection
	s.confirm_enemy_target()             # confirm the group
	await wait_for_signal(s.player_turn_ended, 3.0)
	for i in range(s.enemies.size()):
		assert_lt(s.enemies[i].current_hp, hp_before[i],
			"every living enemy must take AoE damage")
```

> Add fixture `tests/fixtures/test_aoe_caster.tres`: a `CharacterDefinition` whose ability has `target_mode = 4` (ALL_ENEMIES), one `DamageEffect`. Also add `tests/fixtures/test_aoe_healer.tres` (`target_mode = 2`, ALL_ALLIES, one `HealEffect`) for the ALL_ALLIES test (mirror the above).

**Step 2: Run test to verify it fails** — Expected: FAIL (`_perform_ability_on` asserts size 1).

**Step 3: Write minimal implementation**

Generalize `_perform_ability_on(recipients: Array[Combatant])`:
- Spend PP once.
- Pre-await: build `var dmg := {}` mapping each recipient → `_compute_damage_for(r)`.
- If the ability is enemy-side **and** any damage > 0: do one generic forward lunge of the attacker (reuse `LUNGE_DISTANCE`/`LUNGE_DURATION`), then at the peak loop **all** recipients: `r.take_damage(dmg[r])`, `_apply_nondamage_effects_to(r)`, spawn a damage number at that recipient's sprite, and flash enemy sprites (`_start_enemy_flash`) — all simultaneously. Then one return tween + `FLASH_HOLD` wait.
- If no damage (pure heal/buff, e.g. ALL_ALLIES heal): no lunge — apply effects, spawn per-recipient numbers, straight to TICKING (mirrors `confirm_party_target`).
- Spawn the PP-cost number on the attacker once.

Map a recipient → its sprite via `enemies.find(r)` → `$EnemyContainer.get_child(idx)` (enemy side) or `party.find(r)` → `$PartyContainer.get_child(idx)` (ally side).

Update `confirm_enemy_target()` to call `_perform_ability_on(resolve_recipients(...))` using `enemies.filter(is_alive)` as `living_enemies` and the highlighted enemy as `picked`. Keep the **attack** action on the single highlighted enemy (attack never AoEs).

**Step 4: Run tests to verify they pass** — Expected: PASS (AoE damage + existing single-target tests).

**Step 5: Refactor checkpoint**

Ask: "Does the per-recipient sprite lookup break if a recipient died earlier this resolution?" — recipients are captured from *living* lists pre-apply; numbers spawn on still-present sprites. Proceed. If a dead-recipient edge case appears, guard `idx >= 0` before `get_child`.

**Step 6: Commit**
```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene_aoe.gd tests/fixtures/test_aoe_caster.tres tests/fixtures/test_aoe_healer.tres
git commit -m "feat: AoE resolution + animation for ALL_* target_modes (#128)"
```

---

### Task 7: AoE smoketest scenes

**Files:**
- Create: `scenes/battle/TargetModeTest_AoEHeal.tscn`, `scripts/battle/test_aoe_heal_scene.gd`
- Create: `scenes/battle/TargetModeTest_AoEDamage.tscn`, `scripts/battle/test_aoe_damage_scene.gd`

**Depends on:** Task 6
**Parallelizable with:** none — both scenes derive from `BattleScene` and exercise Task 6's code; build together but they are tiny.

**Step 1: Write the content**

`test_aoe_heal_scene.gd` (mirror `test_karim_heal_scene.gd`): seed a 3-member party (e.g. reid + two temporaries) at reduced HP, with the caster's ability = the ALL_ALLIES healer fixture; spawn 1 enemy.

`test_aoe_damage_scene.gd` (mirror `test_enforcer_scene.gd`): seed the ALL_ENEMIES-damage caster fixture in the party; spawn 3 `shade` enemies.

Wire each `.tscn` to its script + the `BattleScene.tscn` base (copy the structure of an existing `StatusEffectTest_*.tscn`).

**Step 2: Verify**

Open each scene in the Godot editor; confirm it loads without script errors (no logic to unit-test — these are smoketest harnesses).

**Step 3: Commit**
```bash
git add scenes/battle/TargetModeTest_AoEHeal.tscn scenes/battle/TargetModeTest_AoEDamage.tscn scripts/battle/test_aoe_heal_scene.gd scripts/battle/test_aoe_damage_scene.gd
git commit -m "test: AoE smoketest scenes (#128)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 5 | HUD signals first (consumed by Task 6's visuals) |
| B (sequential) | Task 6 | Depends on Task 5; same `battle_scene.gd` |
| C (sequential) | Task 7 | Depends on Task 6; scenes exercise AoE |

### Smoketest Checkpoint 3 — AoE looks right

**Step 1: Fetch and merge latest master** — `git fetch origin && git merge origin/master`
**Step 2: Run all GUT tests** — `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/` → all pass.
**Step 3: Launch** — `Start-Process godot_console` (or `/run`).
**Step 4: Confirm with user**
- `TargetModeTest_AoEDamage.tscn`: cast the ability → the whole enemy group's cursors light, one lunge plays, **all** enemies flash and show damage numbers at once.
- `TargetModeTest_AoEHeal.tscn`: cast → all party cursors light, every ally's HP rises with a number, no lunge.
Wait for confirmation.

---

## Batch 4 — Switchable single↔all toggle

### Task 8: Live single↔all toggle during target selection

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene_switchable.gd` (new)

**Depends on:** Task 6 (AoE apply), Task 5 (group cursor)
**Parallelizable with:** none — same `battle_scene.gd`.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_battle_scene_switchable.gd
extends GutTest

const SWITCH_CASTER := "res://tests/fixtures/test_switch_caster.tres"  # ONE_ENEMY, switchable

func _scene(enemy_ids: Array) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	BattleContext.enemies = ",".join(enemy_ids)
	PartyManager._permanent_members.append(Combatant.from_definition(load(SWITCH_CASTER)))
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

func test_toggle_to_all_hits_every_enemy() -> void:
	var s := _scene(["shade", "shade"])
	var caster: Combatant = s.party[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")     # enters SELECTING_ENEMY, single
	s.expand_target_to_all()        # simulate push toward enemy side
	assert_true(s._target_all, "pushing toward the enemy group must expand to all")
	var hp_before := s.enemies.map(func(e): return e.current_hp)
	s.confirm_enemy_target()
	await wait_for_signal(s.player_turn_ended, 3.0)
	for i in range(s.enemies.size()):
		assert_lt(s.enemies[i].current_hp, hp_before[i], "expanded cast must hit all enemies")

func test_collapse_back_to_single() -> void:
	var s := _scene(["shade", "shade"])
	s._begin_player_turn(s.party[0])
	s.execute_action("ability")
	s.expand_target_to_all()
	s.collapse_target_to_single()
	assert_false(s._target_all, "pushing back must collapse to single")
```

> Add fixture `tests/fixtures/test_switch_caster.tres`: `target_mode = 3` (ONE_ENEMY), `switchable = true`, one `DamageEffect`.

**Step 2: Run test to verify it fails** — Expected: FAIL (no `expand_target_to_all`).

**Step 3: Write minimal implementation**

Add `expand_target_to_all()` / `collapse_target_to_single()` (extracted so tests don't depend on raw input):
```gdscript
func expand_target_to_all() -> void:
	if _active == null or _active.ability == null or not _active.ability.switchable:
		return
	_target_all = true
	if _active.ability.targets_enemy_side():
		enemy_target_changed.emit(null)          # clear single cursor
		enemy_group_target_changed.emit(true)
	else:
		party_target_changed.emit(null)
		party_group_target_changed.emit(true)

func collapse_target_to_single() -> void:
	if not _target_all:
		return
	_target_all = false
	if _active.ability.targets_enemy_side():
		enemy_group_target_changed.emit(false)
		enemy_target_changed.emit(enemies[_enemy_target_idx])
	else:
		party_group_target_changed.emit(false)
		party_target_changed.emit(party[_party_target_idx])
```

Wire input in `_unhandled_input`:
- In `SELECTING_ENEMY`: `move_right` → `expand_target_to_all()`; `move_left` → `collapse_target_to_single()`. (Enemies = "far right".)
- In `SELECTING_ALLY`: `move_left` → `expand_target_to_all()`; `move_right` → `collapse_target_to_single()`. (Party = "far left".)
- When `_target_all` is true, `move_up`/`move_down` navigation is ignored (group has no per-target cursor).

Reset `_target_all = false` in `_begin_enemy_targeting`/`_begin_party_targeting` (single by default) and in `_end_turn`. For a fixed-`ALL_*` ability, set `_target_all = true` and emit the group signal at the start of targeting (so the group cursor shows immediately and the toggle keys are no-ops because `switchable` is false).

`confirm_enemy_target()`/`confirm_party_target()` already pass `_target_all` into `resolve_recipients` (Tasks 4 & 6) — no further change.

**Step 4: Run tests to verify they pass** — Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does expand/collapse break for non-switchable ALL abilities?" — `expand_target_to_all` early-returns unless `switchable`; fixed-ALL sets `_target_all` directly at targeting start. Proceed.

**Step 6: Commit**
```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene_switchable.gd tests/fixtures/test_switch_caster.tres
git commit -m "feat: switchable single<->all target toggle (#128)"
```

---

### Task 9: Switchable smoketest scene

**Files:**
- Create: `scenes/battle/TargetModeTest_Caster.tscn`, `scripts/battle/test_target_caster_scene.gd`

**Depends on:** Task 8
**Parallelizable with:** none — single scene exercising Task 8.

**Step 1: Write the content**

`test_target_caster_scene.gd` (mirror `test_enforcer_scene.gd`): seed the switchable caster fixture in the party; spawn 3 `shade` enemies so the toggle is meaningful.

**Step 2: Verify** — open in editor; loads clean.

**Step 3: Commit**
```bash
git add scenes/battle/TargetModeTest_Caster.tscn scripts/battle/test_target_caster_scene.gd
git commit -m "test: switchable caster smoketest scene (#128)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 8 | Toggle logic in `battle_scene.gd` |
| B (sequential) | Task 9 | Depends on Task 8; scene |

### Smoketest Checkpoint 4 — the FF toggle feels right

**Step 1–3:** merge master, run GUT (all pass), launch (`/run`).
**Step 4: Confirm with user**
In `TargetModeTest_Caster.tscn`: select the ability → single enemy cursor. Press **right** → cursor expands to the whole enemy group; press **left** → back to single. Confirm a single-target cast hits one enemy and an expanded cast hits all. Wait for confirmation.

---

## Batch 5 — SummonEffect + Enforcer migration

### Task 10: `SummonEffect` + `Combatant.summon` delegate

**Files:**
- Create: `scripts/battle/summon_effect.gd`
- Modify: `scripts/battle/enemy_definition.gd`, `scripts/battle/combatant.gd`
- Test: `tests/test_summon_effect.gd` (new)

**Depends on:** Task 4 (so `SummonEffect` is already handled by `_apply_nondamage_effects_to`)
**Parallelizable with:** none — `combatant.gd`/`enemy_definition.gd` are read by the enforcer migration (Task 11) which must follow.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_summon_effect.gd
extends GutTest

func test_make_summon_returns_combatant_for_id() -> void:
	var s := SummonEffect.new()
	s.enemy_id = "block_captain"
	var c := s.make_summon()
	assert_not_null(c, "make_summon must build a Combatant from GameData")
	assert_eq(c.id, "block_captain", "summoned combatant must match the configured id")

func test_make_summon_full_hp() -> void:
	var s := SummonEffect.new()
	s.enemy_id = "block_captain"
	var c := s.make_summon()
	assert_eq(c.current_hp, c.max_hp, "summoned enemy must spawn at full HP")

func test_make_summon_empty_id_returns_null() -> void:
	assert_null(SummonEffect.new().make_summon(), "empty enemy_id must yield null, not crash")

func test_enemy_definition_has_summon_field() -> void:
	assert_true("summon" in EnemyDefinition.new(), "EnemyDefinition must expose a summon slot")

func test_combatant_summon_delegates_to_definition() -> void:
	var def := EnemyDefinition.new()
	var s := SummonEffect.new(); s.enemy_id = "block_captain"
	def.summon = s
	var c := Combatant.from_definition(def)
	assert_eq(c.summon, s, "Combatant.summon must delegate to its EnemyDefinition")

func test_combatant_summon_null_for_character() -> void:
	var c := Combatant.from_definition(CharacterDefinition.new())
	assert_null(c.summon, "non-enemy combatants have no summon")
```

**Step 2: Run test to verify it fails** — Expected: FAIL (`SummonEffect` undefined).

**Step 3: Write minimal implementation**

```gdscript
# scripts/battle/summon_effect.gd
class_name SummonEffect
extends AbilityEffect

# Data-driven reinforcement: names the enemy id to add to the battle.
# Resolves the definition via GameData (no resource paths). battle_scene/AI owns *when*.
@export var enemy_id: String = ""


func make_summon() -> Combatant:
	if enemy_id == "":
		return null
	var d := GameData.get_definition(enemy_id)
	return Combatant.from_definition(d) if d != null else null
```

```gdscript
# scripts/battle/enemy_definition.gd
class_name EnemyDefinition
extends CombatantDefinition

@export var ai: EnemyAI = null
@export var summon: SummonEffect = null
```

Add to `combatant.gd` (next to the `ai` delegate):
```gdscript
var summon: SummonEffect:
	get: return (def as EnemyDefinition).summon if def is EnemyDefinition else null
```

**Step 4: Run tests to verify they pass** — Expected: PASS.

**Step 5: Refactor checkpoint** — `make_summon` mirrors `_spawn_enemies`' `from_definition(GameData...)` pattern; consistent. Proceed.

**Step 6: Commit**
```bash
git add scripts/battle/summon_effect.gd scripts/battle/enemy_definition.gd scripts/battle/combatant.gd tests/test_summon_effect.gd
git commit -m "feat: SummonEffect + EnemyDefinition.summon delegate (#128)"
```

---

### Task 11: Migrate `TerritoryEnforcerAI` to the data-driven summon

**Files:**
- Modify: `scripts/battle/ai/territory_enforcer_ai.gd`, `characters/enemies/territory_enforcer.tres`
- Test: `tests/test_territory_enforcer_ai.gd` (new or existing — check first)

**Depends on:** Task 10
**Parallelizable with:** none — depends on the `summon` field/delegate.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_territory_enforcer_ai.gd
extends GutTest

func test_enforcer_summons_via_definition_summon() -> void:
	var enforcer := Combatant.from_definition(GameData.get_definition("territory_enforcer"))
	var ai := enforcer.ai
	var party: Array[Combatant] = [
		Combatant.from_definition(GameData.get_definition("reid")),
		Combatant.from_definition(GameData.get_definition("reid")),
	]
	var enemies: Array[Combatant] = [enforcer]          # outnumbered -> should summon
	var added: Array[Combatant] = []
	var add_fn := func(c: Combatant) -> void: added.append(c)
	ai.resolve_action(enforcer, party, enemies, add_fn)
	assert_eq(added.size(), 1, "enforcer must summon exactly one backup when outnumbered")
	assert_eq(added[0].id, "block_captain", "backup id must come from the definition's SummonEffect")

func test_enforcer_summon_id_not_in_script() -> void:
	# Guard against regression to a hardcoded id: the AI script must not name an enemy id.
	var src := FileAccess.get_file_as_string("res://scripts/battle/ai/territory_enforcer_ai.gd")
	assert_false(src.contains("block_captain"),
		"no enemy id may be hardcoded in the AI — it comes from the .tres summon")
```

**Step 2: Run test to verify it fails** — Expected: FAIL (id still in script / summon not wired).

**Step 3: Write minimal implementation**

Edit `territory_enforcer_ai.gd` summon branch:
```gdscript
	if living_enemies.size() < living_party.size() and not combatant.ai_state.get("backup_called", false):
		var summon := combatant.summon
		if summon != null:
			var backup := summon.make_summon()
			if backup != null:
				combatant.ai_state["backup_called"] = true
				add_enemy_fn.call(backup)
		return {}
```

Author the summon on `characters/enemies/territory_enforcer.tres`:
```
[ext_resource type="Script" path="res://scripts/battle/summon_effect.gd" id="3_summon"]

[sub_resource type="Resource" id="summon_backup"]
script = ExtResource("3_summon")
enemy_id = "block_captain"
```
…and in `[resource]` add: `summon = SubResource("summon_backup")` (and bump `load_steps`).

**Step 4: Run tests to verify they pass** — Expected: PASS.

**Step 5: Refactor checkpoint** — id now lives only in data; the script-scan test enforces it. Proceed.

**Step 6: Commit**
```bash
git add scripts/battle/ai/territory_enforcer_ai.gd characters/enemies/territory_enforcer.tres tests/test_territory_enforcer_ai.gd
git commit -m "refactor: enforcer backup via data-driven SummonEffect (#128)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 5

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 10 | SummonEffect + field/delegate |
| B (sequential) | Task 11 | Depends on Task 10; AI + fixture migration |

### Smoketest Checkpoint 5 — summon still works, now data-driven

**Step 1–3:** merge master, run GUT (all pass), launch (`/run`).
**Step 4: Confirm with user**
Play `scenes/battle/StatusEffectTest_Enforcer.tscn` with a party that outnumbers the lone Enforcer. Confirm the Block Captain backup still pops in mid-fight (HUD adds the row via `enemy_added`), identical to before — only now sourced from the `.tres`. Wait for confirmation.

---

## Batch 6 — Final verification + acceptance

### Task 12: Full-suite regression + acceptance-criteria sweep

**Files:** none (verification only)

**Depends on:** all prior tasks
**Parallelizable with:** none — final gate.

**Step 1: Run the entire GUT suite**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: all pass, zero failures (note any pre-existing failures recorded in memory and confirm they are unchanged, not newly introduced).

**Step 2: Walk the acceptance criteria**
- **AC1** — Enforcer backup via `SummonEffect`/`GameData`: Checkpoint 5 + `test_territory_enforcer_ai.gd`. ✓
- **AC2** — every `target_mode` resolves: `test_target_resolution.gd` + Checkpoints 2–4. ✓
- **AC3** — no hardcoded enemy resource paths/ids in AI: `test_enforcer_summon_id_not_in_script`. ✓
- **AC4** — GUT for SummonEffect + target_mode: `test_summon_effect.gd`, `test_target_resolution.gd`, AoE + switchable suites. ✓

**Step 3: Commit (if any cleanup)**
```bash
git commit --allow-empty -m "chore: verify #128 acceptance criteria"
```

### Final Checkpoint — hand to `finishing-a-development-branch`

Once Checkpoints 1–5 are user-confirmed and the full suite is green, proceed to the project `finishing-a-development-branch` skill (tests → smoketest → PR → cleanup). This plan integrates **PR-only**, never a local merge to master.

> **Lessons Learned gate:** `executing-plans` runs its Lessons Learned step after the final smoketest — capture anything notable (e.g. the two-level→one-level targeting consolidation, or the `Combatant.summon` delegate pattern) into memory/skills if the user approves.
