# POC Walkable Room Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first playable scene — a player character moving tile-by-tile through a small room — and establish the Tiled → Godot map import pipeline for all future maps.

**Architecture:** `RoomPOC.tscn` (Node2D root) hosts (1) a `TileMapLayer` imported from `maps/room_poc.tmx` via YATI, named `room_poc`; (2) a `Player` (CharacterBody2D) that does a tile-data lookup on the "Walls" TileMapLayer before each step; (3) a `Camera2D` child of the player for automatic following. No physics engine — wall detection is a pure `get_cell_source_id()` check.

**Tech Stack:** GDScript 4.6, `TileMapLayer` node (YATI produces this), GUT v9.x for TDD, Python 3 stdlib (no external packages) for asset generation.

## Open questions (must resolve before starting)

- None — all decisions captured in grill-me session and PRD #3.

---

## Batch 1: Project Infrastructure

### Task 1: Install GUT addon

**Files:**
- Create: `addons/gut/` (GUT release contents)
- Modify: `project.godot` (enable GUT plugin)

**Depends on:** none
**Parallelizable with:** Task 3 — writes different files. Cannot parallelize with Task 2 (both write `project.godot`).

**Step 1: Download GUT release**

```bash
gh release download --repo bitwes/Gut --pattern "GUT-*.zip" -D /tmp/gut_dl/
ls /tmp/gut_dl/
```

Expected: one `.zip` file listed.

