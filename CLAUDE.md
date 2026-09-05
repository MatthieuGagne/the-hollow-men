# The Hollow Men

Turn-based cyberpunk noir horror JRPG. Protagonist Reid investigates a missing person in
NOX — a perpetually rain-soaked city — uncovering an ancient non-Euclidean entity.
Themes: film noir, Lovecraftian horror, corporate magic bureaucracy (Shadowrun influence).

**Engine:** Godot 4.7 / GDScript — runtime is GDScript only; C# used for editor tooling (YATI importer)

## Autoloads
SceneManager (`scripts/autoload/scene_manager.gd`) is the scene-transition autoload — use `SceneManager.change_scene(path)` for fade transitions (full list in `[autoload]` in `project.godot`).

## Architecture
- Scenes: `scenes/` — battle, world, UI
- Scripts: `scripts/` — GDScript; `scripts/autoload/` for singletons
- Dialogue: YarnSpinner (C# runtime bridge; see YarnSpinner section)
- Maps: Tiled → YATI importer (`addons/YATI`); tileset PNG at `assets/tilesets/`
  - Art sources in `art/tilesets/` (committed); `assets/tilesets/` is a gitignored build-artifact dir
  - Build pipeline: export XCF manually in GIMP → `make` (copies PNGs → Godot reimport)

## Dev Workflow
- Feature branches in worktrees: `feat/issue-<N>-<description>`
- Worktree creation goes through Orca: invoke the `orca-cli` skill (exact commands from `ORCA skills get orca-cli` — never guess flags). Orca worktrees live under `~\orca\workspaces\<repo>\<name>`. Never use `git worktree add`, the `EnterWorktree` tool, or `.worktrees/`/`.claude/worktrees/` directories.
- **After creating a new worktree**, run `make worktree-init` (inside the new Orca worktree) before launching the game — this copies gitignored build artifacts (e.g. `placeholder.png`) from the main repo and runs a full headless reimport. Without it, the map renders empty.
- TDD for all GDScript logic: write failing GUT test first
- Run GUT: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- **Never invoke `godot_console` directly** — launching it via its install symlink dies with `.NET: Assemblies not found` + signal 11. Always resolve the real Godot path via `scripts/godot_path.ps1` first.
- PR-only integration — never merge locally to master
- Use the `run` skill to launch the game or editor — handles worktree init checks and stale-instance cleanup

## Feature Lifecycle

```
idea → brainstorm → PRD (GitHub issue) → plan → worktree → implement → finish → PR → merge → cleanup
```

1. `brainstorming` skill — explore the idea
2. `prd` skill — write a GitHub issue spec
3. `writing-plans` skill — turn spec into step-by-step tasks
4. Create worktree via Orca (`orca-cli` skill), then `make worktree-init` inside it
5. `executing-plans` skill — implement with checkpoints
6. `finishing-a-development-branch` skill — tests, smoketest, PR, cleanup

## Skills & Agents

| Skill | When to use |
|---|---|
| `tiled-map` | Map pipeline: creating/editing TMX/TSX, debugging imports |
| `story-lore` | Writing narrative, dialogue, lore, flavor text |

| Agent | When to use |
|---|---|
| `godot-expert` | GDScript implementation and TDD with GUT — **Claude Code only** (omp does not load `.claude/agents`; in omp sessions run the TDD workflow via the `executing-plans` skill) |

## YarnSpinner

Dialogue is YarnSpinner-based (C# runtime bridge). After editing `.yarn`, use the `run` skill — it clears the stale compiled yarnproject cache and reimports. `dialogue/*.import` build artifacts come from the main repo via `make worktree-init`.

## C# / GDScript Bridge

- Access GDScript autoloads from C# via `GetNode<Node>("/root/AutoloadName")` — **not** `Engine.GetSingleton()` (that only finds C#-registered singletons, not GDScript autoloads)

## Key Conventions
- Signal-driven UI: UI connects to autoload signals, never polls
- Static typing preferred: `var foo: int = 0`
- Test files: `tests/test_<module>.gd`
