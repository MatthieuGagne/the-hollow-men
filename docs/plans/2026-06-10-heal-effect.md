# HealEffect Implementation Plan (Issue #126)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate the hardcoded `target.heal(60)` in `battle_scene.confirm_party_target` to a composable, data-driven `HealEffect` carried on the ability's `effects` array, routed through the existing no-lunge ally-targeting flow.

**Architecture:** `HealEffect extends AbilityEffect` follows the descriptor + pure-calculator model already established by `DamageEffect`: the effect owns *what* (a pure `compute_heal(user, target) -> int`), and `battle_scene` owns *when* (immediate, no-lunge timing — untouched). `confirm_party_target` iterates `ability.effects`, sums the heal from every `HealEffect`, and applies it once via the existing `Combatant.heal` (which clamps to `max_hp`). Karim's "Field Suture" carries the heal as data.

**Tech Stack:** Godot 4.6 / GDScript; GUT for tests; `.tres` Resource definitions.

## Open questions (must resolve before starting)

- None — all resolved in grill-me (formula, apply path, migration, routing all settled below).

## Design decisions (settled in grill-me)

- **Formula:** `compute_heal(user, target) = amount + user.get_effective_stat(StatusEffect.StatAxis.PSY) / 2`. Integer division floors. Uses **effective** PSY (status-aware), mirroring how `DamageEffect.compute` reads effective stats.
- **Karim tuning:** `amount = 38` → `38 + (45 / 2) = 38 + 22 = 60`. Behavior-preserving at Karim's current `psy_stat = 45` (today's heal is exactly 60).
- **Apply path:** `confirm_party_target` sums `compute_heal` over every `HealEffect` in `ability.effects`, then calls `target.heal(total)` once — mirrors `_resolve_ability`'s damage accumulation. All other logic in `confirm_party_target` (PP spend, `combatant_updated` emits, PP-cost damage number, `_end_turn`, `_check_win_loss`, no-lunge timing) is untouched.
- **Routing untouched:** `execute_action`'s `targets_party` → `_begin_party_targeting` routing is unchanged (R3: heal keeps immediate, no-lunge timing).
- **No existing tests modified:** All existing `test_battle_scene.gd` heal tests use threshold assertions (`assert_gt(reid.current_hp, 100)`, caps-at-max, PP spent, no-ANIMATING) and Karim's heal stays exactly 60, so they pass unchanged.

---

## Pre-flight (run once before Task 1)

This is a fresh worktree. Initialize build artifacts so the game and headless test runner work:

```bash
make worktree-init
```

Then confirm the existing suite is green before changing anything:

```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: existing tests pass (note any pre-existing failures recorded in memory; do not attribute them to this work).

---

## Batch 1 — HealEffect class, Karim migration, battle routing

### Task 1: `HealEffect` class + pure `compute_heal`

**Files:**
- Create: `scripts/battle/heal_effect.gd`
- Create (test): `tests/test_heal_effect.gd`

**Depends on:** none
**Parallelizable with:** none — Task 2 (`.tres`) references this script's path and Task 3 references the `HealEffect` class; both need this file to exist first. This is the head of a strictly sequential chain.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_heal_effect.gd
extends GutTest


func _healer(psy: int) -> Combatant:
	var d := CombatantDefinition.new()
	d.psy_stat = psy
	return Combatant.from_definition(d)


func test_heal_effect_is_ability_effect() -> void:
	assert_true(HealEffect.new() is AbilityEffect,
		"HealEffect must extend AbilityEffect")


func test_compute_heal_is_amount_plus_half_psy() -> void:
	var e := HealEffect.new()
	e.amount = 38
	var user := _healer(45)            # PSY 45 -> 45/2 = 22
	assert_eq(e.compute_heal(user, user), 60,
		"compute_heal = amount + floor(PSY/2) = 38 + 22")


func test_compute_heal_floors_odd_psy() -> void:
	var e := HealEffect.new()
	e.amount = 0
	var user := _healer(45)            # 45/2 floors to 22
	assert_eq(e.compute_heal(user, user), 22,
		"integer division floors odd PSY")


func test_compute_heal_scales_with_psy() -> void:
	var e := HealEffect.new()
	e.amount = 38
	var weak := _healer(0)             # 38 + 0
	var strong := _healer(100)         # 38 + 50
	assert_eq(e.compute_heal(weak, weak), 38, "no PSY -> just amount")
	assert_eq(e.compute_heal(strong, strong), 88, "PSY 100 -> 38 + 50")


func test_compute_heal_uses_effective_psy() -> void:
	# A PSY debuff must lower the heal (effect reads effective, not base, stat).
	var e := HealEffect.new()
	e.amount = 0
	var user := _healer(45)
	user.add_effect(StatusEffect.new(StatusEffect.Kind.WEAKEN_PSY, 3, 10))
	var base_half: int = 45 / 2
	assert_lt(e.compute_heal(user, user), base_half,
		"effective PSY (debuffed) must reduce the heal below base PSY/2")
```

