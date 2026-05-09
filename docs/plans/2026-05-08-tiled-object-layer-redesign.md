# Tiled Object Layer Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the dual-layer object system (Objects tile layer + Interactions rect objects) with a single Interactions object group using Tiled tile objects, so objects of any size are placed, moved, and configured entirely within Tiled.

**Architecture:** `objects.tsx` becomes a collection-of-images tileset (one tile per object type, each at its natural pixel size). YATI instantiates each Interactions tile object into its `res_path` scene, merges TSX tile default properties + per-object overrides as node metadata, and calls `_ready()` — which reads `tile_cols × tile_rows` for multi-cell `CellRegistry` registration and loads `sprite_texture` for its `Sprite2D`. The Objects tile layer is removed entirely; wall detection falls through to `CellRegistry` alone.

**Tech Stack:** Godot 4.6 / GDScript, YATI importer, Tiled 1.8, Python 3 (sync_tsx.py)

## Open questions (must resolve before starting)

_(none — resolved in grill-me session)_

---

## Batch 1 — TSX restructure + pipeline fix

### Task 1: Restructure `objects.tsx` as collection tileset

**Files:**
- Modify: `maps/objects.tsx`

**Depends on:** none
**Parallelizable with:** Task 2 — different output files, no shared state

**Step 1: Write the content**

Replace the entire file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.8" tiledversion="1.8.2" name="objects" tilewidth="16" tileheight="16" tilecount="2" columns="0" objectalignment="topleft">
 <tile id="0" type="instance">
  <properties>
   <property name="blocks_movement" type="bool" value="true"/>
   <property name="examine_text" value=""/>
   <property name="object_name" value="Desk"/>
   <property name="res_path" type="file" value="res://scenes/world/WorldObject.tscn"/>
   <property name="sprite_texture" type="file" value="res://assets/objects/desk_placeholder.png"/>
   <property name="tile_cols" type="int" value="3"/>
   <property name="tile_rows" type="int" value="1"/>
  </properties>
  <image source="../assets/objects/desk_placeholder.png" width="48" height="16"/>
 </tile>
 <tile id="1" type="instance">
  <properties>
   <property name="blocks_movement" type="bool" value="true"/>
   <property name="object_name" value="Iris"/>
   <property name="res_path" type="file" value="res://scenes/world/NPC.tscn"/>
   <property name="sprite_texture" type="file" value="res://assets/objects/iris.png"/>
   <property name="tile_cols" type="int" value="1"/>
   <property name="tile_rows" type="int" value="1"/>
  </properties>
  <image source="../assets/objects/iris.png" width="16" height="24"/>
 </tile>
</tileset>
```

Key design decisions baked in:
- `columns="0"` — Tiled marker for collection-of-images tileset; each tile has its own `<image>`
- `objectalignment="topleft"` — YATI sets instance `Position = (objX, objY)` with no alignment correction; topleft ensures x/y in TMX equals top-left pixel of the tile, so `get_cell() = Vector2i(x/16, y/16)` is correct
- `sprite_texture` is a `file`-type property; YATI's `HandleProperties` passes file properties as strings to `set_meta()`, and `load()` accepts `res://` paths directly
- The desk tile's `examine_text` defaults to `""` — per-object TMX overrides supply the real text

**Step 2: Verify**

```bash
cat maps/objects.tsx
```
Confirm `columns="0"` and two tiles with their own `<image>` elements.

**Step 3: Commit**

```bash
git add maps/objects.tsx
git commit -m "feat: restructure objects.tsx as collection-of-images tileset"
```

---

### Task 2: Update `sync_tsx.py` to skip collection tilesets

**Files:**
- Modify: `scripts/sync_tsx.py`

**Depends on:** none
**Parallelizable with:** Task 1 — different output files, no shared state

**Step 1: Write the fix**

The current script does `re.search(r'<image source="([^"]+)"', text)` which would match the first tile's `<image>` in a collection TSX, then wrongly compute `columns` and patch the file. Add an early-exit guard for `columns="0"`:

In `sync_tsx.py`, find the `sync()` function. After the line that matches `<image source=`, add a guard **before** opening the image file:

```python
def sync(tsx: Path) -> None:
    text = tsx.read_text()
    # Collection tilesets (columns="0") manage their own tiles; skip patching.
    if re.search(r'columns="0"', text):
        print(f"  skip {tsx.name}: collection tileset")
        return
    m = re.search(r'<image source="([^"]+)"', text)
    if not m:
        return
    # ... rest unchanged
```

**Step 2: Verify**

```bash
python3 scripts/sync_tsx.py
```
Expected output includes: `skip objects.tsx: collection tileset`

**Step 3: Commit**

```bash
git add scripts/sync_tsx.py
git commit -m "fix: skip collection tilesets in sync_tsx.py"
```

---

### Task 3: Run `make assets` and verify pipeline

**Files:** none (build artifacts only)

**Depends on:** Task 1, Task 2
**Parallelizable with:** none — requires Tasks 1 and 2 to complete first; is a verification step, not a source change

**Step 1: Copy art and sync TSX files**

```bash
make copy-art sync-tsx
```
Expected: `skip objects.tsx: collection tileset` printed; `assets/objects/iris.png` now exists.

**Step 2: Verify**

```bash
ls assets/objects/
```
Confirm `iris.png` and `desk_placeholder.png` are present.

**Step 3: No commit needed** — build artifacts are gitignored.

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2 | Different output files, no shared state |
| B (sequential) | Task 3 | Depends on Group A — must run after both complete |

### Smoketest Checkpoint 1 — TSX restructure and pipeline

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
The game should launch and play identically to before (no TSX or GDScript logic has changed yet). Confirm no startup errors in the console and that the desk and Iris still work as before.

---

## Batch 2 — WorldObject multi-cell registration + Sprite2D (TDD)

### Task 4: Write failing GUT tests for WorldObject changes

**Files:**
- Modify: `tests/test_world_object.gd`

**Depends on:** none
**Parallelizable with:** none — must write tests before implementation to honour TDD gate; Task 5 and Task 6 both depend on this task

**Step 1: Write the failing GUT tests**

Replace `tests/test_world_object.gd` with:

