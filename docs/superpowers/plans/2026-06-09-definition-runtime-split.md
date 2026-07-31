# CombatantDefinition + Runtime Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `Combatant` resource into read-only `CombatantDefinition` templates (`CharacterDefinition` / `EnemyDefinition`) and a runtime-only `Combatant`, with sprite data on definitions, a `from_definition` factory, and stat delegation.

**Architecture:** `CombatantDefinition` (and subclasses) hold all static template data. Runtime `Combatant extends RefCounted` holds only `definition: CombatantDefinition` plus mutable runtime state; every template-field accessor delegates to the definition. Nine `.tres` files are re-authored as the appropriate subclass. Five `load().duplicate().reset_runtime_state()` call sites are replaced with `Combatant.from_definition(GameData.get_combatant(id))`.

**Tech Stack:** Godot 4.6 / GDScript, GUT 9.x

---

## File Structure

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `scripts/battle/combatant_definition.gd` | Base template: id, stats, sprite, sigil |
| Create | `scripts/battle/character_definition.gd` | Adds `ability: Ability` |
| Create | `scripts/battle/enemy_definition.gd` | Adds `ai: EnemyAI` |
| Create | `tests/test_combatant_definition.gd` | Tests for all 3 definition classes |
| Modify | `scripts/battle/combatant.gd` | Add `definition` field + copy-in factory; Task 10 converts to delegation |
| Modify | `scripts/autoload/game_data.gd` | Accept `CombatantDefinition`; return type change |
| Modify | `scripts/autoload/party_manager.gd` | Use `from_definition` factory |
| Modify | `scripts/world/room_poc.gd` | Use `from_definition` factory |
| Modify | `scripts/world/cutscene_zone.gd` | Use `from_definition` factory |
| Modify | `scripts/battle/ai/territory_enforcer_ai.gd` | Use `from_definition` factory |
| Modify | `scripts/battle/battle_scene.gd` | Read sprites from definition; remove sprite dicts |
| Rewrite | `characters/reid.tres`, `iris.tres`, `karim.tres`, `margot.tres` | CharacterDefinition |
| Rewrite | `characters/enemies/shade.tres`, `territory_enforcer.tres`, `block_captain.tres`, `private_security_guard.tres`, `security_captain.tres` | EnemyDefinition |
| Modify | `tests/test_combatant.gd` | Update to new API in two waves (Tasks 9, 10) |
| Modify | `tests/test_game_data.gd`, `test_battle_sprites.gd`, `test_battle_scene.gd`, `test_skip_turn.gd` | Update load+duplicate patterns (Task 9) |
| Modify | `tests/test_party_manager.gd` | Update `Combatant.new()` + field-setting (Task 10) |

**Commit plan:** Tasks 1–4 each get their own commit. Tasks 5–9 form one atomic batch committed together. Tasks 10, 11–12 each get their own commit.

---

## Task 1: Create `CombatantDefinition` base class

**Files:**
- Create: `scripts/battle/combatant_definition.gd`
- Create: `tests/test_combatant_definition.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_combatant_definition.gd
extends GutTest


func test_combatant_definition_default_id_is_empty() -> void:
    var def := CombatantDefinition.new()
    assert_eq(def.id, "")


func test_combatant_definition_default_max_hp_is_100() -> void:
    var def := CombatantDefinition.new()
    assert_eq(def.max_hp, 100)


func test_combatant_definition_default_sigil_type_is_none() -> void:
    var def := CombatantDefinition.new()
    assert_eq(def.sigil_type, CombatantDefinition.SigilType.NONE)


func test_combatant_definition_default_sprite_path_is_empty() -> void:
    var def := CombatantDefinition.new()
    assert_eq(def.sprite_path, "")


func test_combatant_definition_default_sprite_vframes_is_1() -> void:
    var def := CombatantDefinition.new()
    assert_eq(def.sprite_vframes, 1)
```

- [ ] **Step 2: Run tests to confirm they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: FAIL with "Class 'CombatantDefinition' not found"

- [ ] **Step 3: Create `combatant_definition.gd`**

```gdscript
# scripts/battle/combatant_definition.gd
class_name CombatantDefinition
extends Resource

enum SigilType { NONE, BUREAU, JAILBROKEN }

@export var id: String = ""
@export var character_name: String = ""
@export var is_player_controlled: bool = false
@export var max_hp: int = 100
@export var max_pp: int = 50
@export var str_stat: int = 10
@export var def_stat: int = 10
@export var psy_stat: int = 10
@export var res_stat: int = 10
@export var spd_stat: int = 10
@export var sigil_type: SigilType = SigilType.NONE
@export var sprite_path: String = ""
@export var sprite_vframes: int = 1
```

- [ ] **Step 4: Run tests to confirm they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: 5 PASS

- [ ] **Step 5: Run full suite to confirm no regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: All previously passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/battle/combatant_definition.gd tests/test_combatant_definition.gd
git commit -m "feat: add CombatantDefinition base class with sprite fields"
```

---

## Task 2: Create `CharacterDefinition`

**Files:**
- Create: `scripts/battle/character_definition.gd`
- Modify: `tests/test_combatant_definition.gd`

- [ ] **Step 1: Write the failing tests (append to `test_combatant_definition.gd`)**

```gdscript
func test_character_definition_has_ability_field() -> void:
    var def := CharacterDefinition.new()
    assert_null(def.ability, "ability must default to null")


func test_character_definition_is_combatant_definition() -> void:
    var def := CharacterDefinition.new()
    assert_true(def is CombatantDefinition)


func test_character_definition_default_vframes_is_8() -> void:
    var def := CharacterDefinition.new()
    assert_eq(def.sprite_vframes, 8, "party characters default to 8 animation frames")
```

- [ ] **Step 2: Run tests to confirm they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: 3 FAIL with "Class 'CharacterDefinition' not found"

- [ ] **Step 3: Create `character_definition.gd`**

```gdscript
# scripts/battle/character_definition.gd
class_name CharacterDefinition
extends CombatantDefinition

@export var ability: Ability = null


func _init() -> void:
    is_player_controlled = true
    sprite_vframes = 8
```

- [ ] **Step 4: Run tests to confirm they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: All 8 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/character_definition.gd tests/test_combatant_definition.gd
git commit -m "feat: add CharacterDefinition subclass"
```

---

## Task 3: Create `EnemyDefinition`

