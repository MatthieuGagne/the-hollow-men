# Debug Battle Scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken `StatusEffectTestScene.tscn` with two editor-runnable standalone scenes (Block Captain and Territory Enforcer) and add a debug-only status effect overlay to the HUD for both enemies and party members.

**Architecture:** Two override scripts extend `BattleScene` and override `_spawn_enemies()` to spawn specific enemies. Two standalone `.tscn` files (not inherited scenes) use those scripts as the root script and duplicate the BattleScene node hierarchy. `hud.gd` gains per-enemy rows and effect labels rendered from `combatant.active_effects` inside `_update_panel()` / `_update_enemy_panel()`, driven by the existing `combatant_updated` signal — no new signal wiring.

**Tech Stack:** GDScript 4, Godot 4.6, GUT test framework.

> **Prerequisite:** This plan must be executed on top of `feat/issue-86-status-effects` (or after it merges to main). It references `StatusEffect`, `active_effects`, `_spawn_enemies()`, `CAPTAIN_RES`, `ENFORCER_RES`, `_captain_ai`, and `_enforcer_ai` — all introduced in that branch.

---

## File Structure

**Delete:**
- `scenes/battle/StatusEffectTestScene.tscn` — broken inherited-scene approach
- `scripts/battle/status_effect_test_scene.gd` — replaced by per-enemy scripts

**Create:**
- `scripts/battle/test_captain_scene.gd` — extends BattleScene, spawns Block Captain
- `scripts/battle/test_enforcer_scene.gd` — extends BattleScene, spawns Territory Enforcer
- `scenes/battle/StatusEffectTest_Captain.tscn` — standalone scene (not inherited), Captain root script
- `scenes/battle/StatusEffectTest_Enforcer.tscn` — standalone scene (not inherited), Enforcer root script

**Modify:**
- `scenes/battle/BattleScene.tscn` — replace `EnemyLabel` (Label) with `EnemyRows` (VBoxContainer)
- `scripts/ui/hud.gd` — replace `_build_enemy_label` with per-enemy rows; add `EffectsLabel` to party and enemy panels; extend `_on_combatant_updated` to handle enemies

---

## Task 1: Remove Broken Test Scene Files

**Files:**
- Delete: `scenes/battle/StatusEffectTestScene.tscn`
- Delete: `scripts/battle/status_effect_test_scene.gd`

- [ ] **Step 1: Delete the broken files**

```bash
git rm scenes/battle/StatusEffectTestScene.tscn
git rm scripts/battle/status_effect_test_scene.gd
```

- [ ] **Step 2: Run the full test suite to confirm nothing broke**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS (the deleted files had no test coverage, so the suite is unaffected).

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove broken StatusEffectTestScene (inherited-scene script override approach)"
```

---

## Task 2: Per-Enemy Override Scripts

**Files:**
- Create: `scripts/battle/test_captain_scene.gd`
- Create: `scripts/battle/test_enforcer_scene.gd`

No GUT tests required for debug scenes (out of scope per issue #112).

- [ ] **Step 1: Create `scripts/battle/test_captain_scene.gd`**

```gdscript
extends BattleScene

func _spawn_enemies() -> void:
	var captain: Combatant = load(CAPTAIN_RES).duplicate()
	captain.reset_runtime_state()
	add_enemy(captain)
```

- [ ] **Step 2: Create `scripts/battle/test_enforcer_scene.gd`**

```gdscript
extends BattleScene

func _spawn_enemies() -> void:
	var enforcer: Combatant = load(ENFORCER_RES).duplicate()
	enforcer.reset_runtime_state()
	add_enemy(enforcer)