**Step 2: Extract into addons/**

```bash
unzip /tmp/gut_dl/GUT-*.zip -d /tmp/gut_extracted/
cp -r /tmp/gut_extracted/addons/gut addons/
ls addons/gut/gut_cmdln.gd
```

Expected: `addons/gut/gut_cmdln.gd` exists.

**Step 3: Enable GUT plugin in project.godot**

In `project.godot`, find the `[editor_plugins]` section and add GUT to the enabled list alongside YATI:
```
enabled=PackedStringArray("res://addons/gut/plugin.cfg", "res://addons/YATI/plugin.cfg")
```

**Step 4: Verify GUT starts**

```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | head -30
```

Expected: GUT prints version string and exits cleanly. A warning about no tests found is fine.

**Step 5: Commit**

```bash
git add addons/gut/ project.godot
git commit -m "chore: install GUT addon for TDD"
```

---

### Task 2: Add input actions to project.godot

**Files:**
- Modify: `project.godot`

**Depends on:** Task 1 (same file — must not edit concurrently)
**Parallelizable with:** Task 3 (writes different files)

**Step 1: Append input map section to project.godot**

Add this block at the end of `project.godot` (after the `[rendering]` section):

```ini
[input]

move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

Physical keycodes reference: W=87, S=83, A=65, D=68, Up=4194320, Down=4194322, Left=4194319, Right=4194321.

**Step 2: Verify**

```bash
grep -c "move_up\|move_down\|move_left\|move_right" project.godot
```

Expected: 4

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: add WASD + arrow key input actions"
```

---

### Task 3: Generate placeholder tileset + Tiled map files

**Files:**
- Create: `assets/tilesets/placeholder.png`
- Create: `maps/placeholder.tsx`
- Create: `maps/room_poc.tmx`

**Depends on:** none
**Parallelizable with:** Task 2

**Step 1: Run asset generation script**

Save the following as `/tmp/gen_map_assets.py` and run it from the worktree root:

```python
#!/usr/bin/env python3
"""Generates placeholder.png, placeholder.tsx, and room_poc.tmx. No external deps."""
import struct, zlib, os

# ── PNG generation ──────────────────────────────────────────────────────────
def png_chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

def make_png(path: str, pixels: list) -> None:
    h, w = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + bytes([c for px in row for c in px]) for row in pixels)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(png_chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(png_chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(png_chunk(b"IEND", b""))

FLOOR = (40, 40, 60)    # dark blue-grey
WALL  = (130, 90, 150)  # muted purple

floor_tile = [[FLOOR] * 16 for _ in range(16)]
wall_tile  = [[WALL]  * 16 for _ in range(16)]
spritesheet = [fr + wr for fr, wr in zip(floor_tile, wall_tile)]
make_png("assets/tilesets/placeholder.png", spritesheet)
print("Created assets/tilesets/placeholder.png (32×16, 2 tiles: floor at x=0, wall at x=16)")

# ── TSX (Tiled tileset definition) ──────────────────────────────────────────
tsx = """\
<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.10.2" name="placeholder"
 tilewidth="16" tileheight="16" tilecount="2" columns="2">
 <image source="../assets/tilesets/placeholder.png" width="32" height="16"/>
</tileset>
"""
os.makedirs("maps", exist_ok=True)
with open("maps/placeholder.tsx", "w") as f:
    f.write(tsx)
print("Created maps/placeholder.tsx")

# ── TMX (Tiled map): 25×15, outer-wall border ────────────────────────────────
W, H = 25, 15
FLOOR_GID, WALL_GID = 1, 2  # 1-indexed GIDs

def ground_row():
    return ",".join([str(FLOOR_GID)] * W)

def walls_row(r):
    if r == 0 or r == H - 1:
        return ",".join([str(WALL_GID)] * W)
    return str(WALL_GID) + "," + ",".join(["0"] * (W - 2)) + "," + str(WALL_GID)

ground_csv = "\n".join(ground_row() for _ in range(H))
walls_csv  = "\n".join(walls_row(r) for r in range(H))

tmx = f"""\
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal"
 renderorder="right-down" width="{W}" height="{H}"
 tilewidth="16" tileheight="16" infinite="0"
 nextlayerid="3" nextobjectid="1">
 <tileset firstgid="1" source="placeholder.tsx"/>
 <layer id="1" name="Ground" width="{W}" height="{H}">
  <data encoding="csv">
{ground_csv}
  </data>
 </layer>
 <layer id="2" name="Walls" width="{W}" height="{H}">
  <data encoding="csv">
{walls_csv}
  </data>
 </layer>
</map>
"""
with open("maps/room_poc.tmx", "w") as f:
    f.write(tmx)
print(f"Created maps/room_poc.tmx ({W}×{H} tiles = {W*16}×{H*16}px, outer walls)")
```

```bash
python3 /tmp/gen_map_assets.py
```

Expected output:
```
Created assets/tilesets/placeholder.png (32×16, 2 tiles: floor at x=0, wall at x=16)
Created maps/placeholder.tsx
Created maps/room_poc.tmx (25×15 tiles = 400×240px, outer walls)
```

**Step 2: Verify files exist and are non-empty**

```bash
ls -lh assets/tilesets/placeholder.png maps/placeholder.tsx maps/room_poc.tmx
```

Expected: all three files present with sizes > 0.

**Step 3: Commit**

```bash
git add assets/tilesets/placeholder.png maps/placeholder.tsx maps/room_poc.tmx
git commit -m "feat: add placeholder tileset and POC Tiled map (25x15)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Must complete first; edits `project.godot` for GUT plugin |
| B (parallel) | Task 2, Task 3 | Task 2 edits `project.godot` (different section); Task 3 writes new asset files — no overlap |

### Smoketest Checkpoint 1 — GUT starts, assets exist, input actions defined

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run GUT headless**
```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | head -20
```
Expected: GUT prints its version and exits. A warning about no test files is fine. No "file not found" crash.

**Step 3: Verify artifacts**
```bash
ls assets/tilesets/placeholder.png maps/placeholder.tsx maps/room_poc.tmx
grep "move_up" project.godot
```
Expected: all three asset files listed; `move_up` appears in `project.godot`.

**Step 4: Confirm with user**
Tell the user: "Batch 1 complete. GUT is installed and runs. Input actions are configured. The Tiled map assets are generated. No visual game yet — confirm to proceed to TDD for player movement."

---

## Batch 2: Player Logic (TDD)

### Task 4: Write failing GUT test for player movement

**Files:**
- Create: `tests/test_player.gd`

**Depends on:** none
**Parallelizable with:** none — this is the first step of the TDD sequence; Task 5 must follow this file being committed.

**Step 1: Create tests/ directory and test file**

```bash
mkdir -p tests
```

Create `tests/test_player.gd`:

```gdscript
extends GutTest


func test_direction_to_offset_up() -> void:
	assert_eq(Player.direction_to_offset("move_up"), Vector2i(0, -1))


func test_direction_to_offset_down() -> void:
	assert_eq(Player.direction_to_offset("move_down"), Vector2i(0, 1))


func test_direction_to_offset_left() -> void:
	assert_eq(Player.direction_to_offset("move_left"), Vector2i(-1, 0))


func test_direction_to_offset_right() -> void:
	assert_eq(Player.direction_to_offset("move_right"), Vector2i(1, 0))


func test_direction_to_offset_unknown_returns_zero() -> void:
	assert_eq(Player.direction_to_offset(""), Vector2i.ZERO)


func test_snap_to_grid_already_aligned() -> void:
	assert_eq(Player.snap_to_grid(Vector2(32.0, 48.0), 16), Vector2(32.0, 48.0))


func test_snap_to_grid_rounds_to_nearest_tile() -> void:
	# 17.0 / 16 = 1.0625 → rounds to 1 → 16.0
	# 26.0 / 16 = 1.625  → rounds to 2 → 32.0
	assert_eq(Player.snap_to_grid(Vector2(17.0, 26.0), 16), Vector2(16.0, 32.0))
```

**Step 2: Run to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd 2>&1 | tail -20
```

Expected: FAIL — errors like "Identifier 'Player' not found" or class not declared.

**Step 3: Commit**

```bash
git add tests/test_player.gd
git commit -m "test: add failing GUT tests for Player movement utilities"
```

---

### Task 5: Implement player.gd

**Files:**
- Create: `scripts/world/player.gd`

**Depends on:** Task 4
**Parallelizable with:** none — TDD gate requires Task 4's failing tests to exist first.

**Step 1: Create player.gd**

```gdscript
# scripts/world/player.gd
class_name Player
extends CharacterBody2D

const TILE_SIZE: int = 16
const MOVE_DURATION: float = 0.1

var _moving: bool = false
var _walls_layer: int = -1

@onready var _tilemap: TileMapLayer = $"../room_poc"


func _ready() -> void:
	position = snap_to_grid(position, TILE_SIZE)
	for i: int in _tilemap.get_layers_count():
		if _tilemap.get_layer_name(i) == "Walls":
			_walls_layer = i
			break


func _unhandled_input(event: InputEvent) -> void:
	if _moving:
		return
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			_try_move(action)
			return


func _try_move(action: String) -> void:
	var offset: Vector2i = direction_to_offset(action)
	var target_pos: Vector2 = position + Vector2(offset) * TILE_SIZE
	if _is_wall(target_pos):
		return
	_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	tween.tween_callback(func() -> void: _moving = false)


func _is_wall(world_pos: Vector2) -> bool:
	if _walls_layer == -1:
		return false
	# Both Player and TileMap are direct children of the same root at (0,0);
	# local_to_map receives the position in the TileMap's local space.
	var cell: Vector2i = _tilemap.local_to_map(world_pos)
	return _tilemap.get_cell_source_id(_walls_layer, cell) != -1


static func direction_to_offset(action: String) -> Vector2i:
	match action:
		"move_up":    return Vector2i(0, -1)
		"move_down":  return Vector2i(0, 1)
		"move_left":  return Vector2i(-1, 0)
		"move_right": return Vector2i(1, 0)
	return Vector2i.ZERO


static func snap_to_grid(pos: Vector2, tile_size: int) -> Vector2:
	return Vector2(
		roundf(pos.x / tile_size) * tile_size,
		roundf(pos.y / tile_size) * tile_size,
	)
```

**Step 2: Run tests — must PASS**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd 2>&1 | tail -20
```

Expected: 7 tests pass, 0 failures.

**Step 3: Refactor checkpoint**

Ask: "Does `direction_to_offset` and `snap_to_grid` generalize, or are there hard-coded assumptions?"
- Both accept arbitrary `action` strings and `tile_size` values — no hard-coding. Proceed.

**Step 4: Commit**

```bash
git add scripts/world/player.gd
git commit -m "feat: implement Player tile-by-tile movement (TDD)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 4, Task 5 | TDD gate: tests must fail before implementation; Task 5 writes a different file but cannot start until Task 4 is committed |

### Smoketest Checkpoint 2 — GUT tests pass

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```
Expected: 7 tests pass, 0 failures.

**Step 3: Confirm with user**
Tell the user: "All 7 player movement tests pass. `direction_to_offset` and `snap_to_grid` are verified. Ready to assemble the scene."

---

## Batch 3: Scene Assembly

### Task 6: Create RoomPOC.tscn

**Files:**
- Create: `scenes/world/RoomPOC.tscn`

**Depends on:** Task 2 (input actions in project.godot), Task 3 (`.tmx` must exist for import), Task 5 (`player.gd` must exist)
**Parallelizable with:** none — Task 7 depends on this scene file existing.

**Step 1: Trigger Godot import of maps/room_poc.tmx**

```bash
godot --headless --import 2>&1 | tail -10
```

Expected: Godot scans the project and imports new files. Then verify the import artifact:

```bash
find .godot/imported/ -name "*room_poc*" 2>/dev/null | head -5
```

Expected: at least one file matching `room_poc.tmx-*.scn`.

**Step 2: Create the scene file**

Create `scenes/world/RoomPOC.tscn`:

```
[gd_scene load_steps=3 format=3 uid="uid://room_poc_scene"]

[ext_resource type="PackedScene" path="res://maps/room_poc.tmx" id="1_map"]
[ext_resource type="Script" path="res://scripts/world/player.gd" id="2_player"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(12.0, 12.0)

[node name="RoomPOC" type="Node2D"]

[node name="room_poc" parent="." instance=ExtResource("1_map")]

[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(200.0, 112.0)
script = ExtResource("2_player")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
position = Vector2(0.0, -6.0)
shape = SubResource("RectangleShape2D_1")

[node name="Sprite" type="ColorRect" parent="Player"]
offset_left = -8.0
offset_top = -24.0
offset_right = 8.0
offset_bottom = 0.0
color = Color(0.8, 0.3, 0.3, 1.0)

[node name="Camera2D" type="Camera2D" parent="Player"]
limit_left = 0
limit_top = 0
limit_right = 400
limit_bottom = 240
position_smoothing_enabled = true
position_smoothing_speed = 5.0
```

**Derivations:**
- Player starts at tile (12, 7): pixel = (12×16 + 8, 7×16 + 8) = (200, 120). Offset -8 on Y places the base of the 24px sprite at tile center → position = (200, 112).
- Camera `limit_right` = 25 × 16 = 400; `limit_bottom` = 15 × 16 = 240.
- `CollisionShape2D` 12×12 rect, shifted up 6px so it sits in the lower portion of the 24px sprite.

**Step 3: Verify scene imports cleanly**

```bash
godot --headless --import 2>&1 | grep -i "error" | head -10
```

Expected: no errors mentioning `RoomPOC.tscn`.

**Step 4: Commit**

```bash
git add scenes/world/RoomPOC.tscn
git commit -m "feat: create RoomPOC scene with player, camera, and Tiled map"
```

---

### Task 7: Set RoomPOC as main scene

**Files:**
- Modify: `project.godot`

**Depends on:** Task 6 (scene file must exist before setting it as main)
**Parallelizable with:** none — this is the final config step and modifies `project.godot` which earlier tasks also touched.

**Step 1: Add main_scene to project.godot**

In `project.godot`, find the `[application]` section:
```ini
[application]

config/name="Final Noire"
config/features=PackedStringArray("4.6", "Mobile")
config/icon="res://icon.svg"
```

Add `run/main_scene` so it becomes:
```ini
[application]

config/name="Final Noire"
config/features=PackedStringArray("4.6", "Mobile")
config/icon="res://icon.svg"
run/main_scene="res://scenes/world/RoomPOC.tscn"
```

**Step 2: Verify**

```bash
grep "main_scene" project.godot
```

Expected: `run/main_scene="res://scenes/world/RoomPOC.tscn"`

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: set RoomPOC as main scene"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 6, Task 7 | Task 7 writes same `project.godot` as earlier tasks; must also wait for scene file from Task 6 |

### Smoketest Checkpoint 3 — Full end-to-end: player moves in room

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -10
```
Expected: 7 tests pass, 0 failures.

**Step 3: Launch game**
```bash
godot
```

**Step 4: Confirm with user**
Ask the user to verify all acceptance criteria:
- [ ] Game boots directly into a room (purple walls, dark floor)
- [ ] A red rectangle (player) is visible near the center
- [ ] Arrow keys and WASD move the player exactly one tile at a time
- [ ] Player cannot move through the outer wall border
- [ ] Camera follows the player and stays inside room bounds

Wait for explicit confirmation before concluding.
