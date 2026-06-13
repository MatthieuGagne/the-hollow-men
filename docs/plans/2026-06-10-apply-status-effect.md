# ApplyStatusEffect Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a composable, data-driven `ApplyStatusEffect` so an ability can apply a status (buff/debuff) to a combatant — proven end-to-end by a throwaway demo ability that deals damage *and* debuffs the enemy in one cast.

**Architecture:** `ApplyStatusEffect extends AbilityEffect` (descriptor + pure-calculator model, matching merged `DamageEffect`/`HealEffect`). It holds a `StatusEffect` *template* and a minimal `target_mode` enum `{ TARGET, SELF }`. `battle_scene` owns *when* (on cast, synchronously, inside the single shared `_resolve_ability` resolver — covering both enemy-path call sites). Each application produces a **fresh `status.duplicate(true)`** so concurrent targets never share a mutable duration counter.

**Tech Stack:** Godot 4.6 / GDScript, GUT for tests. Mobile renderer (no renderer concerns here).

## Open questions (must resolve before starting)

- None. All six design decisions were locked during grill-me:
  1. `target_mode = { TARGET, SELF }` (defer multi-target `ALL_*` to #128).
  2. `status.duplicate(true)` (deep) + two-target non-aliasing assertion.
  3. On-cast timing, applied inside `_resolve_ability` (one shared site covers both enemy call sites).
  4. Throwaway demo scene (production `.tres` frozen).
  5. Demo definition is a throwaway `.tres` loaded directly, **not** registered in `GameData`.
  6. AI status refactor (`hold_the_line`/`mark_target`/`authorised_force`) is **out of scope** — no aliasing bug exists there; different dispatch model.

**Scope note:** This slice wires the **enemy path** (`_resolve_ability`), which already covers both `TARGET` (debuff the struck enemy) and `SELF` (self-buff while attacking). The **ally-targeted-buff path** (`confirm_party_target` with `targets_party = true`) is intentionally deferred — it needs its own party-targeting demo and rides cleanly with #128's targeting work. Note this deferral in the PR body.

---

## Task 1: `ApplyStatusEffect` class + unit tests

**Files:**
- Create: `scripts/battle/apply_status_effect.gd`
- Create/Test: `tests/test_apply_status_effect.gd`

**Depends on:** none
**Parallelizable with:** none — foundational; Tasks 2–4 all reference the `ApplyStatusEffect` script or this test file.

**Step 1: Write the failing GUT test**

Create `tests/test_apply_status_effect.gd`:

```gdscript
extends GutTest

# --- helpers ---

func _make_status(axis: int, mod: int, dur: int, ename := "demo") -> StatusEffect:
	var s := StatusEffect.new()
	s.effect_name = ename
	s.stat = axis
	s.modifier = mod
	s.duration = dur
	return s

func _make_effect(mode: int, status: StatusEffect) -> ApplyStatusEffect:
	var ae := ApplyStatusEffect.new()
	ae.target_mode = mode
	ae.status = status
	return ae

func _make_combatant() -> Combatant:
	return Combatant.from_definition(CombatantDefinition.new())

# --- resolve_recipient ---

func test_resolve_recipient_target_returns_target() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET,
		_make_status(StatusEffect.StatAxis.DEF, -6, 2))
	var user := _make_combatant()
	var target := _make_combatant()
	assert_eq(ae.resolve_recipient(user, target), target,
		"TARGET mode must land on the resolved target")

func test_resolve_recipient_self_returns_user() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.SELF,
		_make_status(StatusEffect.StatAxis.STR, 8, 3))
	var user := _make_combatant()
	var target := _make_combatant()
	assert_eq(ae.resolve_recipient(user, target), user,
		"SELF mode must land on the caster")

# --- make_instance: fresh, correct, non-aliasing ---

func test_make_instance_is_fresh_not_template() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2)
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET, tmpl)
	assert_ne(ae.make_instance(), tmpl,
		"applied instance must NOT be the template object")

func test_make_instance_copies_axis_modifier_duration() -> void:
	var tmpl := _make_status(StatusEffect.StatAxis.DEF, -6, 2, "suppress")
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET, tmpl)
	var inst := ae.make_instance()
	assert_eq(inst.effect_name, "suppress")
	assert_eq(inst.stat, StatusEffect.StatAxis.DEF)
	assert_eq(inst.modifier, -6)
	assert_eq(inst.duration, 2)

func test_make_instance_null_status_returns_null() -> void:
	var ae := ApplyStatusEffect.new()  # status left unset
	assert_null(ae.make_instance(), "null template must yield null, not crash")

func test_two_targets_do_not_alias() -> void:
	var ae := _make_effect(ApplyStatusEffect.TargetMode.TARGET,
		_make_status(StatusEffect.StatAxis.DEF, -6, 2))
	var a := _make_combatant()
	var b := _make_combatant()
	a.apply_effect(ae.make_instance())
	b.apply_effect(ae.make_instance())
	a.tick_effects()  # decrements A's copy only
	assert_eq(a.active_effects[0].duration, 1, "A's duration must drop to 1")
	assert_eq(b.active_effects[0].duration, 2,
		"B's duration must be untouched — proves no shared instance")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_apply_status_effect.gd -gexit`
Expected: FAIL — `ApplyStatusEffect` is an unknown class (parse/identifier error).

**Step 3: Write minimal implementation**

Create `scripts/battle/apply_status_effect.gd`:

```gdscript
# scripts/battle/apply_status_effect.gd
class_name ApplyStatusEffect
extends AbilityEffect

# Applies a status to a combatant as data. Holds a StatusEffect *template*;
# each application produces a FRESH duplicate so concurrent targets never
# share a mutable duration counter. battle_scene owns *when*; this owns *what*.

enum TargetMode { TARGET, SELF }

@export var status: StatusEffect
@export var target_mode: TargetMode = TargetMode.TARGET


# The combatant this effect lands on: SELF -> the caster, TARGET -> the
# ability's already-resolved target (enemy or ally).
func resolve_recipient(user: Combatant, target: Combatant) -> Combatant:
	return user if target_mode == TargetMode.SELF else target


# A fresh, non-aliasing StatusEffect instance ready to hand to apply_effect.
# Deep-duplicates so future nested fields stay independent. Null-safe.
func make_instance() -> StatusEffect:
	return status.duplicate(true) if status != null else null
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_apply_status_effect.gd -gexit`
Expected: PASS — 6 passing tests, 0 failures.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize, or did I hard-code something that breaks when N > 1?"
- `make_instance()` returns a fresh copy per call → multiple targets/casts are independent (proven by `test_two_targets_do_not_alias`). Generalizes. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/apply_status_effect.gd tests/test_apply_status_effect.gd
git commit -m "feat: add ApplyStatusEffect with target_mode and non-aliasing make_instance"
```

---

## Task 2: Throwaway demo definition `.tres` (Suppressing Strike)

**Files:**
- Create: `tests/fixtures/test_suppressor.tres`

**Depends on:** Task 1 — the `.tres` references `scripts/battle/apply_status_effect.gd`, which must exist and parse.
**Parallelizable with:** none — Tasks 3 and 4 both consume this fixture; it must land first.

**Step 1: Write the content**

This is a `CharacterDefinition` whose ability composes a `DamageEffect` (physical) **and** an `ApplyStatusEffect` (`TARGET`, DEF −6 for 2 turns, `effect_name = "suppress"`). It is loaded directly via `load(...)` and is **never** registered in `GameData`. Sprite is reused from Reid (throwaway visual). Stats give STR 60 so it reliably deals damage > 0 against the default Shade.

Create the directory if needed, then create `tests/fixtures/test_suppressor.tres`:

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=9 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_chardef"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]
[ext_resource type="Script" path="res://scripts/battle/damage_effect.gd" id="3_dmg"]
[ext_resource type="Script" path="res://scripts/battle/apply_status_effect.gd" id="4_apply"]
[ext_resource type="Script" path="res://scripts/battle/status_effect.gd" id="5_status"]

[sub_resource type="Resource" id="dmg_supp"]
script = ExtResource("3_dmg")
kind = 0

[sub_resource type="Resource" id="status_supp"]
script = ExtResource("5_status")
effect_name = "suppress"
stat = 0
modifier = -6
duration = 2

[sub_resource type="Resource" id="apply_supp"]
script = ExtResource("4_apply")
target_mode = 0
status = SubResource("status_supp")

[sub_resource type="Resource" id="ability_supp"]
script = ExtResource("2_ability")
ability_name = "Suppressing Strike"
pp_cost = 3
targets_party = false
effects = Array[AbilityEffect]([SubResource("dmg_supp"), SubResource("apply_supp")])

[resource]
script = ExtResource("1_chardef")
id = "test_suppressor"
character_name = "Suppressor"
is_player_controlled = true
max_hp = 200
max_pp = 30
str_stat = 60
def_stat = 30
psy_stat = 20
res_stat = 20
spd_stat = 35
sigil_type = 0
sprite_path = "res://assets/sprites/characters/reid.png"
sprite_vframes = 8
ability = SubResource("ability_supp")
```

Notes:
- `kind = 0` → `DamageEffect.Kind.PHYSICAL`.
- `stat = 0` → `StatusEffect.StatAxis.DEF`; `target_mode = 0` → `ApplyStatusEffect.TargetMode.TARGET`.
- `load_steps = 9` = 1 resource + 5 ext + ... recount after authoring if Godot complains; Godot will correct it on first import/save. If reimport warns, open once in the editor and resave, or trust the headless importer to normalize.

**Step 2: Verify**

Run a headless import + a one-line load probe:
```bash
godot_console --headless --editor --quit --path .
godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_apply_status_effect.gd -gexit
```
Expected: import completes with no parse error on the `.tres`; existing Task 1 tests still pass. (Full fixture exercise happens in Task 3.)

**Step 3: Commit**

```bash
git add tests/fixtures/test_suppressor.tres
git commit -m "test: add throwaway Suppressor definition (damage + DEF debuff)"
```

---

## Task 3: Wire `ApplyStatusEffect` into `_resolve_ability` + integration tests

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Modify/Test: `tests/test_apply_status_effect.gd` (append integration tests)

**Depends on:** Task 1, Task 2
**Parallelizable with:** Task 4 — disjoint files (`battle_scene.gd` + test vs. scene `.tscn` + scene script).

**Step 1: Write the failing GUT test**

Append to `tests/test_apply_status_effect.gd`:

```gdscript
# --- integration: wired through battle_scene enemy path ---

const SUPPRESSOR_DEF := "res://tests/fixtures/test_suppressor.tres"

func _make_scene_with(caster_def_path: String) -> BattleScene:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleContext.configure()
	var caster := Combatant.from_definition(load(caster_def_path))
	PartyManager._permanent_members.append(caster)
	var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(s)
	return s

func test_offensive_ability_applies_status_to_enemy() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	var debuffed := shade.active_effects.any(func(ef: StatusEffect) -> bool:
		return ef.effect_name == "suppress")
	assert_true(debuffed,
		"Suppressing Strike must apply the 'suppress' debuff to the struck enemy")

func test_offensive_ability_lowers_enemy_effective_def() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	var def_before := shade.get_effective_stat(StatusEffect.StatAxis.DEF)
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(shade.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
		"applied DEF debuff must reduce the enemy's effective DEF")

func test_offensive_ability_also_deals_damage() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var shade: Combatant = s.enemies[0]
	var hp_before := shade.current_hp
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(shade.current_hp, hp_before,
		"Suppressing Strike composes DamageEffect + ApplyStatusEffect in one cast")

func test_status_ability_spends_pp() -> void:
	var s := _make_scene_with(SUPPRESSOR_DEF)
	var caster: Combatant = s.party[0]
	var pp_before := caster.current_pp
	s._begin_player_turn(caster)
	s.execute_action("ability")
	await wait_for_signal(s.player_turn_ended, 2.0)
	assert_lt(caster.current_pp, pp_before,
		"status ability must still spend PP exactly once via _resolve_ability")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_apply_status_effect.gd -gexit`
Expected: the 4 new integration tests FAIL — `_resolve_ability` ignores `ApplyStatusEffect`, so the enemy gets no `suppress` effect and effective DEF is unchanged. (The 6 Task-1 unit tests still pass.)

**Step 3: Write minimal implementation**

In `scripts/battle/battle_scene.gd`, modify `_resolve_ability` (currently around line 445). Add the `elif` branch — do **not** add a second PP spend; PP is already spent once at the top:

```gdscript
func _resolve_ability(attacker: Combatant, target: Combatant) -> int:
	if attacker.ability == null:
		return 0
	if not attacker.spend_pp(attacker.ability.pp_cost):
		return 0
	var total: int = 0
	for effect in attacker.ability.effects:
		if effect is DamageEffect:
			total += Combatant.apply_damage_variance(effect.compute(attacker, target))
		elif effect is ApplyStatusEffect:
			var inst: StatusEffect = effect.make_instance()
			if inst != null:
				effect.resolve_recipient(attacker, target).apply_effect(inst)
	return total
```

This single edit covers **both** enemy-path call sites (`execute_action` auto-target at ~line 281 and `confirm_enemy_target` at ~line 407), since both route through `_resolve_ability`.

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_apply_status_effect.gd -gexit`
Expected: PASS — all 10 tests (6 unit + 4 integration), 0 failures.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize, or did I hard-code something that breaks when N > 1?"
- The loop handles any number of `ApplyStatusEffect`s in `effects`, each producing its own fresh instance and resolving its own recipient. Damage and status compose without coupling. Generalizes. Proceed.
- Confirm no `target_mode = SELF` regression risk: `resolve_recipient` is unit-tested for both branches (Task 1); the enemy path passes `attacker` as `user`, so a SELF status would correctly land on the caster.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_apply_status_effect.gd
git commit -m "feat: apply ApplyStatusEffect on cast in _resolve_ability (both enemy call sites)"
```

---

## Task 4: Throwaway demo scene for manual smoketest

**Files:**
- Create: `scripts/battle/test_suppressor_scene.gd`
- Create: `scenes/battle/StatusEffectTest_Suppressor.tscn`

**Depends on:** Task 2 (loads the fixture).
**Parallelizable with:** Task 3 — disjoint files.

**Step 1: Write the content**

Mirror the existing #126 precedent (`scripts/battle/test_karim_heal_scene.gd` + `scenes/battle/StatusEffectTest_KarimHeal.tscn`).

Create `scripts/battle/test_suppressor_scene.gd`:

```gdscript
extends BattleScene

func _ready() -> void:
	PartyManager.add_temporary(
		Combatant.from_definition(load("res://tests/fixtures/test_suppressor.tres")))
	super._ready()

func _spawn_enemies() -> void:
	add_enemy(Combatant.from_definition(GameData.get_definition("private_security_guard")))
```

Create `scenes/battle/StatusEffectTest_Suppressor.tscn` by copying `scenes/battle/StatusEffectTest_KarimHeal.tscn` verbatim, then changing exactly two things:
1. The script `ext_resource` path: `res://scripts/battle/test_karim_heal_scene.gd` → `res://scripts/battle/test_suppressor_scene.gd`.
2. The root node name: `[node name="StatusEffectTest_KarimHeal" type="Node2D"]` → `[node name="StatusEffectTest_Suppressor" type="Node2D"]`.

Leave all UI nodes (HUD, windows, ActionMenu, FlashOverlay, labels, DefeatMenu) identical.

**Step 2: Verify**

Reimport so Godot picks up the new scene + script:
```bash
godot_console --headless --editor --quit --path .
```
Expected: no parse/import errors. (Visual confirmation happens in the Smoketest Checkpoint.)

**Step 3: Commit**

```bash
git add scripts/battle/test_suppressor_scene.gd scenes/battle/StatusEffectTest_Suppressor.tscn
git commit -m "test: add Suppressor smoketest scene (damage + DEF debuff demo)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Foundational — defines `ApplyStatusEffect`; all others depend on it |
| B (sequential) | Task 2 | Demo `.tres`; references Task 1's script; consumed by Tasks 3 & 4 |
| C (parallel) | Task 3, Task 4 | Disjoint files (`battle_scene.gd` + test  vs.  scene `.tscn` + scene script); both depend only on Tasks 1–2 |

---

### Smoketest Checkpoint 1 — Suppressing Strike debuffs the enemy and composes with damage

**Step 0: Worktree init (first run in this worktree only)**
```bash
make worktree-init
```
Copies gitignored build artifacts and runs a full headless reimport — without it the map/sprites render empty.

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```
Resolve any conflicts before proceeding.

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```
Expected: all tests pass, zero **new** failures. (Cross-check any pre-existing failures against the godot-expert memory note before flagging.)

**Step 3: Launch the demo scene and verify visually**

Use `/run` (handles worktree detection, stale-instance kill, reimport), then open `scenes/battle/StatusEffectTest_Suppressor.tscn` — or launch that scene directly in the editor.

**Step 4: Confirm with user**

Tell the user to verify in the running game:
- Select **Suppressor**, use the **ability** ("Suppressing Strike") on the security guard.
- The guard takes **damage** AND gains a **DEF-down** status (the `suppress` debuff).
- On a **follow-up** hit while the debuff is active, the guard takes **noticeably more damage** (lower effective DEF), and the debuff **expires after 2 of its turns**.
- PP is spent **once** (no double-charge).

Wait for explicit confirmation before finishing the branch.

---

## After the smoketest passes

- Run `/finishing-a-development-branch` (GUT + smoketest recap, docs check, PR, cleanup).
- In the PR body, note the deferred scope: **ally-targeted-buff path** (`confirm_party_target` + `targets_party`) and the **AI status refactor** (R3) are intentionally left for #128 / a follow-up. Reference issue #127 and the epic #129.
- **Lessons Learned gate** (run by `executing-plans`): ask whether to capture anything in CLAUDE.md / memory (e.g. the "status applied on cast inside the shared `_resolve_ability`" pattern, or the throwaway-`.tres`-loaded-directly test fixture convention).
