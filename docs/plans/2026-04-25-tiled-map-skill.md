# Tiled-Map Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create `.claude/skills/tiled-map.md` — a Claude skill that gives deep expertise over the full Tiled → YATI → Godot map pipeline.

**Architecture:** Single Markdown skill file synthesized from six Tiled official doc pages and three YATI source files (`Importer.gd`, `TilemapCreator.gd`, `TilesetCreator.gd`). The skill covers TMX/TSX authoring, YATI import options, node structure, and GDScript `TileMapLayer` access patterns. `CLAUDE.md` is updated to expose the skill under the Skills list.

**Tech Stack:** Markdown, Tiled TMX/TSX XML, YATI v2.2.7 GDScript, Godot 4.6 `TileMapLayer` API.

## Open questions (must resolve before starting)

- None — scope fully resolved in prior grill-me session (see issue #5).

---

## Batch 1: Research + CLAUDE.md update

### Task 1: Fetch Tiled documentation

**Files:**
- Output: research notes (held in working memory — no file written)

**Depends on:** none
**Parallelizable with:** Task 2, Task 3

Fetch and read these six pages in full. Note every XML element, attribute, encoding rule, and path convention that is relevant to the project (orthogonal maps, CSV/Base64 encoding, tile layers, object layers, image layers, group layers, custom properties, GID flip bits):

1. TMX/TSX format spec: `https://doc.mapeditor.org/en/stable/reference/tmx-map-format/`
2. Layers: `https://doc.mapeditor.org/en/stable/manual/layers/`
3. Objects: `https://doc.mapeditor.org/en/stable/manual/objects/`
4. Maps: `https://doc.mapeditor.org/en/stable/manual/maps/`
5. Editing Tilesets: `https://doc.mapeditor.org/en/stable/manual/editing-tilesets/`
6. Custom Properties: `https://doc.mapeditor.org/en/stable/manual/custom-properties/`

Key facts to extract:
- Full XML structure of `<map>`, `<tileset>`, `<layer>`, `<objectgroup>`, `<imagelayer>`, `<group>`, `<object>`
- GID flip bit encoding: bit 31 (0x80000000) = horizontal flip, bit 30 (0x40000000) = vertical flip, bit 29 (0x20000000) = diagonal flip — mask these off to get the real GID
- CSV encoding: one GID per cell, comma-separated, row-major, no trailing comma on last row (YATI expects this exact format)
- `<image source>` path: relative to the TSX file's own directory
- `<tileset source>` path in TMX: relative to the TMX file's own directory
- All 7 custom property types: string, int, float, bool, color, file, object

**Verify:** All six pages fetched without error; key facts noted.

**Commit:** No commit — research task only.

---

### Task 2: Read YATI source files

**Files:**
- Read: `addons/YATI/Importer.gd`
- Read: `addons/YATI/TilemapCreator.gd`
- Read: `addons/YATI/TilesetCreator.gd`

**Depends on:** none
**Parallelizable with:** Task 1, Task 3

Read all three files in full. Extract:

**From `Importer.gd`** — all 9 import options (names, defaults, effects):
1. `use_default_filter` (default: `false`) — uses Godot's default texture filter; when `false`, uses nearest-neighbor (correct for pixel art)
2. `add_class_as_metadata` (default: `false`) — stores Tiled object class as node metadata key `"class"`
3. `add_id_as_metadata` (default: `false`) — stores Tiled object ID as node metadata key `"id"`
4. `no_alternative_tiles` (default: `false`) — disables alternative tile creation for flipped/rotated tiles; saves memory but loses flip variants
5. `map_wangset_to_terrain` (default: `false`) — maps Tiled Wang sets to Godot Terrain system
6. `custom_data_prefix` (default: `"data_"`) — prefix prepended to Tiled custom property names when creating TileSet custom data layers
7. `tiled_project_file` (default: `""`) — path to `.tiled-project` for resolving custom type definitions
8. `post_processor` (default: `""`) — path to a GDScript run after import; receives the root Node2D
9. `save_tileset_to` (default: `""`) — path to save the generated `TileSet` as a `.tres` resource file

**From `TilemapCreator.gd`** — object class → Godot node mapping (`get_godot_type`):
| Tiled class string | Godot node |
|---|---|
| `""` (empty) | point → Marker2D; polygon → Polygon2D (no body); tile object → none (uses tilemap) |
| `"collision"` or `"staticbody"` | StaticBody2D |
| `"characterbody"` | CharacterBody2D |
| `"rigidbody"` | RigidBody2D |
| `"animatablebody"` | AnimatableBody2D |
| `"area"` | Area2D |
| `"navigation"` | NavigationRegion2D |
| `"occluder"` | LightOccluder2D |
| `"line"` | Line2D |
| `"path"` | Path2D |
| `"polygon"` | Polygon2D |
| `"instance"` | scene instance (requires `res_path` file property) |
| `"parallax"` | Parallax2D |
| any unknown string | warning logged; falls back to StaticBody2D |

Special custom properties handled by `TilemapCreator.gd`:
- `no_import` (bool) — skip the entire layer
- `z_index` (int) — sets `z_index` on the node
- `godot_node_type` — string; overrides the Godot node type
- `godot_group` — string; adds node to a group
- `godot_script` — file path; attaches script to node
- `tile_set` (file) — overrides the TileSet resource
- `tileset_resource_path` (string) — overrides TileSet resource path
- `y_sort_origin` (int) — sets Y-sort origin on TileMapLayer
- `x_draw_order_reversed` (bool) — reverses X draw order on TileMapLayer

Node structure produced by YATI:
- **Multi-layer TMX** (≥2 children): root = `Node2D` named after the TMX basename (e.g. `room_poc`); one `TileMapLayer` child per Tiled tile layer, named after the Tiled layer name (e.g. `Floor`, `Walls`)
- **Single-child TMX**: root returned directly (no wrapping Node2D); the single child is renamed to the TMX basename
- `TileMapLayer` — NOT legacy `TileMap`. `get_layers_count()` does NOT exist on `TileMapLayer`.

**From `TilesetCreator.gd`** — read to understand how it handles physics, navigation, and occlusion layers, and how it maps Tiled tileset properties to Godot TileSet attributes.

**Verify:** All three files read; key facts noted as above.

**Commit:** No commit — research task only.

---

### Task 3: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Depends on:** none
**Parallelizable with:** Task 1, Task 2

In `CLAUDE.md`, find the line:

```
**Skills:** brainstorming, prd, writing-plans, executing-plans, finishing-a-development-branch, run
```

Replace with:

```
**Skills:** brainstorming, prd, writing-plans, executing-plans, finishing-a-development-branch, run, tiled-map
```

**Verify:** `grep "tiled-map" CLAUDE.md` returns the updated line.

**Step: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add tiled-map to CLAUDE.md skills list"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2, Task 3 | All independent — different outputs, no shared state |

### Smoketest Checkpoint 1 — CLAUDE.md updated, research complete

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
Verify that the game launches normally and the Tiled room still loads. Also confirm `CLAUDE.md` now lists `tiled-map` in the Skills line. Wait for confirmation before proceeding.

---

## Batch 2: Write the skill file

### Task 4: Write `.claude/skills/tiled-map.md`

**Files:**
- Create: `.claude/skills/tiled-map.md`

**Depends on:** Task 1, Task 2
**Parallelizable with:** none — single task, only output file in this batch.

Using all research from Tasks 1 and 2, write `.claude/skills/tiled-map.md`. The skill must cover every requirement in the issue's R1–R6 and satisfy every acceptance criterion in AC1–AC6.

The file must begin with this frontmatter block:

```markdown
---
name: tiled-map
description: Tiled→YATI→Godot map pipeline expert. Auto-trigger: any request to create a .tmx or .tsx file. Manual trigger: /tiled-map for validation, debugging, pipeline Q&A, GDScript TileMapLayer access patterns.
invocation: Automatic when creating .tmx/.tsx files. Manual (/tiled-map) for all other uses.
---
```

**Required sections (in order):**

#### 1. Scope & Invocation
- Covers: orthogonal maps, 16×16 tiles, CSV and Base64 encoding, image-based tilesets (not tile collections for this project), YATI v2.2.7, Godot 4.6 `TileMapLayer`
- Out of scope: isometric/hex/staggered, YATI C# version, Tiled editor UI, runtime dynamic loading, tile animations, Wang sets

#### 2. TMX File Structure (R1)
Complete annotated XML template for a multi-layer map:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.0"
     orientation="orthogonal" renderorder="right-down"
     width="20" height="15"
     tilewidth="16" tileheight="16"
     infinite="0" nextlayerid="4" nextobjectid="1">

  <!-- TSX path is relative to this .tmx file -->
  <tileset firstgid="1" source="../assets/tilesets/base.tsx"/>

  <layer id="1" name="Floor" width="20" height="15">
    <data encoding="csv">
<!-- GIDs, row-major, no trailing comma on last row -->
1,1,1,...,1
1,1,1,...,1
    </data>
  </layer>

  <layer id="2" name="Walls" width="20" height="15">
    <data encoding="csv">
0,0,2,...,0
    </data>
  </layer>

  <!-- Object layer for collision/triggers -->
  <objectgroup id="3" name="Colliders">
    <object id="1" class="staticbody" x="0" y="0" width="320" height="16"/>
  </objectgroup>

</map>
```

Key rules:
- `firstgid` must start at 1 for the first tileset, increment by the previous tileset's tile count
- GID 0 = empty cell
- GID flip bits: strip before looking up tile — `real_gid = gid & ~(0x80000000 | 0x40000000 | 0x20000000)`
- `width`/`height` = map dimensions in tiles (not pixels)
- `renderorder="right-down"` is standard for orthogonal

#### 3. TSX File Structure (R1)
Complete annotated TSX template:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.11.0"
         name="base" tilewidth="16" tileheight="16"
         spacing="0" margin="0"
         tilecount="64" columns="8">

  <!-- image source path is relative to THIS .tsx file, not the .tmx file -->
  <image source="../images/base_tiles.png"
         width="128" height="128"/>

</tileset>
```

Key rules:
- `tilecount` = total number of tiles in the tileset
- `columns` = image width ÷ tilewidth
- `spacing` = gap between tiles in pixels (0 for packed sheets)
- `margin` = border around the image in pixels (0 for packed sheets)
- **Critical path gotcha:** `<image source>` is relative to the TSX file location. If TSX is at `assets/tilesets/base.tsx` and the image is at `assets/images/base_tiles.png`, the source is `../images/base_tiles.png`.
- `<tileset source>` in the TMX is relative to the TMX file location.

#### 4. YATI Import Options (R2, AC5)
Document all 9 options with name, default, and effect:

| Option | Default | Effect |
|--------|---------|--------|
| `use_default_filter` | `false` | `false` = nearest-neighbor filter (correct for pixel art); `true` = Godot default (bilinear) |
| `add_class_as_metadata` | `false` | Stores Tiled object class string as node metadata key `"class"` |
| `add_id_as_metadata` | `false` | Stores Tiled object ID as node metadata key `"id"` |
| `no_alternative_tiles` | `false` | `true` = skip alternative tile creation for flipped/rotated tiles; saves memory, loses flip support |
| `map_wangset_to_terrain` | `false` | Maps Tiled Wang sets to Godot Terrain layers |
| `custom_data_prefix` | `"data_"` | Prefix prepended to Tiled custom property names when creating TileSet custom data layers |
| `tiled_project_file` | `""` | Path to `.tiled-project` for resolving custom type definitions |
| `post_processor` | `""` | Path to GDScript run after import; receives root Node2D, can restructure the scene |
| `save_tileset_to` | `""` | Path to save the generated `TileSet` as a `.tres` resource (enables sharing across maps) |

Project default configuration: leave all at defaults. Enable `use_default_filter` = false (already the default — nearest-neighbor is what you want for 16×16 pixel art).

**YATI freeze prevention:** In Project Settings → Advanced → Editor → Import, disable "Use multiple threads" if the project has more than one Tiled map. Multi-threaded import can deadlock with multiple `.tmx` files.

#### 5. YATI-Produced Node Structure (R2, AC4)
```
# Multi-layer TMX (≥2 children at root level):
Node2D "room_poc"          ← TMX basename; this is the root of the imported .tscn
├── TileMapLayer "Floor"   ← Tiled layer name
└── TileMapLayer "Walls"   ← Tiled layer name

# Single-child TMX:
TileMapLayer "room_poc"    ← no wrapping Node2D; child renamed to TMX basename
```

Rules:
- **NOT** `TileMap` — that is the legacy Godot 3 API. `TileMap.get_layers_count()` does NOT exist.
- Layer names are taken directly from Tiled's `name` attribute on `<layer>` elements.
- Object layers become child nodes under the root, not `TileMapLayer`.

#### 6. GDScript Access Patterns (R6, AC4)
```gdscript
# Correct: multi-layer map
@onready var walls: TileMapLayer = $"../room_poc/Walls"

func is_wall(cell: Vector2i) -> bool:
    return walls.get_cell_source_id(cell) != -1

# Correct: get tile atlas coords
func get_tile_coords(cell: Vector2i) -> Vector2i:
    return walls.get_cell_atlas_coords(cell)

# Wrong — TileMap API does not exist on TileMapLayer:
# $"../room_poc".get_layers_count()         # NO
# $"../room_poc".get_cell_source_id(0, ...) # NO (layer index param)
```

World-to-cell conversion:
```gdscript
var cell: Vector2i = walls.local_to_map(walls.to_local(world_position))
```

#### 7. Object Layer → Godot Node Mapping (R2)
| Tiled object class | Godot node produced | Notes |
|---|---|---|
| `""` (empty) | point → Marker2D; polygon → Polygon2D; tile object → positioned sprite | No physics body |
| `"collision"` / `"staticbody"` | StaticBody2D + CollisionShape2D/Polygon2D | Default physics body |
| `"characterbody"` | CharacterBody2D | For moving actors |
| `"rigidbody"` | RigidBody2D | Physics-simulated |
| `"animatablebody"` | AnimatableBody2D | Kinematic with physics |
| `"area"` | Area2D | Trigger zones |
| `"navigation"` | NavigationRegion2D | Pathfinding regions |
| `"occluder"` | LightOccluder2D | 2D light occlusion |
| `"line"` | Line2D | Decorative lines |
| `"path"` | Path2D | Patrol paths |
| `"polygon"` | Polygon2D | Decorative polygons |
| `"instance"` | Instantiated scene | Requires `res_path` (file property) = `res://scenes/foo.tscn` |
| `"parallax"` | Parallax2D | Parallax background layers |
| unknown string | StaticBody2D (with warning logged) | |

#### 8. Special Custom Properties (R2)
| Property name | Type | Effect |
|---|---|---|
| `no_import` | bool | Skip this layer entirely during import |
| `z_index` | int | Sets `z_index` on the resulting node |
| `godot_node_type` | string | Overrides the node type |
| `godot_group` | string | Adds node to named group |
| `godot_script` | file | Attaches GDScript to node |
| `tile_set` | file | Overrides the TileSet resource |
| `tileset_resource_path` | string | Overrides TileSet resource path |
| `y_sort_origin` | int | Sets `y_sort_origin` on TileMapLayer |
| `x_draw_order_reversed` | bool | Reverses X draw order on TileMapLayer |

#### 9. Placeholder Map Creation Checklist (R3, AC1, AC2)
Step-by-step to produce a map that imports with 0 errors, 0 warnings:

1. **Choose sizes:** Map dimensions in tiles (e.g. 20×15). Tile size: always 16×16.
2. **Place assets:** Image at `assets/images/<name>.png`, TSX at `assets/tilesets/<name>.tsx`, TMX at `maps/<name>.tmx`.
3. **Write TSX first** — set `tilecount` and `columns` from image dimensions. Set `<image source>` relative to the TSX file.
4. **Write TMX** — reference TSX with `<tileset source>` relative to the TMX file. Set `firstgid="1"`. Use GIDs 1..tilecount; use 0 for empty cells.
5. **Validate CSV data:** Rows = map height, columns = map width per row. No trailing comma on last row. Row count must equal `height` attribute.
6. **Run import:** Save files in `maps/` and `assets/tilesets/` under `res://`. Godot auto-imports on editor focus. Check the Import dock for errors.
7. **Check output:** `Import succeeded.` with no errors or warnings.

#### 10. Validation Rules (R4, AC3)
**Structural validation:**
- XML is well-formed (tags closed, attributes quoted)
- `firstgid` ≥ 1 and present on every `<tileset>` element
- All GIDs (after stripping flip bits) are in range `[0, firstgid + tilecount - 1]`
- TSX `source` attribute exists and the file is at that path relative to the TMX
- `<image source>` in TSX resolves to an existing file relative to the TSX
- Data encoding is `csv` or `base64` (no unrecognized value)
- Row count in CSV data matches the layer's `height` attribute
- Column count per row matches the layer's `width` attribute

**Project-specific validation:**
- `tilewidth="16"` and `tileheight="16"` on all `<map>` and `<tileset>` elements
- `orientation="orthogonal"` on `<map>`
- TMX files go in `maps/`, TSX files go in `assets/tilesets/`, images in `assets/images/`
- Object class strings are one of the recognized YATI values or empty; unknown strings produce a warning
- Layer names match what game code references (e.g. `"Floor"`, `"Walls"`)

#### 11. YATI Debug Workflow (R5)
**Reading YATI output:**
YATI prints to Godot's output panel during import. Format:
```
Import file 'res://maps/room_poc.tmx'
Import succeeded.
```
Or on failure:
```
Import file 'res://maps/room_poc.tmx'
Import finished with 2 errors and 1 warning.
```
Errors stop correct import; warnings may produce a usable but incorrect scene.

**Silent failure modes:**
| Symptom | Cause | Fix |
|---|---|---|
| TSX not found | Wrong relative path in `<tileset source>` | Path must be relative to the TMX file |
| Image not found / texture missing | Wrong `<image source>` in TSX | Path must be relative to the TSX file |
| GIDs out of range (wrong tiles appear) | GID exceeds `firstgid + tilecount - 1`, or `firstgid` is wrong | Check tileset tile count and firstgid |
| Missing `firstgid` | `<tileset>` has no `firstgid` attribute | Add `firstgid="1"` |
| Unknown object class warning | Object class string not in YATI's known list | Use one of the 13 recognized class strings |
| Editor freezes on import | Multi-thread import with multiple .tmx files | Disable "Use multiple threads" in Project Settings → Editor → Import |
| Scene structure wrong (flat, no wrapper) | Only 1 child at root level | This is intended YATI behavior — add a second layer or accept it |

**Forcing re-import:** Delete the `.import` files for the TMX and TSX (in `.godot/imported/`) and re-focus the editor, or use the Reimport button in the Import dock.

---

**Step 1: Verify the file exists**
```bash
ls .claude/skills/tiled-map.md
```
Expected: file listed.

**Step 2: Self-review against ACs**

Check each acceptance criterion:
- AC1: Does the placeholder map checklist in §9 produce a valid map that imports cleanly?
- AC2: Does §3 (TSX) explicitly document both path rules?
- AC3: Does §10 list wrong tile size, unknown object class, broken paths, GIDs out of range, missing firstgid?
- AC4: Does §5 (node structure) and §6 (GDScript) describe TileMapLayer correctly — no TileMap?
- AC5: Does §4 list all 9 import options?
- AC6: Can a user get end-to-end pipeline answers without leaving the skill?

Fix any gaps before committing.

**Step 3: Commit**
```bash
git add .claude/skills/tiled-map.md
git commit -m "feat: add tiled-map skill — Tiled/YATI/GDScript pipeline expert"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 4 | Single task; writes one file; no parallelism possible — only task in batch |

### Smoketest Checkpoint 2 — skill file complete and verified

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures. (No new tests added — this is a skill file, not game code.)

**Step 3: Functional verification**

Invoke the skill manually:
```
/tiled-map
```

Ask it: "Create a placeholder TMX for a 20×15 room with two layers (Floor, Walls) and one static body collider object layer. Use the base tileset at assets/tilesets/base.tsx."

Verify the output:
- TMX is well-formed XML with `orientation="orthogonal"`, `tilewidth="16"`, `tileheight="16"`
- TSX `source` path is correct relative to the TMX location (`maps/`)
- `<image source>` in TSX is correct relative to TSX location (`assets/tilesets/`)
- CSV data rows count matches `height="15"`, columns count matches `width="20"`
- Object layer has `class="staticbody"` (not `class="collision"` — both are valid but staticbody is preferred)
- `firstgid="1"` present

If you have a Godot project open: copy the generated TMX/TSX into `maps/` and `assets/tilesets/`, focus the editor, and confirm: `Import succeeded.` with 0 errors and 0 warnings.

**Step 4: Confirm with user**
Confirm the skill is invocable, the generated map passes the AC1 test (0 errors/warnings on import), and all ACs are met. Wait for confirmation before proceeding to the PR.
