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
ls <worktree_path>/.godot 2>/dev/null && ls <worktree_path>/assets/tilesets/placeholder.png 2>/dev/null || echo "NEEDS_INIT"
```

If either path is missing, run `make worktree-init` from the worktree root first. This copies gitignored build artifacts from the main repo and runs a full headless reimport. Without it the map scene will load empty and sprites may be missing. Wait for it to complete before continuing.

**Kill any running Godot instance first** (exit 144 from pkill means no process was running — that is normal, not an error):

```sh
pkill -f godot; true
```

**Ensure C# assemblies are built.** Check whether the build output DLL exists:

```sh
ls <project_path>/.godot/mono/temp/bin/Debug/TheHollowMen.dll 2>/dev/null || echo "NEEDS_BUILD"
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

Then run the headless import and wait for it to finish:

```sh
DISPLAY=:0 godot --headless --editor --quit --path <project_path> 2>&1 | tail -10
```

**Determine the mode** from the user's request:
- "open editor", "open in editor", "edit" → use `--editor` flag
- "run", "play", "launch the game" → no extra flag (runs the main scene)

**If inside a worktree** (path contains `worktrees/`), launch from the worktree path:

```sh
DISPLAY=:0 godot [--editor] --path <worktree_path> 2>&1 &
echo "PID: $!"
sleep 3 && ps aux | grep godot | grep -v grep
```

**If in the main repo**, launch from the project root:

```sh
DISPLAY=:0 godot [--editor] --path /home/mathdaman/code/the-hollow-men 2>&1 &
echo "PID: $!"
sleep 3 && ps aux | grep godot | grep -v grep
```

Verify the PID still appears in the `ps` output. If it does not, Godot exited silently — report the failure. Do not rely on the `pkill` exit code to determine whether a prior instance was running.

Report to the user that Godot is launching (editor or game, as appropriate).
