# Annotated TMX / TSX Templates

## TMX file structure — annotated template (multi-layer orthogonal map)

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
                  Both .tmx and .tsx live in maps/, so this is usually
                  just the bare filename.
  -->
  <tileset firstgid="1" source="placeholder.tsx"/>

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
        - To flip a tile, set flip bits in the GID (see Key rules in SKILL.md)
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
      See the class→node mapping table in SKILL.md.
      Rectangle objects: x/y = top-left corner; width/height in pixels.
  -->
  <objectgroup id="3" name="Collision">
    <object id="1" class="staticbody" x="0" y="0" width="320" height="16"/>
  </objectgroup>

</map>
```

## TSX file structure — annotated template

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
<tileset name="placeholder" tilewidth="16" tileheight="16"
         spacing="0" margin="0"
         tilecount="64" columns="8">

  <!--
    IMAGE PATH GOTCHA (CRITICAL):
      The `source` attribute is RELATIVE TO THE TSX FILE'S DIRECTORY.
      .tsx files live in maps/ in this project; tileset images live in
      assets/tilesets/ (object sprites in assets/objects/).
      If placeholder.tsx is at  maps/placeholder.tsx
      and the image is at       assets/tilesets/placeholder.png
      then source MUST be       "../assets/tilesets/placeholder.png"
      NEVER use res:// paths here — YATI resolves them as filesystem paths
      relative to the TSX.
  -->
  <image source="../assets/tilesets/placeholder.png" width="128" height="128"/>

  <!--
    Tile type definition (e.g. walls):
      Set class= on individual tiles to define their type. With the import
      option add_class_as_metadata=true, the class string becomes tile
      metadata readable at runtime via
      get_cell_tile_data(cell).get_meta("class", "").
  -->
  <tile id="0" class="wall"/>

</tileset>
```
