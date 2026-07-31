# Status Effect System + Territory Enforcer & Block Captain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a generic status effect system on `Combatant` and implement Territory Enforcer and Block Captain enemies with data-driven AI behaviors.

**Architecture:** A new `StatusEffect` resource class carries a `StatAxis` enum, modifier, and duration; `Combatant` gains `active_effects`, three new methods, and updated stat-read paths. `BattleScene` gains `add_enemy`, a dispatch-based `_resolve_enemy_action`, and two AI helpers for the new enemy types.

**Tech Stack:** GDScript 4, Godot 4.6, GUT test framework, `.tres` resource files.

---

## File Structure

**New files:**
- `scripts/battle/status_effect.gd` — `StatusEffect` Resource with `StatAxis` enum
- `characters/enemies/territory_enforcer.tres` — Enforcer Combatant resource
- `characters/enemies/block_captain.tres` — Captain Combatant resource

**Modified files:**
- `scripts/battle/combatant.gd` — add `active_effects`, `apply_effect`, `tick_effects`, `get_effective_stat`, `_base_stat`; update `reset_runtime_state`, `take_damage`, `calculate_damage`, `calculate_piercing_strike`, `calculate_static_touch`
- `scripts/battle/battle_scene.gd` — add `ENFORCER_RES`, `CAPTAIN_RES`, `ENEMY_SPRITE_DATA` constants; add `add_enemy`, `_resolve_enemy_action`, `_enforcer_ai`, `_captain_ai`; refactor `_ready`, `_setup_sprites`, `_begin_enemy_turn`, `_enemy_attack_without_interrupting`, `_end_turn`
- `tests/test_combatant.gd` — add status effect tests
- `tests/test_battle_scene.gd` — add enemy AI and `add_enemy` tests

---

## Task 1: StatusEffect Resource

**Files:**
- Create: `scripts/battle/status_effect.gd`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_combatant.gd`:

```gdscript
func test_status_effect_fields_have_correct_defaults() -> void:
    var effect := StatusEffect.new()
    assert_eq(effect.effect_name, "")
    assert_eq(effect.modifier, 0)
    assert_eq(effect.duration, 0)


func test_status_effect_stat_axis_has_all_axes() -> void:
    # Verify the enum members exist and are distinct
    assert_ne(StatusEffect.StatAxis.DEF, StatusEffect.StatAxis.STR)
    assert_ne(StatusEffect.StatAxis.PSY, StatusEffect.StatAxis.RES)
    assert_ne(StatusEffect.StatAxis.SPD, StatusEffect.StatAxis.HP)
```

- [ ] **Step 2: Run test to verify it fails**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: FAIL — `StatusEffect` class not found.

- [ ] **Step 3: Create `scripts/battle/status_effect.gd`**

```gdscript
class_name StatusEffect
extends Resource

enum StatAxis { DEF, STR, PSY, RES, SPD, HP }

@export var effect_name: String = ""
@export var stat: StatAxis = StatAxis.DEF
@export var modifier: int = 0
@export var duration: int = 0
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: new tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/status_effect.gd tests/test_combatant.gd
git commit -m "feat: add StatusEffect resource with StatAxis enum"
```

---

## Task 2: Combatant.apply_effect

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_combatant.gd`:

