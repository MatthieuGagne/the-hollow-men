# Engine & Visual Design — FINAL NOIRE

*Authored: 2026-04-12*

---

## Engine

**Godot 4**

Chosen for its best-in-class 2D pixel art renderer, full control over custom mechanics (ATB, Sigil system, dual-register, PP drain), and zero licensing cost. GDScript enables fast iteration. The engine does not fight pixel art — it is designed for it.

---

## Section 1: Core Visual Specifications

### Base Resolution

**320×180px** (16:9)

Scales cleanly to 1280×720, 1920×1080, and 4K without fractional pixels. Delivers authentic SNES-era pixel density on modern screens without letterboxing.

### Tile Size

**16×16px** — standard SNES RPG grid (FF6, Chrono Trigger).

### Sprite Sizes

| Context | Size |
|---|---|
| Overworld characters | 16×24px |
| Battle sprites | 32×48px |
| Dialogue portraits | 48×48px |
| Standard enemies (battle) | 32×32px – 64×64px |
| Boss sprites (battle) | Up to 64×64px |

### Color Palette

Unrestricted per sprite. Area-level palettes serve as **design guidelines** for cohesion, not hard constraints:

| District | Dominant Palette Identity |
|---|---|
| The Heights | Cold blues, clinical whites |
| The Sprawl | Warm neon, mid-tone grays |
| The Meridian | Wrong greens, deep purples |
| The Warrens | Rust, soot, dim amber |
| The Ruins | Near-black, bone white, deep crimson |

### Pixel Art Rules

- No sub-pixel animation — all movement snaps to pixel grid
- Palette per sprite: unrestricted

### Atmosphere (No Extra Art Cost)

| Effect | Implementation |
|---|---|
| Rain | Godot particle system using 1×3px sprites |
| Neon glow | `Light2D` with additive blending on signage tiles |
| District darkness/tint | `CanvasModulate` overlay per scene |
| Ability effects | Animated 16×16 tile overlays + shaders |

---

## Section 2: Engine Architecture

### Scene Structure

- **`World`** — camera, tilemap, NPC nodes, transition triggers, encounter state flag
- **`BattleScene`** — separate scene, loaded on encounter via flash transition
- **`UI`** — `CanvasLayer` above everything; menus, dialogue box, ATB bars, portraits

### Tilemap

Maps authored in **Tiled**, imported to Godot 4 via the **naddys_tiled_maps** plugin (installed at `addons/naddys_tiled_maps/`).

Tiled layer conventions:

| Layer Name | Purpose |
|---|---|
| `ground` | Floor tiles, base terrain |
| `objects` | Furniture, props, foreground detail |
| `overhead` | Canopies, overhangs — renders above player |
| `collision` | Collision shapes baked into tiles |

### Camera

- `Camera2D` with position smoothing enabled
- Player-centered, smooth scrolling (Chrono Trigger behavior)
- Hard stop at scene boundaries — no reveal beyond map edge

### Investigation vs. Hot Zone Mode

Implemented as a **state flag on the World scene** — toggles encounter rate and ambient audio layer. No separate scene load. Same map, different behavior.

| Mode | Encounter Rate | Audio |
|---|---|---|
| Investigation | Zero to near-zero | Ambient noir (rain, distant city) |
| Hot Zone | Active | Tension underscore |
| The Ruins | Always active | Constant dread layer |

---

## Section 3: Battle System Visuals

### Screen Layout

Side-view battle screen (FF4–FF6 style):
- Enemies displayed on the right, large and detailed
- Party sprites displayed on the left, animated
- UI panel anchored to bottom of screen

### Sprite Animation Budget

| State | Frames |
|---|---|
| Idle | 2–4 frames (breathing, weight shift) |
| Attack | Step forward → hit flash on enemy → step back |
| Damage received | 2-frame knockback |
| KO | Collapse to 1-frame downed pose |

### Ability Effects

| Ability Type | Visual |
|---|---|
| Fire / elemental | Animated 16×16 tile overlay, looped |
| Psychic / PP drain | Desaturate shader on target |
| Limit Break (Bureau) | Gray bloom, capped visual |
| Limit Break (Jailbroken) | Gold bloom, full screen pulse |

### ATB UI Bars

Horizontal fill bars per character in the bottom UI panel:

| Bar | Color |
|---|---|
| HP | Green → red (depletes) |
| PP (Psychic Points) | Purple → empty |
| ATB gauge | White fill |

- When ATB fills: character name pulses, awaiting input
- All bars update in real time (active ATB behavior)

### Limit Break Bar

| Sigil Equipped | Bar Color | Cap |
|---|---|---|
| Bureau Sigil | Gray fill | 80% — visually metered |
| Jailbroken Sigil | Gold fill | 100% — uncapped |

The visual difference communicates the political act without dialogue.

### Encounter Transition

White flash → palette invert → battle scene loads.

FF6 homage. Implemented as a single shader. No additional art required.

---

## Implementation Status

| Item | Status |
|---|---|
| `project.godot` — 320×180, nearest filter, mobile renderer | Done |
| `scenes/world/World.tscn` — TileMapLayer stack, Camera2D, encounter flag | Done |
| `scenes/battle/BattleScene.tscn` — layout, HUD, flash overlay | Done |
| `scripts/battle/combatant.gd` — stats, ATB tick, PP drain, limit cap logic | Done |
| `scripts/battle/battle_scene.gd` — ATB loop, turn queue, win/loss detection | Done |
| `scripts/ui/hud.gd` — HP/PP/ATB/Limit bars with correct colors | Done |
| `scripts/world/world.gd` — Investigation/Hot Zone/Ruins modes | Done |
| naddys_tiled_maps plugin — installed and enabled | Done |
| Asset folders — sprites, tilesets, audio, maps, addons | Done |

---

## Open Questions

- Font choice for UI — pixel font to match aesthetic (suggest looking at fonts in the style of FF6's menu font)
- Battle background art per district — static painted backgrounds or parallax tile layers?
- NPC animation budget — 2-frame idle only, or directional walk cycles?
- Dialogue box style — opaque dark panel with portrait, or translucent overlay?
