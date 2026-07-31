# Experience Loop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the project `executing-plans` skill (NOT superpowers:executing-plans) to implement this plan task-by-task.

**Goal:** Add a durable XP/level/stat-growth system for player characters plus a walkable test-harness room (3 random fights → Iris joins → Territory Enforcer boss) that exercises and persists progression end-to-end.

**Architecture:** A pure `Progression` math module owns the XP curve and the total-XP→level mapping. `PartyManager` owns a per-character progression store (`id → {level, xp}`) seeded for every known `CharacterDefinition`, and `award_xp` mutates both the store and the live `Combatant` objects (level + full-heal). `Combatant`'s stat getters scale `base + growth*(level-1)` for character defs (enemies stay Lv 1). `SaveData` v2 persists roster + progression. A new `ExperienceTestRoom` drives step-based random encounters, a win-counter boss gate, and Iris's level-matched join — all via a new `Player.stepped` signal and `GameState` flags, keeping `BattleScene` and `Player` generic.

**Tech Stack:** Godot 4.6 / GDScript, GUT for tests, Resource (`.tres`) data definitions.

**XP model (decided):** `xp` in each progression record is **lifetime total XP** (never reset on level-up). `level` is denormalized but always recomputable via `Progression.level_for_xp(xp)`. `xp_to_next(level)` = the per-level delta; `cumulative_xp(level)` = total XP to *reach* `level` (Lv 1 → 0). Iris joins with `xp = cumulative_xp(reid.level)`.

## Open questions (must resolve before starting)

- None. All grilled and resolved. Tunable defaults (encounter `GRACE_STEPS=4` / `ENCOUNTER_CHANCE=0.25`, per-character growth values, `security_captain.xp_reward=0`) are documented inline and may be retuned during the smoketests.

---

## Batch 1 — Progression math & definition fields

### Task 1: Progression math module

**Files:**
- Create: `scripts/battle/progression.gd`
- Test: `tests/test_progression.gd`

**Depends on:** none
**Parallelizable with:** Task 2 (different files, no shared symbols)

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_progression.gd
extends GutTest

func test_xp_to_next_sample_values():
	assert_eq(Progression.xp_to_next(1), 100, "Lv1->2 = round(100 * 1^1.5)")
	assert_eq(Progression.xp_to_next(2), 283, "Lv2->3 = round(100 * 2^1.5)")

func test_xp_to_next_is_monotonic():
	assert_true(Progression.xp_to_next(5) > Progression.xp_to_next(4))

func test_cumulative_xp_lv1_is_zero():
	assert_eq(Progression.cumulative_xp(1), 0)

func test_cumulative_xp_lv2_is_first_threshold():
	assert_eq(Progression.cumulative_xp(2), 100)

func test_cumulative_xp_lv3():
	assert_eq(Progression.cumulative_xp(3), 100 + 283)

func test_level_for_xp_boundaries():
	assert_eq(Progression.level_for_xp(0), 1)
	assert_eq(Progression.level_for_xp(99), 1, "just under Lv2 threshold")
	assert_eq(Progression.level_for_xp(100), 2, "exactly at Lv2 threshold")
	assert_eq(Progression.level_for_xp(382), 2, "just under Lv3 threshold")
	assert_eq(Progression.level_for_xp(383), 3)

func test_cap_behavior():
	assert_eq(Progression.xp_to_next(99), Progression.XP_SENTINEL, "no next level at cap")
	assert_eq(Progression.xp_to_next(120), Progression.XP_SENTINEL)
	# Even an enormous XP total cannot exceed the cap.
	assert_eq(Progression.level_for_xp(999_999_999), Progression.LEVEL_CAP)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_progression.gd`
Expected: FAIL (`Progression` undefined).

**Step 3: Write minimal implementation**

```gdscript
# scripts/battle/progression.gd
class_name Progression
extends RefCounted

## Pure XP/level math. `xp` is treated as LIFETIME TOTAL everywhere; `level` is
## always derivable from total xp via level_for_xp().

const BASE_XP: float = 100.0
const EXPONENT: float = 1.5
const LEVEL_CAP: int = 99
## Unreachable "distance to next level" returned at/after the cap so the curve
## stays pure and monotonic without special-casing callers.
const XP_SENTINEL: int = 1_000_000_000


## XP delta required to advance FROM `level` to `level + 1`.
static func xp_to_next(level: int) -> int:
	if level >= LEVEL_CAP:
		return XP_SENTINEL
	return int(round(BASE_XP * pow(float(level), EXPONENT)))


## Total XP required to REACH `level` from Lv 1 (Lv 1 -> 0).
static func cumulative_xp(level: int) -> int:
	var total: int = 0
	for l in range(1, level):
		total += xp_to_next(l)
	return total


## Level implied by a lifetime total XP, clamped to the cap.
static func level_for_xp(total_xp: int) -> int:
	var level: int = 1
	while level < LEVEL_CAP and total_xp >= cumulative_xp(level + 1):
		level += 1
	return level
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_progression.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does `level_for_xp` generalize past Lv 2/3?" — the loop is general; the cap guard prevents runaway. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/progression.gd tests/test_progression.gd
git commit -m "feat: pure Progression XP curve + level mapping (#141)"
```

---

### Task 2: Definition growth + xp_reward fields

**Files:**
- Modify: `scripts/battle/character_definition.gd`
- Modify: `scripts/battle/enemy_definition.gd`

**Depends on:** none
**Parallelizable with:** Task 1 (different files, no shared symbols)

This is a declaration-only change (no logic) — Non-Logic Task template.

**Step 1: Write the content**

```gdscript
# scripts/battle/character_definition.gd
class_name CharacterDefinition
extends CombatantDefinition

@export var ability: Ability = null

## Per-level stat growth. Effective stat = base + growth * (level - 1).
## The base values on CombatantDefinition are the Lv 1 stats.
@export var hp_growth: int = 0
@export var pp_growth: int = 0
@export var str_growth: int = 0
@export var def_growth: int = 0
@export var psy_growth: int = 0
@export var res_growth: int = 0
@export var spd_growth: int = 0
```

```gdscript
# scripts/battle/enemy_definition.gd
class_name EnemyDefinition
extends CombatantDefinition

@export var ai: EnemyAI = null
@export var summon: SummonEffect = null

## XP bounty awarded to survivors when this enemy is defeated.
@export var xp_reward: int = 0
```

**Step 2: Verify**

Open Godot editor (or run a headless import); confirm no parse errors:
`godot_console --headless --editor --quit 2>&1 | grep -i "SCRIPT ERROR" || echo "no script errors"`
Expected: "no script errors".

**Step 3: Commit**

```bash
git add scripts/battle/character_definition.gd scripts/battle/enemy_definition.gd
git commit -m "feat: add growth fields + enemy xp_reward to definitions (#141)"
```

---

### Task 3: Combatant level scaling, level-up heal, xp_reward, transient reset

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd` (append cases)

