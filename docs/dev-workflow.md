# Dev Workflow

End-to-end reference for feature development on The Hollow Men. Kept in sync with `CLAUDE.md` and `.claude/skills/`.

## Feature Lifecycle

```
idea → brainstorm → PRD (GitHub issue) → plan → worktree → implement → finish → PR → merge → cleanup
```

### 1. Explore the idea

Use `/brainstorming` to turn a vague idea into a concrete design before writing any spec. Works at any stage — PRD writing, debugging, or standalone exploration.

### 2. Write a PRD

Use `/prd` to produce a GitHub issue containing the feature spec. No local file is created. Can follow a brainstorming session or start cold.

### 3. Write an implementation plan

Use `/writing-plans` when you have a spec and need step-by-step implementation tasks. Output is a plan file in `docs/plans/`. Can follow brainstorming or a PRD.

### 4. Create a worktree

Branch naming: `feat/issue-<N>-<description>` (omit issue number if no GitHub issue exists).

```bash
git worktree add /home/mathdaman/code/worktrees/<branch> -b <branch>
```

Worktree base: `/home/mathdaman/code/worktrees/`

**After creating a worktree**, always run before launching the game:

```bash
make worktree-init
```

This copies gitignored build artifacts (e.g. `assets/tilesets/placeholder.png`) from the main repo and runs a full headless reimport. Without it the map renders empty and sprites may be missing. See [Worktree Init](#worktree-init) below.

### 5. Implement

Use `/executing-plans` to work through a plan with review checkpoints.

- TDD: write a failing GUT test first, then implement
- Run tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- Static typing preferred: `var foo: int = 0`
- Test files: `tests/test_<module>.gd`

### 6. Finish the branch

Use `/finishing-a-development-branch` when implementation is complete. It:

1. Fetches and merges master
2. Runs GUT tests headlessly
3. Launches a smoketest and waits for confirmation
4. Checks whether skills/CLAUDE.md changed and flags doc updates needed
5. Presents PR / keep / discard options
6. After merge confirmation: removes the worktree and branch

**Never merge locally to master** — all integration is via PR.

---

## Worktree Init

New worktrees are missing two things that are gitignored:

| Missing | Why | Fix |
|---|---|---|
| `.godot/` import cache | Generated at runtime, gitignored | Created automatically on first headless import |
| `assets/tilesets/placeholder.png` | Build artifact, no automated XCF→PNG export yet | Copied from main repo by `make worktree-init` |

`make worktree-init` does both in one step:

```bash
make worktree-init   # copies placeholder.png + runs make assets (copy-art + headless import)
```

If the map still renders empty after init, the TMX import cache may have been built before the tileset PNG existed. Delete the stale cache and reimport:

```bash
rm .godot/imported/room_poc.tmx-*.{md5,tscn}
DISPLAY=:0 godot --headless --editor --quit --path .
```

---

## Running the Game

Use `/run` — it handles worktree detection, pre-flight init check, killing stale Godot instances, and launch.

- "run" / "play" → launches main scene
- "open editor" → opens Godot editor

---

## Map Pipeline (Tiled → Godot)

Use `/tiled-map` for all map work. Summary:

- Edit maps in Tiled, save as `.tmx` in `maps/`
- Tilesets: art sources in `art/tilesets/` (`.xcf` + third-party PNGs — committed); built PNGs in `assets/tilesets/` (gitignored)
- Build: export XCF manually in GIMP → `make` (copies PNGs + reimports)
- Define tile types via `class=` attribute in `.tsx`; after first import set `add_class_as_metadata=true` in the `.tmx.import` file
- Runtime wall check: `tilemap.get_cell_tile_data(cell).get_meta("class", "") == "wall"`

---

## Skills Reference

| Skill | When to use |
|---|---|
| `brainstorming` | Exploring an idea before writing a spec |
| `prd` | Writing a feature spec as a GitHub issue |
| `writing-plans` | Turning a spec into implementation steps |
| `executing-plans` | Working through a plan with checkpoints |
| `finishing-a-development-branch` | Wrapping up implementation: tests, smoketest, PR, cleanup |
| `run` | Launching the game or editor |
| `tiled-map` | Map pipeline: creating/editing TMX/TSX, debugging imports |
| `story-lore` | Writing in-game narrative, dialogue, lore, flavor text |

## Agents Reference

| Agent | When to use |
|---|---|
| `godot-expert` | GDScript implementation and TDD with GUT |
| `yarnspinner` | Dialogue scripting and YarnSpinner integration |