```gdscript
extends GutTest

var _obj: Node2D


func before_each() -> void:
	CellRegistry.clear()
	_obj = Node2D.new()
	_obj.set_script(load("res://scripts/world/world_object.gd"))
	_obj.position = Vector2(80.0, 64.0)  # tile (5, 4)
	_obj.set_meta("examine_text", "A cluttered desk.")
	_obj.set_meta("object_name", "Desk")
	_obj.set_meta("sprite_texture", "res://assets/objects/desk_placeholder.png")
	_obj.set_meta("blocks_movement", true)
	# tile_cols/tile_rows not set → defaults to 1×1


func after_each() -> void:
	if is_instance_valid(_obj):
		_obj.free()
	CellRegistry.clear()


func test_get_cell_returns_correct_tile() -> void:
	assert_eq(_obj.get_cell(), Vector2i(5, 4))


func test_get_cell_at_origin_tile() -> void:
	_obj.position = Vector2(0.0, 0.0)
	assert_eq(_obj.get_cell(), Vector2i(0, 0))


func test_properties_read_from_meta_on_ready() -> void:
	add_child(_obj)
	assert_eq(_obj.examine_text, "A cluttered desk.")
	assert_eq(_obj.object_name, "Desk")
	assert_eq(_obj.sprite_texture, "res://assets/objects/desk_placeholder.png")


func test_single_cell_registers_in_cell_registry_on_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.has(Vector2i(5, 4)))
	assert_eq(CellRegistry.get_occupant(Vector2i(5, 4)), _obj)


func test_multi_cell_registers_all_covered_cells() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	# Desk at (5,4) with tile_cols=3 → covers (5,4), (6,4), (7,4)
	assert_true(CellRegistry.has(Vector2i(5, 4)))
	assert_true(CellRegistry.has(Vector2i(6, 4)))
	assert_true(CellRegistry.has(Vector2i(7, 4)))
	assert_eq(CellRegistry.get_occupant(Vector2i(6, 4)), _obj)


func test_multi_cell_all_covered_cells_are_blocked() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(6, 4)))
	assert_true(CellRegistry.is_blocked(Vector2i(7, 4)))


func test_multi_cell_unregisters_all_on_exit() -> void:
	_obj.set_meta("tile_cols", 3)
	_obj.set_meta("tile_rows", 1)
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.has(Vector2i(5, 4)))
	assert_false(CellRegistry.has(Vector2i(6, 4)))
	assert_false(CellRegistry.has(Vector2i(7, 4)))


func test_unregisters_from_cell_registry_on_exit() -> void:
	add_child(_obj)
	_obj.queue_free()
	await get_tree().process_frame
	assert_false(CellRegistry.has(Vector2i(5, 4)))


func test_is_blocked_true_via_registry_after_ready() -> void:
	add_child(_obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))


func test_is_blocked_true_from_export_property_without_preset_meta() -> void:
	var obj := Node2D.new()
	obj.set_script(load("res://scripts/world/world_object.gd"))
	obj.position = Vector2(80.0, 64.0)
	obj.blocks_movement = true
	add_child(obj)
	assert_true(CellRegistry.is_blocked(Vector2i(5, 4)))
	obj.free()


func test_sprite_texture_loads_texture_on_ready() -> void:
	add_child(_obj)
	var sprite: Sprite2D = _obj.get_node("Sprite2D")
	assert_not_null(sprite, "WorldObject must have a Sprite2D child")
	assert_not_null(sprite.texture, "Sprite2D.texture must be set when sprite_texture meta is a valid path")


func test_empty_sprite_texture_leaves_texture_null() -> void:
	_obj.set_meta("sprite_texture", "")
	add_child(_obj)
	var sprite: Sprite2D = _obj.get_node("Sprite2D")
	assert_not_null(sprite)
	assert_null(sprite.texture, "Sprite2D.texture must remain null when sprite_texture is empty")


func test_interact_with_examine_text_calls_show_text() -> void:
	var obj := WorldObject.new()
	obj.examine_text = "A dusty shelf."
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	mock_box.skip_or_dismiss()
	assert_eq(mock_box.get_displayed_text(), "A dusty shelf.")

	mock_box.free()
	obj.free()


func test_interact_with_no_examine_text_does_nothing() -> void:
	var obj := WorldObject.new()
	obj.examine_text = ""
	add_child(obj)

	var mock_box := Control.new()
	mock_box.set_script(load("res://scripts/ui/dialogue_box.gd"))
	add_child(mock_box)

	obj.interact(mock_box, null)
	assert_false(mock_box.visible)

	mock_box.free()
	obj.free()
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_world_object.gd
```
Expected: FAIL — `sprite_texture` property missing, `Sprite2D` child missing, multi-cell tests fail.

**Step 3: Commit**

```bash
git add tests/test_world_object.gd
git commit -m "test: update test_world_object for multi-cell and sprite_texture"
```

---

### Task 5: Update `world_object.gd` — multi-cell registration + sprite_texture

**Files:**
- Modify: `scripts/world/world_object.gd`

**Depends on:** Task 4
**Parallelizable with:** none — needs Task 4 tests to be failing first; Task 6 (WorldObject.tscn) can be done concurrently since it touches a different file, but the tests will only pass once both Task 5 and Task 6 are done

**Step 1: Write minimal implementation**

