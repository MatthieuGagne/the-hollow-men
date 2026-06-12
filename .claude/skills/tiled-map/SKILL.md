---
name: tiled-map
description: Tiled→YATI→Godot map pipeline expert. Use automatically when creating or editing a .tmx or .tsx file; use manually (/tiled-map) for validation, debugging, pipeline Q&A, and GDScript TileMapLayer access patterns.
---

You are now operating as a Tiled→YATI→Godot map pipeline expert for The Hollow Men. You have deep knowledge of the full pipeline: authoring `.tmx`/`.tsx` files, YATI import options, the produced Godot node tree, and GDScript TileMapLayer access patterns. Use this knowledge exclusively. Do not defer to generic Godot TileMap documentation.

---

## 1. Scope & Invocation

### Covers
- Authoring `.tmx` and `.tsx` files that import cleanly via YATI with 0 errors, 0 warnings
- YATI import options and their effects
- The Godot node tree YATI produces (TileMapLayer, not TileMap)
- GDScript access patterns for TileMapLayer nodes
- Object layer class strings and their Godot node mappings
- Special Tiled custom properties that YATI interprets
- Validation and debugging of the import pipeline

### Out of scope
- Godot AnimationPlayer, shaders, audio
- Tiled Wang sets beyond noting that `map_wangset_to_terrain` exists
- Non-orthogonal map orientations (isometric, hexagonal)
- Non-CSV tile encodings (Base64, zlib, zstd)
- The Dialogue system (YarnSpinner)

### Invocation rules
- **Automatic:** any request that involves creating or editing a `.tmx` or `.tsx` file triggers this skill without needing `/tiled-map`.
- **Manual `/tiled-map`:** use for validation, debugging, pipeline Q&A, GDScript TileMapLayer questions, and any other Tiled/YATI/Godot map topic.

---

## 2. TMX File Rules

> Full annotated XML templates (TMX and TSX): see `references/templates.md`.

| Rule | Detail |
|------|--------|
| `firstgid` for first tileset | MUST be `1` |
| `firstgid` for subsequent tilesets | Previous `firstgid` + previous tileset's `tilecount` |
| GID 0 | Empty cell — never refers to a tile |
| GID flip bits | Bit 31 = flip H (`0x80000000`), bit 30 = flip V (`0x40000000`), bit 29 = flip diag (`0x20000000`); strip all three to get real GID: `real_gid = raw_gid & 0x0FFFFFFF` |
| `width`/`height` on `<layer>` | MUST match `<map>` `width`/`height` |
| `renderorder` | Always `"right-down"` for this project |
| Trailing comma rule | All rows in CSV except the LAST row have a trailing comma — this is Tiled's native format; YATI tolerates whitespace/newlines around GIDs |

## 3. TSX File Rules

| Rule | Detail |
|------|--------|
| `tilecount` math | `columns * rows`; for tightly-packed sheet: `columns = imagewidth / tilewidth`, `rows = imageheight / tileheight` |
| `columns` math | `(imagewidth - 2*margin + spacing) / (tilewidth + spacing)`; simplifies to `imagewidth / tilewidth` when spacing=0 and margin=0 |
| `spacing` | Pixel gap BETWEEN tiles in the source image; 0 for tightly-packed sheets |
| `margin` | Pixel border around the OUTSIDE EDGE of the source image; 0 if none |
| Tile types | Define tile types via the `class=` attribute on individual `<tile>` elements in the `.tsx` (e.g. `class="wall"`); becomes tile metadata when `add_class_as_metadata=true` |
| **TSX image path gotcha** | `<image source>` is **relative to the TSX file's directory** — NOT to the project root and NOT `res://` (TSX in `maps/`, image in `assets/tilesets/` → `../assets/tilesets/<name>.png`) |
| **TMX tileset path gotcha** | `<tileset source>` in a TMX is **relative to the TMX file's directory** — NOT to the project root and NOT `res://` |

---