```

- [ ] **Step 3: Run the full test suite to confirm nothing broke**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS (scripts are not yet wired into scenes).

- [ ] **Step 4: Commit**

```bash
git add scripts/battle/test_captain_scene.gd scripts/battle/test_enforcer_scene.gd
git commit -m "feat: add test_captain_scene and test_enforcer_scene override scripts"
```

---

## Task 3: HUD — Replace EnemyLabel with EnemyRows

**Files:**
- Modify: `scenes/battle/BattleScene.tscn`
- Modify: `scripts/ui/hud.gd`

The current `EnemyWindow` contains a single `EnemyLabel` (flat text list). Replace it with `EnemyRows` (VBoxContainer) so per-enemy panels can be added dynamically.

- [ ] **Step 1: Update `scenes/battle/BattleScene.tscn`**

Replace these lines:

```
[node name="EnemyLabel" type="Label" parent="UI/HUD/EnemyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
text = ""
horizontal_alignment = 0
```

With:

```
[node name="EnemyRows" type="VBoxContainer" parent="UI/HUD/EnemyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 0
```

- [ ] **Step 2: Update `scripts/ui/hud.gd`**

Add two new vars after `_draining`:
```gdscript
var _enemies: Array[Combatant] = []
var _enemy_panels: Array[Control] = []
```

In `setup`, replace the call to `_build_enemy_label(enemies)` with `_build_enemy_rows(enemies)`:
```gdscript
func setup(party: Array[Combatant], enemies: Array[Combatant], battle: Node) -> void:
	_party = party
	battle.combatant_updated.connect(_on_combatant_updated)
	battle.player_turn_started.connect(_on_player_turn_started)
	battle.player_turn_ended.connect(_on_player_turn_ended)
	battle.party_target_changed.connect(_on_party_target_changed)
	_build_enemy_rows(enemies)
	_build_panels()
```

Replace `_build_enemy_label` with `_build_enemy_rows`:
```gdscript
func _build_enemy_rows(enemies_list: Array[Combatant]) -> void:
	_enemies = enemies_list
	var container: VBoxContainer = $EnemyWindow/EnemyRows
	for combatant in _enemies:
		var panel := _make_enemy_panel(combatant)
		container.add_child(panel)
		_enemy_panels.append(panel)
```

Add `_make_enemy_panel` after `_make_placeholder_panel`:
```gdscript
func _make_enemy_panel(combatant: Combatant) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = combatant.character_name.replace(" ", "") + "Panel"
	row.add_theme_constant_override("separation", 2)
	row.custom_minimum_size = Vector2(0, 6)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = combatant.character_name.to_upper()
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	name_label.add_theme_font_size_override("font_size", 6)
	row.add_child(name_label)

	var effects_label := Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.text = ""
	effects_label.add_theme_font_size_override("font_size", 6)
	row.add_child(effects_label)

	return row
```

- [ ] **Step 3: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS (tests use `_build_enemy_rows` via `setup()` which still takes the same args).

- [ ] **Step 4: Commit**

```bash
git add scenes/battle/BattleScene.tscn scripts/ui/hud.gd
git commit -m "feat: replace EnemyLabel with per-enemy EnemyRows in HUD"
```

---

## Task 4: HUD — Effect Labels for Party and Enemy Panels

**Files:**
- Modify: `scripts/ui/hud.gd`

Add `EffectsLabel` to party panels and wire `_on_combatant_updated` to update both party and enemy panels.

- [ ] **Step 1: Add `EffectsLabel` to `_make_panel` in `scripts/ui/hud.gd`**

At the end of `_make_panel`, after the `atb_bar` block and before `return row`, add:

```gdscript
	var effects_label := Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.text = ""
	effects_label.add_theme_font_size_override("font_size", 6)
	row.add_child(effects_label)
```

- [ ] **Step 2: Add `_format_effects` helper and `_update_enemy_panel` to `scripts/ui/hud.gd`**

Add after `_update_panel`:

```gdscript
func _format_effects(combatant: Combatant) -> String:
	var parts: Array = []
	for effect in combatant.active_effects:
		var axis_name: String = StatusEffect.StatAxis.keys()[effect.stat]
		var sign: String = "+" if effect.modifier >= 0 else ""
		parts.append("%s %s%s%d (%dt)" % [effect.effect_name, axis_name, sign, effect.modifier, effect.duration])
	return "\n".join(parts)


func _update_enemy_panel(panel: Control, combatant: Combatant) -> void:
	var name_label: Label = panel.get_node("NameLabel")
	name_label.modulate.a = 0.4 if combatant.is_dead() else 1.0
	panel.get_node("EffectsLabel").text = _format_effects(combatant)
```

- [ ] **Step 3: Call `_format_effects` from `_update_panel` in `scripts/ui/hud.gd`**

At the end of `_update_panel`, after the `panel.modulate.a` line, add:

```gdscript
	if panel.has_node("EffectsLabel"):
		panel.get_node("EffectsLabel").text = _format_effects(combatant)
```

- [ ] **Step 4: Extend `_on_combatant_updated` to handle enemies**

Replace the existing `_on_combatant_updated`:

```gdscript
func _on_combatant_updated(combatant: Combatant) -> void:
	var i := _party.find(combatant)
	if i >= 0 and i < _panels.size():
		_update_panel(_panels[i], combatant)
		return
	var j := _enemies.find(combatant)
	if j >= 0 and j < _enemy_panels.size():
		_update_enemy_panel(_enemy_panels[j], combatant)
```

- [ ] **Step 5: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: add status effect labels to HUD party and enemy panels"
```

---

## Task 5: Standalone StatusEffectTest_Captain.tscn

**Files:**
- Create: `scenes/battle/StatusEffectTest_Captain.tscn`

This is a standalone scene (not inherited from BattleScene.tscn). It mirrors the BattleScene node hierarchy exactly but uses `test_captain_scene.gd` as the root script and has `EnemyRows` (VBoxContainer) matching the updated BattleScene structure from Task 3.

- [ ] **Step 1: Create `scenes/battle/StatusEffectTest_Captain.tscn`**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/battle/test_captain_scene.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="2_hud"]
[ext_resource type="Theme" path="res://assets/themes/nox_window.tres" id="3_theme"]
[ext_resource type="PackedScene" path="res://scenes/ui/ActionMenu.tscn" id="4_action_menu"]
[ext_resource type="PackedScene" path="res://scenes/ui/DefeatMenu.tscn" id="5_defeat_menu"]

[node name="StatusEffectTest_Captain" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
centered = false

[node name="EnemyContainer" type="Node2D" parent="."]
position = Vector2(60, 70)

[node name="PartyContainer" type="Node2D" parent="."]
position = Vector2(230, 70)

[node name="UI" type="CanvasLayer" parent="."]

[node name="HUD" type="Control" parent="UI"]
script = ExtResource("2_hud")
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="EnemyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 0.375
anchor_bottom = 1.0
offset_top = -40.0

[node name="EnemyRows" type="VBoxContainer" parent="UI/HUD/EnemyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 0

[node name="PartyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.375
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -40.0

[node name="PartyRows" type="VBoxContainer" parent="UI/HUD/PartyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 0

[node name="ActionMenu" parent="UI/HUD" instance=ExtResource("4_action_menu")]
layout_mode = 1

[node name="FlashOverlay" type="ColorRect" parent="UI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(1, 1, 1, 0)
mouse_filter = 2

[node name="VictoryLabel" type="Label" parent="UI"]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
text = "Victory!"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="DefeatLabel" type="Label" parent="UI"]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
modulate = Color(1, 0.3, 0.3, 1)
text = "Defeat!"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="PausedLabel" type="Label" parent="UI"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -5.0
offset_right = 20.0
offset_bottom = 5.0
text = "PAUSED"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="DefeatMenu" parent="UI" instance=ExtResource("5_defeat_menu")]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -40.0
offset_top = 8.0
offset_right = 40.0
offset_bottom = 22.0
grow_horizontal = 2
grow_vertical = 2
```

- [ ] **Step 2: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS (new .tscn file has no effect on the headless test suite).

- [ ] **Step 3: Commit**

```bash
git add scenes/battle/StatusEffectTest_Captain.tscn
git commit -m "feat: add standalone StatusEffectTest_Captain scene"
```

---

## Task 6: Standalone StatusEffectTest_Enforcer.tscn

**Files:**
- Create: `scenes/battle/StatusEffectTest_Enforcer.tscn`

Identical structure to `StatusEffectTest_Captain.tscn` from Task 5, with two differences: root script is `test_enforcer_scene.gd` and root node name is `StatusEffectTest_Enforcer`.

- [ ] **Step 1: Create `scenes/battle/StatusEffectTest_Enforcer.tscn`**

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/battle/test_enforcer_scene.gd" id="1_script"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="2_hud"]
[ext_resource type="Theme" path="res://assets/themes/nox_window.tres" id="3_theme"]
[ext_resource type="PackedScene" path="res://scenes/ui/ActionMenu.tscn" id="4_action_menu"]
[ext_resource type="PackedScene" path="res://scenes/ui/DefeatMenu.tscn" id="5_defeat_menu"]

[node name="StatusEffectTest_Enforcer" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
centered = false

[node name="EnemyContainer" type="Node2D" parent="."]
position = Vector2(60, 70)

[node name="PartyContainer" type="Node2D" parent="."]
position = Vector2(230, 70)

[node name="UI" type="CanvasLayer" parent="."]

[node name="HUD" type="Control" parent="UI"]
script = ExtResource("2_hud")
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="EnemyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 0.375
anchor_bottom = 1.0
offset_top = -40.0

[node name="EnemyRows" type="VBoxContainer" parent="UI/HUD/EnemyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 0

[node name="PartyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.375
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -40.0

[node name="PartyRows" type="VBoxContainer" parent="UI/HUD/PartyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 0

[node name="ActionMenu" parent="UI/HUD" instance=ExtResource("4_action_menu")]
layout_mode = 1

[node name="FlashOverlay" type="ColorRect" parent="UI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(1, 1, 1, 0)
mouse_filter = 2

[node name="VictoryLabel" type="Label" parent="UI"]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
text = "Victory!"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="DefeatLabel" type="Label" parent="UI"]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
grow_horizontal = 2
grow_vertical = 2
modulate = Color(1, 0.3, 0.3, 1)
text = "Defeat!"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="PausedLabel" type="Label" parent="UI"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -20.0
offset_top = -5.0
offset_right = 20.0
offset_bottom = 5.0
text = "PAUSED"
horizontal_alignment = 1
visible = false
theme_override_font_sizes/font_size = 8

[node name="DefeatMenu" parent="UI" instance=ExtResource("5_defeat_menu")]
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -40.0
offset_top = 8.0
offset_right = 40.0
offset_bottom = 22.0
grow_horizontal = 2
grow_vertical = 2
```

- [ ] **Step 2: Run the full test suite**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add scenes/battle/StatusEffectTest_Enforcer.tscn
git commit -m "feat: add standalone StatusEffectTest_Enforcer scene"
```

---

## Task 7: Manual Smoke Test

**No code changes — verification only.**

- [ ] **Step 1: Open the Captain scene in the Godot editor and run it**

In the Godot editor: open `scenes/battle/StatusEffectTest_Captain.tscn`, click "Run Scene" (F6).

Expected (AC1 + AC3 + AC5):
- Battle starts with the Block Captain as the only enemy
- Captain's first turn: `hold_the_line DEF+8 (2t)` appears in the enemy HUD row
- After 2 turns: the `hold_the_line` label disappears
- Captain's second turn (after HTL): `mark_target DEF-6 (99t)` appears on the affected party member's HUD row
- Mark Target label disappears immediately when that party member is next hit

- [ ] **Step 2: Open the Enforcer scene and run it**

In the Godot editor: open `scenes/battle/StatusEffectTest_Enforcer.tscn`, click "Run Scene" (F6).

Expected (AC2):
- Battle starts with the Territory Enforcer as the only enemy
- Enforcer deals damage each turn (Shakedown)
- When the party has more living members than enemies, a second Enforcer is added mid-battle (Call Backup)

- [ ] **Step 3: Run the full test suite one final time**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests PASS.

---

## Self-Review

### Spec Coverage

| Requirement | Task |
|---|---|
| R1: Per-enemy runnable scenes for Territory Enforcer and Block Captain | Tasks 5, 6 |
| R2: Active status effects shown on-screen for enemies and party members | Task 4 |
| R3: Effect display updates each turn and clears on expiry | Task 4 (`_on_combatant_updated` → `_update_panel`) |
| R4: Fix broken `StatusEffectTestScene.tscn` / `status_effect_test_scene.gd` | Task 1 (delete) + Tasks 2, 5, 6 (replacement) |
| R5: Permanent fixture in repo | Tasks 5, 6 (committed .tscn files) |

### Acceptance Criteria

| AC | Covered by |
|---|---|
| AC1: Captain scene starts battle with Block Captain; Hold the Line → Mark Target → Heavy Strike | Task 2 (`test_captain_scene.gd`), Task 7 smoke test |
| AC2: Enforcer scene starts battle with Territory Enforcer; Shakedown + Call Backup | Task 2 (`test_enforcer_scene.gd`), Task 7 smoke test |
| AC3: Hold the Line shows `hold_the_line DEF+8 (2t)` on enemy row, disappears after 2 turns | Task 4 (`_update_enemy_panel` + `_format_effects`), Task 7 smoke test |
| AC4: Mark Target shows on affected party member's row, disappears on hit | Task 4 (`_update_panel` + `_format_effects`), Task 7 smoke test |
| AC5: All labels update on `combatant_updated` (no polling) | Task 4 (`_on_combatant_updated` routes to both party and enemy panels) |

### Placeholder Scan

No TBDs or placeholder code. Every step has exact file paths and complete code.

### Type Consistency

- `_make_enemy_panel` returns `HBoxContainer` — contains `NameLabel` and `EffectsLabel`
- `_update_enemy_panel` calls `panel.get_node("NameLabel")` and `panel.get_node("EffectsLabel")` — both added in `_make_enemy_panel` ✓
- `_make_panel` adds `EffectsLabel` at end — `_update_panel` guards with `panel.has_node("EffectsLabel")` ✓
- `_format_effects` references `StatusEffect.StatAxis.keys()` — `StatusEffect` is defined in `scripts/battle/status_effect.gd` (issue #86) ✓
- Both standalone scenes use `EnemyRows` (VBoxContainer) — `_build_enemy_rows` references `$EnemyWindow/EnemyRows` ✓
