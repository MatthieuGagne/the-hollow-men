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

**Ensure assets are imported.** Spot-check for a few key import files that are commonly missing after a fresh clone, pull, or worktree creation:

```sh
ls <project_path>/.godot/imported/ 2>/dev/null | grep -cE "reid|iris|Monocraft|desk"
```

If the count is less than 4, run a headless reimport and wait for it to finish:

```sh
DISPLAY=:0 godot --headless --editor --quit --path <project_path> 2>&1 | tail -5
```

Also run `make copy-art` first if any art source files in `art/` are newer than their counterparts in `assets/` — this copies PNGs from the art pipeline into the asset directories before importing.

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