```gdscript
class_name WorldObject
extends Node2D

const TILE_SIZE: int = 16

@export var examine_text: String = ""
@export var object_name: String = ""
@export var sprite_texture: String = ""
@export var blocks_movement: bool = true
@export var tile_cols: int = 1
@export var tile_rows: int = 1

var _registered_cells: Array[Vector2i] = []


func _ready() -> void:
	examine_text    = get_meta("examine_text",    examine_text)
	object_name     = get_meta("object_name",     object_name)
	sprite_texture  = get_meta("sprite_texture",  sprite_texture)
	blocks_movement = get_meta("blocks_movement", blocks_movement)
	tile_cols       = get_meta("tile_cols",       tile_cols)
	tile_rows       = get_meta("tile_rows",       tile_rows)
	set_meta("blocks_movement", blocks_movement)

	if sprite_texture != "":
		$Sprite2D.texture = load(sprite_texture)

	var origin: Vector2i = get_cell()
	for row: int in range(tile_rows):
		for col: int in range(tile_cols):
			var cell := origin + Vector2i(col, row)
			_registered_cells.append(cell)
			CellRegistry.register(cell, self)


func _exit_tree() -> void:
	for cell: Vector2i in _registered_cells:
		CellRegistry.unregister(cell)


func get_cell() -> Vector2i:
	return Vector2i(int(position.x) / TILE_SIZE, int(position.y) / TILE_SIZE)


func interact(dialogue_box: Node, _yarn_bridge: Node) -> void:
	if examine_text != "":
		dialogue_box.show_text(examine_text)
```

**Step 2: Run tests (expect partial failure — Sprite2D child still missing)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_world_object.gd
```
Expected: Multi-cell tests pass; `test_sprite_texture_loads_texture_on_ready` and `test_empty_sprite_texture_leaves_texture_null` fail because `WorldObject.tscn` has no Sprite2D child yet.

**Step 3: Commit**

```bash
git add scripts/world/world_object.gd
git commit -m "feat: add multi-cell registration and sprite_texture to WorldObject"
```

---

### Task 6: Add `Sprite2D` child to `WorldObject.tscn`

**Files:**
- Modify: `scenes/world/WorldObject.tscn`

**Depends on:** Task 5
**Parallelizable with:** none — the Sprite2D node must exist for the `$Sprite2D` reference in world_object.gd to resolve; this is the second half of the Task 5 implementation

**Step 1: Write the content**

Replace `scenes/world/WorldObject.tscn` with:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/world_object.gd" id="1_script"]

[node name="WorldObject" type="Node2D"]
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
centered = false
```

`centered = false`: texture top-left anchors to node origin. With `objectalignment="topleft"` in the TSX, YATI sets the instance position to the tile's top-left pixel — so the sprite renders exactly over the covered cells with no offset arithmetic.

**Step 2: Verify**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_world_object.gd
```
Expected: ALL tests pass.

**Step 3: Refactor checkpoint**

Ask: "Does the multi-cell registration generalize for any tile_cols/tile_rows, or is it hard-coded for the 3×1 desk?"
— Answer: the nested `range(tile_rows)` / `range(tile_cols)` loops generalize. No follow-up issue needed.

**Step 4: Commit**

```bash
git add scenes/world/WorldObject.tscn
git commit -m "feat: add Sprite2D child to WorldObject.tscn (centered=false)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 4 | Write tests first — TDD gate |
| B (sequential) | Task 5 | Depends on Task 4 (tests must exist) |
| C (sequential) | Task 6 | Depends on Task 5 (`$Sprite2D` reference) |

### Smoketest Checkpoint 2 — WorldObject multi-cell + Sprite2D

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
The game should launch without errors. The desk and Iris should appear as before (the desk still renders via the old YATI-generated Objects tile layer; Iris is still the manually-placed node in RoomPOC.tscn). The structural changes are not yet visible in-game — confirm no regressions.

---

## Batch 3 — NPC update + player.gd cleanup (TDD)

### Task 7: Write failing GUT test for NPC `yarn_node_id` meta-reading

**Files:**
- Modify: `tests/test_npc.gd`

**Depends on:** none
**Parallelizable with:** Task 10 — different output files, no shared state

**Step 1: Write the failing GUT test**

Add one test to `tests/test_npc.gd` (append after the existing tests):