**Depends on:** Task 2 (needs growth + xp_reward fields)
**Parallelizable with:** Task 4 (different files: `combatant.gd` vs `.tres` data)

**Step 1: Write the failing GUT test** (append to `tests/test_combatant.gd`)

```gdscript
func _make_char_def() -> CharacterDefinition:
	var d := CharacterDefinition.new()
	d.id = "tester"
	d.character_name = "Tester"
	d.max_hp = 100
	d.max_pp = 20
	d.str_stat = 10
	d.def_stat = 8
	d.spd_stat = 6
	d.hp_growth = 15
	d.pp_growth = 2
	d.str_growth = 3
	d.def_growth = 2
	d.spd_growth = 1
	return d

func test_level1_stats_equal_base():
	var c := Combatant.from_definition(_make_char_def())
	assert_eq(c.level, 1)
	assert_eq(c.max_hp, 100)
	assert_eq(c.str_stat, 10)

func test_stats_scale_with_level():
	var c := Combatant.from_definition(_make_char_def())
	c.level = 3
	assert_eq(c.max_hp, 100 + 15 * 2)
	assert_eq(c.max_pp, 20 + 2 * 2)
	assert_eq(c.str_stat, 10 + 3 * 2)
	assert_eq(c.def_stat, 8 + 2 * 2)
	assert_eq(c.spd_stat, 6 + 1 * 2)

func test_enemy_stats_ignore_level():
	var e := EnemyDefinition.new()
	e.max_hp = 200
	e.str_stat = 45
	var c := Combatant.from_definition(e)
	c.level = 5  # enemies never level, but prove the getter is safe
	assert_eq(c.max_hp, 200)
	assert_eq(c.str_stat, 45)

func test_apply_level_recomputes_max_and_full_heals():
	var c := Combatant.from_definition(_make_char_def())
	c.current_hp = 10
	c.current_pp = 1
	c.apply_level(3)
	assert_eq(c.level, 3)
	assert_eq(c.max_hp, 130)
	assert_eq(c.current_hp, 130, "level-up = full heal")
	assert_eq(c.current_pp, c.max_pp)

func test_xp_reward_from_enemy_def():
	var e := EnemyDefinition.new()
	e.xp_reward = 18
	assert_eq(Combatant.from_definition(e).xp_reward, 18)

func test_xp_reward_zero_for_character():
	assert_eq(Combatant.from_definition(_make_char_def()).xp_reward, 0)

func test_reset_battle_transient_preserves_hp_pp():
	var c := Combatant.from_definition(_make_char_def())
	c.current_hp = 42
	c.current_pp = 5
	c.atb = 80.0
	c.limit_gauge = 50.0
	c.apply_effect(StatusEffect.new())
	c.reset_battle_transient()
	assert_eq(c.current_hp, 42, "HP carries across battles (attrition)")
	assert_eq(c.current_pp, 5)
	assert_eq(c.atb, 0.0)
	assert_eq(c.limit_gauge, 0.0)
	assert_eq(c.active_effects.size(), 0)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: FAIL (`level`/`apply_level`/`xp_reward`/`reset_battle_transient` undefined).

**Step 3: Write minimal implementation** (edits within `scripts/battle/combatant.gd`)

Add the `level` field near the other runtime state (after `var ai_state`):

```gdscript
var level: int = 1
```

Replace the stat-delegating properties block (`max_hp` … `spd_stat`) with level-scaled getters, and add the `_grow` helper + `xp_reward`:

```gdscript
# CharacterDefinitions scale per level; enemies (EnemyDefinition) never level.
func _grow(base_value: int, growth: int) -> int:
	return base_value + growth * (level - 1)

var max_hp: int:
	get: return _grow(def.max_hp, (def as CharacterDefinition).hp_growth) if def is CharacterDefinition else def.max_hp

var max_pp: int:
	get: return _grow(def.max_pp, (def as CharacterDefinition).pp_growth) if def is CharacterDefinition else def.max_pp

var str_stat: int:
	get: return _grow(def.str_stat, (def as CharacterDefinition).str_growth) if def is CharacterDefinition else def.str_stat

var def_stat: int:
	get: return _grow(def.def_stat, (def as CharacterDefinition).def_growth) if def is CharacterDefinition else def.def_stat

var psy_stat: int:
	get: return _grow(def.psy_stat, (def as CharacterDefinition).psy_growth) if def is CharacterDefinition else def.psy_stat

var res_stat: int:
	get: return _grow(def.res_stat, (def as CharacterDefinition).res_growth) if def is CharacterDefinition else def.res_stat

var spd_stat: int:
	get: return _grow(def.spd_stat, (def as CharacterDefinition).spd_growth) if def is CharacterDefinition else def.spd_stat

var xp_reward: int:
	get: return (def as EnemyDefinition).xp_reward if def is EnemyDefinition else 0
```

Add the level-up and transient-reset methods (near `reset_runtime_state`):

```gdscript
## Set a new level and recompute derived maxima with a full heal (R6).
func apply_level(new_level: int) -> void:
	level = new_level
	current_hp = max_hp
	current_pp = max_pp


