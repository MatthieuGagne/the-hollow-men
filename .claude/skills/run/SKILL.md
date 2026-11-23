---
name: run
description: Launch The Hollow Men in Godot — either run the game or open the editor
---

# Run — The Hollow Men

Read `.claude/skills/godot-dev/SKILL.md` first: it owns binary resolution, stale-instance cleanup, worktree
detection, cache invalidation, launch verification, and the test gates. This file supplies the
project parameters and the scene-selection rules.

## Project parameters

| | |
|---|---|
| Resolver | `& ./scripts/godot_path.ps1` |
| Project root | `C:\Code\the-hollow-men` |
| Worktree init | `make worktree-init` from the worktree root |
| Asset pipeline | `make copy-art sync-tsx` |
| C# assembly | `.godot/mono/temp/bin/Debug/TheHollowMen.dll` (rebuild with `dotnet build`) |
| Yarn project | `.godot/imported/iris.yarnproject-*.tres` |
| Test dir | `res://tests/` |

## Worktree init check

Before anything else in a worktree, confirm both exist:

```sh
ls <worktree_path>/.godot 2>$null && ls <worktree_path>/assets/tilesets/placeholder.png 2>$null || echo "NEEDS_INIT"
```

| Missing | Why | Fix |
|---|---|---|
| `.godot/` import cache | Generated at runtime, gitignored | Created automatically on first headless import |
| `assets/tilesets/placeholder.png` | Build artifact, gitignored | Copied from main repo by `make worktree-init` |
| `dialogue/*.import` + `iris.yarnproject` imported cache | Gitignored YarnSpinner sidecars | Copied from main repo by `make worktree-init` |
| `iris.yarnproject` fails to import | C# YarnSpinner importer not compiled yet | Run `dotnet build` before `make import` |

If the map still renders empty after init, the TMX cache is stale — delete and reimport:

```sh
rm .godot/imported/test_room.tmx-*.md5 .godot/imported/test_room.tmx-*.tscn
& (& ./scripts/godot_path.ps1) --headless --editor --quit --path .
```

## Asset pipeline

Always run the full pipeline before launching — copy PNGs from `art/` into `assets/`, sync TSX
dimensions from the PNG on disk, then reimport:

```sh
make copy-art sync-tsx 2>&1
```

If the output contains "updated", `sync-tsx` patched a `.tsx` and tileset dimensions changed —
clear the stale TMX import cache per `.claude/skills/godot-dev/SKILL.md`.

Check Yarn staleness the same way, comparing `dialogue/*.yarn` against the compiled `.tres`:

```sh
TRES=$(ls <project_path>/.godot/imported/iris.yarnproject-*.tres 2>/dev/null | head -1)
if [ -z "$TRES" ] || find <project_path>/dialogue -name "*.yarn" -newer "$TRES" | grep -q .; then
  rm -f <project_path>/.godot/imported/iris.yarnproject-*.tres <project_path>/.godot/imported/iris.yarnproject-*.md5
fi
```

## Resolving the scene

1. **Explicit hint in ARGUMENTS** (non-empty, non-mode keyword): list scenes, pick the best match
   by name, ask if unsure.

   ```sh
   Get-ChildItem -Recurse -Filter "*.tscn" scenes/ | Select-Object -ExpandProperty FullName
   ```

   Match hint words against scene names and game context ("battle" → `BattleScene.tscn`, "bar" →
   `FourWindsBar.tscn`). Confident → use it. Not confident → ask with candidates.

2. **No hint — infer from context.** Do NOT silently default to the main scene:
   - `git branch --show-current` — `fix/issue-116-cutscene-replay` implies the SprawlSafehouse, a
     beat-specific branch implies that beat's map
   - the recent conversation: a scene we were just debugging is the right choice
   - `git diff --name-only HEAD` — modified `.tscn`/`.tmx` files point at the scene under test
   - Context points to one scene → launch it and say which and why
   - Ambiguous → ask with the most plausible candidates (main scene among them)
   - Default to the main scene only when there is genuinely no signal

## Launch

```sh
Start-Process (& ./scripts/godot_path.ps1) -ArgumentList "[--editor] --path <project_or_worktree_path> [scene_path]"
```

Then verify the process exists per `.claude/skills/godot-dev/SKILL.md`, and tell the user whether the editor or
the game is launching.
