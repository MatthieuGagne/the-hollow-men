# Multi-Room Navigation — Case 1 Stub Maps

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create three stub maps (HeightsSuzy, SprawlSafehouse, KarimClinic) connected bidirectionally to each other and to Four Winds Bar via the ExitDoor → SceneManager → SpawnPoint pipeline.

**Architecture:** Each map is a 16×12-tile TMX file (wall border, walkable interior, two door gaps) imported via YATI and wrapped in a BaseRoom.tscn instance scene. ExitDoors and SpawnPoints are placed as `type="instance"` objects in the TMX Interactions layer — YATI instantiates them at runtime. No GDScript logic is added; this is pure map/scene wiring.

**Tech Stack:** Tiled TMX, YATI importer, Godot 4 BaseRoom pattern (see `scenes/world/FourWindsBar.tscn` + `maps/four_winds_bar.tmx` as the reference).

---

## Navigation topology

```
Four Winds Bar  ↔  HeightsSuzy  ↔  SprawlSafehouse  ↔  KarimClinic
```

## SpawnPoint naming convention

Each map has one SpawnPoint per entry direction, named `<origin>_entrance`:

| Map | SpawnPoint ID | Meaning |
|-----|--------------|---------|
| FourWindsBar | `four_winds_entrance` *(new)* | Player arrives from HeightsSuzy |
| HeightsSuzy | `four_winds_entrance` | Player arrives from FWB |
| HeightsSuzy | `sprawl_entrance` | Player arrives from SprawlSafehouse |
| SprawlSafehouse | `heights_entrance` | Player arrives from HeightsSuzy |
| SprawlSafehouse | `clinic_entrance` | Player arrives from KarimClinic |
| KarimClinic | `sprawl_entrance` | Player arrives from SprawlSafehouse |

## Tile layout (all three new maps)

16×12 tiles (matching FWB). Wall border (tile ID `2`), walkable interior (tile ID `7`). Door gaps at **column 8** of **row 0** (top exit) and **row 11** (bottom exit).

```
Row  0: 2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2
Rows 1–10: 2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2  (× 10 rows)
Row 11: 2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2
```

Door objects pixel positions (Tiled top-left anchor):
- Top door: `x=128, y=8` (centre of row 0)
- Bottom door: `x=128, y=176` (top of row 11)

SpawnPoints (1 tile inward from their door):
- Near top door: `x=128, y=32` (row 2)
- Near bottom door: `x=128, y=144` (row 9)

---

## Batch 1 — Three stub TMX maps

*All three tasks write different files and share no state. Run in parallel.*

---

### Task 1: maps/heights_suzy.tmx

**Files:**
- Create: `maps/heights_suzy.tmx`

**Depends on:** none
**Parallelizable with:** Task 2, Task 3

**Step 1: Create the file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.2" orientation="orthogonal" renderorder="right-down" width="16" height="12" tilewidth="16" tileheight="16" infinite="0" nextlayerid="4" nextobjectid="5">
 <tileset firstgid="1" source="placeholder.tsx"/>
 <layer id="1" name="World" width="16" height="12">
  <data encoding="csv">
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2
</data>
 </layer>
 <objectgroup id="2" name="Objects">
 </objectgroup>
 <objectgroup id="3" name="Interactions">
  <object id="1" type="instance" x="128" y="32" width="16" height="16">
   <properties>
    <property name="spawn_id" value="sprawl_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="2" type="instance" x="128" y="144" width="16" height="16">
   <properties>
    <property name="spawn_id" value="four_winds_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="3" type="instance" x="128" y="8" width="16" height="16">
   <properties>
    <property name="target_path" value="res://scenes/world/SprawlSafehouse.tscn"/>
    <property name="spawn_point" value="heights_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
   </properties>
  </object>
  <object id="4" type="instance" x="128" y="176" width="16" height="16">
   <properties>
    <property name="target_path" value="res://scenes/world/FourWindsBar.tscn"/>
    <property name="spawn_point" value="four_winds_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
   </properties>
  </object>
 </objectgroup>