## Clear per-battle transient state but PRESERVE current HP/PP so damage carries
## across fights within a room (R7 attrition). Call on each battle entry.
func reset_battle_transient() -> void:
	atb = 0.0
	limit_gauge = 0.0
	skip_cooldown = 0.0
	active_effects = []
	ai_state = {}
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does scaling break when `level > 1` for stacked status effects?" — `get_effective_stat` reads the scaled getters then layers modifiers, so level scaling composes correctly. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: level-scaled Combatant stats, apply_level full-heal, transient reset (#141)"
```

---

### Task 4: Tune growth + xp_reward values in .tres

**Files:**
- Modify: `characters/reid.tres`, `characters/iris.tres`, `characters/karim.tres`, `characters/margot.tres`
- Modify: `characters/enemies/shade.tres`, `characters/enemies/private_security_guard.tres`, `characters/enemies/territory_enforcer.tres`, `characters/enemies/block_captain.tres`

**Depends on:** Task 2 (fields must exist or Godot warns on unknown property)
**Parallelizable with:** Task 3 (different files)

Non-Logic Task template (data edits).

**Step 1: Write the content**

Append these growth lines to the `[resource]` block of **each** character `.tres` (placeholder, tunable; identical across all four — growth does NOT affect the level-up-beat timing, only stat feel):

```
hp_growth = 15
pp_growth = 2
str_growth = 2
def_growth = 2
psy_growth = 2
res_growth = 2
spd_growth = 2
```

Add `xp_reward` to the `[resource]` block of each enemy `.tres` (values from R4):
- `characters/enemies/shade.tres` → `xp_reward = 18`
- `characters/enemies/private_security_guard.tres` → `xp_reward = 22`
- `characters/enemies/territory_enforcer.tres` → `xp_reward = 60`
- `characters/enemies/block_captain.tres` → `xp_reward = 45`

(`security_captain.tres` is unused by the harness; leave it at the field default `0` — no edit.)

**Step 2: Verify**

```bash
godot_console --headless --editor --quit 2>&1 | grep -iE "error|unknown property" || echo "clean import"
```
Expected: "clean import" (no "unknown property" warnings). Spot-check by opening `reid.tres` in the editor inspector and confirming the growth fields are present and set.

**Step 3: Commit**

```bash
git add characters/*.tres characters/enemies/*.tres
git commit -m "feat: tune per-character growth + enemy xp_reward values (#141)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2 | Different files (`progression.gd` vs `*_definition.gd`), no shared symbols |
| B (parallel) | Task 3, Task 4 | Both depend on Task 2; different files (`combatant.gd`+test vs `.tres` data) |

### Smoketest Checkpoint 1 — progression math + scaling exist, no regressions

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures (new `test_progression.gd` + appended `test_combatant.gd` green; **all pre-existing tests still pass** — this batch changed `combatant.gd` stat getters, so watch `test_battle_scene*`, `test_combatant`, `test_target_resolution`).

**Step 3: Launch game and verify visually**
```powershell
Start-Process godot_console
```
(Or use the `/run` skill.)

**Step 4: Confirm with user**
Ask the user to launch the existing game (Rooftop) and confirm it still plays normally — characters at Lv 1 should have unchanged stats (growth only applies at Lv ≥ 2), enemies unchanged. Wait for confirmation before Batch 2.

---

## Batch 2 — Progression store & XP award

### Task 5: PartyManager progression store + GameData helper

**Files:**
- Modify: `scripts/autoload/party_manager.gd`
- Modify: `scripts/autoload/game_data.gd` (add `all_character_definitions`)
- Test: `tests/test_party_manager.gd` (append), `tests/test_game_data.gd` (append)

**Depends on:** Task 1 (Progression), Task 3 (Combatant.level / apply_level)
**Parallelizable with:** none — Task 6 edits the same `party_manager.gd` and depends on this store.

**Step 1: Write the failing GUT test** (append to `tests/test_party_manager.gd`)

```gdscript
func before_each():
	PartyManager.reset_new_game()

func test_progression_seeded_for_all_known_characters():
	for id in ["reid", "iris", "karim", "margot"]:
		assert_eq(PartyManager.get_level(id), 1, "%s seeded Lv1" % id)
		assert_eq(PartyManager.get_xp(id), 0)

func test_default_roster_is_reid_only():
	var roster := PartyManager.snapshot_roster()
	assert_eq(roster, ["reid"])

func test_snapshot_progression_is_a_deep_copy():
	var snap := PartyManager.snapshot_progression()
	snap["reid"]["level"] = 50
	assert_eq(PartyManager.get_level("reid"), 1, "snapshot must not alias the store")
```

Append to `tests/test_game_data.gd`:

```gdscript
func test_all_character_definitions_excludes_enemies():
	var chars := GameData.all_character_definitions()
	var ids := chars.map(func(d): return d.id)
	assert_has(ids, "reid")
	assert_does_not_have(ids, "shade")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd`
Expected: FAIL (`get_level`/`reset_new_game`/`snapshot_roster` undefined).

**Step 3: Write minimal implementation**

Add to `scripts/autoload/game_data.gd`:

```gdscript
func all_character_definitions() -> Array[CharacterDefinition]:
	var result: Array[CharacterDefinition] = []
	for d: CombatantDefinition in _registry.values():
		if d is CharacterDefinition:
			result.append(d)
	return result
```

Replace `scripts/autoload/party_manager.gd` entirely:

```gdscript
extends Node

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []
## id -> {"level": int, "xp": int}. xp is lifetime total.
var _progression: Dictionary = {}


func _ready() -> void:
	reset_new_game()


# --- New game / seeding ---

func reset_new_game() -> void:
	_seed_progression()
	_permanent_members.clear()
	_temporary_members.clear()
	_add_permanent_by_id("reid")


func _seed_progression() -> void:
	_progression.clear()
	for d: CharacterDefinition in GameData.all_character_definitions():
		_progression[d.id] = {"level": 1, "xp": 0}


func _add_permanent_by_id(id: String) -> void:
	var c := Combatant.from_definition(GameData.get_definition(id))
	c.level = get_level(id)
	c.reset_runtime_state()  # current HP/PP at the level-scaled max
	_permanent_members.append(c)


# --- Roster ---

func add_member(combatant: Combatant) -> void:
	_permanent_members.append(combatant)

func add_temporary(combatant: Combatant) -> void:
	_temporary_members.append(combatant)

func remove_temporary_members() -> void:
	_temporary_members.clear()

func get_active_members() -> Array[Combatant]:
	var result: Array[Combatant] = []
	result.append_array(_permanent_members)
	result.append_array(_temporary_members)
	return result

func has_member(character_name: String) -> bool:
	for member in get_active_members():
		if member.character_name == character_name:
			return true
	return false


# --- Progression queries ---

func get_level(id: String) -> int:
	return _progression[id]["level"] if _progression.has(id) else 1

func get_xp(id: String) -> int:
	return _progression[id]["xp"] if _progression.has(id) else 0


# --- Persistence snapshot/restore ---

func snapshot_roster() -> Array:
	var ids: Array = []
	for m: Combatant in _permanent_members:
		ids.append(m.id)
	return ids

func snapshot_progression() -> Dictionary:
	return _progression.duplicate(true)

## Restore from a save. Always re-seeds defaults first so unknown/legacy ids
## fall back to Lv1; an empty roster (legacy v1) defaults to Reid only (R16).
func restore(progression: Dictionary, roster: Array) -> void:
	_seed_progression()
	for id: String in progression:
		if _progression.has(id):
			_progression[id] = (progression[id] as Dictionary).duplicate(true)
	_permanent_members.clear()
	_temporary_members.clear()
	var ids: Array = roster if not roster.is_empty() else ["reid"]
	for id: String in ids:
		_add_permanent_by_id(id)
```

> Note: `RoomPOC` still calls `add_member(Combatant)` — that path is unchanged. `_ready` now routes through `reset_new_game()` instead of directly appending Reid.

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd -gtest=res://tests/test_game_data.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does seeding break if a character `.tres` is added later?" — `_seed_progression` iterates `GameData.all_character_definitions()` dynamically, so new characters seed automatically. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/party_manager.gd scripts/autoload/game_data.gd tests/test_party_manager.gd tests/test_game_data.gd
git commit -m "feat: PartyManager progression store + GameData character helper (#141)"
```

---

### Task 6: PartyManager.award_xp + join_member

**Files:**
- Modify: `scripts/autoload/party_manager.gd`
- Test: `tests/test_party_manager.gd` (append)

**Depends on:** Task 5 (same file, uses the store)
**Parallelizable with:** none — same file as Task 5; must run after it.

**Step 1: Write the failing GUT test** (append)

```gdscript
func _living_reid() -> Combatant:
	# get_active_members()[0] is the seeded Reid Combatant
	return PartyManager.get_active_members()[0]

func test_award_single_member_below_threshold_stays_lv1():
	var reid := _living_reid()
	var result := PartyManager.award_xp(80, [reid])
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(result["xp_gained"], 80)
	assert_eq(result["level_ups"].size(), 0)
	assert_eq(reid.level, 1)

func test_award_crossing_one_threshold_levels_and_heals():
	var reid := _living_reid()
	reid.current_hp = 1
	var result := PartyManager.award_xp(100, [reid])
	assert_eq(PartyManager.get_level("reid"), 2)
	assert_eq(reid.level, 2, "live combatant synced")
	assert_eq(reid.current_hp, reid.max_hp, "level-up full heal")
	assert_eq(result["level_ups"].size(), 1)
	assert_eq(result["level_ups"][0]["name"], "Reid")
	assert_eq(result["level_ups"][0]["level"], 2)

func test_award_crossing_multiple_thresholds_carries_remainder():
	var reid := _living_reid()
	# 100 (Lv2) + 283 (Lv3) = 383 to reach Lv3; give 400 -> Lv3 with 17 over.
	PartyManager.award_xp(400, [reid])
	assert_eq(PartyManager.get_level("reid"), 3)
	assert_eq(PartyManager.get_xp("reid"), 400, "xp is lifetime total, not reset")

func test_award_only_living_members_listed_get_xp():
	# Caller passes survivors only; a member NOT in the list is untouched.
	PartyManager.join_member("iris", 1)
	var reid := _living_reid()
	PartyManager.award_xp(100, [reid])  # iris excluded (simulating downed)
	assert_eq(PartyManager.get_level("reid"), 2)
	assert_eq(PartyManager.get_level("iris"), 1, "excluded member gains nothing")

func test_join_member_level_matched_and_seeded_xp():
	var reid := _living_reid()
	PartyManager.award_xp(100, [reid])  # Reid -> Lv2
	PartyManager.join_member("iris", PartyManager.get_level("reid"))
	assert_eq(PartyManager.get_level("iris"), 2)
	assert_eq(PartyManager.get_xp("iris"), Progression.cumulative_xp(2))
	assert_true(PartyManager.has_member("Iris"))

func test_join_member_idempotent():
	PartyManager.join_member("iris", 1)
	PartyManager.join_member("iris", 1)
	var iris_count := PartyManager.get_active_members().filter(
		func(m): return m.id == "iris").size()
	assert_eq(iris_count, 1)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd`
Expected: FAIL (`award_xp`/`join_member` undefined).

**Step 3: Write minimal implementation** (append to `party_manager.gd`)

```gdscript
# --- XP award ---

## Award `total` XP to every member in `living` (caller passes survivors only,
## R5). Mutates the store AND each live Combatant (level + full-heal on level-up,
## R6). Returns {"xp_gained": int, "level_ups": [{"name": String, "level": int}]}.
func award_xp(total: int, living: Array[Combatant]) -> Dictionary:
	var level_ups: Array = []
	for m: Combatant in living:
		if not _progression.has(m.id):
			_progression[m.id] = {"level": 1, "xp": 0}
		var rec: Dictionary = _progression[m.id]
		var old_level: int = rec["level"]
		rec["xp"] += total
		rec["level"] = Progression.level_for_xp(rec["xp"])
		if rec["level"] >= Progression.LEVEL_CAP:
			rec["xp"] = mini(rec["xp"], Progression.cumulative_xp(Progression.LEVEL_CAP))
		if rec["level"] > old_level:
			m.apply_level(rec["level"])  # sets level + full heal
			level_ups.append({"name": m.character_name, "level": rec["level"]})
		else:
			m.level = rec["level"]
	return {"xp_gained": total, "level_ups": level_ups}


## Add a permanent member at a matched level, xp seeded to that level's
## cumulative threshold (R11). No-op if already rostered.
func join_member(id: String, level: int) -> void:
	_progression[id] = {"level": level, "xp": Progression.cumulative_xp(level)}
	if has_member(GameData.get_definition(id).character_name):
		return
	_add_permanent_by_id(id)
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does the multi-threshold loop live in one place?" — yes, `Progression.level_for_xp` owns the crossing logic; `award_xp` just diffs old/new level. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/party_manager.gd tests/test_party_manager.gd
git commit -m "feat: PartyManager.award_xp (survivors-only, multi-level) + join_member (#141)"
```

---

### Task 7: BattleScene victory XP award + readout + per-battle reset

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd` (append)

**Depends on:** Task 6 (award_xp), Task 3 (xp_reward, reset_battle_transient)
**Parallelizable with:** none — depends on Task 6's award_xp.

**Step 1: Write the failing GUT test** (append to `tests/test_battle_scene.gd`)

```gdscript
func test_victory_text_no_levelup():
	var result := {"xp_gained": 40, "level_ups": []}
	assert_eq(BattleScene.victory_text(result), "Victory!\nGained 40 XP")

func test_victory_text_with_levelup():
	var result := {"xp_gained": 100, "level_ups": [{"name": "Reid", "level": 2}]}
	assert_eq(BattleScene.victory_text(result),
		"Victory!\nGained 100 XP\nReid reached Lv 2!")

func test_collect_defeated_bounty():
	var shade := Combatant.from_definition(GameData.get_definition("shade"))
	var guard := Combatant.from_definition(GameData.get_definition("private_security_guard"))
	shade.current_hp = 0   # defeated
	guard.current_hp = 5   # survived (won't happen on victory, but proves the filter)
	assert_eq(BattleScene.collect_defeated_bounty([shade, guard]), 18)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd`
Expected: FAIL (`victory_text`/`collect_defeated_bounty` undefined).

**Step 3: Write minimal implementation** (edits in `scripts/battle/battle_scene.gd`)

Add two pure static helpers (near `resolve_recipients`):

```gdscript
# Sum xp_reward of defeated enemies (R5).
static func collect_defeated_bounty(enemy_list: Array[Combatant]) -> int:
	var total: int = 0
	for e: Combatant in enemy_list:
		if e.is_dead():
			total += e.xp_reward
	return total


# Build the post-victory readout from award_xp's result struct (R14).
static func victory_text(result: Dictionary) -> String:
	var lines: Array[String] = ["Victory!", "Gained %d XP" % result["xp_gained"]]
	for lu in result["level_ups"]:
		lines.append("%s reached Lv %d!" % [lu["name"], lu["level"]])
	return "\n".join(lines)
```

In `_ready()`, after `party = PartyManager.get_active_members()`, add the per-battle transient reset (preserves carried HP/PP, R7):

```gdscript
	party = PartyManager.get_active_members()
	for m: Combatant in party:
		m.reset_battle_transient()
```

In `_on_battle_ended(victory)`, replace the `if victory:` branch head so XP is awarded and the label shows the readout:

```gdscript
func _on_battle_ended(victory: bool) -> void:
	_action_menu.hide()
	if victory:
		var bounty := collect_defeated_bounty(enemies)
		var survivors: Array[Combatant] = party.filter(
			func(p: Combatant) -> bool: return p.is_alive())
		var result := PartyManager.award_xp(bounty, survivors)
		_victory_label.text = victory_text(result)
		PartyManager.remove_temporary_members()
		_victory_label.show()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		if is_inside_tree():
			var target := BattleContext.return_scene if BattleContext.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target, BattleContext.return_spawn)
	else:
		_defeat_label.show()
		_defeat_menu.show()
```

> The `enemies` array is typed `Array[Combatant]`, so it satisfies `collect_defeated_bounty`'s signature directly.

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Is the award logic testable without a live scene?" — the pure helpers (`collect_defeated_bounty`, `victory_text`) are unit-tested; the wiring is verified in the smoketest. Proceed.

**Step 6: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: award XP + show readout + carry HP/PP on battle victory (#141)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 5 → Task 6 | Same file (`party_manager.gd`); Task 6 uses Task 5's store |
| B (sequential) | Task 7 | Depends on Task 6 (award_xp) and Task 3 |

### Smoketest Checkpoint 2 — winning a battle awards XP with a readout

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All pass. PartyManager `_ready` now seeds via `reset_new_game()` and `battle_scene.gd` resets transient state — watch `test_party_manager`, `test_battle_scene*`, `test_skip_turn`, `test_summon_effect` for fallout.

**Step 3: Launch game and verify visually**
```powershell
Start-Process godot_console
```
(Or `/run`.) Open `scenes/battle/BattleScene.tscn` directly so it spawns the default Shade fight.

**Step 4: Confirm with user**
Ask the user to win the battle and confirm the VictoryLabel reads **"Victory! / Gained 18 XP"** (and, if they win enough across repeated launches, a "Reid reached Lv 2!" line). Confirm HP carries (no auto-heal) if they re-enter a fight via the world flow. Wait for confirmation before Batch 3.

---

## Batch 3 — Persistence (absorbs #123 core)

### Task 8: SaveData v2 fields

**Files:**
- Modify: `scripts/save/save_data.gd`
- Test: `tests/test_save_data.gd` (append)

**Depends on:** none (additive fields)
**Parallelizable with:** none — Task 9 depends on these fields; no other concurrent task touches save.

**Step 1: Write the failing GUT test** (append to `tests/test_save_data.gd`)

```gdscript
func test_save_data_has_party_runtime_fields():
	var d := SaveData.new()
	assert_eq(d.roster, [])
	assert_eq(d.progression, {})

func test_save_data_roster_and_progression_assignable():
	var d := SaveData.new()
	d.roster = ["reid", "iris"]
	d.progression = {"reid": {"level": 2, "xp": 150}}
	assert_eq(d.roster.size(), 2)
	assert_eq(d.progression["reid"]["level"], 2)
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: FAIL (`roster`/`progression` undefined).

**Step 3: Write minimal implementation**

```gdscript
# scripts/save/save_data.gd
class_name SaveData
extends Resource

## Versioned save container. v2 adds the party-runtime block (#141 / #123 core).

@export var save_version: int = 1
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""
## Active permanent-member ids (the roster). Empty on a legacy v1 save.
@export var roster: Array[String] = []
## Per-character progression: id -> {"level": int, "xp": int} for all known chars.
@export var progression: Dictionary = {}
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Do the defaults make a v1 load safe?" — `roster=[]` / `progression={}` are exactly the legacy-migration sentinels `PartyManager.restore` keys off. Proceed.

**Step 6: Commit**

```bash
git add scripts/save/save_data.gd tests/test_save_data.gd
git commit -m "feat: SaveData v2 roster + progression block (#141)"
```

---

### Task 9: SaveManager snapshot/restore/migration + version bump

**Files:**
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_save_manager.gd` (append)

**Depends on:** Task 8 (SaveData fields), Task 5/6 (PartyManager snapshot/restore/reset)
**Parallelizable with:** none — depends on Task 8 in the same batch.

**Step 1: Write the failing GUT test** (append to `tests/test_save_manager.gd`)

```gdscript
func before_each():
	PartyManager.reset_new_game()

func test_save_captures_roster_and_progression():
	var reid := PartyManager.get_active_members()[0]
	PartyManager.award_xp(100, [reid])  # Reid -> Lv2
	SaveManager.save(9, "res://scenes/world/Rooftop.tscn", "")
	var data := SaveManager.read(9)
	assert_eq(data.save_version, 2)
	assert_eq(data.roster, ["reid"])
	assert_eq(data.progression["reid"]["level"], 2)

func test_load_roundtrips_progression_for_party_and_nonparty():
	var reid := PartyManager.get_active_members()[0]
	PartyManager.award_xp(100, [reid])
	PartyManager.join_member("iris", 2)
	SaveManager.save(9)
	PartyManager.reset_new_game()  # wipe to defaults
	assert_eq(PartyManager.get_level("reid"), 1)
	var data := SaveManager.read(9)
	SaveManager.apply(data, false)  # no navigation in tests
	assert_eq(PartyManager.get_level("reid"), 2, "party member restored")
	assert_eq(PartyManager.get_level("iris"), 2, "roster restored with iris")
	assert_true(PartyManager.has_member("Iris"))

func test_load_resets_hp_to_max():
	var reid := PartyManager.get_active_members()[0]
	reid.current_hp = 1
	SaveManager.save(9)
	SaveManager.apply(SaveManager.read(9), false)
	var restored := PartyManager.get_active_members()[0]
	assert_eq(restored.current_hp, restored.max_hp, "HP/PP back to full on load")

func test_v1_save_migrates_to_reid_lv1():
	var legacy := SaveData.new()
	legacy.save_version = 1
	legacy.flags = {}
	legacy.roster = []        # legacy: no roster
	legacy.progression = {}   # legacy: no progression
	SaveManager.apply(legacy, false)
	assert_eq(PartyManager.snapshot_roster(), ["reid"])
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_level("iris"), 1)

func after_all():
	# Clean up the test slot file.
	if FileAccess.file_exists("user://hollow_men_save_9.tres"):
		DirAccess.remove_absolute("user://hollow_men_save_9.tres")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd`
Expected: FAIL (`save_version` is 1, restore not wired).

**Step 3: Write minimal implementation** (edits in `scripts/autoload/save_manager.gd`)

Bump the version:

```gdscript
const CURRENT_VERSION: int = 2
```

In `save()`, after setting `spawn_point`, capture the party-runtime block:

```gdscript
	data.roster.assign(PartyManager.snapshot_roster())
	data.progression = PartyManager.snapshot_progression()
```

In `apply()`, restore the party block before navigation:

```gdscript
func apply(data: SaveData, navigate: bool = true) -> void:
	GameState.restore_flags(data.flags)
	PartyManager.restore(data.progression, data.roster)
	if navigate:
		SceneManager.change_scene(data.current_scene, data.spawn_point)
```

In `new_game()`, reset the party store alongside flags:

```gdscript
func new_game(navigate: bool = true) -> void:
	GameState.clear_flags()
	PartyManager.reset_new_game()
	game_loaded.emit(-1)
	if navigate:
		SceneManager.change_scene(STARTING_SCENE, STARTING_SPAWN)
```

> Migration is automatic: a v1 `.tres` deserializes into a `SaveData` whose new fields default to `[]`/`{}`, and `PartyManager.restore` treats those as the Lv1/Reid-only defaults (R16). No version-branch code needed.

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Is HP/PP reset-to-max on load handled?" — `restore` rebuilds members via `_add_permanent_by_id`, which calls `reset_runtime_state()` (full HP/PP at level-scaled max). Out-of-scope live-HP saving is correctly omitted. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd
git commit -m "feat: persist roster + progression, bump save_version to 2, v1 migration (#141)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 8 → Task 9 | Task 9 depends on Task 8's SaveData fields (and PartyManager from Batch 2) |

### Smoketest Checkpoint 3 — progression survives save/load

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All pass (watch `test_save_manager`, `test_save_data`).

**Step 3: Launch game and verify visually**
```powershell
Start-Process godot_console
```
(Or `/run`.)

**Step 4: Confirm with user**
Ask the user to: win a fight to gain XP → press the debug **save** hotkey (`debug_save`, see `scripts/autoload/debug_overlay.gd`) → press debug **new game** (resets to Lv1) → press debug **load** → confirm the console prints show the save/load succeeded and progression returns (optionally extend the debug print to show `PartyManager.get_level("reid")`). Wait for confirmation before Batch 4.

---

## Batch 4 — Step encounters & harness room (random fights only)

### Task 10: Player `stepped` signal

**Files:**
- Modify: `scripts/world/player.gd`
- Test: `tests/test_player.gd` (append)

**Depends on:** none
**Parallelizable with:** Task 11 (different files)

**Step 1: Write the failing GUT test** (append to `tests/test_player.gd`)

```gdscript
func test_stepped_emitted_on_successful_move():
	# Reuse the test's existing world-layer fixture pattern; see other tests here
	# for how Player + a TileMapLayer are constructed.
	var player: Player = autofree(Player.new())
	var layer := _make_open_layer()  # helper used by existing movement tests
	add_child_autofree(player)
	player.setup(layer)
	watch_signals(player)
	player._try_move("move_right")
	assert_signal_emitted(player, "stepped")

func test_stepped_not_emitted_into_wall():
	var player: Player = autofree(Player.new())
	var layer := _make_walled_layer()  # all-wall fixture
	add_child_autofree(player)
	player.setup(layer)
	watch_signals(player)
	player._try_move("move_right")
	assert_signal_not_emitted(player, "stepped")
```

> If `tests/test_player.gd` lacks `_make_open_layer`/`_make_walled_layer` helpers, model the fixtures on the existing movement tests in that file (it already constructs a `TileMapLayer` for `_try_move`). Reuse whatever the file already does — do not invent a new fixture style.

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd`
Expected: FAIL (no `stepped` signal).

**Step 3: Write minimal implementation** (edits in `scripts/world/player.gd`)

Add the signal at the top (after `extends`):

```gdscript
signal stepped  ## Emitted once per successful grid move (drives step encounters).
```

In `_try_move`, emit right after the move is committed (after the wall/blocked guard, when `_moving` is set):

```gdscript
	_moving = true
	stepped.emit()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	tween.tween_callback(func() -> void: _moving = false)
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does `stepped` fire on blocked moves?" — no; it is emitted only after the wall/`CellRegistry` guard passes. Proceed.

**Step 6: Commit**

```bash
git add scripts/world/player.gd tests/test_player.gd
git commit -m "feat: Player.stepped signal on successful grid move (#141)"
```

---

### Task 11: ExperienceTestRoom script — random encounter loop

**Files:**
- Create: `scripts/world/experience_test_room.gd`
- Test: `tests/test_experience_test_room.gd`

**Depends on:** Task 5/6 (PartyManager join/store referenced by later boss code; the random-loop code uses only constants + BattleContext)
**Parallelizable with:** Task 10 (different files)

> This task adds the script with the random-encounter loop and the pure `roll_comp` helper. The boss-gating methods are added in Task 13/14. The scene wiring is Task 12.

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_experience_test_room.gd
extends GutTest

func test_roll_comp_size_is_two():
	for _i in 30:
		assert_eq(ExperienceTestRoom.roll_comp().size(), 2)

func test_roll_comp_only_draws_from_pool():
	for _i in 50:
		for id in ExperienceTestRoom.roll_comp():
			assert_true(id in ExperienceTestRoom.RANDOM_POOL,
				"%s must come from the pool" % id)

func test_roll_comp_can_produce_both_enemies():
	# Over many rolls, both pool members should appear at least once.
	seed(12345)
	var seen := {}
	for _i in 100:
		for id in ExperienceTestRoom.roll_comp():
			seen[id] = true
	assert_eq(seen.size(), ExperienceTestRoom.RANDOM_POOL.size(),
		"all pool members reachable")

func test_per_fight_xp_band_guarantees_levelup_beat():
	# R10 invariant: 2 * max_bounty < Lv1->2 threshold <= 3 * min_bounty.
	var shade: int = GameData.get_definition("shade").xp_reward
	var guard: int = GameData.get_definition("private_security_guard").xp_reward
	var min_b: int = mini(shade, guard)
	var max_b: int = maxi(shade, guard)
	var threshold: int = Progression.xp_to_next(1)
	assert_true(2 * (2 * max_b) < threshold,
		"after 2 fights still Lv1 (2*%d*2 < %d)" % [max_b, threshold])
	assert_true(threshold <= 3 * (2 * min_b),
		"by 3 fights reaches Lv2 (%d <= 3*%d*2)" % [threshold, min_b])
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_experience_test_room.gd`
Expected: FAIL (`ExperienceTestRoom` undefined).

**Step 3: Write minimal implementation**

```gdscript
# scripts/world/experience_test_room.gd
class_name ExperienceTestRoom
extends BaseRoom

## Walkable harness: step-based random encounters (2 enemies from the pool),
## a 3-win boss gate, then a level-matched Iris join for the Enforcer fight.

const RANDOM_POOL: Array[String] = ["shade", "private_security_guard"]
const GRACE_STEPS: int = 4          # tunable: steps before encounters can start
const ENCOUNTER_CHANCE: float = 0.25  # tunable: per-step trigger probability
const FIGHTS_BEFORE_BOSS: int = 3
const BOSS_ENEMY: String = "territory_enforcer"
const BATTLE_SCENE: String = "res://scenes/battle/BattleScene.tscn"

var _steps_since_battle: int = 0


func _ready() -> void:
	super._ready()
	$Player.stepped.connect(_on_player_stepped)
	_reconcile_pending()


## Pure: 2 picks with replacement from the pool (R9).
static func roll_comp() -> Array[String]:
	var out: Array[String] = []
	for _i in 2:
		out.append(RANDOM_POOL[randi() % RANDOM_POOL.size()])
	return out


func _on_player_stepped() -> void:
	if GameState.get_flag("test_room_complete", false):
		return
	_steps_since_battle += 1
	if _steps_since_battle <= GRACE_STEPS:
		return
	if randf() < ENCOUNTER_CHANCE:
		_start_random_battle()


func _start_random_battle() -> void:
	GameState.set_flag("test_room_pending", "random")
	BattleContext.configure(",".join(roll_comp()), battle_background,
		scene_file_path, "default")
	SceneManager.change_scene(BATTLE_SCENE)


## On (re)entry, reconcile a battle we just returned from. Returning here only
## happens on victory (defeat routes to the defeat menu), so a pending tag means
## a win. Boss reconciliation is added in Task 14.
func _reconcile_pending() -> void:
	var pending: String = str(GameState.get_flag("test_room_pending", ""))
	if pending == "":
		return
	GameState.set_flag("test_room_pending", "")
	_steps_since_battle = 0
	if pending == "random":
		var wins: int = int(GameState.get_flag("test_room_random_wins", 0)) + 1
		GameState.set_flag("test_room_random_wins", wins)
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_experience_test_room.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Is the level-up beat protected against retuning?" — yes, `test_per_fight_xp_band_guarantees_levelup_beat` asserts the `2*max < threshold ≤ 3*min` invariant, so changing bounties or the curve fails loudly. Proceed.

**Step 6: Commit**

```bash
git add scripts/world/experience_test_room.gd tests/test_experience_test_room.gd
git commit -m "feat: ExperienceTestRoom random-encounter loop + roll_comp + XP-band guard (#141)"
```

---

### Task 12: ExperienceTestRoom scene

**Files:**
- Create: `scenes/world/ExperienceTestRoom.tscn`

**Depends on:** Task 11 (script must exist), Task 10 (Player.stepped signal)
**Parallelizable with:** none — the scene wires Task 11's script and Task 10's signal; both must exist first.

Non-Logic Task template (scene authoring).

**Step 1: Write the content**

Build the scene by copying the structure of `scenes/world/RoomPOC.tscn` (it already instances `BaseRoom.tscn`, a Tiled map, a `SpawnPoint`, and a light). Concretely:

- Root node `ExperienceTestRoom` = instance of `res://scenes/world/BaseRoom.tscn`, with `script = res://scripts/world/experience_test_room.gd`.
- Set root exported properties:
  - `world_layer_path = NodePath("room_poc/World")`
  - `battle_background = "alley"`
  - `default_spawn = "default"`
  - `ambient_color = Color(0.08, 0.08, 0.12, 1)`
- Reuse the placeholder map: instance `res://maps/room_poc.tmx` as a child named `room_poc` (same as RoomPOC) so no new Tiled asset is needed.
- Add a child `SpawnPoint` instance (`res://scenes/world/SpawnPoint.tscn`) named `DefaultSpawn`, `spawn_id = "default"`, positioned on an open floor tile (mirror RoomPOC's `Vector2(120, 88)`).

(The boss-trigger `Area2D` node is added in Task 14 — leave it out here so this batch is independently smoke-testable as a pure random-encounter loop.)

**Step 2: Verify**

Launch the room directly:
```powershell
Start-Process godot_console -ArgumentList "res://scenes/world/ExperienceTestRoom.tscn"
```
(Or use `/run` and point it at the room.) Confirm the room loads, the player spawns on the floor, and walking is possible. No script errors in the console.

**Step 3: Commit**

```bash
git add scenes/world/ExperienceTestRoom.tscn
git commit -m "feat: ExperienceTestRoom scene (walkable harness, random encounters) (#141)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 10, Task 11 | Different files (`player.gd` vs `experience_test_room.gd`), no shared symbols |
| B (sequential) | Task 12 | Depends on Tasks 10 + 11 (wires the signal + script into a scene) |

### Smoketest Checkpoint 4 — walking triggers random 2-enemy fights

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All pass (watch `test_player`, `test_experience_test_room`).

**Step 3: Launch the harness room directly**
```powershell
Start-Process godot_console -ArgumentList "res://scenes/world/ExperienceTestRoom.tscn"
```
(Or `/run` the room scene.)

**Step 4: Confirm with user**
Ask the user to walk around: after the grace steps, random encounters should fire with **exactly 2 enemies** drawn from {Shade, Private Security Guard}; winning returns to the room with HP carried and XP gained. Ask them to confirm encounters vary in composition. (Boss is not wired yet — that's Batch 5.) Wait for confirmation before Batch 5.

---

## Batch 5 — Boss gating & Iris join

### Task 13: Boss reconciliation + completion flag (room script)

**Files:**
- Modify: `scripts/world/experience_test_room.gd`
- Test: `tests/test_experience_test_room.gd` (append)

**Depends on:** Task 11 (room script), Task 6 (join_member)
**Parallelizable with:** none — same file as Task 14, which wires the scene.

> The reconcile + boss-trigger logic is extracted into pure-ish helpers so it can be unit-tested against `GameState` without a live scene.

**Step 1: Write the failing GUT test** (append)

```gdscript
func before_each():
	GameState.clear_flags()
	PartyManager.reset_new_game()

func test_boss_unlocks_only_after_three_wins():
	GameState.set_flag("test_room_random_wins", 2)
	assert_false(ExperienceTestRoom.boss_unlocked(), "2 wins: locked")
	GameState.set_flag("test_room_random_wins", 3)
	assert_true(ExperienceTestRoom.boss_unlocked(), "3 wins: unlocked")

func test_boss_locked_when_complete():
	GameState.set_flag("test_room_random_wins", 3)
	GameState.set_flag("test_room_complete", true)
	assert_false(ExperienceTestRoom.boss_unlocked(),
		"harness complete: boss must not re-trigger")

func test_reconcile_boss_sets_complete():
	GameState.set_flag("test_room_pending", "boss")
	ExperienceTestRoom.reconcile_flags()
	assert_true(GameState.get_flag("test_room_complete", false))
	assert_eq(str(GameState.get_flag("test_room_pending", "")), "")
```

**Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_experience_test_room.gd`
Expected: FAIL (`boss_unlocked`/`reconcile_flags` undefined).

**Step 3: Write minimal implementation** (edits in `scripts/world/experience_test_room.gd`)

Add static, GameState-only helpers and refactor `_reconcile_pending` to delegate:

```gdscript
## Boss is enterable after FIGHTS_BEFORE_BOSS random wins and before completion.
static func boss_unlocked() -> bool:
	if GameState.get_flag("test_room_complete", false):
		return false
	return int(GameState.get_flag("test_room_random_wins", 0)) >= FIGHTS_BEFORE_BOSS


## Reconcile the pending battle tag into win-count / completion. Static so it is
## testable without a live scene. Returns the tag that was reconciled ("").
static func reconcile_flags() -> String:
	var pending: String = str(GameState.get_flag("test_room_pending", ""))
	if pending == "":
		return ""
	GameState.set_flag("test_room_pending", "")
	if pending == "random":
		GameState.set_flag("test_room_random_wins",
			int(GameState.get_flag("test_room_random_wins", 0)) + 1)
	elif pending == "boss":
		GameState.set_flag("test_room_complete", true)
	return pending
```

Replace the body of the instance method `_reconcile_pending` to use the static helper (keeps the `_steps_since_battle` reset, which needs the instance):

```gdscript
func _reconcile_pending() -> void:
	if reconcile_flags() != "":
		_steps_since_battle = 0
```

**Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_experience_test_room.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Is the gate logic duplicated?" — `boss_unlocked` is the single source for both the scene handler (Task 14) and tests. Proceed.

**Step 6: Commit**

```bash
git add scripts/world/experience_test_room.gd tests/test_experience_test_room.gd
git commit -m "feat: boss-gate (boss_unlocked) + boss/win reconciliation helpers (#141)"
```

---

### Task 14: Boss trigger zone + Iris join (scene + handler)

**Files:**
- Modify: `scripts/world/experience_test_room.gd`
- Modify: `scenes/world/ExperienceTestRoom.tscn`

**Depends on:** Task 13 (`boss_unlocked`), Task 12 (scene), Task 6 (join_member)
**Parallelizable with:** none — modifies both the room script and its scene together.

> The handler itself is integration glue (scene change + autoload calls); it is verified in the smoketest. The gate decision it relies on (`boss_unlocked`) is already unit-tested in Task 13. This is the Non-Logic / integration template with a small code addition.

**Step 1: Write the content**

In `scripts/world/experience_test_room.gd`, connect the boss zone in `_ready` and add the handler:

```gdscript
func _ready() -> void:
	super._ready()
	$Player.stepped.connect(_on_player_stepped)
	$BossZone.body_entered.connect(_on_boss_zone_entered)
	_reconcile_pending()
```

```gdscript
func _on_boss_zone_entered(_body: Node2D) -> void:
	if not boss_unlocked():
		return
	# Iris joins level-matched to Reid (R11), then the Enforcer fight begins.
	PartyManager.join_member("iris", PartyManager.get_level("reid"))
	GameState.set_flag("test_room_pending", "boss")
	BattleContext.configure(BOSS_ENEMY, battle_background, scene_file_path, "default")
	SceneManager.change_scene(BATTLE_SCENE)
```

In `scenes/world/ExperienceTestRoom.tscn`, add an `Area2D` child named `BossZone`:
- `Area2D` named `BossZone` with a `CollisionShape2D` child (a `RectangleShape2D`, ~1–2 tiles), positioned on a reachable floor tile distinct from the spawn (so the player must walk to it).
- No script on the node — the room script connects `body_entered` in `_ready`.
- Ensure its collision layer/mask lets the `Player` (CharacterBody2D) trigger `body_entered` (match the layer setup used by `scenes/world/BattleEncounter.tscn`).

**Step 2: Verify**

Launch the room and play the full loop (see Smoketest Checkpoint 5). Confirm no script errors and that the boss zone does nothing until 3 wins, then triggers.

**Step 3: Commit**

```bash
git add scripts/world/experience_test_room.gd scenes/world/ExperienceTestRoom.tscn
git commit -m "feat: boss trigger zone + level-matched Iris join → Enforcer fight (#141)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 5

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 13 → Task 14 | Both modify `experience_test_room.gd`; Task 14 also edits the scene and depends on Task 13's `boss_unlocked` |

### Smoketest Checkpoint 5 — full harness loop end-to-end

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: **Full suite green** (AC11). Watch every suite touched across batches: `test_progression`, `test_combatant`, `test_party_manager`, `test_game_data`, `test_battle_scene*`, `test_save_data`, `test_save_manager`, `test_player`, `test_experience_test_room`.

**Step 3: Launch the harness room directly**
```powershell
Start-Process godot_console -ArgumentList "res://scenes/world/ExperienceTestRoom.tscn"
```
(Or `/run` the room scene.)

**Step 4: Confirm with user**
Walk the full designed loop and confirm:
- Random 2-enemy fights trigger; **Reid is still Lv 1 after the 2nd win, reaches Lv 2 on the 3rd** (AC6b) — watch for the "Reid reached Lv 2!" readout on the 3rd victory.
- After 3 wins the **BossZone** triggers on entry; **Iris joins at Reid's level** and the **Territory Enforcer** fight starts; the Enforcer **summons the Block Captain** mid-fight (AC7).
- Post-victory readout shows XP gained / level-up lines (AC8); after the boss win, returning to the room sets completion and the boss does not re-trigger (AC6/R13).
- (Optional) Save mid-run with the debug hotkey, new-game, load — progression and roster round-trip (AC9).

Wait for confirmation. Then proceed to the `executing-plans` Lessons Learned gate and `finishing-a-development-branch`.

---

## Plan Self-Review Checklist (author pass)

| # | Check | Result |
|---|-------|--------|
| 1 | No hardcoded values | PASS — XP curve, cap, growth, bounties, grace/chance, fights-before-boss are all named constants; node paths reference real nodes. |
| 2 | All tasks have explicit test criteria | PASS — every task gives the exact GUT command + expected PASS/FAIL, or a concrete visual check. |
| 3 | Parallel annotations justified | PASS — every task has `Depends on` + `Parallelizable with`; each `none` carries a one-sentence reason. |
| 4 | Parallel Execution Groups tables present | PASS — one table precedes each of the 5 Smoketest Checkpoints. |
| 5 | No leaked design narrative | PASS — plan holds file paths + steps; rationale stays in issue #141. |