```gdscript
func test_yarn_node_id_read_from_meta_on_ready() -> void:
	var npc := Node2D.new()
	npc.set_script(load("res://scripts/world/npc.gd"))
	npc.set_meta("yarn_node_id", "iris_intro")
	add_child(npc)
	assert_eq(npc.yarn_node_id, "iris_intro")
	npc.free()
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_npc.gd
```
Expected: FAIL — `yarn_node_id` is not read from meta; remains `""`.

**Step 3: Commit**

```bash
git add tests/test_npc.gd
git commit -m "test: add yarn_node_id meta-reading test for NPC"
```

---

### Task 8: Update `npc.gd` — read `yarn_node_id` from meta in `_ready()`

**Files:**
- Modify: `scripts/world/npc.gd`

**Depends on:** Task 7
**Parallelizable with:** none — needs Task 7 test to be failing first

**Step 1: Write minimal implementation**

```gdscript
class_name NPC
extends WorldObject

@export var yarn_node_id: String = ""


func _ready() -> void:
	super._ready()
	yarn_node_id = get_meta("yarn_node_id", yarn_node_id)


func interact(_dialogue_box: Node, yarn_bridge: Node) -> void:
	if yarn_node_id == "" or yarn_bridge == null:
		return
	yarn_bridge.start_dialogue(yarn_node_id)
```

**Step 2: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_npc.gd
```
Expected: PASS.

**Step 3: Refactor checkpoint**

Ask: "Does NPC._ready() break if called without node meta set?" — No: `get_meta("yarn_node_id", yarn_node_id)` uses the export default as fallback. No follow-up issue needed.

**Step 4: Commit**

```bash
git add scripts/world/npc.gd
git commit -m "feat: read yarn_node_id from meta in NPC._ready()"
```

---

### Task 9: Create `NPC.tscn`

**Files:**
- Create: `scenes/world/NPC.tscn`

**Depends on:** Task 8
**Parallelizable with:** none — npc.gd must exist before the scene can reference it; this is the scene counterpart to the script

**Step 1: Write the content**

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/npc.gd" id="1_script"]

[node name="NPC" type="Node2D"]
script = ExtResource("1_script")

[node name="Sprite2D" type="Sprite2D" parent="."]
centered = false
```

Mirrors `WorldObject.tscn` exactly — same structure, different script. `centered=false` for the same alignment reason.

**Step 2: Verify**

Open the Godot editor and confirm `NPC.tscn` loads without errors and has a `Sprite2D` child.

Alternatively, verify headlessly:
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests still pass (no regressions).

**Step 3: Commit**

```bash
git add scenes/world/NPC.tscn
git commit -m "feat: add NPC.tscn with Sprite2D child"
```

---

### Task 10: Update `player.gd` — remove `_objects_layer`, simplify `_is_wall()`

**Files:**
- Modify: `scripts/world/player.gd`

**Depends on:** none
**Parallelizable with:** Task 7 — different output files; however this task must be completed before room_poc.tmx is modified (Task 11), because removing the Objects tile layer from TMX causes the `_objects_layer` @onready to fail at runtime

**Step 1: Write the changes**

Remove the `_objects_layer` @onready declaration and simplify `_is_wall()`:

```gdscript
# Remove this line:
@onready var _objects_layer: TileMapLayer = $"../room_poc/Objects"

# Simplify _is_wall() from:
func _is_wall(world_pos: Vector2) -> bool:
    var cell: Vector2i = _world_layer.local_to_map(world_pos)
    var td: TileData = _world_layer.get_cell_tile_data(cell)
    if td == null:
        return true
    if td.get_meta("class", "") == "wall":
        return true
    var obj_td: TileData = _objects_layer.get_cell_tile_data(cell)
    return obj_td != null and obj_td.get_meta("class", "") == "wall"

# To:
func _is_wall(world_pos: Vector2) -> bool:
    var cell: Vector2i = _world_layer.local_to_map(world_pos)
    var td: TileData = _world_layer.get_cell_tile_data(cell)
    if td == null:
        return true
    return td.get_meta("class", "") == "wall"
```

Object blocking (desk, Iris) is already handled by `CellRegistry.is_blocked(target_cell)` in `_try_move()` — the `_objects_layer` check was redundant. After this change, the function is identical in behaviour for the World tile layer, and CellRegistry handles everything else.