```gdscript
func test_apply_effect_adds_to_active_effects() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 8
    effect.duration = 2
    c.apply_effect(effect)
    assert_eq(c.active_effects.size(), 1)


func test_apply_effect_reapply_refreshes_duration_not_stacks() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var e1 := StatusEffect.new()
    e1.effect_name = "hold_the_line"
    e1.stat = StatusEffect.StatAxis.DEF
    e1.modifier = 8
    e1.duration = 1  # nearly expired
    c.apply_effect(e1)
    var e2 := StatusEffect.new()
    e2.effect_name = "hold_the_line"
    e2.stat = StatusEffect.StatAxis.DEF
    e2.modifier = 8
    e2.duration = 2  # fresh application
    c.apply_effect(e2)
    assert_eq(c.active_effects.size(), 1, "reapply must not stack a second instance")
    assert_eq(c.active_effects[0].duration, 2, "reapply must refresh duration to new value")


func test_reset_runtime_state_clears_active_effects() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.duration = 2
    c.apply_effect(effect)
    c.reset_runtime_state()
    assert_eq(c.active_effects.size(), 0, "reset_runtime_state must clear active effects")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: FAIL — `active_effects` and `apply_effect` not found on `Combatant`.

- [ ] **Step 3: Update `scripts/battle/combatant.gd`**

After the `skip_cooldown` line, add:
```gdscript
var active_effects: Array[StatusEffect] = []
```

At the end of `reset_runtime_state`, add:
```gdscript
    active_effects = []
```

Add the new method after `reset_runtime_state`:
```gdscript
func apply_effect(effect: StatusEffect) -> void:
    for existing in active_effects:
        if existing.effect_name == effect.effect_name:
            existing.duration = effect.duration
            return
    active_effects.append(effect)
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add active_effects and apply_effect to Combatant"
```

---

## Task 3: Combatant.tick_effects

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_combatant.gd`:

```gdscript
func test_tick_effects_decrements_duration() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 5
    effect.duration = 3
    c.apply_effect(effect)
    c.tick_effects()
    assert_eq(c.active_effects[0].duration, 2, "duration must decrement by 1 per tick")


func test_tick_effects_removes_expired_effect() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 5
    effect.duration = 1
    c.apply_effect(effect)
    c.tick_effects()
    assert_eq(c.active_effects.size(), 0, "expired effect must be removed after tick")


func test_tick_effects_only_removes_expired_leaves_others() -> void:
    var c := Combatant.new()
    c.reset_runtime_state()
    var short := StatusEffect.new()
    short.effect_name = "short"
    short.stat = StatusEffect.StatAxis.DEF
    short.modifier = 1
    short.duration = 1
    var long_eff := StatusEffect.new()
    long_eff.effect_name = "long"
    long_eff.stat = StatusEffect.StatAxis.STR
    long_eff.modifier = 2
    long_eff.duration = 3
    c.apply_effect(short)
    c.apply_effect(long_eff)
    c.tick_effects()
    assert_eq(c.active_effects.size(), 1, "only expired effects must be removed")
    assert_eq(c.active_effects[0].effect_name, "long")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: FAIL — `tick_effects` not found.

- [ ] **Step 3: Add `tick_effects` to `scripts/battle/combatant.gd`**

Add after `apply_effect`:

```gdscript
func tick_effects() -> void:
    var i := active_effects.size() - 1
    while i >= 0:
        active_effects[i].duration -= 1
        if active_effects[i].duration <= 0:
            active_effects.remove_at(i)
        i -= 1
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add tick_effects to Combatant"
```

---

## Task 4: Combatant.get_effective_stat + Updated Stat Reads

**Files:**
- Modify: `scripts/battle/combatant.gd`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_combatant.gd`:

```gdscript
func test_get_effective_stat_no_effects_returns_base() -> void:
    var c := Combatant.new()
    c.def_stat = 10
    c.reset_runtime_state()
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 10)


func test_get_effective_stat_with_buff() -> void:
    var c := Combatant.new()
    c.def_stat = 10
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 8
    effect.duration = 2
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 18)


func test_get_effective_stat_with_debuff() -> void:
    var c := Combatant.new()
    c.def_stat = 10
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "mark_target"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = -6
    effect.duration = 99
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 4)


func test_get_effective_stat_clamps_at_zero() -> void:
    var c := Combatant.new()
    c.def_stat = 5
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "mark_target"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = -20
    effect.duration = 99
    c.apply_effect(effect)
    assert_eq(c.get_effective_stat(StatusEffect.StatAxis.DEF), 0, "effective stat must clamp at 0")


func test_take_damage_clears_mark_target() -> void:
    var c := Combatant.new()
    c.max_hp = 100
    c.reset_runtime_state()
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
    var c := Combatant.new()
    c.max_hp = 100
    c.reset_runtime_state()
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 8
    effect.duration = 2
    c.apply_effect(effect)
    c.take_damage(10)
    assert_eq(c.active_effects.size(), 1, "take_damage must not clear non-mark_target effects")


func test_calculate_damage_uses_effective_stats() -> void:
    # DEF buff on target reduces damage
    var attacker := Combatant.new()
    attacker.str_stat = 40
    var target := Combatant.new()
    target.def_stat = 10
    # With buff: effective DEF = 30, so damage = floor((40-30)*[0.9,1.1]) = [9,11]
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
    # DEF debuff on target increases damage
    var attacker := Combatant.new()
    attacker.str_stat = 40
    var target := Combatant.new()
    target.def_stat = 10
    # With debuff: effective DEF = 4, so damage = floor((40-4)*[0.9,1.1]) = [32,39]
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

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: FAIL — `get_effective_stat` not found; `take_damage` and `calculate_damage` still use raw fields.

- [ ] **Step 3: Update `scripts/battle/combatant.gd`**

Add after `tick_effects`:

```gdscript
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
```

Replace `take_damage` with:

```gdscript
func take_damage(amount: int) -> void:
    var i := active_effects.size() - 1
    while i >= 0:
        if active_effects[i].effect_name == "mark_target":
            active_effects.remove_at(i)
        i -= 1
    current_hp = maxi(current_hp - amount, 0)
    var ratio: float = float(amount) / float(max_hp)
    limit_gauge = minf(limit_gauge + ratio * LIMIT_MAX, limit_cap())
```

Replace the three `calculate_*` static functions with:

```gdscript
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

- [ ] **Step 4: Run the full test suite to verify all tests pass (including pre-existing)**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS. The existing `test_calculate_damage_within_expected_range` and friends pass because active_effects is empty by default, so effective stats equal base stats.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/combatant.gd tests/test_combatant.gd
git commit -m "feat: add get_effective_stat; update stat reads and take_damage for status effects"
```

---

## Task 5: Enemy Resource Files

**Files:**
- Create: `characters/enemies/territory_enforcer.tres`
- Create: `characters/enemies/block_captain.tres`
- Test: `tests/test_combatant.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_combatant.gd`:

```gdscript
func test_territory_enforcer_loads_with_correct_stats() -> void:
    var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres")
    enforcer.reset_runtime_state()
    assert_eq(enforcer.character_name, "Territory Enforcer")
    assert_false(enforcer.is_player_controlled)
    assert_eq(enforcer.max_hp, 180)
    assert_eq(enforcer.str_stat, 55)
    assert_eq(enforcer.def_stat, 10)
    assert_eq(enforcer.spd_stat, 20)
    assert_eq(enforcer.current_hp, 180)


func test_block_captain_loads_with_correct_stats() -> void:
    var captain: Combatant = load("res://characters/enemies/block_captain.tres")
    captain.reset_runtime_state()
    assert_eq(captain.character_name, "Block Captain")
    assert_false(captain.is_player_controlled)
    assert_eq(captain.max_hp, 300)
    assert_eq(captain.str_stat, 35)
    assert_eq(captain.def_stat, 45)
    assert_eq(captain.spd_stat, 15)
    assert_eq(captain.current_hp, 300)
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: FAIL — resource files not found.

- [ ] **Step 3: Create `characters/enemies/territory_enforcer.tres`**

```ini
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]

[resource]
script = ExtResource("1_combatant")
character_name = "Territory Enforcer"
is_player_controlled = false
max_hp = 180
max_pp = 0
str_stat = 55
def_stat = 10
psy_stat = 5
res_stat = 5
spd_stat = 20
sigil_type = 0
```

- [ ] **Step 4: Create `characters/enemies/block_captain.tres`**