## 4. YATI Import Options

All options appear in the Godot Import dock when a `.tmx` file is selected.

| Option | Default | Effect |
|--------|---------|--------|
| `use_default_filter` | `false` | `false` = nearest-neighbor (correct for pixel art); `true` = Godot default bilinear filter |
| `add_class_as_metadata` | `false` | Stores the Tiled object/layer/tile class string as metadata key `"class"` — **this project requires `true`**: after the first import, set `add_class_as_metadata=true` in the generated `.tmx.import` file (needed for the runtime wall check) |
| `add_id_as_metadata` | `false` | Stores the Tiled object/layer id as node metadata key `"id"` |
| `no_alternative_tiles` | `false` | `true` = skip creating alternative tiles for flipped/rotated variants; saves memory but loses flip support |
| `map_wangset_to_terrain` | `false` | Maps Tiled Wang sets to Godot Terrain layers in the TileSet |
| `custom_data_prefix` | `"data_"` | Prefix prepended to Tiled custom property names when creating TileSet custom data layers (e.g. Tiled property `walkable` → Godot custom data layer `data_walkable`) |
| `tiled_project_file` | `""` | Path to `.tiled-project` file; needed to resolve custom type definitions defined at the project level |
| `post_processor` | `""` | Path to a GDScript run after import completes; the script receives the root node; if it throws errors the import continues anyway |
| `save_tileset_to` | `""` | Path to save the generated TileSet as a `.tres` resource; enables sharing a single TileSet across multiple maps |

`.tmx.import` files are **gitignored build artifacts** (regenerated by headless import) — do not commit them.

### YATI freeze prevention

If you have multiple `.tmx` files in the project, disable **"Use multiple threads"** in Project Settings → Advanced → Editor → Import. YATI is not thread-safe across concurrent imports and can cause Godot to freeze or produce corrupt TileSet resources.

---

## 5. YATI-Produced Node Structure

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

---

## 6. GDScript Access Patterns

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

---

## 7. Object Layer → Godot Node Mapping

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

---

## 8. Special Custom Properties

> Full table of YATI-interpreted custom properties (`no_import`, `z_index`, `godot_node_type`, `godot_script`, etc.): see `references/yati-reference.md`.

---

## 9. Placeholder Map Creation Checklist

Follow these steps to create a valid map that imports with 0 errors, 0 warnings on the first attempt.

1. **Create the TSX tileset file** at `maps/<name>.tsx` (e.g. `maps/objects.tsx`, `maps/placeholder.tsx`)
   - Set `tilewidth="16"` and `tileheight="16"`
   - Set `<image source>` as a path **relative to the TSX file's directory** — tileset images live in `assets/tilesets/`, object sprites in `assets/objects/` (e.g. `../assets/tilesets/placeholder.png`)
   - Calculate and set `columns` and `tilecount` from the actual image dimensions
   - Verify the image file exists at the resolved path before saving
   - Define tile types via `class=` on the `<tile>` elements (e.g. `class="wall"`)

2. **Create the TMX map file** at `maps/<name>.tmx`
   - Set `tilewidth="16"` `tileheight="16"` `orientation="orthogonal"` `renderorder="right-down"` `infinite="0"`
   - Set `<tileset firstgid="1" source="..."/>` with path **relative to the TMX file's directory** (TSX is in the same `maps/` dir, so usually just the filename)
   - For multiple tilesets, compute each `firstgid` correctly: `firstgid_N = firstgid_{N-1} + tilecount_{N-1}`

3. **Add tile layers** — one `<layer>` per logical layer (e.g. Floor, Walls)
   - Set `width` and `height` on each `<layer>` to match the `<map>` dimensions
   - Use `<data encoding="csv">`
   - Write `width` GIDs per row, ALL rows except the last end with a trailing comma
   - The last row has NO trailing comma; no blank line before `</data>`
   - Use GID 0 for empty cells; first tile in first tileset = GID 1

