# Battle Scene HUD Layout Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Standardize the battle HUD to 76px height, 5 party slots, 6px padding across all panels, and reposition party sprites to a 5-slot grid with 8px gaps.

**Architecture:** All changes are pure layout — `.tscn` node property edits and GDScript UI-building updates. No autoload state changes, no signals modified, no GUT tests required. Two passes: first the static scene files, then the runtime-built UI and sprite layout in GDScript.

**Tech Stack:** Godot 4.6 / GDScript, Mobile renderer, 320×180 canvas.

## Open questions (must resolve before starting)

- None.

---

## Batch 1: Static scene layout

### Task 1: BattleScene.tscn — panel dimensions, flush anchors, inner padding

**Files:**
- Modify: `scenes/battle/BattleScene.tscn`

**Depends on:** none
**Parallelizable with:** Task 2 — different output file (`DialogueBox.tscn`).

**Step 1: Edit `scenes/battle/BattleScene.tscn`**

Make the following targeted changes:

*EnemyWindow node:*
- `anchor_right`: `0.38` → `0.375`
- `offset_top`: `-32.0` → `-76.0`

*EnemyLabel node — add offsets (currently has none):*
- `offset_left = 6.0`
- `offset_top = 6.0`
- `offset_right = -6.0`
- `offset_bottom = -6.0`

*PartyWindow node:*
- `anchor_left`: `0.4` → `0.375`
- `offset_top`: `-56.0` → `-76.0`

*PartyRows node — add offsets and separation (currently has none):*
- `offset_left = 6.0`
- `offset_top = 6.0`
- `offset_right = -6.0`
- `offset_bottom = -6.0`
- `theme_override_constants/separation = 1`

After edits those four nodes should look like:

```
[node name="EnemyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.0
anchor_top = 1.0
anchor_right = 0.375
anchor_bottom = 1.0
offset_top = -76.0

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

[node name="PartyWindow" type="Panel" parent="UI/HUD"]
theme = ExtResource("3_theme")
layout_mode = 1
anchor_left = 0.375
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_top = -76.0

[node name="PartyRows" type="VBoxContainer" parent="UI/HUD/PartyWindow"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 1
```

**Step 2: Verify**

Open `scenes/battle/BattleScene.tscn` in the Godot editor. In the 2D viewport, confirm:
- EnemyWindow right edge and PartyWindow left edge share the same x position (120px from left)
- No visible gap between the two panels
- Both panels are the same height

**Step 3: Commit**

```bash
git add scenes/battle/BattleScene.tscn
git commit -m "feat: update BattleScene HUD panel dimensions, flush anchors, inner padding"
```

---

### Task 2: DialogueBox.tscn — standardize 6px padding

**Files:**
- Modify: `scenes/ui/DialogueBox.tscn`

**Depends on:** none
**Parallelizable with:** Task 1 — different output file (`BattleScene.tscn`).

**Step 1: Edit `scenes/ui/DialogueBox.tscn`**

*SpeakerLabel:* change `offset_left` `10.0` → `6.0`, `offset_right` `-10.0` → `-6.0`. Leave `offset_top = 6.0` and `offset_bottom = 20.0` unchanged (positional row offsets, not padding).

*Label:* change `offset_left` `10.0` → `6.0`, `offset_right` `-10.0` → `-6.0`, `offset_bottom` `-8.0` → `-6.0`. Leave `offset_top = 22.0` unchanged (positional).

*ChoiceList:* change `offset_left` `10.0` → `6.0`, `offset_right` `-10.0` → `-6.0`, `offset_bottom` `-8.0` → `-6.0`. Leave `offset_top = 22.0` unchanged (positional).

After edits those three nodes should look like:

```
[node name="SpeakerLabel" type="Label" parent="."]
layout_mode = 1
anchor_right = 1.0
offset_left = 6.0
offset_top = 6.0
offset_right = -6.0
offset_bottom = 20.0
text = ""

[node name="Label" type="Label" parent="."]
layout_mode = 1
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 22.0
offset_right = -6.0
offset_bottom = -6.0
text = ""
autowrap_mode = 3

[node name="ChoiceList" type="VBoxContainer" parent="."]
visible = false
layout_mode = 1
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 6.0
offset_top = 22.0
offset_right = -6.0
offset_bottom = -6.0
theme_override_constants/separation = 2
```

**Step 2: Verify**

Open `scenes/ui/DialogueBox.tscn` in the Godot editor. Confirm the `Label` and `SpeakerLabel` rects are inset 6px from all edges of the panel.

**Step 3: Commit**

```bash
git add scenes/ui/DialogueBox.tscn
git commit -m "feat: standardize DialogueBox padding to 6px on all sides"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2 | Different output files — `BattleScene.tscn` vs `DialogueBox.tscn` |

### Smoketest Checkpoint 1 — HUD panels flush and padded; DialogueBox padded

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

**Step 4: Confirm with user**
Verify in the running game:
- EnemyWindow and PartyWindow are the same height and sit flush side-by-side at the bottom of the screen with no visible gap between them
- Text in EnemyWindow has 6px clearance from all panel edges
- Trigger a dialogue line and confirm the dialogue text has visible 6px clearance from the DialogueBox edges

Wait for confirmation before proceeding to Batch 2.

---

## Batch 2: Runtime-built UI and sprites

### Task 3: hud.gd — 5 party slots with placeholder rows

**Files:**
- Modify: `scripts/ui/hud.gd`

**Depends on:** none
**Parallelizable with:** Task 4 — different output file (`battle_scene.gd`); no shared state.

**Step 1: Add `custom_minimum_size` to `_make_panel()`**

Inside `_make_panel()`, add `row.custom_minimum_size = Vector2(0, 12)` immediately after `row.add_theme_constant_override("separation", 3)`:

```gdscript
func _make_panel(combatant: Combatant) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = combatant.character_name + "Panel"
	row.custom_minimum_size = Vector2(0, 12)
	row.add_theme_constant_override("separation", 3)
	# ... rest unchanged
