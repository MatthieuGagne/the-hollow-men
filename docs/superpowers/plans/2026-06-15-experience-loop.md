# Experience Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a durable XP/level/stat-growth system for player characters (persisted to save) and a walkable test-room harness where Reid clears 3 random fights (leveling up on the 3rd) before Iris joins for a boss fight against the Territory Enforcer (which summons the Block Captain).

**Architecture:** A pure `Progression` utility owns the XP curve and stat-growth math (fully unit-testable, no engine state). `CharacterDefinition` gains per-stat growth fields; `Combatant` gains a `level` and growth-aware stat getters. `PartyManager` owns the per-character progression store (level + xp for *all* known characters) and the active roster, both snapshotted into `SaveData` (this absorbs the core of the still-unbuilt PRD G / #123). `BattleScene` awards XP to survivors on victory and shows a results readout. A reused TMX map plus a step-based random-encounter controller and a gated boss trigger drive the harness loop via `GameState` flags.

**Tech Stack:** Godot 4.6 / GDScript, GUT (headless unit tests), Resource-based data definitions (`.tres`), autoload singletons.

---

## Conventions for every task

- **Run a single GUT test file:**
  `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit`
- **Run the full GUT suite (phase gates):**
  `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`
- Static typing everywhere (`var x: int = 0`). Test files live at `tests/test_<module>.gd` and `extends GutTest`.
- Commit after every task (conventional-commit style). Do **not** push or merge — integration is PR-only.
- Commit message trailer (last line):
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

---

## Setup (do once, before Task 1)

- [ ] **Create the worktree and init build artifacts**

```powershell
git worktree add .worktrees/feat-issue-141-experience-loop -b feat/issue-141-experience-loop
cd .worktrees/feat-issue-141-experience-loop
make worktree-init
```

`make worktree-init` copies gitignored build artifacts (placeholder PNGs, dialogue `.import` files) and runs a headless reimport. Without it the reused map renders empty in smoketests. All paths below are relative to the worktree root.

---

## Phase 1 — Progression core logic

### Task 1: `Progression` utility (XP curve + growth math)

**Files:**
- Create: `scripts/battle/progression.gd`
- Test: `tests/test_progression.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_progression.gd
extends GutTest


func test_xp_to_next_level_1_is_base() -> void:
	assert_eq(Progression.xp_to_next(1), 100)


func test_xp_to_next_level_2() -> void:
	# round(100 * 2 ^ 1.5) = round(282.84) = 283
	assert_eq(Progression.xp_to_next(2), 283)


func test_xp_to_next_at_cap_is_zero() -> void:
	assert_eq(Progression.xp_to_next(Progression.MAX_LEVEL), 0,
		"no XP is needed past the level cap")


func test_apply_xp_no_levelup_accumulates() -> void:
	var r := Progression.apply_xp(1, 0, 50)
	assert_eq(r["level"], 1)
	assert_eq(r["xp"], 50)


func test_apply_xp_single_levelup_zeroes_remainder() -> void:
	var r := Progression.apply_xp(1, 0, 100)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 0)


func test_apply_xp_carries_remainder() -> void:
	var r := Progression.apply_xp(1, 0, 120)
	assert_eq(r["level"], 2)
	assert_eq(r["xp"], 20)


func test_apply_xp_crosses_multiple_levels() -> void:
	# 100 (1->2) + 283 (2->3) = 383 lands exactly at level 3 with 0 leftover
	var r := Progression.apply_xp(1, 0, 383)
	assert_eq(r["level"], 3)
	assert_eq(r["xp"], 0)


func test_apply_xp_clamps_at_max_level() -> void:
	var r := Progression.apply_xp(Progression.MAX_LEVEL, 0, 999999)
	assert_eq(r["level"], Progression.MAX_LEVEL)
	assert_eq(r["xp"], 0, "xp is zeroed at the cap")


func test_grown_stat_level_1_is_base() -> void:
	assert_eq(Progression.grown_stat(100, 10, 1), 100)


func test_grown_stat_scales_linearly_per_level() -> void:
	# 100 + 10 * (3 - 1) = 120
	assert_eq(Progression.grown_stat(100, 10, 3), 120)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_progression.gd -gexit`
Expected: FAIL — `Identifier "Progression" not declared in the current scope`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/battle/progression.gd
class_name Progression
extends RefCounted

## Pure XP/level/stat-growth math. No engine or autoload state — fully unit-testable.

const BASE_XP: int = 100
const CURVE_EXPONENT: float = 1.5
const MAX_LEVEL: int = 99


## XP required to advance FROM `level` to `level + 1`. Returns 0 at/after the cap.
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return roundi(BASE_XP * pow(float(level), CURVE_EXPONENT))


## Apply `gain` XP to a (level, xp-progress-into-level) pair.
## Returns {"level": int, "xp": int}. Crosses as many thresholds as the gain allows;
## carries the remainder; clamps to MAX_LEVEL (xp zeroed at the cap).
static func apply_xp(level: int, xp: int, gain: int) -> Dictionary:
	var lvl: int = level
	var pool: int = xp + gain
	while lvl < MAX_LEVEL:
		var needed: int = xp_to_next(lvl)
		if pool < needed:
			break
		pool -= needed
		lvl += 1
	if lvl >= MAX_LEVEL:
		pool = 0
	return {"level": lvl, "xp": pool}


## Level-scaled stat: base at level 1, +growth per level thereafter.
static func grown_stat(base: int, growth: int, level: int) -> int:
	return base + growth * (level - 1)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_progression.gd -gexit`
Expected: PASS (10/10 passing, 0 failing).

- [ ] **Step 5: Commit**

```powershell
git add scripts/battle/progression.gd tests/test_progression.gd
git commit -m "feat: add Progression utility (XP curve + stat growth) (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `CharacterDefinition` per-stat growth fields

**Files:**
- Modify: `scripts/battle/character_definition.gd`
- Test: `tests/test_combatant_definition.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_combatant_definition.gd`)

