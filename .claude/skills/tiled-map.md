---
name: tiled-map
description: Tiled→YATI→Godot map pipeline expert. Auto-trigger: any request to create a .tmx or .tsx file. Manual trigger (/tiled-map): validation, debugging, pipeline Q&A, GDScript TileMapLayer access patterns.
invocation: Automatic when creating .tmx/.tsx files. Manual (/tiled-map) for all other uses.
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

## 2. TMX File Structure

### Annotated template (multi-layer orthogonal map)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Map attributes:
    version       — Tiled format version; always "1.10" for Tiled 1.10.x
    tiledversion  — Tiled application version that last saved this file
    orientation   — always "orthogonal" for this project
    renderorder   — always "right-down" (left→right, top→bottom)
    width/height  — map dimensions in tiles
    tilewidth/tileheight — tile size in pixels; ALWAYS 16×16 for this project
    infinite      — always "0" (finite map)
    nextlayerid   — auto-managed by Tiled; increment when adding layers manually
    nextobjectid  — auto-managed by Tiled; increment when adding objects manually
-->
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal"
     renderorder="right-down"
     width="20" height="15"
     tilewidth="16" tileheight="16"
     infinite="0" nextlayerid="4" nextobjectid="2">

  <!--
    External tileset reference.
      firstgid  — first Global ID assigned to this tileset's tiles.
                  First tileset MUST be 1.
                  Second tileset = firstgid_of_first + tilecount_of_first.
                  Etc.
      source    — path to .tsx file, RELATIVE TO THIS .tmx FILE.
  -->
  <tileset firstgid="1" source="../assets/tilesets/dungeon.tsx"/>

  <!--
    Tile layer.
      id     — unique layer id; auto-managed by Tiled
      name   — becomes the TileMapLayer node name in Godot
      width/height — MUST match <map> width/height
  -->
  <layer id="1" name="Floor" width="20" height="15">
    <!--
      CSV encoding rules (CRITICAL for YATI compatibility):
        - Row-major, left-to-right, top-to-bottom
        - Each row has exactly `width` GIDs separated by commas
        - ALL rows EXCEPT the last row end with a trailing comma followed by \n
        - The last row has NO trailing comma
        - No blank line before </data>
        - GID 0 = empty cell
        - GID = firstgid + (tile_row * columns + tile_col)
        - To flip a tile, set flip bits in the GID (see Key rules below)
    -->
    <data encoding="csv">
1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,
1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1</data>
  </layer>

  <layer id="2" name="Walls" width="20" height="15">
    <data encoding="csv">
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</data>
  </layer>

  <!--
    Object layer.
      Objects have a `class` attribute that YATI maps to Godot node types.
      See Section 7 for the full class→node mapping table.
      Rectangle objects: x/y = top-left corner; width/height in pixels.
  -->
  <objectgroup id="3" name="Collision">
    <object id="1" class="staticbody" x="0" y="0" width="320" height="16"/>
  </objectgroup>

</map>
```

### Key rules

| Rule | Detail |
|------|--------|
| `firstgid` for first tileset | MUST be `1` |
| `firstgid` for subsequent tilesets | Previous `firstgid` + previous tileset's `tilecount` |
| GID 0 | Empty cell — never refers to a tile |
| GID flip bits | Bit 31 = flip H (`0x80000000`), bit 30 = flip V (`0x40000000`), bit 29 = flip diag (`0x20000000`); strip all three to get real GID: `real_gid = raw_gid & 0x0FFFFFFF` |
| `width`/`height` on `<layer>` | MUST match `<map>` `width`/`height` |
| `renderorder` | Always `"right-down"` for this project |
| Trailing comma rule | All rows in CSV except the LAST row have a trailing comma — this is Tiled's native format; YATI tolerates whitespace/newlines around GIDs |

---

## 3. TSX File Structure

### Annotated template

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!--
  TSX tileset attributes:
    name        — human-readable name; becomes the TileSet resource name in Godot
    tilewidth   — tile width in pixels; ALWAYS 16 for this project
    tileheight  — tile height in pixels; ALWAYS 16 for this project
    spacing     — pixel gap between tiles in the source image (0 if tightly packed)
    margin      — pixel border around the edge of the source image (0 if none)
    tilecount   — total number of tiles; = columns * rows
    columns     — number of tile columns; = (imagewidth - 2*margin + spacing) / (tilewidth + spacing)
                  For a tightly-packed sheet: columns = imagewidth / tilewidth
-->
<tileset name="dungeon" tilewidth="16" tileheight="16"
         spacing="0" margin="0"
         tilecount="64" columns="8">

  <!--
    IMAGE PATH GOTCHA (AC2 — CRITICAL):
      The `source` attribute is RELATIVE TO THE TSX FILE'S DIRECTORY.
      If dungeon.tsx is at  assets/tilesets/dungeon.tsx
      and the image is at   assets/images/dungeon.png
      then source MUST be   "../images/dungeon.png"   (NOT "res://...")
      NEVER use res:// paths here — YATI resolves them as filesystem paths relative to the TSX.
  -->
  <image source="../images/dungeon.png" width="128" height="128"/>

</tileset>
```

