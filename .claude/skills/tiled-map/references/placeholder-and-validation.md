# Tiled-Map Reference — Placeholder Authoring Checklist & Validation

Follow when creating a new placeholder map or validating an existing `.tmx`/`.tsx`. The always-fired rules live in `SKILL.md`; this is the step-by-step checklist and the exhaustive validation table.

## Placeholder Map Creation Checklist

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
   - Use only class strings from the object-layer mapping table (see `nodes-and-gdscript.md`)
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
   - Headless reimport after creating or changing a TMX: `& (& ./scripts/godot_path.ps1) --headless --editor --quit --path .`
   - Or in the editor: select the `.tmx`, open the Import dock, set `use_default_filter = false` (nearest-neighbor for pixel art), set `save_tileset_to` if you want a shared `.tres` TileSet, click "Reimport"
   - **After the first import**, set `add_class_as_metadata=true` in the generated `.tmx.import` file (required for the runtime wall check), then reimport
   - `.tmx.import` files are gitignored build artifacts — do not commit them
   - Check the Output panel for YATI messages: zero errors and zero warnings = success

## Validation Rules

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
| Object class strings | Must be one of the known strings in the object-layer mapping (see `nodes-and-gdscript.md`); unknown strings produce a warning and fall back to StaticBody2D |
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