```gdscript
func test_character_definition_growth_fields_default_zero() -> void:
	var d := CharacterDefinition.new()
	assert_eq(d.hp_growth, 0)
	assert_eq(d.pp_growth, 0)
	assert_eq(d.str_growth, 0)
	assert_eq(d.def_growth, 0)
	assert_eq(d.psy_growth, 0)
	assert_eq(d.res_growth, 0)
	assert_eq(d.spd_growth, 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant_definition.gd -gexit`
Expected: FAIL — `Invalid access to property or key 'hp_growth'`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/battle/character_definition.gd
class_name CharacterDefinition
extends CombatantDefinition

@export var ability: Ability = null

# Per-level stat growth. Effective stat = base + growth * (level - 1); the .tres
# base values are the level-1 stats. Default 0 keeps level-1 behavior unchanged.
@export var hp_growth: int = 0
@export var pp_growth: int = 0
@export var str_growth: int = 0
@export var def_growth: int = 0
@export var psy_growth: int = 0
@export var res_growth: int = 0
@export var spd_growth: int = 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant_definition.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/battle/character_definition.gd tests/test_combatant_definition.gd
git commit -m "feat: add per-stat growth fields to CharacterDefinition (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `Combatant.level` + growth-aware stat getters + `set_level`

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_combatant.gd`)

```gdscript
func _make_growing_character() -> Combatant:
	var d := CharacterDefinition.new()
	d.max_hp = 100
	d.max_pp = 20
	d.str_stat = 10
	d.def_stat = 8
	d.psy_stat = 6
	d.res_stat = 4
	d.spd_stat = 12
	d.hp_growth = 30
	d.pp_growth = 5
	d.str_growth = 4
	d.def_growth = 3
	d.psy_growth = 2
	d.res_growth = 1
	d.spd_growth = 2
	return Combatant.from_definition(d)


func test_combatant_level_defaults_to_one() -> void:
	var c := _make_growing_character()
	assert_eq(c.level, 1)


func test_level_one_stats_equal_base() -> void:
	var c := _make_growing_character()
	assert_eq(c.max_hp, 100)
	assert_eq(c.str_stat, 10)
	assert_eq(c.spd_stat, 12)


func test_set_level_applies_growth_to_stats() -> void:
	var c := _make_growing_character()
	c.set_level(3)
	# base + growth * (3 - 1)
	assert_eq(c.max_hp, 100 + 30 * 2)
	assert_eq(c.max_pp, 20 + 5 * 2)
	assert_eq(c.str_stat, 10 + 4 * 2)
	assert_eq(c.def_stat, 8 + 3 * 2)
	assert_eq(c.spd_stat, 12 + 2 * 2)


func test_set_level_full_heals_to_grown_max() -> void:
	var c := _make_growing_character()
	c.current_hp = 5
	c.current_pp = 1
	c.set_level(2)
	assert_eq(c.current_hp, c.max_hp, "set_level must full-heal HP to the grown max")
	assert_eq(c.current_pp, c.max_pp, "set_level must full-heal PP to the grown max")


func test_enemy_stats_unaffected_by_level() -> void:
	# EnemyDefinition has no growth fields; an enemy stays at its base stats.
	var enemy: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	enemy.level = 5
	assert_eq(enemy.max_hp, 200, "enemy stats must not scale with level")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: FAIL — `Invalid access to property or key 'level'` (and `set_level` missing).

- [ ] **Step 3: Write the minimal implementation**

In `scripts/battle/combatant.gd`, add a `level` field to the runtime state block (just after `var atb`):

```gdscript
	# Runtime state
	var current_hp: int = 0
	var current_pp: int = 0
	var level: int = 1
	var atb: float = 0.0
```

Add a private helper near the delegating properties:

```gdscript
# Returns the CharacterDefinition for player characters, else null (enemies don't grow).
func _char_def() -> CharacterDefinition:
	return def as CharacterDefinition
```

Replace the six stat getters (`max_hp`, `max_pp`, `str_stat`, `def_stat`, `psy_stat`, `res_stat`, `spd_stat`) with growth-aware versions:

```gdscript
	var max_hp: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.max_hp, cd.hp_growth, level) if cd else def.max_hp

	var max_pp: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.max_pp, cd.pp_growth, level) if cd else def.max_pp

	var str_stat: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.str_stat, cd.str_growth, level) if cd else def.str_stat

	var def_stat: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.def_stat, cd.def_growth, level) if cd else def.def_stat

	var psy_stat: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.psy_stat, cd.psy_growth, level) if cd else def.psy_stat

	var res_stat: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.res_stat, cd.res_growth, level) if cd else def.res_stat

	var spd_stat: int:
		get:
			var cd := _char_def()
			return Progression.grown_stat(def.spd_stat, cd.spd_growth, level) if cd else def.spd_stat
```

Add a `set_level` method in the runtime-methods section (just after `reset_runtime_state`):

```gdscript
# Set the character's level and full-heal to the new (grown) maxima. Used on
# level-up (PRD R6) and when rebuilding a combatant from saved progression.
func set_level(new_level: int) -> void:
	level = new_level
	current_hp = max_hp
	current_pp = max_pp
```

Also update `reset_runtime_state` to use the grown maxima (so a leveled combatant resets to its correct max):

