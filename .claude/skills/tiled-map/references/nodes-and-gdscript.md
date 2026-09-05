# Tiled-Map Reference — YATI Node Structure & GDScript Access

Look-up reference for the node tree YATI produces from a `.tmx` and the GDScript patterns to read it. Consult when authoring code that reads a map or mapping objects to nodes — not the always-fired authoring rules.

## YATI-Produced Node Structure

### Multi-layer map (2 or more tile/object layers)

```
Node2D "room_poc"           ← TMX basename; root node of the imported .tscn
├── TileMapLayer "Floor"    ← Tiled layer name (tile layer)
├── TileMapLayer "Walls"    ← Tiled layer name (tile layer)
└── StaticBody2D "Collision" ← Tiled object layer name, or individual object node
```

### Single-child map (exactly 1 tile/object layer after cleanup)

```
TileMapLayer "room_poc"     ← no wrapping Node2D; the single child is renamed to the TMX basename
```

A single-layer TMX therefore produces one root `TileMapLayer` named after the file (e.g. `room_poc`). YATI checks `if _base_node.get_child_count() > 1` to decide which structure to use. A temporary `ParallaxBackground` is added/removed before this check and does NOT affect the count.

### CRITICAL WARNING

**YATI produces `TileMapLayer` nodes — NOT `TileMap`.**

`TileMapLayer` does NOT have:
- `get_layers_count()`
- `set_cell(layer, coords, ...)` (no `layer` parameter)
- `get_used_cells(layer)`
- `get_cell_source_id(layer, coords)` (no `layer` parameter)

Each `TileMapLayer` IS a layer. You access cells directly on the node.

## GDScript Access Patterns

### Referencing TileMapLayer nodes

```gdscript
# Multi-layer map: room_poc.tscn loaded as a child of the current scene
# The imported scene root is a Node2D named after the TMX basename.
@onready var floor_layer: TileMapLayer = $"room_poc/Floor"
@onready var walls_layer: TileMapLayer = $"room_poc/Walls"

# Single-layer map: the TileMapLayer IS the root, named after the TMX basename.
@onready var map: TileMapLayer = $"room_poc"
```

### Wall / collision detection (canonical pattern)

Walls are identified by the tile's `class="wall"` metadata (requires `class=` set in the `.tsx` and `add_class_as_metadata=true` in the `.tmx.import`):

```gdscript
# Canonical wall check — reads the tile's class metadata.
func is_wall(cell: Vector2i) -> bool:
    var tile_data := tilemap.get_cell_tile_data(cell)
    return tile_data != null and tile_data.get_meta("class", "") == "wall"

# Check if a cell has ANY tile (occupancy, not wall-ness):
func has_tile(cell: Vector2i) -> bool:
    return tilemap.get_cell_source_id(cell) != -1

# Get the atlas coordinates of the tile at a cell (useful for tile variant lookup)
func get_tile_variant(cell: Vector2i) -> Vector2i:
    return tilemap.get_cell_atlas_coords(cell)
```

### World position → map cell conversion

```gdscript
# Convert a global world position to a TileMapLayer cell coordinate.
# to_local() converts from global space to TileMapLayer local space.
# local_to_map() then converts local pixels to integer cell coords.
func world_to_cell(world_pos: Vector2) -> Vector2i:
    return walls_layer.local_to_map(walls_layer.to_local(world_pos))
```

### Iterating used cells

```gdscript
# Get all cells that have a tile on this layer.
func get_all_wall_cells() -> Array[Vector2i]:
    return walls_layer.get_used_cells()
```

### WRONG patterns — do NOT use

```gdscript
# WRONG: TileMap API — does not exist on TileMapLayer
walls_layer.set_cell(0, cell, source_id, atlas_coords)   # ERROR: no layer param
walls_layer.get_cell_source_id(0, cell)                  # ERROR: no layer param
walls_layer.get_layers_count()                           # ERROR: method does not exist
walls_layer.get_used_cells(0)                            # ERROR: no layer param

# WRONG: looking for the wrapping node when only one layer exists
# (single-child maps have NO wrapping Node2D)
var layer = $"room_poc/Floor"   # ERROR if room_poc.tmx had only one layer
```

## Object Layer → Godot Node Mapping

YATI maps the Tiled object `class` attribute to a Godot node type. The lookup is **case-insensitive** (YATI calls `.to_lower()` on the class string before matching).

| Tiled class string | Godot node produced | Notes |
|---|---|---|
| `""` (empty) | `Marker2D` (point) or `StaticBody2D` (rect/polygon) | Empty class on a rectangle/polygon is promoted to BODY before shape handling |
| `"collision"` | `StaticBody2D` | Alias for staticbody |
| `"staticbody"` | `StaticBody2D` | |
| `"characterbody"` | `CharacterBody2D` | |
| `"rigidbody"` | `RigidBody2D` | |
| `"animatablebody"` | `AnimatableBody2D` | |
| `"area"` | `Area2D` | |
| `"navigation"` | `NavigationRegion2D` | Ellipse/Capsule shapes are skipped with a warning |
| `"occluder"` | `LightOccluder2D` | Ellipse/Capsule shapes are skipped with a warning |
| `"line"` | `Line2D` | |
| `"path"` | `Path2D` | |
| `"polygon"` | `Polygon2D` | |
| `"instance"` | Instantiated scene | Requires a file custom property `res_path` = `res://scenes/foo.tscn`; skipped if missing |
| `"parallax"` | `Parallax2D` | |
| any unknown string | `StaticBody2D` | Warning: `Unknown class 'X'. -> Assuming Default` |
