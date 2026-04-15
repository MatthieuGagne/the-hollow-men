---
name: run
description: Launch the current build of The Hollow Men game in the Godot editor
---

Determine whether you are running inside a git worktree or the main repo:

```sh
pwd
```

**If inside a worktree** (path contains `worktrees/`):

1. Kill any running Godot instance (ignore errors if none running):
   ```sh
   pkill -f godot || true
   ```
2. Launch the game from the worktree:
   ```sh
   godot --path <worktree_path> &
   ```

**If in the main repo**:

```sh
cd /home/mathdaman/code/noir-fantasy-rpg && godot &
```

Report to the user that the game is launching.
