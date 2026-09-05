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

## 5. Lookup References (load on demand)

The heavy look-up content lives in `references/` — open the relevant file when the task needs it:

| Topic | File |
|---|---|
| YATI node structure, GDScript TileMapLayer access patterns (incl. WRONG patterns), object-layer → node mapping | `references/nodes-and-gdscript.md` |
| Placeholder-map creation checklist + full validation tables | `references/placeholder-and-validation.md` |
| Annotated XML templates (TMX/TSX) | `references/templates.md` |
| YATI-interpreted custom properties (`no_import`, `z_index`, `godot_node_type`, `godot_script`, …) | `references/yati-reference.md` |
| Debugging (reading YATI output, silent failures, forcing re-import) | `references/debugging.md` |

## 6. Special Custom Properties

> Full table of YATI-interpreted custom properties (`no_import`, `z_index`, `godot_node_type`, `godot_script`, etc.): see `references/yati-reference.md`.

## 7. Debugging

> Debug workflow — reading YATI output, silent failure modes, full warning/error message reference, forcing re-import, and the tileset-PNG update sequence: see `references/debugging.md`.

Quick reference: reimport after changing a TMX with `& (& ./scripts/godot_path.ps1) --headless --editor --quit --path .`
