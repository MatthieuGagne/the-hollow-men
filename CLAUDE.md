# The Hollow Men

Turn-based cyberpunk noir horror JRPG. Protagonist Reid investigates a missing person in
NOX — a perpetually rain-soaked city — uncovering an ancient non-Euclidean entity.
Themes: film noir, Lovecraftian horror, corporate magic bureaucracy (Shadowrun influence).

**Engine:** Godot 4.6 / GDScript (no C#)
**Renderer:** Mobile (GL Compatibility)
**Resolution:** 320×180 → upscaled to 1280×720 (4:3)

## Autoloads
- `scripts/autoload/scene_manager.gd` — fade transitions; call `SceneManager.change_scene(path)`

## Architecture
- Scenes: `scenes/` — battle, world, UI
- Scripts: `scripts/` — GDScript; `scripts/autoload/` for singletons
- Dialogue: YarnSpinner planned (C# integration TBD — open architectural question)
- Maps: Tiled integration via `naddys_tiled_maps` addon

## Dev Workflow
- Feature branches in worktrees: `feat/issue-<N>-<description>`
- Worktree base: `/home/mathdaman/code/worktrees/`
- TDD for all GDScript logic: write failing GUT test first
- Run GUT: `godot --headless -s addons/gut/gut_cmdln.gd`
- PR-only integration — never merge locally to master
- See skills: writing-plans, executing-plans, finishing-a-development-branch

## Skills & Agents
**Skills:** brainstorming, prd, writing-plans, executing-plans, finishing-a-development-branch, run
**Agents:** godot-expert (GDScript TDD), yarnspinner (global — dialogue scripting)

## Key Conventions
- Signal-driven UI: UI connects to autoload signals, never polls
- Static typing preferred: `var foo: int = 0`
- Test files: `tests/test_<module>.gd`