> **Note on `test_compute_heal_uses_effective_psy`:** verify the real `StatusEffect` API before running — confirm the enum member that lowers PSY (`StatusEffect.Kind.*`) and the `add_effect`/constructor signature against `scripts/battle/status_effect.gd` and `scripts/battle/combatant.gd`. If a PSY-lowering status does not exist, **delete this single test** (the other four fully cover the formula) rather than inventing an API. Do not block on it.

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heal_effect.gd`
Expected: FAIL (`HealEffect` undefined).

**Step 3: Write minimal implementation**

```gdscript
# scripts/battle/heal_effect.gd
class_name HealEffect
extends AbilityEffect

# Flat base restored, plus half the healer's effective PSY (status-aware).
# Pure: no RNG, no mutation. battle_scene owns *when*; this owns *what*.
@export var amount: int = 0

func compute_heal(user: Combatant, target: Combatant) -> int:
	return amount + user.get_effective_stat(StatusEffect.StatAxis.PSY) / 2
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heal_effect.gd`
Expected: PASS.

**Step 5: Refactor checkpoint**

Ask: "Does this generalize, or did I hard-code something that breaks when N > 1?" — `amount` is data-driven and `target` is accepted (unused now) so a future target-scaled formula needs no call-site change. No follow-up needed.

**Step 6: Commit**

```bash
git add scripts/battle/heal_effect.gd tests/test_heal_effect.gd
git commit -m "feat: add HealEffect (amount + effective PSY/2), pure compute_heal"
```

---

### Task 2: Migrate Karim's "Field Suture" to carry a `HealEffect`

**Files:**
- Modify: `characters/karim.tres`
- Modify (test): `tests/test_heal_effect.gd` (add a `.tres`-loaded assertion, mirroring `test_damage_effect.gd`'s `reid.tres` test)

**Depends on:** Task 1 (the `.tres` references `res://scripts/battle/heal_effect.gd` and the assertion needs the class).
**Parallelizable with:** none — edits `heal_effect.gd`'s consumer data and the same test file Task 1 created.

**Step 1: Write the failing GUT test**

Append to `tests/test_heal_effect.gd`:

```gdscript
func test_karim_ability_has_heal_effect() -> void:
	var karim: Combatant = Combatant.from_definition(load("res://characters/karim.tres"))
	var a := karim.ability
	assert_eq(a.ability_name, "Field Suture")
	assert_true(a.targets_party, "Field Suture targets the party")
	assert_eq(a.effects.size(), 1, "exactly one effect")
	assert_true(a.effects[0] is HealEffect, "effect is a HealEffect")
	assert_eq(a.effects[0].amount, 38, "tuned so 38 + PSY(45)/2 = 60")


func test_karim_heals_60_at_current_psy() -> void:
	var karim: Combatant = Combatant.from_definition(load("res://characters/karim.tres"))
	var heal: HealEffect = karim.ability.effects[0]
	assert_eq(heal.compute_heal(karim, karim), 60,
		"behavior-preserving: Karim still heals 60 at PSY 45")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heal_effect.gd`
Expected: FAIL (`a.effects` is empty — size 0, not 1).

**Step 3: Write minimal implementation**

Edit `characters/karim.tres`. Add the `heal_effect.gd` ext_resource, a `HealEffect` sub_resource, and wire it into the ability's `effects` array (mirrors `reid.tres`'s structure). Bump `load_steps` from 3 to 4.

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_chardef"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]
[ext_resource type="Script" path="res://scripts/battle/heal_effect.gd" id="3_heal"]

[sub_resource type="Resource" id="heal_karim"]
script = ExtResource("3_heal")
amount = 38

[sub_resource type="Resource" id="ability_karim"]
script = ExtResource("2_ability")
ability_name = "Field Suture"
pp_cost = 10
targets_party = true
effects = Array[AbilityEffect]([SubResource("heal_karim")])