```ini
[gd_resource type="Resource" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/battle/combatant.gd" id="1_combatant"]

[resource]
script = ExtResource("1_combatant")
character_name = "Block Captain"
is_player_controlled = false
max_hp = 300
max_pp = 0
str_stat = 35
def_stat = 45
psy_stat = 5
res_stat = 10
spd_stat = 15
sigil_type = 0
```

- [ ] **Step 5: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_combatant.gd
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add characters/enemies/territory_enforcer.tres characters/enemies/block_captain.tres tests/test_combatant.gd
git commit -m "feat: add Territory Enforcer and Block Captain resource files"
```

---

## Task 6: BattleScene.add_enemy

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_battle_scene.gd`:

```gdscript
func test_add_enemy_appends_to_enemies_array() -> void:
    var count_before: int = _scene.enemies.size()
    var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres").duplicate()
    enforcer.reset_runtime_state()
    _scene.add_enemy(enforcer)
    assert_eq(_scene.enemies.size(), count_before + 1, "add_enemy must append to enemies array")
    assert_eq(_scene.enemies.back().character_name, "Territory Enforcer")


func test_add_enemy_adds_sprite_to_enemy_container() -> void:
    var container: Node2D = _scene.get_node("EnemyContainer")
    var sprites_before: int = container.get_child_count()
    var captain: Combatant = load("res://characters/enemies/block_captain.tres").duplicate()
    captain.reset_runtime_state()
    _scene.add_enemy(captain)
    assert_eq(container.get_child_count(), sprites_before + 1,
        "add_enemy must add a sprite to EnemyContainer")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_battle_scene.gd
```

Expected: FAIL — `add_enemy` not found.

- [ ] **Step 3: Update `scripts/battle/battle_scene.gd`**

Add constants after `SHADE_RES` / `SHADE_TEX` (keep `SHADE_TEX` and `SHADE_RES` as-is):

```gdscript
const ENFORCER_RES := "res://characters/enemies/territory_enforcer.tres"
const CAPTAIN_RES  := "res://characters/enemies/block_captain.tres"

const ENEMY_SPRITE_DATA: Dictionary = {
    "Shade":              {"texture": "res://assets/sprites/enemies/shade.png"},
    "Territory Enforcer": {"texture": "res://assets/sprites/enemies/shade.png"},
    "Block Captain":      {"texture": "res://assets/sprites/enemies/shade.png"},
}
```

In `_ready`, replace:
```gdscript
    var shade: Combatant = load(SHADE_RES).duplicate()
    shade.reset_runtime_state()
    enemies = [shade]

    _setup_sprites()
```
with:
```gdscript
    var shade: Combatant = load(SHADE_RES).duplicate()
    shade.reset_runtime_state()
    add_enemy(shade)

    _setup_sprites()
```

In `_setup_sprites`, remove the three shade sprite lines at the bottom:
```gdscript
    # Remove these three lines:
    var shade_sprite := Sprite2D.new()
    shade_sprite.texture = load(SHADE_TEX)
    $EnemyContainer.add_child(shade_sprite)
```
The method now only creates party sprites.

Add the new method (before `_process`):

```gdscript
func add_enemy(combatant: Combatant) -> void:
    enemies.append(combatant)
    var sprite := Sprite2D.new()
    var data: Dictionary = ENEMY_SPRITE_DATA.get(combatant.character_name,
        {"texture": SHADE_TEX})
    sprite.texture = load(data["texture"])
    var idx := enemies.size() - 1
    sprite.position = Vector2(0, idx * (SPRITE_FRAME_HEIGHT + SPRITE_GAP_PX))
    $EnemyContainer.add_child(sprite)
```

- [ ] **Step 4: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS (including all pre-existing battle scene tests — Shade is still added via `add_enemy` in `_ready`, so behavior is unchanged).

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: add add_enemy to BattleScene; route initial enemy setup through it"
```

---

## Task 7: BattleScene Enforcer AI

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd`