**Files:**
- Create: `scripts/battle/enemy_definition.gd`
- Modify: `tests/test_combatant_definition.gd`

- [ ] **Step 1: Write the failing tests (append to `test_combatant_definition.gd`)**

```gdscript
func test_enemy_definition_has_ai_field() -> void:
    var def := EnemyDefinition.new()
    assert_null(def.ai, "ai must default to null")


func test_enemy_definition_is_combatant_definition() -> void:
    var def := EnemyDefinition.new()
    assert_true(def is CombatantDefinition)


func test_enemy_definition_is_not_player_controlled() -> void:
    var def := EnemyDefinition.new()
    assert_false(def.is_player_controlled)
```

- [ ] **Step 2: Run tests to confirm they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: 3 FAIL with "Class 'EnemyDefinition' not found"

- [ ] **Step 3: Create `enemy_definition.gd`**

```gdscript
# scripts/battle/enemy_definition.gd
class_name EnemyDefinition
extends CombatantDefinition

@export var ai: EnemyAI = null
```

- [ ] **Step 4: Run tests to confirm they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant_definition.gd
```

Expected: All 11 PASS

- [ ] **Step 5: Run full suite — no regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

- [ ] **Step 6: Commit**

```bash
git add scripts/battle/enemy_definition.gd tests/test_combatant_definition.gd
git commit -m "feat: add EnemyDefinition subclass"
```

---

## Task 4: Add `from_definition` factory to `Combatant`

This task is **additive** — all existing @export fields and tests remain untouched. We add a `definition` field, two sprite fields, update `reset_runtime_state`, and add the factory.

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Modify: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing tests (append to `test_combatant.gd`)**

```gdscript
func test_from_definition_initializes_full_hp() -> void:
    var def := CombatantDefinition.new()
    def.max_hp = 200
    def.max_pp = 60
    var c := Combatant.from_definition(def)
    assert_eq(c.current_hp, 200)
    assert_eq(c.current_pp, 60)


func test_from_definition_independent_instances() -> void:
    var def := CombatantDefinition.new()
    def.max_hp = 100
    var c1 := Combatant.from_definition(def)
    var c2 := Combatant.from_definition(def)
    c1.take_damage(40)
    assert_eq(c1.current_hp, 60)
    assert_eq(c2.current_hp, 100, "sibling must be unaffected")


func test_from_definition_delegates_character_name() -> void:
    var def := CombatantDefinition.new()
    def.character_name = "Tester"
    var c := Combatant.from_definition(def)
    assert_eq(c.character_name, "Tester")


func test_from_definition_delegates_stats() -> void:
    var def := CombatantDefinition.new()
    def.max_hp = 300
    def.str_stat = 55
    var c := Combatant.from_definition(def)
    assert_eq(c.max_hp, 300)
    assert_eq(c.str_stat, 55)


func test_from_definition_copies_sprite_fields() -> void:
    var def := CombatantDefinition.new()
    def.sprite_path = "res://assets/sprites/characters/reid.png"
    def.sprite_vframes = 8
    var c := Combatant.from_definition(def)
    assert_eq(c.sprite_path, "res://assets/sprites/characters/reid.png")
    assert_eq(c.sprite_vframes, 8)


func test_from_definition_copies_ability_for_character() -> void:
    var ability := Ability.new()
    ability.ability_name = "Test Strike"
    var def := CharacterDefinition.new()
    def.ability = ability
    var c := Combatant.from_definition(def)
    assert_not_null(c.ability)
    assert_eq(c.ability.ability_name, "Test Strike")


func test_from_definition_copies_ai_for_enemy() -> void:
    var def := EnemyDefinition.new()
    def.ai = EnemyAI.new()
    var c := Combatant.from_definition(def)
    assert_not_null(c.ai)
```

- [ ] **Step 2: Run tests to confirm they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: 7 FAIL with "Method 'from_definition' not found"

- [ ] **Step 3: Update `scripts/battle/combatant.gd`**

Add these fields immediately after the `# AI` block (before `# Runtime state`):

```gdscript
# Definition reference (set by from_definition)
var definition: CombatantDefinition = null

# Sprite (copied from definition by from_definition)
var sprite_path: String = ""
var sprite_vframes: int = 1
```

Update `reset_runtime_state` to use the definition when available:

```gdscript
func reset_runtime_state() -> void:
    current_hp = definition.max_hp if definition else max_hp
    current_pp = definition.max_pp if definition else max_pp
    atb = 0.0
    limit_gauge = 0.0
    skip_cooldown = 0.0
    active_effects = []
    ai_state = {}
```

Add the factory at the end of the file (before the last closing line):

```gdscript
static func from_definition(def: CombatantDefinition) -> Combatant:
    var c := Combatant.new()
    c.definition = def
    c.id = def.id
    c.character_name = def.character_name
    c.is_player_controlled = def.is_player_controlled
    c.max_hp = def.max_hp
    c.max_pp = def.max_pp
    c.str_stat = def.str_stat
    c.def_stat = def.def_stat
    c.psy_stat = def.psy_stat
    c.res_stat = def.res_stat
    c.spd_stat = def.spd_stat
    c.sigil_type = def.sigil_type
    c.sprite_path = def.sprite_path
    c.sprite_vframes = def.sprite_vframes
    if def is CharacterDefinition:
        c.ability = (def as CharacterDefinition).ability
    if def is EnemyDefinition:
        c.ai = (def as EnemyDefinition).ai
    c.reset_runtime_state()
    return c
```

- [ ] **Step 4: Run tests to confirm new tests pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: All PASS (new 7 + all existing)

- [ ] **Step 5: Run full suite — no regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

- [ ] **Step 6: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add Combatant.from_definition factory with sprite field support"
```

---

## Tasks 5–9: Atomic migration batch

These five steps must all be completed before any commit. Tests are red between steps; commit only when the full suite is green.

### Task 5: Re-author all 9 `.tres` files as definition subclasses

Sprite paths come from `BattleScene.PARTY_SPRITE_DATA` / `ENEMY_SPRITE_DATA` (the dicts we're about to delete). Copy the values below exactly.

- [ ] **Rewrite `characters/reid.tres`**

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_char_def"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_reid"]
script = ExtResource("2_ability")
ability_name = "Piercing Strike"
pp_cost = 3

[resource]
script = ExtResource("1_char_def")
id = "reid"
character_name = "Reid"
max_hp = 350
max_pp = 20
str_stat = 45
def_stat = 30
psy_stat = 15
res_stat = 25
spd_stat = 30
sigil_type = 0
sprite_path = "res://assets/sprites/characters/reid.png"
sprite_vframes = 8
ability = SubResource("ability_reid")
```