### Key rules

| Rule | Detail |
|------|--------|
| `tilecount` math | `columns * rows`; for tightly-packed sheet: `columns = imagewidth / tilewidth`, `rows = imageheight / tileheight` |
| `columns` math | `(imagewidth - 2*margin + spacing) / (tilewidth + spacing)`; simplifies to `imagewidth / tilewidth` when spacing=0 and margin=0 |
| `spacing` | Pixel gap BETWEEN tiles in the source image; 0 for tightly-packed sheets |
| `margin` | Pixel border around the OUTSIDE EDGE of the source image; 0 if none |
| **TSX image path gotcha** | `<image source>` is **relative to the TSX file's directory** — NOT to the project root and NOT `res://` |
| **TMX tileset path gotcha** | `<tileset source>` in a TMX is **relative to the TMX file's directory** — NOT to the project root and NOT `res://` |

---

## 4. YATI Import Options

All options appear in the Godot Import dock when a `.tmx` file is selected.

| Option | Default | Effect |
|--------|---------|--------|
| `use_default_filter` | `false` | `false` = nearest-neighbor (correct for pixel art); `true` = Godot default bilinear filter |
| `add_class_as_metadata` | `false` | Stores the Tiled object/layer class string as node metadata key `"class"` |
| `add_id_as_metadata` | `false` | Stores the Tiled object/layer id as node metadata key `"id"` |
| `no_alternative_tiles` | `false` | `true` = skip creating alternative tiles for flipped/rotated variants; saves memory but loses flip support |
| `map_wangset_to_terrain` | `false` | Maps Tiled Wang sets to Godot Terrain layers in the TileSet |
| `custom_data_prefix` | `"data_"` | Prefix prepended to Tiled custom property names when creating TileSet custom data layers (e.g. Tiled property `walkable` → Godot custom data layer `data_walkable`) |
| `tiled_project_file` | `""` | Path to `.tiled-project` file; needed to resolve custom type definitions defined at the project level |
| `post_processor` | `""` | Path to a GDScript run after import completes; the script receives the root node; if it throws errors the import continues anyway |
| `save_tileset_to` | `""` | Path to save the generated TileSet as a `.tres` resource; enables sharing a single TileSet across multiple maps |

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

YATI checks `if _base_node.get_child_count() > 1` to decide which structure to use. A temporary `ParallaxBackground` is added/removed before this check and does NOT affect the count.

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

### Wall / collision detection