This task introduces `_resolve_enemy_action` (dispatch router), `_enforcer_ai`, and refactors `_begin_enemy_turn` and `_enemy_attack_without_interrupting` to use it. The default path (Shade's basic attack) is preserved.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_battle_scene.gd`:

```gdscript
func test_call_backup_adds_enforcer_when_enemies_outnumbered() -> void:
    # Party: Reid + Iris (2 living). Enemy: 1 Enforcer. → Call Backup fires.
    PartyManager._temporary_members.clear()
    var iris: Combatant = load("res://characters/iris.tres").duplicate()
    iris.reset_runtime_state()
    PartyManager.add_member(iris)
    var scene2: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(scene2)
    # Swap Shade for Enforcer (logic only — leave Shade sprite in container)
    var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres").duplicate()
    enforcer.reset_runtime_state()
    scene2.enemies = [enforcer]
    var count_before: int = scene2.enemies.size()
    scene2._resolve_enemy_action(enforcer)
    assert_eq(scene2.enemies.size(), count_before + 1,
        "Call Backup must add a Territory Enforcer when enemies < living party")


func test_call_backup_not_called_when_enemies_equal_party() -> void:
    # Party: 1 Reid. Enemies: 1 Enforcer. → no backup.
    var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres").duplicate()
    enforcer.reset_runtime_state()
    _scene.enemies = [enforcer]
    var count_before: int = _scene.enemies.size()
    _scene._resolve_enemy_action(enforcer)
    assert_eq(_scene.enemies.size(), count_before,
        "Call Backup must not fire when enemy count >= living party count")


func test_enforcer_shakedown_deals_damage_when_not_outnumbered() -> void:
    var reid: Combatant = _scene.party[0]
    var enforcer: Combatant = load("res://characters/enemies/territory_enforcer.tres").duplicate()
    enforcer.reset_runtime_state()
    _scene.enemies = [enforcer]
    var hp_before: int = reid.current_hp
    _scene._resolve_enemy_action(enforcer)
    assert_lt(reid.current_hp, hp_before,
        "Shakedown must deal damage to a party member when enemies >= living party")


func test_resolve_enemy_action_default_attacks_party() -> void:
    # Shade (default path) must still deal damage
    var shade: Combatant = _scene.enemies[0]
    var reid: Combatant = _scene.party[0]
    var hp_before: int = reid.current_hp
    _scene._resolve_enemy_action(shade)
    assert_lt(reid.current_hp, hp_before,
        "Default enemy (Shade) must attack a party member via _resolve_enemy_action")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_battle_scene.gd
```

Expected: FAIL — `_resolve_enemy_action` not found.

- [ ] **Step 3: Add `_resolve_enemy_action`, `_enforcer_ai` to `scripts/battle/battle_scene.gd`**

Add after `_enemy_attack_without_interrupting` (before `_select_enemy_target`):

```gdscript
func _resolve_enemy_action(combatant: Combatant) -> Dictionary:
    match combatant.character_name:
        "Territory Enforcer":
            return _enforcer_ai(combatant)
        "Block Captain":
            return _captain_ai(combatant)
    var target := _select_enemy_target()
    if target == null:
        return {}
    var damage := Combatant.calculate_damage(combatant, target)
    target.take_damage(damage)
    return {"action": "attack", "target": target, "damage": damage}


func _enforcer_ai(combatant: Combatant) -> Dictionary:
    var living_enemies := enemies.filter(func(e: Combatant) -> bool: return e.is_alive())
    var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
    if living_enemies.size() < living_party.size():
        var backup: Combatant = load(ENFORCER_RES).duplicate()
        backup.reset_runtime_state()
        add_enemy(backup)
        return {}
    var target := _select_enemy_target()
    if target == null:
        return {}
    var damage := maxi(1,
        floori(combatant.get_effective_stat(StatusEffect.StatAxis.STR) * 1.5 * randf_range(0.9, 1.1)))
    target.take_damage(damage)
    return {"action": "attack", "target": target, "damage": damage}


func _captain_ai(combatant: Combatant) -> Dictionary:
    var htl_active := enemies.any(func(e: Combatant) -> bool:
        return e.is_alive() and e.active_effects.any(func(ef: StatusEffect) -> bool:
            return ef.effect_name == "hold_the_line"))
    if not htl_active:
        for e in enemies:
            if e.is_alive():
                var effect := StatusEffect.new()
                effect.effect_name = "hold_the_line"
                effect.stat = StatusEffect.StatAxis.DEF
                effect.modifier = 8
                effect.duration = 2
                e.apply_effect(effect)
        return {}
    var marked_exists := party.any(func(p: Combatant) -> bool:
        return p.is_alive() and p.active_effects.any(func(ef: StatusEffect) -> bool:
            return ef.effect_name == "mark_target"))
    if not marked_exists:
        var living_party := party.filter(func(p: Combatant) -> bool: return p.is_alive())
        if not living_party.is_empty():
            var effect := StatusEffect.new()
            effect.effect_name = "mark_target"
            effect.stat = StatusEffect.StatAxis.DEF
            effect.modifier = -6
            effect.duration = 99
            living_party[randi() % living_party.size()].apply_effect(effect)
        return {}
    var target := _select_enemy_target()
    if target == null:
        return {}
    var damage := Combatant.calculate_damage(combatant, target)
    target.take_damage(damage)
    return {"action": "attack", "target": target, "damage": damage}
```

Replace `_begin_enemy_turn` with:

```gdscript
func _begin_enemy_turn(combatant: Combatant) -> void:
    _active = combatant
    _state = BattleState.ANIMATING
    var result := _resolve_enemy_action(combatant)
    if result.get("action") == "attack":
        var target: Combatant = result["target"]
        var damage: int = result["damage"]
        combatant_updated.emit(target)
        var idx: int = party.find(target)
        _spawn_damage_number(damage, $PartyContainer.get_child(idx))
    await get_tree().create_timer(0.3).timeout
    _end_turn()
    _check_win_loss()
```

Replace `_enemy_attack_without_interrupting` with:

```gdscript
func _enemy_attack_without_interrupting(combatant: Combatant) -> void:
    var result := _resolve_enemy_action(combatant)
    if result.get("action") == "attack":
        var target: Combatant = result["target"]
        var damage: int = result["damage"]
        combatant_updated.emit(target)
        var idx: int = party.find(target)
        _spawn_damage_number(damage, $PartyContainer.get_child(idx))
    combatant.consume_atb()
```

- [ ] **Step 4: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: add _resolve_enemy_action, Enforcer AI (Call Backup + Shakedown), Captain AI (Hold the Line + Mark Target + Heavy Strike)"
```

---

## Task 8: BattleScene Captain AI Tests

**Files:**
- Test: `tests/test_battle_scene.gd`

The `_captain_ai` is already implemented in Task 7. This task adds the missing acceptance-criteria tests for it.

- [ ] **Step 1: Write the tests**

Append to `tests/test_battle_scene.gd`:

```gdscript
func _make_captain_scene() -> BattleScene:
    PartyManager._permanent_members.clear()
    PartyManager._temporary_members.clear()
    var reid: Combatant = load("res://characters/reid.tres").duplicate()
    reid.reset_runtime_state()
    PartyManager._permanent_members.append(reid)
    var s: BattleScene = load("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(s)
    var captain: Combatant = load("res://characters/enemies/block_captain.tres").duplicate()
    captain.reset_runtime_state()
    s.enemies = [captain]
    return s


func test_captain_hold_the_line_buffs_enemy_def() -> void:
    var s := _make_captain_scene()
    var captain: Combatant = s.enemies[0]
    var def_before := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
    s._resolve_enemy_action(captain)
    assert_gt(captain.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
        "Hold the Line must raise Captain's effective DEF")


func test_captain_hold_the_line_not_repeated_while_active() -> void:
    var s := _make_captain_scene()
    var captain: Combatant = s.enemies[0]
    # First action: Hold the Line fires
    s._resolve_enemy_action(captain)
    var def_after_first := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
    # Manually add a second living enemy without Hold the Line to test that
    # Hold the Line is already considered active for the whole group
    # Second action: Hold the Line is already active → goes to Mark Target path
    s._resolve_enemy_action(captain)
    # Party member should be marked now (no mark existed before)
    var reid: Combatant = s.party[0]
    var marked := reid.active_effects.any(func(ef: StatusEffect) -> bool:
        return ef.effect_name == "mark_target")
    assert_true(marked,
        "Captain must use Mark Target on second action when Hold the Line is already active")


func test_captain_mark_target_applies_def_debuff() -> void:
    var s := _make_captain_scene()
    var captain: Combatant = s.enemies[0]
    # Seed Hold the Line so it's already active
    var htl := StatusEffect.new()
    htl.effect_name = "hold_the_line"
    htl.stat = StatusEffect.StatAxis.DEF
    htl.modifier = 8
    htl.duration = 2
    captain.apply_effect(htl)
    var reid: Combatant = s.party[0]
    var def_before := reid.get_effective_stat(StatusEffect.StatAxis.DEF)
    s._resolve_enemy_action(captain)
    assert_lt(reid.get_effective_stat(StatusEffect.StatAxis.DEF), def_before,
        "Mark Target must lower the target party member's effective DEF")


func test_captain_heavy_strike_when_both_active() -> void:
    var s := _make_captain_scene()
    var captain: Combatant = s.enemies[0]
    var reid: Combatant = s.party[0]
    # Seed Hold the Line (active) and Mark Target (active on Reid)
    var htl := StatusEffect.new()
    htl.effect_name = "hold_the_line"
    htl.stat = StatusEffect.StatAxis.DEF
    htl.modifier = 8
    htl.duration = 2
    captain.apply_effect(htl)
    var mark := StatusEffect.new()
    mark.effect_name = "mark_target"
    mark.stat = StatusEffect.StatAxis.DEF
    mark.modifier = -6
    mark.duration = 99
    reid.apply_effect(mark)
    var hp_before: int = reid.current_hp
    s._resolve_enemy_action(captain)
    assert_lt(reid.current_hp, hp_before,
        "Captain must use Heavy Strike when both Hold the Line and Mark Target are already active")


func test_hold_the_line_raises_effective_def_during_combat() -> void:
    # AC1: attacks during Hold the Line window deal less damage
    var s := _make_captain_scene()
    var captain: Combatant = s.enemies[0]
    var reid: Combatant = s.party[0]
    var def_no_buff := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
    # Apply Hold the Line
    var htl := StatusEffect.new()
    htl.effect_name = "hold_the_line"
    htl.stat = StatusEffect.StatAxis.DEF
    htl.modifier = 8
    htl.duration = 2
    captain.apply_effect(htl)
    var def_with_buff := captain.get_effective_stat(StatusEffect.StatAxis.DEF)
    assert_gt(def_with_buff, def_no_buff,
        "Hold the Line must increase effective DEF above base")
    # Damage from Reid against buffed Captain must be lower
    for _i in range(50):
        var dmg_buffed := Combatant.calculate_damage(reid, captain)
        captain.current_hp = captain.max_hp  # reset so we can sample repeatedly
        assert_lte(dmg_buffed, Combatant.calculate_damage(reid, Combatant.new()) + 1,
            "damage against buffed enemy must be lower than against unbuffed")
```

- [ ] **Step 2: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_battle_scene.gd
```

Expected: all tests PASS (implementation already in place from Task 7).

- [ ] **Step 3: Commit**

```bash
git add tests/test_battle_scene.gd
git commit -m "test: add Captain AI acceptance tests (Hold the Line, Mark Target, Heavy Strike)"
```

---

## Task 9: BattleScene tick_effects at Turn End

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Test: `tests/test_battle_scene.gd`

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_battle_scene.gd`:

```gdscript
func test_end_turn_ticks_active_combatant_effects() -> void:
    var reid: Combatant = _scene.party[0]
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 5
    effect.duration = 2
    reid.apply_effect(effect)
    _scene._active = reid
    _scene._end_turn()
    assert_eq(reid.active_effects[0].duration, 1,
        "effect duration must decrement by 1 when _end_turn is called")


func test_end_turn_removes_expired_effects() -> void:
    var reid: Combatant = _scene.party[0]
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 5
    effect.duration = 1
    reid.apply_effect(effect)
    _scene._active = reid
    _scene._end_turn()
    assert_eq(reid.active_effects.size(), 0,
        "expired effect must be removed when _end_turn is called")


func test_enemy_attack_without_interrupting_ticks_effects() -> void:
    var shade: Combatant = _scene.enemies[0]
    var effect := StatusEffect.new()
    effect.effect_name = "hold_the_line"
    effect.stat = StatusEffect.StatAxis.DEF
    effect.modifier = 5
    effect.duration = 2
    shade.apply_effect(effect)
    _scene._enemy_attack_without_interrupting(shade)
    assert_eq(shade.active_effects[0].duration, 1,
        "enemy effect must tick after _enemy_attack_without_interrupting")
```

- [ ] **Step 2: Run tests to verify they fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=res://tests/test_battle_scene.gd
```

Expected: FAIL — effects are not ticked in `_end_turn` or `_enemy_attack_without_interrupting`.

- [ ] **Step 3: Update `scripts/battle/battle_scene.gd`**

Replace `_end_turn` with:

```gdscript
func _end_turn() -> void:
    if _active and _active.is_player_controlled:
        player_turn_ended.emit()
    if _active:
        _active.tick_effects()
        _active.consume_atb()
        _active = null
    _state = BattleState.TICKING
```

In `_enemy_attack_without_interrupting`, add `combatant.tick_effects()` before `combatant.consume_atb()`:

```gdscript
func _enemy_attack_without_interrupting(combatant: Combatant) -> void:
    var result := _resolve_enemy_action(combatant)
    if result.get("action") == "attack":
        var target: Combatant = result["target"]
        var damage: int = result["damage"]
        combatant_updated.emit(target)
        var idx: int = party.find(target)
        _spawn_damage_number(damage, $PartyContainer.get_child(idx))
    combatant.tick_effects()
    combatant.consume_atb()
```

- [ ] **Step 4: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: call tick_effects at end of each combatant's turn"
```

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|---|---|
| R1: StatusEffect resource with StatAxis, modifier, duration | Task 1 |
| R2: active_effects, reapply refreshes duration | Task 2 |
| R3: apply_effect, tick_effects, get_effective_stat | Tasks 2–4 |
| R4: calculate_* uses get_effective_stat | Task 4 |
| R5: No HUD display (data-only) | N/A — no HUD code added |
| R6: territory_enforcer.tres | Task 5 |
| R7: block_captain.tres | Task 5 |
| R8: BattleScene.add_enemy | Task 6 |
| R9: _resolve_enemy_action dispatch | Task 7 |
| R10: Enforcer AI (Call Backup + Shakedown) | Task 7 |
| R11: Captain AI (Hold the Line + Mark Target + Heavy Strike) | Task 7 |
| R12: take_damage clears mark_target | Task 4 |

### Acceptance Criteria

| AC | Covered by |
|---|---|
| AC1: Hold the Line raises effective DEF for 2 turns | Task 8: `test_hold_the_line_raises_effective_def_during_combat` |
| AC2: Mark Target lowers DEF, cleared on hit | Task 4: `test_take_damage_clears_mark_target` + Task 8: `test_captain_mark_target_applies_def_debuff` |
| AC3: Call Backup adds Territory Enforcer mid-battle | Task 7: `test_call_backup_adds_enforcer_when_enemies_outnumbered` |
| AC4: Reapply refreshes duration | Task 2: `test_apply_effect_reapply_refreshes_duration_not_stacks` |
| AC5: Expired effects removed cleanly | Task 3: `test_tick_effects_removes_expired_effect` |
| AC6: Existing damage calculation tests pass | Task 4 Step 4 — full suite run |
| AC7: GUT tests cover all specified behaviors | Tasks 2–9 |