</map>
```

**Step 2: Verify**

Open in Tiled (optional). The file must be valid XML — run:
```powershell
[xml](Get-Content maps\heights_suzy.tmx)
```
Expected: no parse error.

**Step 3: Commit**

```bash
git add maps/heights_suzy.tmx
git commit -m "feat: add heights_suzy stub TMX map"
```

---

### Task 2: maps/sprawl_safehouse.tmx

**Files:**
- Create: `maps/sprawl_safehouse.tmx`

**Depends on:** none
**Parallelizable with:** Task 1, Task 3

**Step 1: Create the file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.2" orientation="orthogonal" renderorder="right-down" width="16" height="12" tilewidth="16" tileheight="16" infinite="0" nextlayerid="4" nextobjectid="5">
 <tileset firstgid="1" source="placeholder.tsx"/>
 <layer id="1" name="World" width="16" height="12">
  <data encoding="csv">
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2
</data>
 </layer>
 <objectgroup id="2" name="Objects">
 </objectgroup>
 <objectgroup id="3" name="Interactions">
  <object id="1" type="instance" x="128" y="32" width="16" height="16">
   <properties>
    <property name="spawn_id" value="heights_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="2" type="instance" x="128" y="144" width="16" height="16">
   <properties>
    <property name="spawn_id" value="clinic_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="3" type="instance" x="128" y="8" width="16" height="16">
   <properties>
    <property name="target_path" value="res://scenes/world/HeightsSuzy.tscn"/>
    <property name="spawn_point" value="sprawl_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
   </properties>
  </object>
  <object id="4" type="instance" x="128" y="176" width="16" height="16">
   <properties>
    <property name="target_path" value="res://scenes/world/KarimClinic.tscn"/>
    <property name="spawn_point" value="sprawl_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
   </properties>
  </object>
 </objectgroup>
</map>
```

**Step 2: Verify**

```powershell
[xml](Get-Content maps\sprawl_safehouse.tmx)
```
Expected: no parse error.

**Step 3: Commit**

```bash
git add maps/sprawl_safehouse.tmx
git commit -m "feat: add sprawl_safehouse stub TMX map"
```

---

### Task 3: maps/karim_clinic.tmx

**Files:**
- Create: `maps/karim_clinic.tmx`

**Depends on:** none
**Parallelizable with:** Task 1, Task 2

**Step 1: Create the file**

Karim's Clinic is the chain terminus — one entrance (from Sprawl), one return exit. Bottom door leads back to Sprawl; top gap kept open for future use with no ExitDoor yet.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.11.2" orientation="orthogonal" renderorder="right-down" width="16" height="12" tilewidth="16" tileheight="16" infinite="0" nextlayerid="4" nextobjectid="4">
 <tileset firstgid="1" source="placeholder.tsx"/>
 <layer id="1" name="World" width="16" height="12">
  <data encoding="csv">
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,7,7,7,7,7,7,7,7,7,7,7,7,7,7,2,
2,2,2,2,2,2,2,2,7,2,2,2,2,2,2,2
</data>
 </layer>
 <objectgroup id="2" name="Objects">
 </objectgroup>
 <objectgroup id="3" name="Interactions">
  <object id="1" type="instance" x="128" y="32" width="16" height="16">
   <properties>
    <property name="spawn_id" value="sprawl_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="2" type="instance" x="128" y="144" width="16" height="16">
   <properties>
    <property name="spawn_id" value="default"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
   </properties>
  </object>
  <object id="3" type="instance" x="128" y="176" width="16" height="16">
   <properties>
    <property name="target_path" value="res://scenes/world/SprawlSafehouse.tscn"/>
    <property name="spawn_point" value="clinic_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
   </properties>
  </object>
 </objectgroup>
</map>
```

**Step 2: Verify**

```powershell
[xml](Get-Content maps\karim_clinic.tmx)
```
Expected: no parse error.

**Step 3: Commit**

```bash
git add maps/karim_clinic.tmx
git commit -m "feat: add karim_clinic stub TMX map"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2, Task 3 | Different output files, no shared state |
| B (sequential) | Reimport | Depends on all three TMX files existing |

### Smoketest Checkpoint 1 — maps import without errors

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Reimport all maps**
```bash
godot_console --headless --editor --quit --path .
```
Expected: No `ERROR:` lines relating to TMX import. The exit-time "RID allocations leaked" warnings are normal and can be ignored.

**Step 3: Confirm**
Tell the user: "Three new TMX files are imported. No scene exists for them yet — that's Batch 2. Confirm there are no import errors above."

Wait for confirmation before proceeding.

---

## Batch 2 — Three BaseRoom scenes

*Tasks 4–6 are parallel (each depends only on its own Task 1–3 and the Batch 1 reimport).*

---

### Task 4: scenes/world/HeightsSuzy.tscn

