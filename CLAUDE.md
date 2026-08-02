# The Hollow Men

Turn-based cyberpunk noir horror JRPG. Protagonist Reid investigates a missing person in
NOX — a perpetually rain-soaked city — uncovering an ancient non-Euclidean entity.
Themes: film noir, Lovecraftian horror, corporate magic bureaucracy (Shadowrun influence).

**Engine:** Godot 4.7 / GDScript — runtime is GDScript only; C# used for editor tooling (YATI importer)
**Renderer:** Mobile (GL Compatibility)
**Resolution:** 320×180 → upscaled to 1280×720 (4:3)

## Autoloads
Listed under `[autoload]` in `project.godot`. SceneManager (`scripts/autoload/scene_manager.gd`) handles fade transitions via `SceneManager.change_scene(path)`.

## Architecture
- Scenes: `scenes/` — battle, world, UI
- Scripts: `scripts/` — GDScript; `scripts/autoload/` for singletons
- Dialogue: YarnSpinner (C# runtime bridge; see YarnSpinner section)
- Maps: Tiled → YATI importer (`addons/YATI`); tileset PNG at `assets/tilesets/`
  - Art sources in `art/tilesets/` (committed); `assets/tilesets/` is a gitignored build-artifact dir
  - Build pipeline: export XCF manually in GIMP → `make` (copies PNGs → Godot reimport)

## Dev Workflow
- Feature branches in worktrees: `feat/issue-<N>-<description>`
- Worktree base: `.worktrees/` (project-local, gitignored)
- **After creating a new worktree**, run `make worktree-init` before launching the game — this copies gitignored build artifacts (e.g. `placeholder.png`) from the main repo and runs a full headless reimport. Without it, the map renders empty.
- TDD for all GDScript logic: write failing GUT test first
- Run GUT: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- **Never invoke `godot_console` directly** — it is a winget symlink in `WinGet\Links\`, and Godot resolves its bundled `GodotSharp/Api/Debug/` assemblies relative to the launched executable, so it dies with `.NET: Assemblies not found` + signal 11. Always resolve the real path via `scripts/godot_path.ps1` first.
- PR-only integration — never merge locally to master
- Use `/run` to launch the game or editor — handles worktree init checks and stale-instance cleanup

## Feature Lifecycle

```
idea → brainstorm → PRD (GitHub issue) → plan → worktree → implement → finish → PR → merge → cleanup
```

1. `/brainstorming` — explore the idea
2. `/prd` — write a GitHub issue spec
3. `/writing-plans` — turn spec into step-by-step tasks
4. Create worktree: `git worktree add .worktrees/<branch> -b <branch>` then `make worktree-init`
5. `/executing-plans` — implement with checkpoints
6. `/finishing-a-development-branch` — tests, smoketest, PR, cleanup

## Skills & Agents

| Skill | When to use |
|---|---|
| `tiled-map` | Map pipeline: creating/editing TMX/TSX, debugging imports |
| `story-lore` | Writing narrative, dialogue, lore, flavor text |

| Agent | When to use |
|---|---|
| `godot-expert` | GDScript implementation and TDD with GUT |

## YarnSpinner

- `dialogue/*.import` files are gitignored — copied from main repo by `make worktree-init`
- After editing `.yarn` files, use `/run` — it deletes the stale compiled yarnproject cache and reimports automatically

## C# / GDScript Bridge

- Access GDScript autoloads from C# via `GetNode<Node>("/root/AutoloadName")` — **not** `Engine.GetSingleton()` (that only finds C#-registered singletons, not GDScript autoloads)

## Key Conventions
- Signal-driven UI: UI connects to autoload signals, never polls
- Static typing preferred: `var foo: int = 0`
- Test files: `tests/test_<module>.gd`
