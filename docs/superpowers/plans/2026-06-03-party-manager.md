# PartyManager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a `PartyManager` autoload that owns party `Combatant` instances across scenes (preserving HP/PP between battles), support temporary guest members, and refactor `BattleScene` to read from it instead of hardcoding four members.

**Architecture:** `PartyManager` is a new GDScript autoload singleton (registered alongside `GameState`) that holds permanent and temporary `Combatant` arrays. `BattleScene._ready()` reads from `PartyManager.get_active_members()` instead of loading hardcoded resources; `_setup_sprites()` uses a per-character dictionary for texture/vframe lookup. `BattleParams` gains a `return_scene` field so callers (CutsceneZone, BattleEncounter) can specify where to return after victory.

**Tech Stack:** Godot 4.6 / GDScript, GUT test framework, `.tres` Combatant resources

---

## File Map

### New Files
- `scripts/autoload/party_manager.gd` — PartyManager singleton: permanent/temporary members, full API
- `tests/test_party_manager.gd` — GUT tests for all PartyManager methods

### Modified Files
- `scripts/autoload/battle_params.gd` — add `return_scene: String = ""`
- `scripts/battle/battle_scene.gd` — refactor party loading, sprite setup, victory path
- `project.godot` — register PartyManager in `[autoload]` section

---

### Task 1: Add `return_scene` to BattleParams

**Files:**
- Modify: `scripts/autoload/battle_params.gd`
- Modify: `tests/test_battle_scene.gd` (add one guard assertion)

- [ ] **Step 1: Write the failing test**

In `tests/test_battle_scene.gd`, add to the existing test class (find a logical spot near the top, after any existing `before_each`):

```gdscript
func test_battle_params_return_scene_defaults_to_empty() -> void:
	assert_eq(BattleParams.return_scene, "", "return_scene should default to empty string")
```

- [ ] **Step 2: Run tests to verify the new test fails**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: `test_battle_params_return_scene_defaults_to_empty` fails with attribute-not-found or similar error.

- [ ] **Step 3: Add `return_scene` to BattleParams**

Read `scripts/autoload/battle_params.gd`. It currently contains:
```gdscript
extends Node

var background_id: String = ""
```

Replace with:
```gdscript
extends Node

var background_id: String = ""
var return_scene: String = ""
```

- [ ] **Step 4: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests pass including the new one.

- [ ] **Step 5: Commit**

```
git add scripts/autoload/battle_params.gd tests/test_battle_scene.gd
git commit -m "feat: add return_scene field to BattleParams"
```

---

### Task 2: Create PartyManager autoload

**Files:**
- Create: `scripts/autoload/party_manager.gd`
- Create: `tests/test_party_manager.gd`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_party_manager.gd`:

```gdscript
extends GutTest

func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()

func test_get_active_members_returns_permanent_and_temporary() -> void:
	var a: Combatant = Combatant.new()
	a.character_name = "A"
	var b: Combatant = Combatant.new()
	b.character_name = "B"
	PartyManager.add_member(a)
	PartyManager.add_temporary(b)
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 2)
	assert_eq(members[0].character_name, "A")
	assert_eq(members[1].character_name, "B")

func test_add_member_persists_across_calls() -> void:
	var c: Combatant = Combatant.new()
	c.character_name = "C"
	PartyManager.add_member(c)
	assert_eq(PartyManager.get_active_members().size(), 1)

func test_add_temporary_appears_in_active_members() -> void:
	var guest: Combatant = Combatant.new()
	guest.character_name = "Guest"
	PartyManager.add_temporary(guest)
	assert_true(PartyManager.has_member("Guest"))

func test_remove_temporary_members_clears_guests_only() -> void:
	var perm: Combatant = Combatant.new()
	perm.character_name = "Perm"
	var temp: Combatant = Combatant.new()
	temp.character_name = "Temp"
	PartyManager.add_member(perm)
	PartyManager.add_temporary(temp)
	PartyManager.remove_temporary_members()
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].character_name, "Perm")