**Step 2: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass (player tests only cover static methods, none reference `_objects_layer`).

**Step 3: Refactor checkpoint**

Ask: "Could any wall tile exist only in the Objects tile layer (not the World layer)?" — No: looking at `objects.tsx`, tiles had `type="wall"` for object-tile blocking. That was the legacy approach. Now CellRegistry handles all object blocking. No follow-up issue needed.

**Step 4: Commit**

```bash
git add scripts/world/player.gd
git commit -m "feat: remove _objects_layer from player.gd — CellRegistry handles object blocking"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 7, Task 10 | Different output files, no shared state |
| B (sequential) | Task 8 | Depends on Task 7 (failing test must exist) |
| C (sequential) | Task 9 | Depends on Task 8 (npc.gd must exist) |

### Smoketest Checkpoint 3 — NPC + player.gd cleanup

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
The game should launch and play identically to before. The `_objects_layer` reference is gone from `player.gd`, but the Objects tile layer is still in the TMX (it hasn't been removed yet) — however it is no longer referenced at runtime. Confirm desk blocking, Iris blocking, and Iris dialogue all still work.

---

## Batch 4 — TMX / scene migration + full integration

### Task 11: Edit `room_poc.tmx` — remove Objects layer, replace desk objects, add Iris tile object

**Files:**
- Modify: `maps/room_poc.tmx`

**Depends on:** Task 10 (player.gd must no longer reference _objects_layer before the Objects layer is removed)
**Parallelizable with:** Task 12 — different output files (TMX vs TSCN)

**Step 1: Write the content**

Replace `maps/room_poc.tmx` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.8" tiledversion="1.8.2" orientation="orthogonal" renderorder="right-down" width="15" height="11" tilewidth="16" tileheight="16" infinite="0" nextlayerid="4" nextobjectid="3">
 <tileset firstgid="1" source="placeholder.tsx"/>
 <tileset firstgid="11" source="objects.tsx"/>
 <layer id="1" name="World" width="15" height="11">
  <data encoding="csv">
2147483656,10,2,3,4,4,5,10,10,2,3,4,5,10,8,
2147483656,7,9,7,7,7,7,7,7,9,7,7,7,7,8,
2147483656,6,6,6,6,1,6,6,6,6,3221225473,6,6,1,8,
2147483656,6,1,6,6,6,6,6,6,2147483649,6,6,6,6,8,
2147483656,2147483649,6,6,6,6,6,6,6,6,6,1,6,6,8,
2147483656,6,6,1073741825,6,6,6,6,6,3221225473,6,6,6,6,8,
2147483656,6,1,6,6,6,6,6,6,6,6,6,6,6,8,
2147483656,6,6,6,6,2147483649,6,2147483649,6,1,6,6,6,6,8,
2147483656,6,6,6,6,1,6,1,6,6,6,1,6,2147483649,8,
2147483656,6,6,6,3221225473,6,6,6,6,6,1073741825,6,6,6,8,
2147483656,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,1610612744,8
  </data>
 </layer>
 <objectgroup id="2" name="Interactions">
  <object id="1" gid="11" x="80" y="64" width="48" height="16">
   <properties>
    <property name="examine_text" value="A cluttered desk covered in papers."/>
   </properties>
  </object>
  <object id="2" gid="12" x="192" y="128" width="16" height="24">
   <properties>
    <property name="yarn_node_id" value="iris_intro"/>
   </properties>
  </object>
 </objectgroup>
</map>
```

Key changes from the original:
- Objects tile layer (`<layer id="3" name="Objects">`) removed entirely
- 3 separate desk rect objects → 1 desk tile object (`gid="11"`, width=48, height=16) at (80,64) = cell (5,4)
- Iris tile object added (`gid="12"`, width=16, height=24) at (192,128) = cell (12,8), matching her current position in `RoomPOC.tscn`
- `nextlayerid="4"` preserved; `nextobjectid="3"` (ids 1 and 2 are now used)
- `firstgid="11"` for objects.tsx is unchanged — placeholder.tsx still has 10 tiles