```gdscript
func reset_runtime_state() -> void:
	current_hp = max_hp
	current_pp = max_pp
	atb = 0.0
	limit_gauge = 0.0
	skip_cooldown = 0.0
	active_effects = []
	ai_state = {}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: PASS (all existing combatant tests still green — level-1 grown stats equal base, so nothing regresses).

- [ ] **Step 5: Commit**

```powershell
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add Combatant.level + growth-aware stats + set_level full-heal (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `EnemyDefinition.xp_reward` + `Combatant.xp_reward` + enemy `.tres` bounties

**Files:**
- Modify: `scripts/battle/enemy_definition.gd`
- Modify: `scripts/battle/combatant.gd`
- Modify: `characters/enemies/shade.tres`, `private_security_guard.tres`, `territory_enforcer.tres`, `block_captain.tres`, `security_captain.tres`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_combatant.gd`)

```gdscript
func test_enemy_definition_xp_reward_defaults_zero() -> void:
	var d := EnemyDefinition.new()
	assert_eq(d.xp_reward, 0)


func test_character_combatant_xp_reward_is_zero() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	assert_eq(reid.xp_reward, 0, "player characters carry no bounty")


func test_shade_xp_reward() -> void:
	var shade: Combatant = Combatant.from_definition(load("res://characters/enemies/shade.tres"))
	assert_eq(shade.xp_reward, 18)


func test_guard_xp_reward() -> void:
	var guard: Combatant = Combatant.from_definition(load("res://characters/enemies/private_security_guard.tres"))
	assert_eq(guard.xp_reward, 22)


func test_boss_xp_rewards() -> void:
	var enforcer: Combatant = Combatant.from_definition(load("res://characters/enemies/territory_enforcer.tres"))
	var captain: Combatant = Combatant.from_definition(load("res://characters/enemies/block_captain.tres"))
	assert_eq(enforcer.xp_reward, 60)
	assert_eq(captain.xp_reward, 45)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: FAIL — `Invalid access to property or key 'xp_reward'`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/battle/enemy_definition.gd
class_name EnemyDefinition
extends CombatantDefinition

@export var ai: EnemyAI = null
@export var summon: SummonEffect = null
@export var xp_reward: int = 0
```

In `scripts/battle/combatant.gd`, add an `xp_reward` delegating getter (just after the `summon` getter):

```gdscript
	var xp_reward: int:
		get: return (def as EnemyDefinition).xp_reward if def is EnemyDefinition else 0
```

Add `xp_reward = <N>` to the `[resource]` block of each enemy `.tres`:
- `characters/enemies/shade.tres` → `xp_reward = 18`
- `characters/enemies/private_security_guard.tres` → `xp_reward = 22`
- `characters/enemies/territory_enforcer.tres` → `xp_reward = 60`
- `characters/enemies/block_captain.tres` → `xp_reward = 45`
- `characters/enemies/security_captain.tres` → `xp_reward = 50`

Example (append inside the existing `[resource]` block of `block_captain.tres`, after `ai = SubResource("ai_captain")`):

```
xp_reward = 45
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/battle/enemy_definition.gd scripts/battle/combatant.gd characters/enemies/*.tres tests/test_combatant.gd
git commit -m "feat: add EnemyDefinition.xp_reward + enemy bounties (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: `GameData.get_player_character_ids`

**Files:**
- Modify: `scripts/autoload/game_data.gd`
- Test: `tests/test_game_data.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_game_data.gd`)

```gdscript
func test_get_player_character_ids_returns_only_characters() -> void:
	var ids := GameData.get_player_character_ids()
	assert_true(ids.has("reid"), "reid is a player character")
	assert_true(ids.has("iris"), "iris is a player character")
	assert_false(ids.has("shade"), "enemies are excluded")
	assert_false(ids.has("territory_enforcer"), "enemies are excluded")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_data.gd -gexit`
Expected: FAIL — `Invalid call. Nonexistent function 'get_player_character_ids'`.

- [ ] **Step 3: Write the minimal implementation** (add to `scripts/autoload/game_data.gd`)

```gdscript
## Ids of every registered player character (CharacterDefinition), excluding enemies.
func get_player_character_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _registry:
		if _registry[id] is CharacterDefinition:
			ids.append(id)
	return ids
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_data.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/autoload/game_data.gd tests/test_game_data.gd
git commit -m "feat: add GameData.get_player_character_ids (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: `PartyManager` progression store, `award_xp`, roster join + snapshot/restore

**Files:**
- Modify: `scripts/autoload/party_manager.gd`
- Test: `tests/test_party_manager.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_party_manager.gd`; also extend `before_each`)

Replace the existing `before_each` with one that also clears progression:

```gdscript
func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
```

Then append:

```gdscript
func test_seed_progression_defaults_all_characters_level_one() -> void:
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_xp("reid"), 0)
	assert_eq(PartyManager.get_level("iris"), 1, "non-party characters are tracked too")


func test_award_xp_to_living_member_levels_up() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	var leveled := PartyManager.award_xp([reid], 100)  # exactly the 1->2 threshold
	assert_eq(PartyManager.get_level("reid"), 2)
	assert_eq(reid.level, 2, "the live combatant's level is synced")
	assert_eq(leveled.size(), 1)
	assert_eq(leveled[0]["name"], "Reid")
	assert_eq(leveled[0]["to"], 2)


func test_award_xp_below_threshold_no_levelup() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	var leveled := PartyManager.award_xp([reid], 50)
	assert_eq(PartyManager.get_level("reid"), 1)
	assert_eq(PartyManager.get_xp("reid"), 50)
	assert_eq(leveled.size(), 0)


func test_add_member_at_level_seeds_progression_and_syncs_combatant() -> void:
	PartyManager.add_member_at_level("iris", 4)
	assert_eq(PartyManager.get_level("iris"), 4)
	assert_eq(PartyManager.get_xp("iris"), 0)
	assert_true(PartyManager.has_member("Iris"))
	var members := PartyManager.get_active_members()
	assert_eq(members[members.size() - 1].level, 4, "the joined combatant is at the matched level")


func test_snapshot_and_restore_progression_round_trips() -> void:
	PartyManager.set_progression("reid", 5, 42)
	PartyManager.set_progression("iris", 3, 7)
	var snap := PartyManager.snapshot_progression()
	PartyManager._progression.clear()
	PartyManager.restore_progression(snap)
	assert_eq(PartyManager.get_level("reid"), 5)
	assert_eq(PartyManager.get_xp("reid"), 42)
	assert_eq(PartyManager.get_level("iris"), 3)


func test_snapshot_roster_lists_permanent_ids() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	assert_eq(PartyManager.snapshot_roster(), ["reid"])


func test_restore_roster_rebuilds_combatants_at_stored_level() -> void:
	PartyManager.set_progression("reid", 3, 0)
	PartyManager.restore_roster(["reid"])
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].id, "reid")
	assert_eq(members[0].level, 3, "restored combatant uses stored level")


func test_restore_roster_empty_defaults_to_reid() -> void:
	PartyManager.restore_roster([])
	assert_true(PartyManager.has_member("Reid"), "a legacy/empty roster falls back to Reid")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd -gexit`
Expected: FAIL — `Invalid access to property or key '_progression'` / missing methods.

- [ ] **Step 3: Write the minimal implementation**

Rewrite `scripts/autoload/party_manager.gd`:

```gdscript
extends Node

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

# Per-character progression for ALL known player characters, keyed by id:
#   { "<id>": {"level": int, "xp": int} }
# Tracked even for characters not currently in the party (PRD R1).
var _progression: Dictionary = {}


func _ready() -> void:
	_seed_progression()
	_permanent_members.append(Combatant.from_definition(GameData.get_definition("reid")))


func _seed_progression() -> void:
	for id: String in GameData.get_player_character_ids():
		if not _progression.has(id):
			_progression[id] = {"level": 1, "xp": 0}


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


# Add a permanent member at a specific level (level-matched joins, e.g. Iris at
# Reid's level). Seeds the progression store and full-heals the new combatant.
func add_member_at_level(id: String, level: int) -> void:
	set_progression(id, level, 0)
	var c := Combatant.from_definition(GameData.get_definition(id))
	c.set_level(level)
	_permanent_members.append(c)


# --- Progression ---

func get_level(id: String) -> int:
	return _progression.get(id, {"level": 1, "xp": 0})["level"]


func get_xp(id: String) -> int:
	return _progression.get(id, {"level": 1, "xp": 0})["xp"]


func set_progression(id: String, level: int, xp: int) -> void:
	_progression[id] = {"level": level, "xp": xp}


# Award `amount` XP to each given (alive) member. Updates the store and syncs the
# live combatant's level, full-healing on a level-up (PRD R5/R6). Returns one
# {"name": String, "to": int} entry per member who leveled up.
func award_xp(members: Array[Combatant], amount: int) -> Array[Dictionary]:
	var leveled: Array[Dictionary] = []
	for m: Combatant in members:
		var rec: Dictionary = _progression.get(m.id, {"level": 1, "xp": 0})
		var before: int = rec["level"]
		var result := Progression.apply_xp(rec["level"], rec["xp"], amount)
		_progression[m.id] = result
		if result["level"] > before:
			m.set_level(result["level"])
			leveled.append({"name": m.character_name, "to": result["level"]})
		else:
			m.level = result["level"]
	return leveled


# --- Save/restore ---

func snapshot_progression() -> Dictionary:
	return _progression.duplicate(true)


func restore_progression(data: Dictionary) -> void:
	_seed_progression()  # ensure every known character has a Lv 1 baseline
	for id: String in data:
		_progression[id] = {"level": data[id]["level"], "xp": data[id]["xp"]}


func snapshot_roster() -> Array[String]:
	var ids: Array[String] = []
	for m: Combatant in _permanent_members:
		ids.append(m.id)
	return ids


# Rebuild the permanent roster from stored ids at their stored levels. An empty
# roster (legacy save) falls back to Reid. Call AFTER restore_progression().
func restore_roster(ids: Array) -> void:
	_permanent_members.clear()
	_temporary_members.clear()
	var effective: Array = ids if not ids.is_empty() else ["reid"]
	for id: String in effective:
		var c := Combatant.from_definition(GameData.get_definition(id))
		c.set_level(get_level(id))
		_permanent_members.append(c)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_manager.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/autoload/party_manager.gd tests/test_party_manager.gd
git commit -m "feat: PartyManager progression store, award_xp, roster snapshot/restore (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: Set growth values on the four character `.tres`

**Files:**
- Modify: `characters/reid.tres`, `characters/iris.tres`, `characters/karim.tres`, `characters/margot.tres`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_combatant.gd`)

```gdscript
func test_reid_levels_up_stats_from_tres_growth() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	reid.set_level(2)
	# Reid Lv1 max_hp=350, hp_growth=35 -> Lv2 = 385
	assert_eq(reid.max_hp, 385)
	# Reid Lv1 str=45, str_growth=5 -> Lv2 = 50
	assert_eq(reid.str_stat, 50)


func test_iris_levels_up_stats_from_tres_growth() -> void:
	var iris: Combatant = Combatant.from_definition(load("res://characters/iris.tres"))
	iris.set_level(2)
	# Iris Lv1 max_hp=270, hp_growth=28 -> Lv2 = 298
	assert_eq(iris.max_hp, 298)
	# Iris Lv1 psy=50, psy_growth=5 -> Lv2 = 55
	assert_eq(iris.psy_stat, 55)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: FAIL — grown stats equal base (growth still 0 in `.tres`).

- [ ] **Step 3: Add growth lines to each `[resource]` block**

`characters/reid.tres` (append in the `[resource]` block after `ability = SubResource("ability_reid")`):

```
hp_growth = 35
pp_growth = 2
str_growth = 5
def_growth = 3
psy_growth = 1
res_growth = 2
spd_growth = 2
```

`characters/iris.tres` (append in the `[resource]` block after `ability = SubResource("ability_iris")`):

```
hp_growth = 28
pp_growth = 6
str_growth = 3
def_growth = 2
psy_growth = 5
res_growth = 2
spd_growth = 4
```

`characters/karim.tres` (append in the `[resource]` block):

```
hp_growth = 32
pp_growth = 7
str_growth = 3
def_growth = 3
psy_growth = 4
res_growth = 3
spd_growth = 2
```

`characters/margot.tres` (append in the `[resource]` block):

```
hp_growth = 24
pp_growth = 9
str_growth = 2
def_growth = 2
psy_growth = 6
res_growth = 3
spd_growth = 3
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_combatant.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add characters/reid.tres characters/iris.tres characters/karim.tres characters/margot.tres tests/test_combatant.gd
git commit -m "feat: set per-character stat growth values (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Phase 1 gate

- [ ] Run the full suite: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit` — expect all green. Stop and investigate any regression before Phase 2.

---

## Phase 2 — Persistence (absorbs #123 core)

### Task 8: `SaveData` roster + progression fields, version 2

**Files:**
- Modify: `scripts/save/save_data.gd`
- Test: `tests/test_save_data.gd`

- [ ] **Step 1: Update/extend the test**

In `tests/test_save_data.gd`, change `test_defaults` to expect version 2 and the new fields, and add a progression-defaults assertion:

```gdscript
func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 2)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")
	assert_eq(data.roster, [])
	assert_eq(data.progression, {})
```

Add a new test for the legacy save defaulting the new fields (the existing `_LEGACY_TRES` is a v1 resource without roster/progression):

```gdscript
func test_loads_legacy_save_defaults_party_runtime() -> void:
	_cleanup_legacy()
	var f := FileAccess.open(_LEGACY_PATH, FileAccess.WRITE)
	f.store_string(_LEGACY_TRES)
	f.close()

	var data: SaveData = ResourceLoader.load(
		_LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(data)
	assert_eq(data.roster, [], "missing roster must default to []")
	assert_eq(data.progression, {}, "missing progression must default to {}")
	_cleanup_legacy()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd -gexit`
Expected: FAIL — `save_version` is 1 and `roster`/`progression` don't exist.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/save/save_data.gd
class_name SaveData
extends Resource

## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.

@export var save_version: int = 2
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""

## Active permanent-party member ids, in order.
@export var roster: Array[String] = []
## Per-character progression: { "<id>": {"level": int, "xp": int} } for all known characters.
@export var progression: Dictionary = {}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/save/save_data.gd tests/test_save_data.gd
git commit -m "feat: SaveData v2 — party roster + progression block (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: `SaveManager` save/restore progression + roster, version bump, migration

**Files:**
- Modify: `scripts/autoload/save_manager.gd`
- Test: `tests/test_save_manager.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_save_manager.gd`; extend `before_each`/`after_each` to reset party state)

Replace `before_each` and `after_each`:

```gdscript
func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func after_each() -> void:
	_remove_slot(SLOT)
	GameState.clear_flags()
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
```

Append:

```gdscript
func test_current_version_is_two() -> void:
	assert_eq(SaveManager.CURRENT_VERSION, 2)


func test_save_round_trips_progression_for_party_and_non_party() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	PartyManager.set_progression("reid", 4, 12)
	PartyManager.set_progression("iris", 2, 5)  # iris NOT in the party

	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")

	# Simulate a restart: wipe party runtime, then load.
	PartyManager._permanent_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()

	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)  # navigate = false
	assert_eq(PartyManager.get_level("reid"), 4)
	assert_eq(PartyManager.get_xp("reid"), 12)
	assert_eq(PartyManager.get_level("iris"), 2, "non-party progression persists")
	assert_eq(PartyManager.snapshot_roster(), ["reid"])


func test_apply_restores_roster_combatant_at_saved_level_full_hp() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	PartyManager.set_progression("reid", 3, 0)
	SaveManager.save(SLOT)

	PartyManager._permanent_members.clear()
	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)
	var members := PartyManager.get_active_members()
	assert_eq(members[0].level, 3)
	assert_eq(members[0].current_hp, members[0].max_hp, "HP restores to (grown) full on load")


func test_apply_legacy_v1_data_defaults_to_reid_level_one() -> void:
	var data := SaveData.new()  # roster=[] progression={} (legacy shape)
	data.flags = {"intro_complete": true}
	SaveManager.apply(data, false)
	assert_true(PartyManager.has_member("Reid"))
	assert_eq(PartyManager.get_level("reid"), 1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: FAIL — `CURRENT_VERSION` is 1; save/apply don't touch party runtime.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/autoload/save_manager.gd`:

Bump the version constant:

```gdscript
const CURRENT_VERSION: int = 2
```

In `save()`, after setting `data.spawn_point`, add the party-runtime snapshot:

```gdscript
	data.roster = PartyManager.snapshot_roster()
	data.progression = PartyManager.snapshot_progression()
```

Rewrite `apply()` to restore progression then roster:

```gdscript
func apply(data: SaveData, navigate: bool = true) -> void:
	GameState.restore_flags(data.flags)
	PartyManager.restore_progression(data.progression)
	PartyManager.restore_roster(data.roster)
	if navigate:
		SceneManager.change_scene(data.current_scene, data.spawn_point)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd -gexit`
Expected: PASS (existing flag/location round-trip tests still green).

- [ ] **Step 5: Commit**

```powershell
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd
git commit -m "feat: SaveManager persists/restores party roster + progression (v2) (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Phase 2 gate

- [ ] Full suite green: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`.

---

## Phase 3 — Battle integration (XP award + readout)

### Task 10: Award XP on victory + victory results readout

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_battle_scene.gd`)

```gdscript
func test_build_victory_text_no_levelups() -> void:
	var text := BattleScene.build_victory_text(36, [])
	assert_eq(text, "Victory!\nGained 36 XP")


func test_build_victory_text_with_levelup() -> void:
	var text := BattleScene.build_victory_text(40, [{"name": "Reid", "to": 2}])
	assert_eq(text, "Victory!\nGained 40 XP\nReid reached Lv 2!")


func test_build_victory_text_multiple_levelups() -> void:
	var text := BattleScene.build_victory_text(105,
		[{"name": "Reid", "to": 2}, {"name": "Iris", "to": 2}])
	assert_eq(text,
		"Victory!\nGained 105 XP\nReid reached Lv 2!\nIris reached Lv 2!")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd -gexit`
Expected: FAIL — `Nonexistent function 'build_victory_text'`.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/battle/battle_scene.gd`, add the static text builder (place it near `resolve_recipients`, the other static helper):

```gdscript
# Builds the post-victory readout text from total XP and the level-up entries
# ({"name": String, "to": int}) returned by PartyManager.award_xp.
static func build_victory_text(total_xp: int, leveled: Array) -> String:
	var lines: PackedStringArray = ["Victory!", "Gained %d XP" % total_xp]
	for entry: Dictionary in leveled:
		lines.append("%s reached Lv %d!" % [entry["name"], entry["to"]])
	return "\n".join(lines)
```

Replace the victory branch of `_on_battle_ended` (currently `_victory_label.show()` etc.) with the XP-award + readout flow:

```gdscript
func _on_battle_ended(victory: bool) -> void:
	_action_menu.hide()
	if victory:
		# Every enemy is dead on victory; sum their bounties.
		var total_xp: int = 0
		for e: Combatant in enemies:
			total_xp += e.xp_reward
		var survivors: Array[Combatant] = party.filter(
			func(p: Combatant) -> bool: return p.is_alive())
		var leveled := PartyManager.award_xp(survivors, total_xp)
		PartyManager.remove_temporary_members()
		_victory_label.text = build_victory_text(total_xp, leveled)
		_victory_label.show()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		if is_inside_tree():
			var target := BattleContext.return_scene if BattleContext.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target, BattleContext.return_spawn)
	else:
		_defeat_label.show()
		_defeat_menu.show()
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_battle_scene.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: award XP to survivors on victory + results readout (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Phase 4 — Test-room harness

### Task 11: `Player.stepped` signal

**Files:**
- Modify: `scripts/world/player.gd`
- Test: `tests/test_player.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_player.gd`)

```gdscript
func test_try_move_emits_stepped_with_target_cell() -> void:
	var player := Player.new()
	var layer := TileMapLayer.new()
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	layer.tile_set = tile_set
	add_child(layer)
	add_child(player)
	player.setup(layer)
	player.position = Vector2(8.0, 8.0)  # tile (0,0)
	watch_signals(player)

	player._try_move("move_right")  # target tile (1, 0)

	assert_signal_emitted_with_parameters(player, "stepped", [Vector2i(1, 0)])
	player.free()
	layer.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd -gexit`
Expected: FAIL — signal `stepped` does not exist.

- [ ] **Step 3: Write the minimal implementation**

In `scripts/world/player.gd`, declare the signal at the top (after `extends CharacterBody2D`):

```gdscript
## Emitted after the player commits a grid move, with the destination cell.
## Rooms use this to drive step-based random encounters.
signal stepped(cell: Vector2i)
```

In `_try_move`, emit it at the end of the successful-move path (after the tween is created):

```gdscript
	_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	tween.tween_callback(func() -> void: _moving = false)
	stepped.emit(target_cell)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/world/player.gd tests/test_player.gd
git commit -m "feat: emit Player.stepped on grid move (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 12: Register harness flags in `KnownFlags`

**Files:**
- Modify: `scripts/save/known_flags.gd`
- Test: `tests/test_known_flags.gd`

- [ ] **Step 1: Write the failing test** (append to `tests/test_known_flags.gd`)

```gdscript
func test_harness_flags_are_known() -> void:
	var flags := {
		"test_room_random_wins": 3,
		"test_room_pending_random": false,
		"test_room_pending_boss": false,
		"test_room_harness_complete": true,
	}
	var result := KnownFlags.validate(flags)
	assert_eq(result["warnings"].size(), 0, "harness flags must be in the manifest")
	assert_eq(result["errors"].size(), 0, "harness flag types must match")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_known_flags.gd -gexit`
Expected: FAIL — unknown-flag warnings for the four harness flags.

- [ ] **Step 3: Write the minimal implementation**

Add the four entries to `MANIFEST` in `scripts/save/known_flags.gd`:

```gdscript
const MANIFEST: Dictionary = {
	"intro_complete": TYPE_BOOL,
	"case_1_beat3_complete": TYPE_BOOL,
	"case_1_beat4_complete": TYPE_BOOL,
	# Experience-loop harness (#141)
	"test_room_random_wins": TYPE_INT,
	"test_room_pending_random": TYPE_BOOL,
	"test_room_pending_boss": TYPE_BOOL,
	"test_room_harness_complete": TYPE_BOOL,
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_known_flags.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/save/known_flags.gd tests/test_known_flags.gd
git commit -m "feat: register experience-loop harness flags in KnownFlags (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 13: `RandomEncounterController`

**Files:**
- Create: `scripts/world/random_encounter_controller.gd`
- Test: `tests/test_random_encounter_controller.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_random_encounter_controller.gd
extends GutTest


func test_no_trigger_during_grace_steps() -> void:
	# steps within the grace window never trigger, even on a low roll
	assert_false(RandomEncounterController.should_trigger(1, 3, 0.25, 0.0))
	assert_false(RandomEncounterController.should_trigger(3, 3, 0.25, 0.0))


func test_trigger_after_grace_when_roll_below_chance() -> void:
	assert_true(RandomEncounterController.should_trigger(4, 3, 0.25, 0.1))


func test_no_trigger_after_grace_when_roll_above_chance() -> void:
	assert_false(RandomEncounterController.should_trigger(4, 3, 0.25, 0.5))


func test_build_comp_joins_two_ids() -> void:
	assert_eq(RandomEncounterController.build_comp("shade", "private_security_guard"),
		"shade,private_security_guard")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_random_encounter_controller.gd -gexit`
Expected: FAIL — `Identifier "RandomEncounterController" not declared`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/world/random_encounter_controller.gd
class_name RandomEncounterController
extends Node

## Drives step-based random encounters in the test room. Connects to the sibling
## Player's `stepped` signal; after a grace window, each step has a chance to start
## a battle against 2 enemies randomly drawn from POOL. Stops once the required
## number of random victories has been reached (boss phase).

const POOL: Array[String] = ["shade", "private_security_guard"]
const GRACE_STEPS: int = 3
const TRIGGER_CHANCE: float = 0.25
const BATTLE_SCENE: String = "res://scenes/battle/BattleScene.tscn"
const WINS_FLAG: String = "test_room_random_wins"
const PENDING_FLAG: String = "test_room_pending_random"

@export var battle_background: String = "alley"
@export var return_scene: String = ""
@export var return_spawn: String = "default"
@export var required_wins: int = 3

var _steps: int = 0


func _ready() -> void:
	var player := get_parent().get_node_or_null("Player")
	if player != null and player.has_signal("stepped"):
		player.stepped.connect(_on_stepped)


# Pure trigger decision: no trigger within the grace window; past it, trigger when
# the roll falls under the chance.
static func should_trigger(steps: int, grace: int, chance: float, roll: float) -> bool:
	if steps <= grace:
		return false
	return roll < chance


static func build_comp(a: String, b: String) -> String:
	return "%s,%s" % [a, b]


func _on_stepped(_cell: Vector2i) -> void:
	if int(GameState.get_flag(WINS_FLAG, 0)) >= required_wins:
		return  # random phase over — boss is available
	_steps += 1
	if not should_trigger(_steps, GRACE_STEPS, TRIGGER_CHANCE, randf()):
		return
	_steps = 0
	var comp := build_comp(POOL[randi() % POOL.size()], POOL[randi() % POOL.size()])
	GameState.set_flag(PENDING_FLAG, true)
	BattleContext.configure(comp, battle_background, return_scene, return_spawn)
	SceneManager.change_scene(BATTLE_SCENE)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_random_encounter_controller.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/world/random_encounter_controller.gd tests/test_random_encounter_controller.gd
git commit -m "feat: add RandomEncounterController (step-based encounters) (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 14: `BossTrigger`

**Files:**
- Create: `scripts/world/boss_trigger.gd`
- Test: `tests/test_boss_trigger.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_boss_trigger.gd
extends GutTest


func before_each() -> void:
	GameState.clear_flags()


func test_can_trigger_requires_enough_wins() -> void:
	assert_false(BossTrigger.can_trigger(2, 3, false), "fewer than required wins -> no boss")
	assert_true(BossTrigger.can_trigger(3, 3, false), "exactly required wins -> boss unlocks")
	assert_true(BossTrigger.can_trigger(5, 3, false))


func test_can_trigger_blocked_when_complete() -> void:
	assert_false(BossTrigger.can_trigger(3, 3, true), "completed harness must not re-trigger")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_boss_trigger.gd -gexit`
Expected: FAIL — `Identifier "BossTrigger" not declared`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/world/boss_trigger.gd
class_name BossTrigger
extends Area2D

## Gated boss-fight trigger in the test room. Once the player has won the required
## number of random fights (and the harness isn't already complete), entering this
## zone adds Iris (level-matched to Reid) and starts the Territory Enforcer fight.
## The Enforcer summons the Block Captain mid-fight via its existing SummonEffect.

const BATTLE_SCENE: String = "res://scenes/battle/BattleScene.tscn"
const WINS_FLAG: String = "test_room_random_wins"
const PENDING_BOSS_FLAG: String = "test_room_pending_boss"
const COMPLETE_FLAG: String = "test_room_harness_complete"

@export var required_wins: int = 3
@export var battle_background: String = "alley"
@export var return_scene: String = ""
@export var return_spawn: String = "default"

var _fired: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


# Pure gate: boss is available once wins meet the requirement and the harness
# isn't already complete.
static func can_trigger(wins: int, required: int, complete: bool) -> bool:
	if complete:
		return false
	return wins >= required


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body is Player:
		return
	var wins := int(GameState.get_flag(WINS_FLAG, 0))
	var complete := bool(GameState.get_flag(COMPLETE_FLAG, false))
	if not can_trigger(wins, required_wins, complete):
		return
	_fired = true
	if not PartyManager.has_member("Iris"):
		PartyManager.add_member_at_level("iris", PartyManager.get_level("reid"))
	GameState.set_flag(PENDING_BOSS_FLAG, true)
	BattleContext.configure("territory_enforcer", battle_background, return_scene, return_spawn)
	SceneManager.change_scene(BATTLE_SCENE)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_boss_trigger.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/world/boss_trigger.gd tests/test_boss_trigger.gd
git commit -m "feat: add gated BossTrigger that adds Iris and starts boss fight (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 15: `TestRoom` script (return bookkeeping)

**Files:**
- Create: `scripts/world/test_room.gd`
- Test: `tests/test_test_room.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_test_room.gd
extends GutTest


func before_each() -> void:
	GameState.clear_flags()


func test_returning_from_random_fight_increments_wins_and_clears_pending() -> void:
	GameState.set_flag("test_room_random_wins", 1)
	GameState.set_flag("test_room_pending_random", true)
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins"), 2)
	assert_false(bool(GameState.get_flag("test_room_pending_random")))


func test_first_random_win_initializes_counter() -> void:
	GameState.set_flag("test_room_pending_random", true)
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins"), 1)


func test_returning_from_boss_sets_complete_and_clears_pending() -> void:
	GameState.set_flag("test_room_pending_boss", true)
	TestRoom.resolve_return_bookkeeping()
	assert_true(bool(GameState.get_flag("test_room_harness_complete")))
	assert_false(bool(GameState.get_flag("test_room_pending_boss")))


func test_no_pending_flags_is_noop() -> void:
	TestRoom.resolve_return_bookkeeping()
	assert_eq(GameState.get_flag("test_room_random_wins", 0), 0)
	assert_false(bool(GameState.get_flag("test_room_harness_complete", false)))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_test_room.gd -gexit`
Expected: FAIL — `Identifier "TestRoom" not declared`.

- [ ] **Step 3: Write the minimal implementation**

```gdscript
# scripts/world/test_room.gd
class_name TestRoom
extends BaseRoom

## Experience-loop harness room. On (re)entry — i.e. returning from a won battle —
## it reconciles the harness flags: a pending random win bumps the win counter;
## a pending boss win marks the harness complete. A victory is the only way back
## to this room (defeat shows the defeat menu), so a set pending flag means a win.

const WINS_FLAG: String = "test_room_random_wins"
const PENDING_RANDOM_FLAG: String = "test_room_pending_random"
const PENDING_BOSS_FLAG: String = "test_room_pending_boss"
const COMPLETE_FLAG: String = "test_room_harness_complete"


func _ready() -> void:
	resolve_return_bookkeeping()
	super._ready()


static func resolve_return_bookkeeping() -> void:
	if bool(GameState.get_flag(PENDING_RANDOM_FLAG, false)):
		GameState.set_flag(PENDING_RANDOM_FLAG, false)
		GameState.set_flag(WINS_FLAG, int(GameState.get_flag(WINS_FLAG, 0)) + 1)
	if bool(GameState.get_flag(PENDING_BOSS_FLAG, false)):
		GameState.set_flag(PENDING_BOSS_FLAG, false)
		GameState.set_flag(COMPLETE_FLAG, true)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_test_room.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/world/test_room.gd tests/test_test_room.gd
git commit -m "feat: add TestRoom return-bookkeeping for the experience loop (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 16: Assemble `TestRoom.tscn` and smoketest the full loop

**Files:**
- Create: `scenes/world/TestRoom.tscn`

This task wires the existing pieces into a scene. It reuses the existing `room_poc.tmx` map (no Tiled work) plus the `BaseRoom` base scene, exactly like `RoomPOC.tscn`.

- [ ] **Step 1: Author the scene file**

Create `scenes/world/TestRoom.tscn`:

```
[gd_scene load_steps=6 format=3]

[ext_resource type="PackedScene" path="res://scenes/world/BaseRoom.tscn" id="1_baseroom"]
[ext_resource type="PackedScene" uid="uid://cqsd50e1c7p52" path="res://maps/room_poc.tmx" id="2_map"]
[ext_resource type="PackedScene" path="res://scenes/world/SpawnPoint.tscn" id="3_spawnpoint"]
[ext_resource type="Script" path="res://scripts/world/test_room.gd" id="4_testroom"]
[ext_resource type="Script" path="res://scripts/world/random_encounter_controller.gd" id="5_encounters"]
[ext_resource type="Script" path="res://scripts/world/boss_trigger.gd" id="6_boss"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_boss"]
size = Vector2(16, 16)

[node name="TestRoom" instance=ExtResource("1_baseroom") script=ExtResource("4_testroom")]
world_layer_path = NodePath("room_poc/World")
battle_background = "alley"
default_spawn = "default"
ambient_color = Color(0.08, 0.08, 0.12, 1)

[node name="room_poc" parent="." instance=ExtResource("2_map")]

[node name="DefaultSpawn" parent="." instance=ExtResource("3_spawnpoint")]
position = Vector2(120, 88)
spawn_id = "default"

[node name="RandomEncounters" type="Node" parent="."]
script = ExtResource("5_encounters")
return_scene = "res://scenes/world/TestRoom.tscn"
return_spawn = "default"
required_wins = 3

[node name="BossTrigger" type="Area2D" parent="."]
position = Vector2(56, 88)
script = ExtResource("6_boss")
required_wins = 3
return_scene = "res://scenes/world/TestRoom.tscn"
return_spawn = "default"

[node name="BossMarker" type="ColorRect" parent="BossTrigger"]
offset_left = -8.0
offset_top = -8.0
offset_right = 8.0
offset_bottom = 8.0
color = Color(0.85, 0.1, 0.1, 0.6)

[node name="CollisionShape2D" type="CollisionShape2D" parent="BossTrigger"]
shape = SubResource("RectangleShape2D_boss")
```

> The `BossTrigger` is placed a few tiles left of the spawn (`Vector2(56, 88)` vs spawn `Vector2(120, 88)`), so the player must walk to it — and will accumulate steps / random fights on the way. Adjust the position if `room_poc.tmx` walls block that tile.

- [ ] **Step 2: Headless scene-load sanity check**

Confirm the scene and its scripts parse/instantiate without error:

Run: `godot_console --headless --quit-after 2 res://scenes/world/TestRoom.tscn`
Expected: loads with no script/parse errors in the output (the window opens and quits after 2 frames).

- [ ] **Step 3: Manual smoketest the full loop**

Launch via the project's runner (it handles worktree-init checks and stale-instance cleanup):

Run: `/run` and open `res://scenes/world/TestRoom.tscn` (or temporarily set it as the main scene).

Verify end-to-end:
1. Walking around triggers random 2-enemy battles (shade/guard).
2. After each win, the victory screen shows "Gained N XP"; you return to the room.
3. Reaching the boss zone before 3 wins does nothing.
4. After the 2nd win Reid is still Lv 1; on the **3rd** win the victory readout shows "Reid reached Lv 2!".
5. With 3 wins, entering the boss zone adds Iris and starts the fight; the Territory Enforcer summons the Block Captain mid-fight.
6. Winning the boss returns to the room; re-entering the boss zone no longer triggers (harness complete).
7. Save (F5), quit, relaunch, load (F9): Reid's level and XP, plus Iris in the roster, are restored; HP is full.

- [ ] **Step 4: Commit**

```powershell
git add scenes/world/TestRoom.tscn
git commit -m "feat: assemble TestRoom scene for the experience loop (#141)`n`nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Final gate

- [ ] Full GUT suite green: `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit`.
- [ ] Manual smoketest (Task 16, Step 3) all 7 checks pass.
- [ ] Hand off to `finishing-a-development-branch` (tests, smoketest, PR, cleanup). PR references #141.

---

## Notes & known risks (from the PRD)

- **Attrition soft-lock (PRD open question):** HP/PP carry between random fights with no auto-heal except a level-up full-heal (Task 3/6). A member downed early stays down into the boss. This plan accepts the risk (it's a tuning harness). If it proves unplayable, add a post-victory revive-to-1-HP in `_on_battle_ended` — out of scope here.
- **Level-up beat determinism:** the 2-enemy fixed comp size (Task 13) + bounties (Task 4) + the Lv 1→2 threshold of 100 (Task 1) guarantee Reid is Lv 1 after 2 wins and Lv 2 after 3. If you retune any of these, re-check `2 × max_fight_xp < 100 ≤ 3 × min_fight_xp`.
- **Iris "level-match" representation:** scheme is `level = Reid.level, xp = 0` (start of that level), implemented by `add_member_at_level` (Task 6) — the PRD's "cumulative threshold" wording maps to xp-progress-into-level = 0.
- **Karim/Margot growth** values (Task 7) are placeholders; they aren't exercised by the harness but are tracked/persisted like everyone else.