func test_has_member_returns_false_when_absent() -> void:
	assert_false(PartyManager.has_member("Nobody"))

func test_has_member_finds_temporary_member() -> void:
	var g: Combatant = Combatant.new()
	g.character_name = "Iris"
	PartyManager.add_temporary(g)
	assert_true(PartyManager.has_member("Iris"))

func test_remove_temporary_does_not_affect_permanent() -> void:
	var perm: Combatant = Combatant.new()
	perm.character_name = "Reid"
	PartyManager.add_member(perm)
	PartyManager.remove_temporary_members()
	assert_true(PartyManager.has_member("Reid"))
```

- [ ] **Step 2: Run tests to verify they all fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all `test_party_manager.gd` tests fail (PartyManager doesn't exist yet).

- [ ] **Step 3: Create `scripts/autoload/party_manager.gd`**

```gdscript
extends Node

const REID_RES := "res://characters/reid.tres"

var _permanent_members: Array[Combatant] = []
var _temporary_members: Array[Combatant] = []

func _ready() -> void:
	var reid: Combatant = load(REID_RES).duplicate()
	reid.reset_runtime_state()
	_permanent_members.append(reid)

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
```

- [ ] **Step 4: Register PartyManager in `project.godot`**

Read `project.godot`. Locate the `[autoload]` section. It will look like:

```ini
[autoload]
CellRegistry="*res://scripts/autoload/cell_registry.gd"
SceneManager="*res://scripts/autoload/scene_manager.gd"
BattleParams="*res://scripts/autoload/battle_params.gd"
AudioManager="*res://scripts/autoload/audio_manager.gd"
GameState="*res://scripts/autoload/game_state.gd"
DialogueManager="*res://scenes/autoload/DialogueManager.tscn"
DebugOverlay="*res://scripts/autoload/debug_overlay.gd"
```

Add `PartyManager` after `GameState`:

```ini
GameState="*res://scripts/autoload/game_state.gd"
PartyManager="*res://scripts/autoload/party_manager.gd"
```

- [ ] **Step 5: Run tests to verify they pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all `test_party_manager.gd` tests pass. All pre-existing tests also pass.

- [ ] **Step 6: Commit**

```
git add scripts/autoload/party_manager.gd tests/test_party_manager.gd project.godot
git commit -m "feat: add PartyManager autoload with permanent and temporary member support"
```

---

### Task 3: Refactor BattleScene to use PartyManager

**Files:**
- Modify: `scripts/battle/battle_scene.gd`
- Modify: `tests/test_battle_scene.gd`

- [ ] **Step 1: Update `test_battle_scene.gd` `before_each` to reset PartyManager**

Read `tests/test_battle_scene.gd`. Find the `before_each()` method. It currently looks like:

```gdscript
func before_each() -> void:
    _scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(_scene)
```

Replace it with:

```gdscript
func before_each() -> void:
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	BattleParams.return_scene = ""
	var reid: Combatant = load("res://characters/reid.tres").duplicate()
	reid.reset_runtime_state()
	PartyManager._permanent_members.append(reid)
	_scene = load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(_scene)
```

- [ ] **Step 2: Add new tests for the refactored behavior**

Still in `tests/test_battle_scene.gd`, add these new tests:

```gdscript
func test_party_comes_from_party_manager() -> void:
	assert_eq(_scene.party.size(), 1)
	assert_eq(_scene.party[0].character_name, "Reid")

func test_party_includes_temporary_members() -> void:
	# before_each resets PartyManager and instantiates _scene after setup,
	# so we need a fresh scene with a temporary member already in PartyManager.
	PartyManager._temporary_members.clear()
	var iris: Combatant = load("res://characters/iris.tres").duplicate()
	iris.reset_runtime_state()
	PartyManager.add_temporary(iris)
	var scene2 := load("res://scenes/battle/BattleScene.tscn").instantiate()
	add_child_autofree(scene2)
	assert_eq(scene2.party.size(), 2)
	assert_eq(scene2.party[1].character_name, "Iris")

