---
name: run
description: Launch the current build of The Hollow Men game in the Godot editor
---

Determine whether you are running inside a git worktree or the main repo:

```sh
pwd
```

**Kill any running Godot instance first** (exit 144 from pkill means no process was running — that is normal, not an error):

```sh
pkill -f godot; true
```

**If inside a worktree** (path contains `worktrees/`), launch from the worktree path:

```sh
DISPLAY=:0 godot --path <worktree_path> 2>&1 &
echo "PID: $!"
sleep 3 && ps aux | grep godot | grep -v grep
```

**If in the main repo**, launch from the project root:

```sh
DISPLAY=:0 godot --path /home/mathdaman/code/the-hollow-men 2>&1 &
echo "PID: $!"
sleep 3 && ps aux | grep godot | grep -v grep
```

Verify the PID still appears in the `ps` output. If it does not, Godot exited silently — report the failure. Do not rely on the `pkill` exit code to determine whether a prior instance was running.

Report to the user that the game is launching.
