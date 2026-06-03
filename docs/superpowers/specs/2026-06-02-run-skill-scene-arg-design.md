# Run Skill — Scene Argument Design

**Date:** 2026-06-02

## Goal

Allow `/run <hint>` to launch a specific scene instead of always running the main scene. The scene is resolved dynamically from the current filesystem — no alias table to maintain.

## Behaviour

### When no argument is given

Unchanged: runs the default main scene (`project.godot` → `run/main_scene`).

### When an argument is given

If `ARGUMENTS` is non-empty and is not a mode keyword (`editor`, `edit`, `open editor`), treat it as a scene hint.

**Resolution steps:**

1. List current scenes: `ls scenes/**/*.tscn`
2. Use AI judgment to pick the most likely match — weighing the hint words against scene names and game context (e.g. "battle" → `BattleScene.tscn`, "bar" or "winds" → `FourWindsBar.tscn`, "office" → `OfficeBuildingInterior.tscn`).
3. If confident → pass the scene path as an extra positional argument to Godot:
   ```
   godot_console --path <project> scenes/battle/BattleScene.tscn
   ```
4. If not confident → use `AskUserQuestion` with the plausible candidates as options (up to 4), plus an "Other" free-text fallback.

### Mode interaction

`editor`/`edit`/`open editor` always takes priority. If the user somehow passes both, prefer editor mode.

## What does NOT change

- Worktree detection and init check
- Killing stale Godot processes
- C# assembly build check
- Asset pipeline (`make copy-art sync-tsx`)
- Stale Yarn cache invalidation
- Headless reimport step
- Launch command structure