- [ ] **Rewrite `characters/iris.tres`**

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_char_def"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_iris"]
script = ExtResource("2_ability")
ability_name = "Static Touch"
pp_cost = 8

[resource]
script = ExtResource("1_char_def")
id = "iris"
character_name = "Iris"
max_hp = 270
max_pp = 60
str_stat = 30
def_stat = 20
psy_stat = 50
res_stat = 20
spd_stat = 50
sigil_type = 0
sprite_path = "res://assets/sprites/characters/iris.png"
sprite_vframes = 8
ability = SubResource("ability_iris")
```

- [ ] **Rewrite `characters/karim.tres`**

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_char_def"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_karim"]
script = ExtResource("2_ability")
ability_name = "Field Suture"
pp_cost = 10
targets_party = true

[resource]
script = ExtResource("1_char_def")
id = "karim"
character_name = "Karim"
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

- [ ] **Rewrite `characters/margot.tres`**

```
[gd_resource type="Resource" script_class="CharacterDefinition" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/character_definition.gd" id="1_char_def"]
[ext_resource type="Script" path="res://scripts/battle/ability.gd" id="2_ability"]

[sub_resource type="Resource" id="ability_margot"]
script = ExtResource("2_ability")
ability_name = "Void Calculus"
pp_cost = 15
targets_party = false

[resource]
script = ExtResource("1_char_def")
id = "margot"
character_name = "Margot"
max_hp = 240
max_pp = 90
str_stat = 15
def_stat = 15
psy_stat = 70
res_stat = 20
spd_stat = 40
sigil_type = 0
sprite_path = "res://assets/sprites/characters/margot.png"
sprite_vframes = 8
ability = SubResource("ability_margot")
```

- [ ] **Rewrite `characters/enemies/shade.tres`**

```
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/enemy_definition.gd" id="1_enemy_def"]
[ext_resource type="Script" path="res://scripts/battle/enemy_ai.gd" id="2_enemy_ai"]

[sub_resource type="Resource" id="ai_shade"]
script = ExtResource("2_enemy_ai")

[resource]
script = ExtResource("1_enemy_def")
id = "shade"
character_name = "Shade"
max_hp = 200
max_pp = 0
str_stat = 45
def_stat = 15
psy_stat = 10
res_stat = 10
spd_stat = 25
sigil_type = 0
sprite_path = "res://assets/sprites/enemies/shade.png"
sprite_vframes = 1
ai = SubResource("ai_shade")
```

- [ ] **Rewrite `characters/enemies/territory_enforcer.tres`**

```
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/enemy_definition.gd" id="1_enemy_def"]
[ext_resource type="Script" path="res://scripts/battle/ai/territory_enforcer_ai.gd" id="2_enforcer_ai"]

[sub_resource type="Resource" id="ai_enforcer"]
script = ExtResource("2_enforcer_ai")

[resource]
script = ExtResource("1_enemy_def")
id = "territory_enforcer"
character_name = "Territory Enforcer"
max_hp = 150
max_pp = 0
str_stat = 35
def_stat = 10
psy_stat = 5
res_stat = 5
spd_stat = 20
sigil_type = 0
sprite_path = "res://assets/sprites/enemies/shade.png"
sprite_vframes = 1
ai = SubResource("ai_enforcer")
```

- [ ] **Rewrite `characters/enemies/block_captain.tres`**

```
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/enemy_definition.gd" id="1_enemy_def"]
[ext_resource type="Script" path="res://scripts/battle/ai/block_captain_ai.gd" id="2_captain_ai"]

[sub_resource type="Resource" id="ai_captain"]
script = ExtResource("2_captain_ai")

[resource]
script = ExtResource("1_enemy_def")
id = "block_captain"
character_name = "Block Captain"
max_hp = 200
max_pp = 0
str_stat = 35
def_stat = 15
psy_stat = 5
res_stat = 10
spd_stat = 15
sigil_type = 0
sprite_path = "res://assets/sprites/enemies/shade.png"
sprite_vframes = 1
ai = SubResource("ai_captain")
```

- [ ] **Rewrite `characters/enemies/private_security_guard.tres`**

```
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/enemy_definition.gd" id="1_enemy_def"]
[ext_resource type="Script" path="res://scripts/battle/enemy_ai.gd" id="2_enemy_ai"]

[sub_resource type="Resource" id="ai_guard"]
script = ExtResource("2_enemy_ai")

[resource]
script = ExtResource("1_enemy_def")
id = "private_security_guard"
character_name = "Private Security Guard"
max_hp = 150
max_pp = 0
str_stat = 40
def_stat = 28
psy_stat = 5
res_stat = 12
spd_stat = 32
sigil_type = 0
sprite_path = "res://assets/sprites/enemies/private_security_guard.png"
sprite_vframes = 1
ai = SubResource("ai_guard")
```

- [ ] **Rewrite `characters/enemies/security_captain.tres`**

```
[gd_resource type="Resource" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/battle/enemy_definition.gd" id="1_enemy_def"]
[ext_resource type="Script" path="res://scripts/battle/ai/security_captain_ai.gd" id="2_captain_ai"]

[sub_resource type="Resource" id="ai_sec_captain"]
script = ExtResource("2_captain_ai")

[resource]
script = ExtResource("1_enemy_def")
id = "security_captain"
character_name = "Security Captain"
max_hp = 220
max_pp = 0
str_stat = 38
def_stat = 38
psy_stat = 12
res_stat = 22
spd_stat = 14
sigil_type = 0
sprite_path = "res://assets/sprites/enemies/security_captain.png"
sprite_vframes = 1
ai = SubResource("ai_sec_captain")
```

---

### Task 6: Update `GameData` to register `CombatantDefinition`

**File:** `scripts/autoload/game_data.gd`

- [ ] **Step 1: Replace `_try_register` and `get_combatant`**

Change `_try_register` (lines 28–38): replace `if not res is Combatant` with `if not res is CombatantDefinition` and `var c := res as Combatant` with `var c := res as CombatantDefinition`.

Change `get_combatant` return type (line 41): `func get_combatant(id: String) -> CombatantDefinition:`.

Complete updated file:

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
        dir.include_navigational = false
        dir.include_hidden = false
        dir.list_dir_begin()
        var file_name: String = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".tres"):
                _try_register(dir_path + file_name)
            file_name = dir.get_next()
        dir.list_dir_end()


func _try_register(path: String) -> void:
    var res := load(path)
    if not res is CombatantDefinition:
        return
    var c := res as CombatantDefinition
    if c.id == "":
        return
    if _registry.has(c.id):
        push_warning("GameData: duplicate id '%s' found in %s — skipping" % [c.id, path])
        return
    _registry[c.id] = c


func get_combatant(id: String) -> CombatantDefinition:
    if not _registry.has(id):
        assert(false, "GameData: unknown combatant id '%s'" % id)
        return null
    return _registry[id]
```

---

### Task 7: Migrate 5 `load().duplicate().reset_runtime_state()` call sites

Pattern: `GameData.get_combatant(X).duplicate()` + `c.reset_runtime_state()` → `Combatant.from_definition(GameData.get_combatant(X))`

For direct `.tres` loads: `(load(path) as Combatant).duplicate()` + `c.reset_runtime_state()` → `Combatant.from_definition(load(path))`

- [ ] **Update `scripts/autoload/party_manager.gd` lines 6–9**

```gdscript
func _ready() -> void:
    var reid := Combatant.from_definition(GameData.get_combatant("reid"))
    _permanent_members.append(reid)
```

- [ ] **Update `scripts/world/room_poc.gd` `_seed_full_party`**

```gdscript
func _seed_full_party() -> void:
    for res_path: String in _PARTY_RESOURCES:
        var combatant := Combatant.from_definition(load(res_path))
        if not PartyManager.has_member(combatant.character_name):
            PartyManager.add_member(combatant)
```

- [ ] **Update `scripts/battle/battle_scene.gd` `_spawn_enemies`**

```gdscript
func _spawn_enemies() -> void:
    if BattleContext.enemies != "":
        for id: String in BattleContext.enemies.split(","):
            add_enemy(Combatant.from_definition(GameData.get_combatant(id.strip_edges())))
    else:
        add_enemy(Combatant.from_definition(GameData.get_combatant("shade")))
```

- [ ] **Update `scripts/battle/ai/territory_enforcer_ai.gd` line 10**

```gdscript
var backup := Combatant.from_definition(GameData.get_combatant("block_captain"))
add_enemy_fn.call(backup)
```

(Remove the `backup.reset_runtime_state()` call — `from_definition` handles it.)

- [ ] **Update `scripts/world/cutscene_zone.gd` `_on_dialogue_closed` lines 74–78**

```gdscript
func _on_dialogue_closed() -> void:
    if pre_battle_guests != "":
        for id: String in pre_battle_guests.split(","):
            PartyManager.add_temporary(Combatant.from_definition(
                GameData.get_combatant(id.strip_edges())))
    BattleContext.configure(pre_battle_enemies, "", battle_return_scene, battle_return_spawn_point)
    if next_scene.is_empty():
        return
    SceneManager.change_scene(next_scene)
```

---

### Task 8: Update `test_combatant.gd` — `.tres`-loading tests

These tests break because the `.tres` files now return `CombatantDefinition` subclasses, not `Combatant`.

Pattern: replace `var X: Combatant = load("res://characters/Y.tres"); X.reset_runtime_state()` with `var X := Combatant.from_definition(load("res://characters/Y.tres"))`.

- [ ] **Step 1: Update all 13 `.tres`-loading tests**

Replace each occurrence. Example — `test_reid_loads_with_correct_stats`:

```gdscript
func test_reid_loads_with_correct_stats() -> void:
    var reid := Combatant.from_definition(load("res://characters/reid.tres"))
    assert_eq(reid.character_name, "Reid")
    assert_eq(reid.max_hp, 350)
    assert_eq(reid.max_pp, 20)
    assert_eq(reid.spd_stat, 30)
    assert_eq(reid.current_hp, 350)
    assert_true(reid.is_player_controlled)
```

Apply the same pattern to `test_iris_loads_with_correct_stats`, `test_shade_loads_with_correct_stats`, `test_karim_loads_with_correct_stats`, `test_margot_loads_with_correct_stats`, `test_territory_enforcer_loads_with_correct_stats`, `test_block_captain_loads_with_correct_stats`, `test_private_security_guard_loads_with_correct_stats`, `test_security_captain_loads_with_correct_stats`.

For the AI tests:
```gdscript
func test_shade_has_ai() -> void:
    var shade := Combatant.from_definition(load("res://characters/enemies/shade.tres"))
    assert_not_null(shade.ai, "Shade must have an ai resource")
```
Apply same to `test_territory_enforcer_has_ai`, `test_block_captain_has_ai`.

For `test_reid_has_correct_id`:
```gdscript
func test_reid_has_correct_id() -> void:
    var reid := Combatant.from_definition(load("res://characters/reid.tres"))
    assert_eq(reid.id, "reid")
```

---

### Task 9: Update remaining test files

- [ ] **Update `tests/test_game_data.gd`** — change `var c: Combatant` → `var c: CombatantDefinition`

```gdscript
func test_get_combatant_reid() -> void:
    var c: CombatantDefinition = GameData.get_combatant("reid")
    assert_not_null(c)
    assert_eq(c.character_name, "Reid")


func test_get_combatant_shade() -> void:
    var c: CombatantDefinition = GameData.get_combatant("shade")
    assert_not_null(c)
    assert_eq(c.character_name, "Shade")
```

The other three tests in `test_game_data.gd` (`test_registry_has_nine_combatants`, `test_get_combatant_all_party_members`, `test_get_combatant_all_enemies`, `test_unknown_id_not_in_registry`) need no changes.

- [ ] **Update `tests/test_battle_sprites.gd` `before_each`**

```gdscript
func before_each() -> void:
    PartyManager._permanent_members.clear()
    PartyManager._temporary_members.clear()
    for path in ["res://characters/reid.tres", "res://characters/iris.tres",
            "res://characters/karim.tres", "res://characters/margot.tres"]:
        PartyManager.add_member(Combatant.from_definition(load(path)))
    _scene = preload("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(_scene)
    await get_tree().process_frame
```

- [ ] **Update `tests/test_skip_turn.gd` `before_each`**

```gdscript
func before_each() -> void:
    PartyManager._permanent_members.clear()
    PartyManager._temporary_members.clear()
    for path in ["res://characters/reid.tres", "res://characters/iris.tres"]:
        PartyManager.add_member(Combatant.from_definition(load(path)))
    _scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(_scene)
    _hud = _scene.get_node("UI/HUD")
```

- [ ] **Update `tests/test_battle_scene.gd` — `before_each`**

```gdscript
func before_each() -> void:
    PartyManager._permanent_members.clear()
    PartyManager._temporary_members.clear()
    BattleContext.configure()
    var reid := Combatant.from_definition(load("res://characters/reid.tres"))
    PartyManager._permanent_members.append(reid)
    _scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(_scene)
```

- [ ] **Update `tests/test_battle_scene.gd` — all inline load+duplicate sites**

Find every occurrence of the old pattern:
```
godot_console --headless -s addons/gut/gut_cmdln.gd  # just to find; use grep instead
grep -n "\.duplicate()" tests/test_battle_scene.gd
```

Replace every `load("res://characters/X.tres").duplicate()` + `Y.reset_runtime_state()` pair with `Combatant.from_definition(load("res://characters/X.tres"))`.

Affected lines (from prior grep): 87–88, 228–229, 268–269, 361–362, 376–377, 388–389, 667–668, 677–678, 691–692, 701–702, 711–712, 716–717, 731–732, 736–737, 749–750, 761–762, 786–787, 791–792, 935–936, 940–941.

Example (lines 87–88):
```gdscript
# Before:
var iris: Combatant = load("res://characters/iris.tres").duplicate()
iris.reset_runtime_state()

# After:
var iris := Combatant.from_definition(load("res://characters/iris.tres"))
```

- [ ] **Update `tests/test_battle_scene.gd` — `_add_karim_to_party` helper (line 267)**

```gdscript
func _add_karim_to_party() -> Combatant:
    var karim := Combatant.from_definition(load("res://characters/karim.tres"))
    _scene.party.append(karim)
    var idx: int = _scene.party.size() - 1
    var sprite := Sprite2D.new()
    sprite.vframes = karim.sprite_vframes
    sprite.frame = 2
    sprite.flip_h = false
    sprite.position = Vector2(0, BattleScene.SLOT_POSITIONS[idx])
    sprite.texture = load(karim.sprite_path)
    sprite.modulate = Color.WHITE
    _scene.get_node("PartyContainer").add_child(sprite)
    return karim
```

Note: `karim.sprite_vframes` and `karim.sprite_path` come from the plain fields set by `from_definition` in Task 4. `PARTY_SPRITE_DATA` is no longer referenced in any test.

- [ ] **Step: Run full suite — confirm green**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: All tests pass (pre-existing failures excluded).

- [ ] **Step: Commit the atomic batch (Tasks 5–9)**

```bash
git add characters/ characters/enemies/ \
    scripts/autoload/game_data.gd \
    scripts/autoload/party_manager.gd \
    scripts/world/room_poc.gd \
    scripts/world/cutscene_zone.gd \
    scripts/battle/ai/territory_enforcer_ai.gd \
    scripts/battle/battle_scene.gd \
    tests/test_combatant.gd \
    tests/test_game_data.gd \
    tests/test_battle_sprites.gd \
    tests/test_battle_scene.gd \
    tests/test_skip_turn.gd
git commit -m "feat: re-author .tres as definitions; migrate all call sites to from_definition"
```

---

## Task 10: Convert `Combatant` to delegating `RefCounted`

Now that all call sites use `from_definition` and all tests use the new API, we can remove the @export template fields from `Combatant`, switch it to `RefCounted`, and make all template accessors delegate to the definition.

**Files:**
- Modify: `scripts/battle/combatant.gd` (full rewrite)
- Modify: `tests/test_combatant.gd` (update stat-setting tests)
- Modify: `tests/test_party_manager.gd` (update Combatant.new() + field-setting)

- [ ] **Step 1: Write `scripts/battle/combatant.gd` — complete replacement**

```gdscript
class_name Combatant
extends RefCounted

# --- Template delegation (read-only; all backed by definition) ---
var definition: CombatantDefinition = null

var id: String:
    get: return definition.id if definition else ""

var character_name: String:
    get: return definition.character_name if definition else ""

var is_player_controlled: bool:
    get: return definition.is_player_controlled if definition else false

var max_hp: int:
    get: return definition.max_hp if definition else 0

var max_pp: int:
    get: return definition.max_pp if definition else 0

var str_stat: int:
    get: return definition.str_stat if definition else 0

var def_stat: int:
    get: return definition.def_stat if definition else 0

var psy_stat: int:
    get: return definition.psy_stat if definition else 0

var res_stat: int:
    get: return definition.res_stat if definition else 0

var spd_stat: int:
    get: return definition.spd_stat if definition else 0

var sigil_type: CombatantDefinition.SigilType:
    get: return definition.sigil_type if definition else CombatantDefinition.SigilType.NONE

var ability: Ability:
    get:
        if definition is CharacterDefinition:
            return (definition as CharacterDefinition).ability
        return null

var ai: EnemyAI:
    get:
        if definition is EnemyDefinition:
            return (definition as EnemyDefinition).ai
        return null

var sprite_path: String:
    get: return definition.sprite_path if definition else ""

var sprite_vframes: int:
    get: return definition.sprite_vframes if definition else 1

# --- Runtime state ---
var current_hp: int = 0
var current_pp: int = 0
var atb: float = 0.0
var limit_gauge: float = 0.0
var skip_cooldown: float = 0.0
var active_effects: Array[StatusEffect] = []
var ai_state: Dictionary = {}

const ATB_MAX: float = 100.0
const LIMIT_MAX: float = 100.0
const LIMIT_CAP_BUREAU: float = 80.0
const ATB_FILL_RATE: float = 1.5


static func from_definition(def: CombatantDefinition) -> Combatant:
    var c := Combatant.new()
    c.definition = def
    c.reset_runtime_state()
    return c


func reset_runtime_state() -> void:
    current_hp = max_hp
    current_pp = max_pp
    atb = 0.0
    limit_gauge = 0.0
    skip_cooldown = 0.0
    active_effects = []
    ai_state = {}


func apply_effect(effect: StatusEffect) -> void:
    for existing in active_effects:
        if existing.effect_name == effect.effect_name:
            existing.duration = effect.duration
            return
    active_effects.append(effect)


func tick_effects() -> void:
    var i := active_effects.size() - 1
    while i >= 0:
        active_effects[i].duration -= 1
        if active_effects[i].duration <= 0:
            active_effects.remove_at(i)
        i -= 1


func get_effective_stat(stat: StatusEffect.StatAxis) -> int:
    var base := _base_stat(stat)
    for effect in active_effects:
        if effect.stat == stat:
            base += effect.modifier
    return maxi(0, base)


func _base_stat(stat: StatusEffect.StatAxis) -> int:
    match stat:
        StatusEffect.StatAxis.DEF: return def_stat
        StatusEffect.StatAxis.STR: return str_stat
        StatusEffect.StatAxis.PSY: return psy_stat
        StatusEffect.StatAxis.RES: return res_stat
        StatusEffect.StatAxis.SPD: return spd_stat
        StatusEffect.StatAxis.HP:  return max_hp
    return 0


func tick_atb(delta: float) -> void:
    if is_dead():
        return
    atb = minf(atb + float(spd_stat) * delta * ATB_FILL_RATE, ATB_MAX)


func atb_full() -> bool:
    return atb >= ATB_MAX


func consume_atb() -> void:
    atb = 0.0


func is_dead() -> bool:
    return current_hp <= 0


func is_alive() -> bool:
    return current_hp > 0


func is_skipping() -> bool:
    return skip_cooldown > 0.0


func limit_cap() -> float:
    return LIMIT_CAP_BUREAU if sigil_type == CombatantDefinition.SigilType.BUREAU else LIMIT_MAX


func is_limit_ready() -> bool:
    return limit_gauge >= limit_cap()


func take_damage(amount: int) -> void:
    var i := active_effects.size() - 1
    while i >= 0:
        if active_effects[i].effect_name == "mark_target":
            active_effects.remove_at(i)
        i -= 1
    current_hp = maxi(current_hp - amount, 0)
    var ratio: float = float(amount) / float(max_hp)
    limit_gauge = minf(limit_gauge + ratio * LIMIT_MAX, limit_cap())


func drain_pp(amount: int) -> void:
    current_pp = maxi(current_pp - amount, 0)


func heal(amount: int) -> void:
    current_hp = mini(current_hp + amount, max_hp)


func spend_pp(cost: int) -> bool:
    if current_pp < cost:
        return false
    current_pp -= cost
    return true


func hp_ratio() -> float:
    return float(current_hp) / float(max_hp)


func pp_ratio() -> float:
    return float(current_pp) / float(max_pp)


func atb_ratio() -> float:
    return atb / ATB_MAX


func limit_ratio() -> float:
    return limit_gauge / limit_cap()


static func calculate_damage(attacker: Combatant, target: Combatant) -> int:
    var atk := attacker.get_effective_stat(StatusEffect.StatAxis.STR)
    var def_ := target.get_effective_stat(StatusEffect.StatAxis.DEF)
    return maxi(1, floori((atk - def_) * randf_range(0.9, 1.1)))


static func calculate_piercing_strike(attacker: Combatant) -> int:
    return maxi(1, floori(attacker.get_effective_stat(StatusEffect.StatAxis.STR) * randf_range(0.9, 1.1)))


static func calculate_static_touch(attacker: Combatant, target: Combatant) -> int:
    var atk := attacker.get_effective_stat(StatusEffect.StatAxis.PSY)
    var res := target.get_effective_stat(StatusEffect.StatAxis.RES)
    return maxi(1, floori((atk - res) * randf_range(0.9, 1.1)))
```

- [ ] **Step 2: Update `test_combatant.gd` — add `_make_combatant` helper and rewrite stat-setting tests**

Add this helper near the top of the file (after `extends GutTest`):

```gdscript
# Helper: creates a Combatant backed by a CombatantDefinition with the given stat values
func _make_combatant(p_max_hp: int = 100, p_max_pp: int = 50, p_str: int = 10,
        p_def: int = 10, p_psy: int = 10, p_res: int = 10, p_spd: int = 10) -> Combatant:
    var def := CombatantDefinition.new()
    def.max_hp = p_max_hp
    def.max_pp = p_max_pp
    def.str_stat = p_str
    def.def_stat = p_def
    def.psy_stat = p_psy
    def.res_stat = p_res
    def.spd_stat = p_spd
    return Combatant.from_definition(def)
```

Rewrite each test that previously used `Combatant.new()` + direct field assignment. The full set of changes:

```gdscript
func test_reset_runtime_state_restores_hp_and_pp() -> void:
    var c := _make_combatant(100, 50)
    c.current_hp = 0
    c.current_pp = 0
    c.atb = 99.0
    c.limit_gauge = 50.0
    c.reset_runtime_state()
    assert_eq(c.current_hp, 100)
    assert_eq(c.current_pp, 50)
    assert_eq(c.atb, 0.0)
    assert_eq(c.limit_gauge, 0.0)


func test_tick_atb_proportional_to_spd() -> void:
    var fast := _make_combatant(100, 50, 10, 10, 10, 10, 50)
    var slow := _make_combatant(100, 50, 10, 10, 10, 10, 25)
    fast.tick_atb(0.1)
    slow.tick_atb(0.1)
    assert_gt(fast.atb, slow.atb)


func test_calculate_damage_within_expected_range() -> void:
    var attacker := _make_combatant(100, 50, 45)  # str=45
    var target := _make_combatant(100, 50, 10, 15)  # def=15
    for _i in range(200):
        var dmg := Combatant.calculate_damage(attacker, target)
        assert_gte(dmg, 27, "damage below minimum expected")
        assert_lte(dmg, 33, "damage above maximum expected")


func test_calculate_damage_minimum_one() -> void:
    var attacker := _make_combatant(100, 50, 5)   # str=5
    var target := _make_combatant(100, 50, 10, 100) # def=100
    for _i in range(50):
        var dmg := Combatant.calculate_damage(attacker, target)
        assert_gte(dmg, 1, "damage must never be below 1")


func test_atb_fills_between_6_and_8_seconds_at_base_speed() -> void:
    var c := _make_combatant(100, 50, 10, 10, 10, 10, 10)
    c.tick_atb(6.0)
    assert_lt(c.atb, Combatant.ATB_MAX, "ATB should not be full after 6 seconds")
    c.tick_atb(2.0)
    assert_gte(c.atb, Combatant.ATB_MAX, "ATB must be full after 8 seconds at base speed")


func test_is_alive_returns_true_when_hp_positive() -> void:
    var c := _make_combatant(100)
    assert_true(c.is_alive())


func test_is_alive_returns_false_when_hp_zero() -> void:
    var c := _make_combatant(100)
    c.current_hp = 0
    assert_false(c.is_alive())


func test_tick_atb_skips_downed_combatant() -> void:
    var c := _make_combatant(100, 50, 10, 10, 10, 10, 50)
    c.current_hp = 0
    var atb_before: float = c.atb
    c.tick_atb(1.0)
    assert_eq(c.atb, atb_before, "dead combatant ATB must not advance")


func test_reset_runtime_state_clears_skip_cooldown() -> void:
    var c := _make_combatant()
    c.skip_cooldown = 3.5
    c.reset_runtime_state()
    assert_eq(c.skip_cooldown, 0.0)


func test_piercing_strike_uses_str_only() -> void:
    var attacker := _make_combatant(100, 50, 45)  # str=45
    for _i in range(200):
        var damage: int = Combatant.calculate_piercing_strike(attacker)
        assert_gte(damage, 40, "piercing strike with str=45 must be at least 40")
        assert_lte(damage, 49, "piercing strike with str=45 must be at most 49")


func test_static_touch_uses_psy_minus_res() -> void:
    var attacker := _make_combatant(100, 50, 10, 10, 50)   # psy=50
    var target := _make_combatant(100, 50, 10, 10, 10, 10) # res=10
    for _i in range(200):
        var damage: int = Combatant.calculate_static_touch(attacker, target)
        assert_gte(damage, 36, "static touch with psy=50, res=10 must be at least 36")
        assert_lte(damage, 44, "static touch with psy=50, res=10 must be at most 44")


func test_piercing_strike_minimum_1() -> void:
    var attacker := _make_combatant(100, 50, 0)  # str=0
    assert_eq(Combatant.calculate_piercing_strike(attacker), 1,
        "piercing strike minimum damage must be 1")


func test_static_touch_minimum_1() -> void:
    var attacker := _make_combatant(100, 50, 10, 10, 5)    # psy=5
    var target := _make_combatant(100, 50, 10, 10, 10, 100) # res=100
    assert_eq(Combatant.calculate_static_touch(attacker, target), 1,
        "static touch minimum damage must be 1 when PSY < RES")


func test_heal_increases_hp() -> void:
    var c := _make_combatant(100)
    c.current_hp = 40
    c.heal(30)
    assert_eq(c.current_hp, 70)


func test_heal_caps_at_max_hp() -> void:
    var c := _make_combatant(100)
    c.current_hp = 90
    c.heal(60)
    assert_eq(c.current_hp, 100)


func test_heal_exact_max() -> void:
    var c := _make_combatant(100)
    c.heal(9999)
    assert_eq(c.current_hp, 100)


func test_get_effective_stat_no_effects_returns_base() -> void:
    var c := _make_combatant(100, 50, 10, 10)  # def=10
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 10)


func test_get_effective_stat_with_buff() -> void:
    var c := _make_combatant(100, 50, 10, 10)  # def=10
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 8
    effect.duration = 2
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 18)


func test_get_effective_stat_with_debuff() -> void:
    var c := _make_combatant(100, 50, 10, 10)  # def=10
    var effect := StatusEffect.new()
    effect.effect_name = "mark_target"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = -6
    effect.duration = 99
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 4)


func test_get_effective_stat_clamps_at_zero() -> void:
    var c := _make_combatant(100, 50, 10, 5)  # def=5
    var effect := StatusEffect.new()
    effect.effect_name = "mark_target"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = -20
    effect.duration = 99
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0, "effective stat must clamp at 0")


func test_take_damage_clears_mark_target() -> void:
    var c := _make_combatant(100)
    var effect := StatusEffect.new()
    effect.effect_name = "mark_target"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = -6
    effect.duration = 99
    c.apply_effect(effect)
    assert_eq(c.active_effects.size(), 1)
    c.take_damage(10)
    assert_eq(c.active_effects.size(), 0, "mark_target must be cleared on first hit")


func test_take_damage_does_not_clear_other_effects() -> void:
    var c := _make_combatant(100)
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 8
    effect.duration = 2
    c.apply_effect(effect)
    c.take_damage(10)
    assert_eq(c.active_effects.size(), 1, "take_damage must not clear non-mark_target effects")


func test_calculate_damage_uses_effective_stats() -> void:
    var attacker := _make_combatant(100, 50, 40)   # str=40
    var target := _make_combatant(100, 50, 10, 10) # def=10
    var buff := StatusEffect.new()
    buff.effect_name = "hold_the_line"
    buff.stat = StatusEffect.StatAxis.DEF
    buff.modifier = 20
    buff.duration = 2
    target.apply_effect(buff)
    for _i in range(100):
        var dmg := Combatant.calculate_damage(attacker, target)
        assert_gte(dmg, 9, "buffed DEF must reduce incoming damage (min)")
        assert_lte(dmg, 11, "buffed DEF must reduce incoming damage (max)")


func test_calculate_damage_mark_target_increases_damage() -> void:
    var attacker := _make_combatant(100, 50, 40)   # str=40
    var target := _make_combatant(100, 50, 10, 10) # def=10
    var debuff := StatusEffect.new()
    debuff.effect_name = "mark_target"
    debuff.stat = StatusEffect.StatAxis.DEF
    debuff.modifier = -6
    debuff.duration = 99
    target.apply_effect(debuff)
    for _i in range(100):
        var dmg := Combatant.calculate_damage(attacker, target)
        assert_gte(dmg, 32, "marked DEF must increase incoming damage (min)")
        assert_lte(dmg, 40, "marked DEF must increase incoming damage (max)")
```

Also update the `test_reset_runtime_state_clears_active_effects`, `test_apply_effect_*`, and `test_tick_effects_*` tests that call `Combatant.new()` then `c.reset_runtime_state()`. These tests only need runtime state, so `_make_combatant()` with defaults works (null definition gives max_hp=0, but those tests don't check HP):

```gdscript
# Replace every:
#   var c := Combatant.new()
#   c.reset_runtime_state()
# with:
#   var c := _make_combatant()
```

Keep `test_skip_cooldown_initial_value_is_zero`, `test_is_skipping_true_when_cooldown_positive`, `test_is_skipping_false_when_cooldown_zero`, `test_combatant_ai_state_defaults_empty`, `test_reset_runtime_state_clears_ai_state`, `test_combatant_ai_property_defaults_null`, `test_id_defaults_to_empty_string`, `test_ability_targets_party_defaults_false` unchanged — they use `Combatant.new()` without setting stats, and `Combatant.new()` still returns a valid (null-definition) instance.

- [ ] **Step 3: Update `tests/test_party_manager.gd` — replace `Combatant.new()` + field-setting with `from_definition`**

```gdscript
extends GutTest

func before_each() -> void:
    PartyManager._permanent_members.clear()
    PartyManager._temporary_members.clear()

func _make_named(name: String) -> Combatant:
    var def := CombatantDefinition.new()
    def.character_name = name
    return Combatant.from_definition(def)

func test_get_active_members_returns_permanent_and_temporary() -> void:
    var a := _make_named("A")
    var b := _make_named("B")
    PartyManager.add_member(a)
    PartyManager.add_temporary(b)
    var members := PartyManager.get_active_members()
    assert_eq(members.size(), 2)
    assert_eq(members[0].character_name, "A")
    assert_eq(members[1].character_name, "B")


func test_add_member_persists_across_calls() -> void:
    PartyManager.add_member(_make_named("C"))
    assert_eq(PartyManager.get_active_members().size(), 1)


func test_add_temporary_appears_in_active_members() -> void:
    PartyManager.add_temporary(_make_named("Guest"))
    assert_true(PartyManager.has_member("Guest"))


func test_remove_temporary_members_clears_guests_only() -> void:
    PartyManager.add_member(_make_named("Perm"))
    PartyManager.add_temporary(_make_named("Temp"))
    PartyManager.remove_temporary_members()
    var members := PartyManager.get_active_members()
    assert_eq(members.size(), 1)
    assert_eq(members[0].character_name, "Perm")


func test_has_member_returns_false_when_absent() -> void:
    assert_false(PartyManager.has_member("Nobody"))


func test_has_member_finds_temporary_member() -> void:
    PartyManager.add_temporary(_make_named("Iris"))
    assert_true(PartyManager.has_member("Iris"))


func test_remove_temporary_does_not_affect_permanent() -> void:
    PartyManager.add_member(_make_named("Reid"))
    PartyManager.remove_temporary_members()
    assert_true(PartyManager.has_member("Reid"))
```

- [ ] **Step 4: Run full suite — confirm all tests pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: All tests pass (pre-existing failures excluded).

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd tests/test_party_manager.gd
git commit -m "refactor: Combatant extends RefCounted with delegating stat getters; drop @export fields"
```

---

## Tasks 11–12: Remove sprite dicts from `BattleScene`

### Task 11: Update `_setup_sprites` and `add_enemy` to read from definition

**File:** `scripts/battle/battle_scene.gd`

- [ ] **Step 1: Replace `_setup_sprites` (lines 110–124)**

```gdscript
func _setup_sprites() -> void:
    for i in range(party.size()):
        var member := party[i]
        if member.sprite_path == "":
            push_warning("BattleScene: no sprite_path for '%s'" % member.character_name)
            continue
        var sprite := Sprite2D.new()
        sprite.vframes = member.sprite_vframes
        sprite.frame = 2
        sprite.flip_h = false
        sprite.position = Vector2(0, SLOT_POSITIONS[i])
        sprite.texture = load(member.sprite_path)
        sprite.modulate = Color.WHITE
        $PartyContainer.add_child(sprite)
```

- [ ] **Step 2: Replace `add_enemy` sprite lookup (lines 128–137)**

```gdscript
func add_enemy(combatant: Combatant) -> void:
    enemies.append(combatant)
    var sprite := Sprite2D.new()
    var tex_path := combatant.sprite_path if combatant.sprite_path != "" else SHADE_TEX
    sprite.texture = load(tex_path)
    var idx := enemies.size() - 1
    sprite.position = Vector2(0, idx * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX))
    $EnemyContainer.add_child(sprite)
    enemy_added.emit(combatant)
```

- [ ] **Step 3: Run full suite — confirm green**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

### Task 12: Delete `PARTY_SPRITE_DATA`, `ENEMY_SPRITE_DATA`, `SHADE_TEX`

**File:** `scripts/battle/battle_scene.gd`

- [ ] **Step 1: Remove lines 15–32 (the three const dicts)**

Delete:
```gdscript
const SHADE_TEX     := "res://assets/sprites/enemies/shade.png"

const ENEMY_SPRITE_DATA: Dictionary = { ... }

const PARTY_SPRITE_DATA: Dictionary = { ... }
```

After deletion, `SHADE_TEX` is still referenced in `add_enemy` (as the fallback). Keep it as a local constant by replacing the `tex_path` line in `add_enemy`:

```gdscript
var tex_path := combatant.sprite_path if combatant.sprite_path != "" \
    else "res://assets/sprites/enemies/shade.png"
```

(Inline the path so `SHADE_TEX` can be fully removed.)

- [ ] **Step 2: Run full suite — confirm green**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

- [ ] **Step 3: Commit**

```bash
git add scripts/battle/battle_scene.gd
git commit -m "refactor: BattleScene reads sprites from CombatantDefinition; remove hardcoded sprite dicts"
```

---

## Self-Review

**Spec coverage check:**

| Requirement | Task(s) |
|---|---|
| R1: CombatantDefinition + subclasses | Tasks 1–3 |
| R2: Re-author 9 .tres files | Task 5 |
| R3: Runtime Combatant with delegation | Task 10 |
| R4: from_definition factory; migrate 5 sites | Tasks 4, 7 |
| R5: sprite_path/vframes on definitions; delete dicts | Tasks 1, 5, 11–12 |
| R6: BattleContext.enemies ids → EnemyDefinition → Combatant | Task 7 (_spawn_enemies) |
| R7: Behavior-preserving | AC1 smoke test (run the game after Task 10) |

**AC checklist:**

| AC | Where verified |
|---|---|
| AC1: game runs, battles identical | smoke test after Task 10 commit |
| AC2: definitions read-only; mutating runtime doesn't change sibling | `test_from_definition_independent_instances` |
| AC3: party HP persists (by-reference) | unchanged: `PartyManager` holds same object; no reset on battle end |
| AC4: no hardcoded sprite dicts | Task 12 deletes them |
| AC5: GUT suites green | run after each commit |