```

**Step 2: Add `_make_placeholder_panel()` function**

Add this function after `_make_panel()`:

```gdscript
func _make_placeholder_panel() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PlaceholderPanel"
	row.custom_minimum_size = Vector2(0, 12)
	row.add_theme_constant_override("separation", 3)
	row.modulate = Color(0.5, 0.5, 0.5, 0.5)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "---"
	name_label.custom_minimum_size = Vector2(NAME_MIN_WIDTH, 0)
	row.add_child(name_label)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "0"
	hp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(hp_label)

	var pp_label := Label.new()
	pp_label.name = "PPLabel"
	pp_label.text = "0"
	pp_label.custom_minimum_size = Vector2(STAT_NUM_WIDTH, 0)
	pp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_label.modulate = COLOR_PP
	row.add_child(pp_label)

	var atb_bar := ProgressBar.new()
	atb_bar.name = "ATBBar"
	atb_bar.max_value = 100.0
	atb_bar.value = 0.0
	atb_bar.show_percentage = false
	atb_bar.custom_minimum_size = Vector2(ATB_MIN_WIDTH, 6)
	atb_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(atb_bar)

	return row
```

**Step 3: Update `_build_panels()` to 5 slots**

Replace the existing `_build_panels()` body:

```gdscript
func _build_panels() -> void:
	var container: VBoxContainer = $PartyWindow/PartyRows
	for i in range(5):
		var panel: Control
		if i < _party.size():
			panel = _make_panel(_party[i])
		else:
			panel = _make_placeholder_panel()
		container.add_child(panel)
		_panels.append(panel)
```

**Step 4: Verify**

Run the battle scene. Confirm the PartyWindow shows exactly 5 rows: first 2 with real character names, HP, PP, and a live ATB bar; rows 3–5 showing `"---"`, `"0"`, `"0"`, flat ATB bar, all visibly greyed out. Confirm all 5 rows fit within the panel without clipping.

**Step 5: Commit**

```bash
git add scripts/ui/hud.gd
git commit -m "feat: expand HUD to 5 party slots with greyed-out placeholder rows"
```

---

### Task 4: battle_scene.gd — 5-slot sprite grid

**Files:**
- Modify: `scripts/battle/battle_scene.gd`

**Depends on:** none
**Parallelizable with:** Task 3 — different output file (`hud.gd`); no shared state.

**Step 1: Add slot position constants**

Add these two constants after the existing `const` declarations at the top of `battle_scene.gd`:

```gdscript
const SLOT_POSITIONS: Array[int] = [-64, -32, 0, 32, 64]
const PLACEHOLDER_MODULATE := Color(0.4, 0.4, 0.4, 0.5)
```

**Step 2: Replace `_setup_sprites()`**

Replace the entire existing `_setup_sprites()` function with:

```gdscript
func _setup_sprites() -> void:
	var party_textures: Array = [load(REID_TEX), load(IRIS_TEX)]

	for i in range(5):
		var sprite := Sprite2D.new()
		sprite.vframes = 6
		sprite.frame = 0
		sprite.flip_h = true
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		if i < party_textures.size():
			sprite.texture = party_textures[i]
		else:
			sprite.texture = load(REID_TEX)
			sprite.modulate = PLACEHOLDER_MODULATE
		$PartyContainer.add_child(sprite)

	var shade_rect := ColorRect.new()
	shade_rect.color = Color(0.5, 0.5, 0.5)
	shade_rect.size = Vector2(32, 32)
	shade_rect.position = Vector2(-16, -16)
	$EnemyContainer.add_child(shade_rect)
```

> **Note:** Slots 3–4 (`y = 32, 64` within `PartyContainer` at canvas y=90) will be partially or fully behind the HUD `CanvasLayer`. This is expected — the HUD overlays the 2D battlefield. Sprite positioning relative to the HUD is out of scope for this issue.

**Step 3: Verify**

Run the battle scene. Confirm:
- Reid and iris sprites are visible in the top portion of the PartyContainer with an 8px gap between them (32px pitch for 24px-tall frames)
- Three greyed-out reid silhouettes appear below (partially hidden by HUD is acceptable)
- No sprites overlap

**Step 4: Commit**

```bash
git add scripts/battle/battle_scene.gd
git commit -m "feat: position party sprites in 5-slot grid with 8px gaps"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 3, Task 4 | Different output files — `hud.gd` vs `battle_scene.gd`; no shared state |

### Smoketest Checkpoint 2 — Full HUD with 5 rows and 5-slot sprites

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

**Step 4: Confirm with user**
Verify all acceptance criteria from [issue #49](https://github.com/MatthieuGagne/the-hollow-men/issues/49):

- **AC1:** EnemyWindow and PartyWindow render at identical height (76px) at runtime
- **AC2:** No visible gap between the two panels; they are flush
- **AC3:** PartyWindow displays 5 rows with name, HP, PP, and ATB bar
- **AC4:** Text in EnemyWindow does not touch the panel border (6px margin visible on all sides)
- **AC5:** Text in PartyWindow rows does not touch the panel border (6px margin visible on all sides)
- **AC6:** DialogueBox text has 6px padding from all edges
- **AC7:** 5 party sprites in the battle field are spaced with 8px gaps; none overlap
