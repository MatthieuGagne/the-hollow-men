# Art Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Makefile pipeline that copies PNG tilesets from `art/tilesets/` to `assets/tilesets/` and triggers a Godot headless reimport.

**Architecture:** A single root-level Makefile with three targets: `copy-art` (rsync PNGs), `import` (Godot headless reimport for both tilesets and TMX maps via YATI), and `assets` (default target that chains both). No GDScript is touched.

**Tech Stack:** GNU Make, rsync, Godot 4.6 headless

## Open questions (must resolve before starting)

- none

---

## Batch 1 — Create the Makefile

### Task 1: Create Makefile

**Files:**
- Create: `Makefile`

**Depends on:** none — first and only task
**Parallelizable with:** none — only task in batch

**Step 1: Create the Makefile**

Create `Makefile` at the project root with this exact content:

```makefile
.DEFAULT_GOAL := assets

.PHONY: assets copy-art import

assets: copy-art import

copy-art:
	rsync -a --include="*.png" --exclude="*" art/tilesets/ assets/tilesets/

import:
	DISPLAY=:0 godot --headless --editor --quit --path .
```

> Note: the indented lines under each target MUST use a real tab character, not spaces — Make requires tabs.

**Step 2: Verify the file was created correctly**

```bash
cat -A Makefile | grep -E "^\^I"
```
Expected: lines starting with `^I` (tab character) for `rsync` and `DISPLAY=:0` lines. If you see spaces instead, fix the indentation.

**Step 3: Run copy-art and verify PNG is copied**

```bash
make copy-art
ls assets/tilesets/
```
Expected: `placeholder.png` present in `assets/tilesets/`. No errors from rsync.

**Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: add art pipeline Makefile (copy-art + import + assets)"
```

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Only task — no parallelism applicable |

### Smoketest Checkpoint 1 — Verify full pipeline runs without errors

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures.

**Step 3: Run the full pipeline**
```bash
make assets
```
Expected: rsync copies PNGs silently, then Godot headless reimport runs and exits cleanly (exit code 0). No error output.

**Step 4: Confirm with user**
Verify that `assets/tilesets/placeholder.png` is present and that running `make assets` a second time completes without errors (idempotent). Wait for confirmation before closing.