**Files:**
- Create: `scenes/world/HeightsSuzy.tscn`

**Depends on:** Task 1, Smoketest Checkpoint 1
**Parallelizable with:** Task 5, Task 6

**Step 1: Create the file**

```gdscript
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/world/BaseRoom.tscn" id="1_baseroom"]
[ext_resource type="PackedScene" path="res://maps/heights_suzy.tmx" id="2_map"]

[node name="HeightsSuzy" instance=ExtResource("1_baseroom")]
world_layer_path = NodePath("heights_suzy/World")
default_spawn = "four_winds_entrance"
ambient_color = Color(0.05, 0.05, 0.10, 1)

[node name="heights_suzy" parent="." instance=ExtResource("2_map")]
```

> **Note:** BaseRoom.tscn has no uid — all existing scenes reference it without one (verified in `FourWindsBar.tscn`, `HeightsStreet.tscn`, `RoomPOC.tscn`). The TMX ext_resource also omits a uid here; Godot assigns one during headless import.

**Step 2: Verify**

After creating the file, run a headless reimport. Godot will validate that `HeightsSuzy.tscn` can resolve its dependencies:
```bash
godot_console --headless --editor --quit --path .
```
Expected: no `ERROR:` lines for `HeightsSuzy.tscn`.

**Step 3: Commit**

```bash
git add scenes/world/HeightsSuzy.tscn
git commit -m "feat: add HeightsSuzy scene (BaseRoom stub)"
```

---

### Task 5: scenes/world/SprawlSafehouse.tscn

**Files:**
- Create: `scenes/world/SprawlSafehouse.tscn`

**Depends on:** Task 2, Smoketest Checkpoint 1
**Parallelizable with:** Task 4, Task 6

**Step 1: Create the file**

```gdscript
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/world/BaseRoom.tscn" id="1_baseroom"]
[ext_resource type="PackedScene" path="res://maps/sprawl_safehouse.tmx" id="2_map"]

[node name="SprawlSafehouse" instance=ExtResource("1_baseroom")]
world_layer_path = NodePath("sprawl_safehouse/World")
default_spawn = "heights_entrance"
ambient_color = Color(0.04, 0.04, 0.08, 1)

[node name="sprawl_safehouse" parent="." instance=ExtResource("2_map")]
```

**Step 2: Verify**

```bash
godot_console --headless --editor --quit --path .
```
Expected: no `ERROR:` lines for `SprawlSafehouse.tscn`.

**Step 3: Commit**

```bash
git add scenes/world/SprawlSafehouse.tscn
git commit -m "feat: add SprawlSafehouse scene (BaseRoom stub)"
```

---

### Task 6: scenes/world/KarimClinic.tscn

**Files:**
- Create: `scenes/world/KarimClinic.tscn`

**Depends on:** Task 3, Smoketest Checkpoint 1
**Parallelizable with:** Task 4, Task 5

**Step 1: Create the file**

```gdscript
[gd_scene format=3]

[ext_resource type="PackedScene" path="res://scenes/world/BaseRoom.tscn" id="1_baseroom"]
[ext_resource type="PackedScene" path="res://maps/karim_clinic.tmx" id="2_map"]

[node name="KarimClinic" instance=ExtResource("1_baseroom")]
world_layer_path = NodePath("karim_clinic/World")
default_spawn = "sprawl_entrance"
ambient_color = Color(0.04, 0.06, 0.08, 1)

[node name="karim_clinic" parent="." instance=ExtResource("2_map")]
```

**Step 2: Verify**

```bash
godot_console --headless --editor --quit --path .
```
Expected: no `ERROR:` lines for `KarimClinic.tscn`.

**Step 3: Commit**

