# The Hollow Men

Turn-based cyberpunk noir horror JRPG. Protagonist Reid investigates a missing person in
NOX — a perpetually rain-soaked city — uncovering an ancient non-Euclidean entity.
Themes: film noir, Lovecraftian horror, corporate magic bureaucracy (Shadowrun influence).

**Engine:** Godot 4.6 / GDScript — runtime is GDScript only; C# used for editor tooling (YATI importer)
**Renderer:** Mobile (GL Compatibility)
**Resolution:** 320×180 → upscaled to 1280×720 (4:3)

## Autoloads
- `scripts/autoload/scene_manager.gd` — fade transitions; call `SceneManager.change_scene(path)`

## Architecture
- Scenes: `scenes/` — battle, world, UI
- Scripts: `scripts/` — GDScript; `scripts/autoload/` for singletons
- Dialogue: YarnSpinner planned (C# runtime bridge TBD)
- Maps: Tiled → YATI importer (`addons/YATI`); tileset PNG at `assets/tilesets/`
  - Art sources in `art/tilesets/` (`.xcf` + third-party PNGs — all committed)
  - `assets/tilesets/` is a build artifact dir (gitignored PNGs, not committed)
  - Build pipeline: export XCF manually in GIMP → `make` (copies PNGs → Godot reimport)
  - Define tile types via `class=` attribute on tiles in the `.tsx` (e.g. `class="wall"`)
  - After first import, set `add_class_as_metadata=true` in the generated `.tmx.import` file
  - Single-layer TMX → YATI produces one root `TileMapLayer` named after the file (e.g. `room_poc`)
  - Reimport after changing a TMX: `DISPLAY=:0 godot --headless --editor --quit --path .`
  - Runtime wall check: `tilemap.get_cell_tile_data(cell).get_meta("class", "") == "wall"`

## Dev Workflow
- Feature branches in worktrees: `feat/issue-<N>-<description>`
- Worktree base: `/home/mathdaman/code/worktrees/`
- **After creating a new worktree**, run `make worktree-init` before launching the game — this copies gitignored build artifacts (e.g. `placeholder.png`) from the main repo and runs a full headless reimport. Without it, the map renders empty.
- TDD for all GDScript logic: write failing GUT test first
- Run GUT: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- PR-only integration — never merge locally to master

### Worktree Init Troubleshooting

| Missing | Why | Fix |
|---|---|---|
| `.godot/` import cache | Generated at runtime, gitignored | Created automatically on first headless import |
| `assets/tilesets/placeholder.png` | Build artifact, gitignored | Copied from main repo by `make worktree-init` |
| `dialogue/*.import` + `iris.yarnproject` imported cache | Gitignored YarnSpinner sidecars | Copied from main repo by `make worktree-init` |
| `iris.yarnproject` fails to import | C# YarnSpinner importer not compiled yet | Run `dotnet build` before `make import` |

If map still renders empty after init, the TMX cache may be stale — delete and reimport:
```bash
rm .godot/imported/room_poc.tmx-*.{md5,tscn}
DISPLAY=:0 godot --headless --editor --quit --path .
```

## Feature Lifecycle

```
idea → brainstorm → PRD (GitHub issue) → plan → worktree → implement → finish → PR → merge → cleanup
```

1. `/brainstorming` — explore the idea
2. `/prd` — write a GitHub issue spec
3. `/writing-plans` — turn spec into step-by-step tasks
4. Create worktree: `git worktree add /home/mathdaman/code/worktrees/<branch> -b <branch>` then `make worktree-init`
5. `/executing-plans` — implement with checkpoints
6. `/finishing-a-development-branch` — tests, smoketest, PR, cleanup

## Running the Game

Use `/run` — handles worktree detection, pre-flight init check, killing stale Godot instances, and launch.

## Skills & Agents

| Skill | When to use |
|---|---|
| `brainstorming` | Exploring an idea before writing a spec |
| `prd` | Writing a feature spec as a GitHub issue |
| `writing-plans` | Turning a spec into implementation steps |
| `executing-plans` | Working through a plan with checkpoints |
| `finishing-a-development-branch` | Tests, smoketest, PR, cleanup |
| `run` | Launching the game or editor |
| `tiled-map` | Map pipeline: creating/editing TMX/TSX, debugging imports |
| `story-lore` | Writing narrative, dialogue, lore, flavor text |

| Agent | When to use |
|---|---|
| `godot-expert` | GDScript implementation and TDD with GUT |
| `yarnspinner` | Dialogue scripting and YarnSpinner integration |

## Key Conventions
- Signal-driven UI: UI connects to autoload signals, never polls
- Static typing preferred: `var foo: int = 0`
- Test files: `tests/test_<module>.gd`