```gdscript
# Check if a cell has any tile (source_id == -1 means empty)
func is_wall(cell: Vector2i) -> bool:
    return walls_layer.get_cell_source_id(cell) != -1

# Get the atlas coordinates of the tile at a cell (useful for tile variant lookup)
func get_tile_variant(cell: Vector2i) -> Vector2i:
    return walls_layer.get_cell_atlas_coords(cell)
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

These Tiled custom properties on layers or objects are interpreted by YATI and affect the imported Godot node. Set them in the Tiled Properties panel.

| Property | Type | Effect |
|---|---|---|
| `no_import` | bool | Skip the entire layer during import; nothing is created for it |
| `z_index` | int | Sets `z_index` on the produced node |
| `godot_node_type` | string | Overrides the node type that YATI would normally produce |
| `godot_group` | string | Comma-separated group names; node is added to each group persistently |
| `godot_script` | file or string | Attaches a GDScript file to the node |
| `tile_set` | file | Overrides the TileSet resource used by this TileMapLayer |
| `tileset_resource_path` | string | Overrides TileSet path (TileMapLayer only; experimental) |
| `y_sort_origin` | int | Sets Y sort origin on TileMapLayer |
| `x_draw_order_reversed` | bool | Reverses X draw order on TileMapLayer |
| `rendering_quadrant_size` | int | Sets rendering quadrant size on TileMapLayer |
| `collision_enabled` | bool | Enables/disables collision on TileMapLayer |
| `use_kinematic_bodies` | bool | Use kinematic bodies for TileMapLayer collision |
| `navigation_enabled` | bool | Enables/disables navigation on TileMapLayer |
| `modulate` | color | Sets `modulate` on any CanvasItem node |
| `self_modulate` | color | Sets `self_modulate` on any CanvasItem node |
| `show_behind_parent` | bool | Sets `show_behind_parent` on any CanvasItem node |
| `top_level` | bool | Sets `top_level` on any CanvasItem node |
| `y_sort_enabled` | bool | Sets `y_sort_enabled` on any CanvasItem node |
| `texture_filter` | int | Sets `texture_filter` on any CanvasItem node |
| `material` | file | Sets `material` on any CanvasItem node |

---

## 9. Placeholder Map Creation Checklist

Follow these steps to create a valid map that imports with 0 errors, 0 warnings on the first attempt.

1. **Create the TSX tileset file** at `assets/tilesets/<name>.tsx`
   - Set `tilewidth="16"` and `tileheight="16"`
   - Set `<image source>` as a path **relative to the TSX file's directory** (e.g. `../images/dungeon.png`)
   - Calculate and set `columns` and `tilecount` from the actual image dimensions
   - Verify the image file exists at the resolved path before saving

2. **Create the TMX map file** at `maps/<name>.tmx`
   - Set `tilewidth="16"` `tileheight="16"` `orientation="orthogonal"` `renderorder="right-down"` `infinite="0"`
   - Set `<tileset firstgid="1" source="..."/>` with path **relative to the TMX file's directory**
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
   - Open the Godot Import dock with the `.tmx` selected
   - Set `use_default_filter = false` (nearest-neighbor for pixel art)
   - Set `save_tileset_to` if you want a shared `.tres` TileSet resource
   - Click "Reimport" and check the Output panel for YATI messages
   - Zero errors and zero warnings = success

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
| Tileset directory | `.tsx` files go in `assets/tilesets/` |
| Image directory | Tileset source images go in `assets/images/` |
| Encoding | Always CSV — never Base64, zlib, or zstd |
| No `res://` in XML | Never use `res://` paths in `.tmx` or `.tsx` files — YATI expects filesystem-relative paths |
| Thread safety | If using multiple `.tmx` files, disable "Use multiple threads" in Project Settings → Advanced → Editor → Import |

---

## 11. YATI Debug Workflow

### Reading YATI output

YATI prints to the Godot Output panel during import. Example lines and what they mean:

```
# Normal progress lines (not errors):
Importing map 'res://maps/room_poc.tmx'
Importing tileset 'res://assets/tilesets/dungeon.tsx'

# Errors that cause partial or broken imports:
FATAL ERROR: Tiled map file 'res://maps/missing.tmx' not found.
ERROR: Tileset file 'res://assets/tilesets/dungeon.tsx' not found. -> Continuing but result may be unusable
ERROR: Template file '...' not found. -> Continuing but result may be unusable
Object of class 'instance': Mandatory file property 'res_path' not found or invalid. -> Skipped

# Warnings that skip individual tiles or objects:
Unknown class 'door'. -> Assuming Default
Unknown godot_node_type 'wall'. -> Assuming Default
Tile 999 at 5,3 outside texture range. -> Skipped
Tile id 999 outside tile count range (0-63). -> Skipped.
Could not get AtlasSource with id 2 -> Skipped
Capsule is unusable for NavigationRegion2D/LightOccluder2D/Polygon2D. -> Skipped
Ellipse is unusable for NavigationRegion2D/LightOccluder2D/Polygon2D. -> Skipped
'Point' has currently no corresponding collision element in Godot 4. -> Skipped
Saving tileset returned error 7
```

