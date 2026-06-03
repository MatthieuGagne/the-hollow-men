---
name: run
description: Launch The Hollow Men in Godot — either run the game or open the editor
---

Determine whether you are running inside a git worktree or the main repo:

```sh
pwd
```

**If inside a worktree**, check initialization before doing anything else:

```sh
ls <worktree_path>/.godot 2>$null && ls <worktree_path>/assets/tilesets/placeholder.png 2>$null || echo "NEEDS_INIT"
```

If either path is missing, run `make worktree-init` from the worktree root first. This copies gitignored build artifacts from the main repo and runs a full headless reimport. Without it the map scene will load empty and sprites may be missing. Wait for it to complete before continuing.

**Kill any running Godot instance first** (if no Godot process is running, the command completes silently — that is normal, not an error):

```sh
Get-Process godot* -ErrorAction SilentlyContinue | Stop-Process -Force
```

**Ensure C# assemblies are built.** Check whether the build output DLL exists:

```sh
ls <project_path>/.godot/mono/temp/bin/Debug/TheHollowMen.dll 2>$null || echo "NEEDS_BUILD"
```

If `NEEDS_BUILD`, run `dotnet build` from the project root and wait for it to complete (expected: "0 Error(s)"). This is required for YarnSpinner and any other C# scripts to instantiate correctly.

**Ensure assets are up to date.** Always run the full asset pipeline — copy PNGs from `art/` into `assets/`, sync TSX dimensions from the PNG on disk, then reimport. This ensures the tileset and map match what is on disk.

```sh
make copy-art sync-tsx 2>&1
```

If the output contains the word "updated" (sync-tsx patched one or more `.tsx` files), the tileset dimensions changed. Clear the stale TMX import cache so the map reimports correctly:

```sh
rm -f <project_path>/.godot/imported/*.tmx-*.md5 <project_path>/.godot/imported/*.tmx-*.tscn
```

**Check for stale Yarn compilation.** The yarnproject compiled `.tres` is not automatically invalidated when `.yarn` files change. Check and invalidate if needed:

```sh
TRES=$(ls <project_path>/.godot/imported/iris.yarnproject-*.tres 2>/dev/null | head -1)
if [ -z "$TRES" ] || find <project_path>/dialogue -name "*.yarn" -newer "$TRES" | grep -q .; then
  echo "Yarn files changed — invalidating compiled yarnproject"
  rm -f <project_path>/.godot/imported/iris.yarnproject-*.tres <project_path>/.godot/imported/iris.yarnproject-*.md5
fi
```

Then run the headless import and wait for it to finish (run this if either TMX cache was cleared OR Yarn cache was invalidated above):

```sh
godot_console --headless --editor --quit --path <project_path>
```

**Determine the mode** from the user's request:
- "open editor", "open in editor", "edit" → use `--editor` flag (takes priority over any scene hint)
- "run", "play", "launch the game" → no extra flag (runs the main scene unless a scene hint is given)

**Resolve the scene** if `ARGUMENTS` is non-empty and is not a mode keyword (`editor`, `edit`, `open editor`):

1. List current scenes:
   ```sh
   Get-ChildItem -Recurse -Filter "*.tscn" scenes/ | Select-Object -ExpandProperty FullName
   ```
2. Use your own judgment to pick the most likely match — weigh the hint words against scene names and game context (e.g. "battle" → `BattleScene.tscn`, "bar" or "winds" → `FourWindsBar.tscn`, "office" → `OfficeBuildingInterior.tscn`).
3. If confident → append the scene path as a positional argument (e.g. `scenes/battle/BattleScene.tscn`).
4. If not confident → use `AskUserQuestion` with the plausible candidates as options (up to 4 choices).

If `ARGUMENTS` is empty, run the default main scene (no extra argument).

**If inside a worktree** (path contains `worktrees/`), launch from the worktree path:

```sh
Start-Process godot_console -ArgumentList "[--editor] --path <worktree_path> [scene_path]"
Start-Sleep 3; Get-Process godot_console -ErrorAction SilentlyContinue
```

**If in the main repo**, launch from the project root:

```sh
Start-Process godot_console -ArgumentList "[--editor] --path C:\Code\the-hollow-men [scene_path]"
Start-Sleep 3; Get-Process godot_console -ErrorAction SilentlyContinue
```

Verify that `Get-Process` returns a result. If it does not, Godot exited silently — report the failure.

Report to the user that Godot is launching (editor or game, as appropriate).