4. **Add object layers** as needed
   - Use only class strings from the confirmed mapping table (Section 7)
   - For `"instance"` objects, add file custom property `res_path` pointing to the `.tscn`
   - Check that object coordinates are in pixels (Tiled native units)

5. **Verify all GIDs are in range**
   - Max valid GID for a tileset = `firstgid + tilecount - 1`
   - No GID should exceed that range; GID 0 is always valid (empty)

6. **Check all file paths resolve**
   - TSX `<image source>` → must resolve to an existing image file
   - TMX `<tileset source>` → must resolve to an existing TSX file
   - All `res_path` properties → must resolve to existing `.tscn` files

7. **Import in Godot**
   - Headless reimport after creating or changing a TMX: `godot_console --headless --editor --quit --path .`
   - Or in the editor: select the `.tmx`, open the Import dock, set `use_default_filter = false` (nearest-neighbor for pixel art), set `save_tileset_to` if you want a shared `.tres` TileSet, click "Reimport"
   - **After the first import**, set `add_class_as_metadata=true` in the generated `.tmx.import` file (required for the runtime wall check), then reimport
   - `.tmx.import` files are gitignored build artifacts — do not commit them
   - Check the Output panel for YATI messages: zero errors and zero warnings = success

---

## 10. Validation Rules

### Structural

| Check | Rule |
|---|---|
| Tile size | Every `.tmx` and `.tsx` MUST have `tilewidth="16"` and `tileheight="16"` |
| Map orientation | `orientation="orthogonal"` always |
| Map infinite | `infinite="0"` always |
| Layer dimensions | `<layer>` `width`/`height` MUST equal `<map>` `width`/`height` |
| firstgid of first tileset | MUST be `1` |
| firstgid of subsequent tilesets | MUST equal previous `firstgid` + previous `tilecount` |
| GID range | Every non-zero GID (after stripping flip bits) must satisfy: `firstgid <= real_gid <= firstgid + tilecount - 1` for its tileset |
| CSV trailing comma | ALL rows except the LAST row in `<data encoding="csv">` must end with `,` |
| CSV row count | Number of rows in CSV data MUST equal `<map>` `height` |
| CSV row width | Number of GIDs per row MUST equal `<map>` `width` |
| TSX image path | `<image source>` must be relative to the TSX file directory, must resolve to an existing file |
| TMX tileset path | `<tileset source>` must be relative to the TMX file directory, must resolve to an existing file |
| Object class strings | Must be one of the known strings in Section 7; unknown strings produce a warning and fall back to StaticBody2D |
| `"instance"` objects | Must have a `res_path` file property pointing to an existing `.tscn` |

### Project-specific

| Check | Rule |
|---|---|
| Tile size | Always 16×16 — never override |
| Renderer | Mobile (GL Compatibility); set `use_default_filter = false` for pixel art |
| Map directory | `.tmx` files go in `maps/` |
| Tileset directory | `.tsx` files go in `maps/` too (e.g. `maps/objects.tsx`, `maps/placeholder.tsx`) — NOT `assets/tilesets/` |
| Image directories | Tileset source PNGs go in `assets/tilesets/`; object sprites in `assets/objects/` (there is no `assets/images/`) |
| Tile classes | Tile types defined via `class=` in the `.tsx`; requires `add_class_as_metadata=true` in the `.tmx.import` (set after first import) |
| Encoding | Always CSV — never Base64, zlib, or zstd |
| No `res://` in XML | Never use `res://` paths in `.tmx` or `.tsx` files — YATI expects filesystem-relative paths |
| Thread safety | If using multiple `.tmx` files, disable "Use multiple threads" in Project Settings → Advanced → Editor → Import |

---

## 11. Debugging

> Debug workflow — reading YATI output, silent failure modes, full warning/error message reference, forcing re-import, and the tileset-PNG update sequence: see `references/debugging.md`.

Quick reference: reimport after changing a TMX with `godot_console --headless --editor --quit --path .`