### Silent failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| TileMapLayer appears but all cells empty | GIDs all out of range (wrong firstgid or wrong tileset tilecount) | Recalculate firstgid and tilecount; check image dimensions |
| Some tiles missing, others present | GID gaps due to incorrect tilecount on a preceding tileset | Verify every tileset's tilecount and recompute firstgid chain |
| Tiles appear blurry/filtered | `use_default_filter = true` in import options | Set `use_default_filter = false` and reimport |
| Import produces TileMap instead of TileMapLayer | Using a very old version of YATI | Ensure YATI is from the current version in `addons/YATI/` |
| Object nodes missing from scene | Object class string not recognized (typo) | Check class string against Section 7 table (case-insensitive) |
| "instance" object not spawned | Missing or invalid `res_path` custom property | Add file property `res_path = res://scenes/foo.tscn` to the object |
| Godot freezes during import | Multiple `.tmx` files with "Use multiple threads" enabled | Disable "Use multiple threads" in Project Settings → Advanced → Editor → Import |
| Scene tree has wrong structure (single layer but expecting Node2D wrapper) | TMX had only 1 child after cleanup — YATI skips wrapping Node2D | Either add a second layer (even empty) or update your scene references |
| TSX image not found error | `<image source>` accidentally written as absolute or `res://` path | Rewrite as a relative path from the TSX file's directory |
| NPC sprite visible but interact does nothing | NPC properties (e.g. `yarn_node_id`) placed on a tile object (gid) in the Objects layer — tile objects are visual only; YATI never reads their custom properties into script | Add a second `type="instance"` object in the Interactions layer at the same cell with `res_path` pointing to `NPC.tscn` and the actual custom properties there |

### YATI warning/error messages reference

Full list of known YATI messages, for copy-paste searching in the Output panel:

```
FATAL ERROR: Tiled map file '...' not found.
ERROR: Template file '...' not found. -> Continuing but result may be unusable
ERROR: Tileset file '...' not found. -> Continuing but result may be unusable
Object of class 'instance': Mandatory file property 'res_path' not found or invalid. -> Skipped
Could not get AtlasSource with id ... -> Skipped
Unknown class '...'. -> Assuming Default
Unknown godot_node_type '...'. -> Assuming Default
Capsule is unusable for NavigationRegion2D/LightOccluder2D/Polygon2D. -> Skipped
Ellipse is unusable for NavigationRegion2D/LightOccluder2D/Polygon2D. -> Skipped
'Point' has currently no corresponding collision element in Godot 4. -> Skipped
Tile N at col,row outside texture range. -> Skipped
Tile id N outside tile count range (0-M). -> Skipped.
Saving tileset returned error N
```

### Forcing re-import

YATI caches import results. If you edit a `.tmx` or `.tsx` outside of Godot, the editor may not detect the change automatically. To force re-import:

1. Select the `.tmx` file in the FileSystem dock
2. Open the Import dock and click **"Reimport"**

Or from the command line (headless):
```bash
DISPLAY=:0 godot --headless --editor --quit --path .
```

To reimport a specific file via the editor, you can also delete its `.import` sidecar file (e.g. `maps/room_poc.tmx.import`) and restart Godot — it will re-import from scratch on startup.

### Updating a tileset image (PNG)

When a tileset PNG changes (e.g. updated in `art/tilesets/` and copied to `assets/tilesets/`), follow this exact order — **sequence matters**:

1. **Copy** the updated PNG from `art/tilesets/<name>.png` to `assets/tilesets/<name>.png`
2. **Kill Godot** before touching the cache — if Godot is running when you delete cache files, it will recreate them from memory with stale content:
   ```bash
   pkill -f godot; sleep 2
   ```
3. **Delete the import cache** for the PNG:
   ```bash
   rm .godot/imported/<name>.png-*.ctex .godot/imported/<name>.png-*.md5
   ```
4. **Run the headless reimport** to regenerate the cache from the new PNG:
   ```bash
   DISPLAY=:0 godot --headless --editor --quit --path .
   ```
5. **Relaunch the editor** normally.

**Verify the reimport worked:** compare `source_md5` in the regenerated `.md5` file against `md5sum assets/tilesets/<name>.png` — they must match. If they differ, Godot imported a stale version (likely because step 2 was skipped).