```bash
git add scenes/world/KarimClinic.tscn
git commit -m "feat: add KarimClinic scene (BaseRoom stub)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 4, Task 5, Task 6 | Each writes a different .tscn; no shared state |
| B (sequential) | Launch game | Depends on all scenes existing and importing cleanly |

### Smoketest Checkpoint 2 — scenes load in editor

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: all tests pass (no regressions — these tasks add no GDScript logic).

**Step 3: Launch game and verify visually**

Launch the game. You will still be in Four Winds Bar because the ExitDoor wiring hasn't been updated yet (that's Batch 3). The goal here is only to verify the new scenes can be opened.

Open each new scene in the editor (`scenes/world/HeightsSuzy.tscn`, `SprawlSafehouse.tscn`, `KarimClinic.tscn`) and confirm:
- The TileMapLayer is visible with the placeholder tileset (wall border + walkable interior)
- No "missing resource" errors in the editor output
- The player node is present (inherited from BaseRoom)

**Step 4: Confirm with user**
Tell the user what was verified above. Wait for confirmation before proceeding to Batch 3.

---

## Batch 3 — FWB wiring

*Task 7 is the only task in this batch. It touches `four_winds_bar.tmx` so it must be sequential with any other task that edits that file. Since no other task in this plan touches it, there is no parallelism opportunity here.*

---

### Task 7: Wire Four Winds Bar to HeightsSuzy

**Files:**
- Modify: `maps/four_winds_bar.tmx`

**Depends on:** Tasks 4, 5, 6 (HeightsSuzy.tscn must exist before FWB targets it), Smoketest Checkpoint 2
**Parallelizable with:** none — only task in batch; writes `four_winds_bar.tmx` which no other task in this plan touches.

Three changes to `four_winds_bar.tmx`:

1. **Update ExitDoor `target_path`** from `res://scenes/world/RoomPOC.tscn` to `res://scenes/world/HeightsSuzy.tscn`
2. **Remove `required_flag`** property from the ExitDoor (temporarily — issue #83 restores it once Suzy's dialogue sets the flag)
3. **Add `four_winds_entrance` SpawnPoint** near the exit door (tile col 8, row 10 — one tile above the door)

**Step 1: Apply the three changes**

Find the ExitDoor object in `maps/four_winds_bar.tmx` (currently `object id="3"`) and update it:

```xml
<object id="3" type="instance" x="128" y="184" width="16" height="16">
 <properties>
  <property name="target_path" value="res://scenes/world/HeightsSuzy.tscn"/>
  <property name="spawn_point" value="four_winds_entrance"/>
  <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
 </properties>
</object>
```

> The `required_flag` property is intentionally absent. Issue #83 will restore it as `required_flag` = `vera_lead_obtained` once `GameStateVariableStorage` strips the `$` prefix and Suzy's dialogue sets the flag.

Also add a new SpawnPoint at the end of the Interactions objectgroup, and bump `nextobjectid` on the `<map>` element to one above the new object's id. Current highest object id is 8; new SpawnPoint gets id 9, so `nextobjectid="10"`:

```xml
<object id="9" type="instance" x="128" y="160" width="16" height="16">
 <properties>
  <property name="spawn_id" value="four_winds_entrance"/>
  <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
 </properties>
</object>
```

Also update the `<map>` tag's `nextobjectid` attribute from `"9"` to `"10"`.

**Step 2: Reimport**

```bash
godot_console --headless --editor --quit --path .
```
Expected: `four_winds_bar.tmx` reimports cleanly. No errors.

**Step 3: Commit**

```bash
git add maps/four_winds_bar.tmx
git commit -m "feat: wire FWB ExitDoor to HeightsSuzy, add four_winds_entrance spawn"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 7 | Only task in batch — no parallel opportunity |

### Smoketest Checkpoint 3 — full chain traversal

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: all tests pass.

**Step 3: Launch game and verify visually**

```bash
godot_console --path .
```

Verify the full navigation chain in both directions:

| Leg | Action | Expected result |
|-----|--------|----------------|
| FWB → Heights | Walk south to exit (bottom of FWB) | Player arrives in HeightsSuzy at `four_winds_entrance` spawn (row 9, col 8) |
| Heights → FWB | Walk south to exit (bottom of HeightsSuzy) | Player arrives in FWB at `four_winds_entrance` spawn (row 9, col 8) |
| Heights → Sprawl | Walk north to exit (top of HeightsSuzy) | Player arrives in SprawlSafehouse at `heights_entrance` spawn (row 2, col 8) |
| Sprawl → Heights | Walk north to exit (top of SprawlSafehouse) | Player arrives in HeightsSuzy at `sprawl_entrance` spawn (row 2, col 8) |
| Sprawl → Clinic | Walk south to exit (bottom of SprawlSafehouse) | Player arrives in KarimClinic at `sprawl_entrance` spawn (row 2, col 8) |
| Clinic → Sprawl | Walk south to exit (bottom of KarimClinic) | Player arrives in SprawlSafehouse at `clinic_entrance` spawn (row 9, col 8) |

**Step 4: Confirm with user**
Tell the user what was verified. Wait for confirmation before calling this feature complete.