**Step 2: Verify syntax**

```bash
python3 -c "import xml.etree.ElementTree as ET; ET.parse('maps/room_poc.tmx'); print('XML valid')"
```
Expected: `XML valid`

**Step 3: Commit**

```bash
git add maps/room_poc.tmx
git commit -m "feat: replace Objects tile layer with tile objects in Interactions group"
```

---

### Task 12: Remove manually-placed Iris from `RoomPOC.tscn`

**Files:**
- Modify: `scenes/world/RoomPOC.tscn`

**Depends on:** Task 11 (Iris must exist in room_poc.tmx before removing her from RoomPOC.tscn, so she's never absent from the scene)
**Parallelizable with:** Task 11 — the files are independent, but Task 11 should complete first to avoid a frame where Iris is in neither place

**Step 1: Write the changes**

Remove the following lines from `scenes/world/RoomPOC.tscn`:

1. Remove the ext_resource for `iris.png` (the texture):
   ```
   [ext_resource type="Texture2D" path="res://assets/sprites/characters/iris.png" id="10_iris"]
   ```

2. Remove the Iris Node2D and its Sprite2D child:
   ```
   [node name="Iris" type="Node2D" parent="."]
   position = Vector2(200, 136)
   y_sort_origin = 8
   script = ExtResource("9_npc")
   yarn_node_id = "iris_intro"
   blocks_movement = true

   [node name="Sprite2D" type="Sprite2D" parent="Iris"]
   texture = ExtResource("10_iris")
   offset = Vector2(0, -4)
   hframes = 1
   vframes = 6
   ```

   The ext_resource for `npc.gd` (`id="9_npc"`) can also be removed if no other node in the scene references it.

After this edit, Iris is instantiated entirely via YATI from `room_poc.tmx` → `NPC.tscn`, with position and properties driven by the tile object.

**Step 2: Verify**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 3: Commit**

```bash
git add scenes/world/RoomPOC.tscn
git commit -m "feat: remove manually-placed Iris — now instantiated by YATI from room_poc.tmx"
```

---

### Task 13: Run `make assets` and headless reimport

**Files:** `.godot/imported/` (build artifacts, gitignored)

**Depends on:** Task 11, Task 12
**Parallelizable with:** none — both TMX and scene edits must be complete before reimport

**Step 1: Delete stale TMX import cache**

```bash
rm -f .godot/imported/*.tmx-*.md5 .godot/imported/*.tmx-*.tscn
```

**Step 2: Run full asset pipeline**

```bash
make assets
```
Expected:
- `copy-art` copies `iris.png` and `desk_placeholder.png` to `assets/objects/`
- `sync-tsx` prints `skip objects.tsx: collection tileset`
- `import` runs headless Godot reimport without errors

**Step 3: Verify import output**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 4: No commit needed** — import artifacts are gitignored.

---

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 11, Task 12 | Different output files; Task 12 should run after Task 11 completes to avoid a missing-Iris frame, but both can be dispatched together |
| B (sequential) | Task 13 | Depends on Group A — reimport must run after both files are updated |

### Smoketest Checkpoint 4 — Full integration

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

Verify the following acceptance criteria in the running game:

- **AC1**: Open `room_poc.tmx` in Tiled — there is exactly one desk object in the Interactions layer. Moving it requires touching only that one object (no tile layer to sync).
- **AC2**: The desk (3 tiles wide) renders at the correct position. Walking into any of the 3 desk cells is blocked. Pressing interact while facing the desk shows "A cluttered desk covered in papers."
- **AC3**: Iris appears at cell (12,8) (near the right side of the room). Reid cannot walk through her. Pressing interact triggers her YarnSpinner dialogue (`iris_intro`).
- **AC4**: No runtime errors in the Godot console on startup or during play.
- **AC5**: All GUT tests pass (covered above).
- **AC6**: `make assets` completed without errors; no missing sprite warnings in the Godot console.