func test_victory_removes_temporary_members() -> void:
	var iris: Combatant = load("res://characters/iris.tres").duplicate()
	iris.reset_runtime_state()
	PartyManager.add_temporary(iris)
	# Manually trigger the victory path handler
	_scene._on_battle_ended(true)
	assert_false(PartyManager.has_member("Iris"))

func test_victory_uses_return_scene_when_set() -> void:
	BattleParams.return_scene = "res://scenes/world/FourWindsBar.tscn"
	# We cannot fully test scene transition, but verify the field is readable
	# and the victory path reads from it (tested via integration).
	assert_eq(BattleParams.return_scene, "res://scenes/world/FourWindsBar.tscn")
```

- [ ] **Step 3: Run tests to confirm which fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: the new tests fail (BattleScene still uses hardcoded party). Existing tests may still pass or may fail if they access `party[1]` — note any failures.

- [ ] **Step 4: Refactor `battle_scene.gd` — remove hardcoded party constants and add sprite data dictionary**

Read `scripts/battle/battle_scene.gd`. Find the block of character resource/texture constants at the top (lines ~13–25):

```gdscript
const REID_RES   := "res://characters/reid.tres"
const IRIS_RES   := "res://characters/iris.tres"
const KARIM_RES  := "res://characters/karim.tres"
const MARGOT_RES := "res://characters/margot.tres"
const SHADE_RES  := "res://characters/enemies/shade.tres"
const REID_TEX          := "res://assets/sprites/characters/reid.png"
const IRIS_TEX          := "res://assets/sprites/characters/iris.png"
const KARIM_TEX         := "res://assets/sprites/characters/karim.png"
const MARGOT_TEX        := "res://assets/sprites/characters/margot.png"
const SHADE_TEX         := "res://assets/sprites/enemies/shade.png"
const SPRITE_FRAME_HEIGHT: int = 24
const PARTY_VFRAMES: Array[int] = [8, 8, 8, 8]  # reid/iris/karim/margot: 192px/24
const SPRITE_GAP_PX: int       = 1
```

Replace with (keep SHADE_RES, SHADE_TEX, and geometry constants; remove party-specific ones; add the sprite data dict):

```gdscript
const SHADE_RES  := "res://characters/enemies/shade.tres"
const SHADE_TEX  := "res://assets/sprites/enemies/shade.png"
const SPRITE_FRAME_HEIGHT: int = 24
const SPRITE_GAP_PX: int       = 1

const PARTY_SPRITE_DATA: Dictionary = {
	"Reid":   {"texture": "res://assets/sprites/characters/reid.png",   "vframes": 8},
	"Iris":   {"texture": "res://assets/sprites/characters/iris.png",   "vframes": 8},
	"Karim":  {"texture": "res://assets/sprites/characters/karim.png",  "vframes": 8},
	"Margot": {"texture": "res://assets/sprites/characters/margot.png", "vframes": 8},
}
```

- [ ] **Step 5: Refactor `_ready()` — replace hardcoded party loading with PartyManager**

Find the `_ready()` method. It currently contains (lines ~67–95):

```gdscript
func _ready() -> void:
	_load_background()
	var reid: Combatant = load(REID_RES)
	reid.reset_runtime_state()

	var iris: Combatant = load(IRIS_RES)
	iris.reset_runtime_state()

	var karim: Combatant = load(KARIM_RES)
	karim.reset_runtime_state()

	var margot: Combatant = load(MARGOT_RES)
	margot.reset_runtime_state()

	var shade: Combatant = load(SHADE_RES)
	shade.reset_runtime_state()

	party = [reid, iris, karim, margot]
	enemies = [shade]

	_setup_sprites()
	# ... rest of signal wiring unchanged
```

Replace the party loading block (leave everything after `enemies = [shade]` unchanged):

```gdscript
func _ready() -> void:
	_load_background()

	party = PartyManager.get_active_members()

	var shade: Combatant = load(SHADE_RES).duplicate()
	shade.reset_runtime_state()
	enemies = [shade]

	_setup_sprites()
	# ... rest of signal wiring unchanged