[resource]
script = ExtResource("1_chardef")
id = "karim"
character_name = "Karim"
is_player_controlled = true
max_hp = 310
max_pp = 70
str_stat = 20
def_stat = 35
psy_stat = 45
res_stat = 50
spd_stat = 22
sigil_type = 0
sprite_path = "res://assets/sprites/characters/karim.png"
sprite_vframes = 8
ability = SubResource("ability_karim")
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_heal_effect.gd`
Expected: PASS.

Also run the combatant suite to confirm the `.tres` still loads cleanly:
Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: PASS (`test_karim_loads_with_correct_stats` unaffected — name/pp/targets_party unchanged).

**Step 5: Refactor checkpoint**

Ask: "Breaks when N > 1?" — `effects` is an array; multiple heal effects already sum at the call site (Task 3). No hard-coding beyond the tuned `amount`, which is intentional data. No follow-up.

**Step 6: Commit**

```bash
git add characters/karim.tres tests/test_heal_effect.gd
git commit -m "feat: migrate Karim Field Suture to data-driven HealEffect (amount 38)"
```

---

### Task 3: Route `confirm_party_target` through `ability.effects`

**Files:**
- Modify: `scripts/battle/battle_scene.gd` (`confirm_party_target`)

**Depends on:** Task 1 (`HealEffect` class), Task 2 (Karim's `.tres` must carry the effect — otherwise `total` is 0 and the existing `test_confirm_party_target_heals_target` would fail).
**Parallelizable with:** none — tail of the sequential chain; requires both prior tasks' symbols and data.

**Step 1: Write the failing GUT test**

The existing `test_battle_scene.gd` heal tests already exercise this path with **threshold** assertions and stay green (Karim heals 60). Add **one exact-amount** test to `tests/test_battle_scene.gd` that pins the data-driven value, proving the effect (not a literal) drives the heal:

```gdscript
func test_confirm_party_target_heals_exact_effect_amount() -> void:
	var karim := _add_karim_to_party()   # PSY 45 -> heals 38 + 22 = 60
	var reid: Combatant = _scene.party[0]
	reid.current_hp = 100
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")
	_scene.confirm_party_target(reid)
	assert_eq(reid.current_hp, 160,
		"data-driven HealEffect restores exactly 60 (100 -> 160)")
```

> Place this test next to the existing `test_confirm_party_target_heals_target` (around line 293). Do **not** modify the existing heal tests.

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd`
Expected: This new test currently PASSES by accident (literal `heal(60)` still gives 160). To see a true red→green, first apply the Step 3 edit's **deletion** of `target.heal(60)` only (leaving no replacement) and re-run — the new test FAILS (`reid.current_hp == 100`), and `test_confirm_party_target_heals_target` also FAILS. This confirms the test pins real behavior. Then complete Step 3.

**Step 3: Write minimal implementation**

In `scripts/battle/battle_scene.gd`, replace the single line `target.heal(60)` in `confirm_party_target` with the effect-summing loop:

```gdscript
	var total: int = 0
	for effect in _active.ability.effects:
		if effect is HealEffect:
			total += effect.compute_heal(_active, target)
	target.heal(total)
```

Leave every other line of `confirm_party_target` exactly as-is (the PP-spend guard above it, the two `combatant_updated.emit` calls, the PP-cost damage number, `_end_turn`, `_check_win_loss`).

**Step 4: Run tests to verify they pass**

Run the full battle suite (covers heal, cap-at-max, PP spend, no-ANIMATING, returns-to-ticking, dead-target):
Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd`
Expected: PASS, including the new exact-amount test and all existing heal tests.

**Step 5: Refactor checkpoint**

Ask: "Breaks when N > 1?" — the loop sums all `HealEffect`s, so multiple heal effects compose correctly. The literal `60` is fully removed (AC2). No follow-up.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: route confirm_party_target through HealEffect; remove literal heal(60)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Head of chain — creates `HealEffect` class + test file |
| B (sequential) | Task 2 | Depends on Task 1 — `.tres` references the script; edits same test file |
| C (sequential) | Task 3 | Depends on Tasks 1 & 2 — needs the class and Karim's effect data |

All three tasks are strictly sequential (shared symbols + shared test file + data dependency). No parallelism available in this batch — this is a small, tightly-coupled migration.

### Smoketest Checkpoint 1 — Karim's heal works end-to-end via data

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero new failures (only pre-existing failures recorded in memory, if any).

**Step 3: Launch game and verify visually**

Use the `/run` skill (handles worktree init check, stale-instance kill, launch). Start a debug battle that includes Karim.

**Step 4: Confirm with user**
Verify in the running game:
- Select Karim → choose his ability ("Field Suture") → it enters ally-target selection (no enemy targeting, no lunge animation).
- Confirm on a wounded ally → that ally's HP jumps by ~60 (exactly 60 at Karim's current PSY), clamped at max HP.
- Karim spends 10 PP and a floating PP-cost label appears over his sprite.
- Turn ends normally (battle returns to ticking; no stuck ANIMATING state).

Wait for user confirmation before finishing the branch.

---

## After smoketest passes

Hand off to the `finishing-a-development-branch` skill: full GUT run, smoketest sign-off, doc check, PR creation, worktree cleanup. Reference issue #126 in the PR; update memory (`project-issue-126-*`) and the godot-expert AbilityEffect notes with the HealEffect pattern.