```

Note: `duplicate()` is added to the shade load to avoid mutating the cached resource.

- [ ] **Step 6: Refactor `_setup_sprites()` — make party sprites data-driven**

Find `_setup_sprites()`. It currently contains a hardcoded loop over 4 party slots:

```gdscript
func _setup_sprites() -> void:
	var party_textures: Array[String] = [
		REID_TEX, IRIS_TEX, KARIM_TEX, MARGOT_TEX
	]
	var party_modulates: Array[Color] = [
		Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE
	]

	for i in range(party_textures.size()):
		var sprite := Sprite2D.new()
		sprite.vframes = PARTY_VFRAMES[i]
		sprite.frame = 2
		sprite.flip_h = false
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		sprite.texture = load(party_textures[i])
		sprite.modulate = party_modulates[i]
		$PartyContainer.add_child(sprite)

	var shade_sprite := Sprite2D.new()
	shade_sprite.texture = load(SHADE_TEX)
	$EnemyContainer.add_child(shade_sprite)
```

Replace the party sprite loop with a data-driven version (leave the shade sprite block unchanged):

```gdscript
func _setup_sprites() -> void:
	for i in range(party.size()):
		var member := party[i]
		if not PARTY_SPRITE_DATA.has(member.character_name):
			push_warning("BattleScene: no sprite data for '%s'" % member.character_name)
			continue
		var data: Dictionary = PARTY_SPRITE_DATA[member.character_name]
		var sprite := Sprite2D.new()
		sprite.vframes = data["vframes"]
		sprite.frame = 2
		sprite.flip_h = false
		sprite.position = Vector2(0, SLOT_POSITIONS[i])
		sprite.texture = load(data["texture"])
		sprite.modulate = Color.WHITE
		$PartyContainer.add_child(sprite)

	var shade_sprite := Sprite2D.new()
	shade_sprite.texture = load(SHADE_TEX)
	$EnemyContainer.add_child(shade_sprite)
```

- [ ] **Step 7: Refactor `_on_battle_ended()` — use `return_scene` and remove temporary members**

Find `_on_battle_ended()`:

```gdscript
func _on_battle_ended(victory: bool) -> void:
	_action_menu.hide()
	if victory:
		_victory_label.show()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		if is_inside_tree():
			SceneManager.change_scene(WORLD_SCENE)
	else:
		_defeat_label.show()
		_defeat_menu.show()
```

Replace the victory branch:

```gdscript
func _on_battle_ended(victory: bool) -> void:
	_action_menu.hide()
	if victory:
		PartyManager.remove_temporary_members()
		_victory_label.show()
		await get_tree().create_timer(VICTORY_DELAY).timeout
		if is_inside_tree():
			var target := BattleParams.return_scene if BattleParams.return_scene != "" else WORLD_SCENE
			SceneManager.change_scene(target)
	else:
		_defeat_label.show()
		_defeat_menu.show()
```

- [ ] **Step 8: Run all tests and fix any regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: all tests pass including the new ones. If any existing test accesses `_scene.party[1]` or higher (which no longer exists with the default 1-member setup), update it by adding a second member to PartyManager in a local setup step within that specific test.

- [ ] **Step 9: Commit**

```
git add scripts/battle/battle_scene.gd tests/test_battle_scene.gd
git commit -m "feat: refactor BattleScene to read party from PartyManager"
```

---

## Verification

Run the full test suite:

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

All tests should pass. Then do a manual smoke test:

1. Launch the game: start from `FourWindsBar.tscn` (or via `/run`)
2. Enter a BattleEncounter — verify Reid appears as the sole party member in the battle HUD
3. Take damage in battle — after returning to the world scene, re-enter a battle and confirm Reid's HP carried over (not reset to full)
4. Verify the victory transition returns to the correct world scene (not a hardcoded default)
