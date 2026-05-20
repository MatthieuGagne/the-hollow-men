# Reliable worktree-init for dialogue (dotnet build + guardrails) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `make worktree-init` reliably set up YarnSpinner dialogue in a fresh worktree and guard `make import` against running before prerequisites exist.

**Architecture:** Two targeted edits to `Makefile` — add precondition guards to the `import` target (R3, R4), then update `worktree-init` to run `dotnet build` and use rsync for all yarn import files (R1, R2). No GDScript, no GUT tests; all verification is manual.

**Tech Stack:** GNU Make, rsync, dotnet CLI, headless Godot

## Open questions (must resolve before starting)

- none

---

### Task 1: Add guards to `import` target

**Files:**
- Modify: `Makefile`

**Depends on:** none
**Parallelizable with:** none — same file as Task 2; apply first to establish a stable base for the Task 2 edit.

**Step 1: Apply the edit**

Replace the `import` target in `Makefile`:

```makefile
import:
	DISPLAY=:0 godot --headless --editor --quit --path .
```

with:

```makefile
import:
	@test -f .godot/mono/temp/bin/Debug/TheHollowMen.dll || \
		(echo "ERROR: C# assemblies not built. Run 'dotnet build' first." && exit 1)
	@test -f dialogue/iris.yarnproject.import || \
		(echo "ERROR: Dialogue not initialized. Run 'make worktree-init' first." && exit 1)
	DISPLAY=:0 godot --headless --editor --quit --path .
```

Note: Makefile recipe lines must be indented with a real tab character, not spaces.

**Step 2: Verify AC2**

```bash
mv .godot/mono/temp/bin/Debug/TheHollowMen.dll /tmp/TheHollowMen.dll.bak
make import
echo "Exit code: $?"
mv /tmp/TheHollowMen.dll.bak .godot/mono/temp/bin/Debug/TheHollowMen.dll
```

Expected: prints `ERROR: C# assemblies not built. Run 'dotnet build' first.` and exits non-zero.

**Step 3: Verify AC3**

```bash
mv dialogue/iris.yarnproject.import /tmp/iris.yarnproject.import.bak
make import
echo "Exit code: $?"
mv /tmp/iris.yarnproject.import.bak dialogue/iris.yarnproject.import
```

Expected: prints `ERROR: Dialogue not initialized. Run 'make worktree-init' first.` and exits non-zero.

**Step 4: Commit**

```bash
git add Makefile
git commit -m "fix: guard make import against missing DLL and yarnproject.import"
```

---

### Task 2: Update `worktree-init` target

**Files:**
- Modify: `Makefile`

**Depends on:** Task 1
**Parallelizable with:** none — same file as Task 1; apply after Task 1's commit.

**Step 1: Apply the edit**

Replace the `worktree-init` target in `Makefile`:

```makefile
worktree-init:
	cp $(MAIN_REPO)/assets/tilesets/placeholder.png assets/tilesets/
	cp $(MAIN_REPO)/dialogue/*.import dialogue/
	cp $(MAIN_REPO)/.godot/imported/iris.yarnproject-* .godot/imported/
	rm -f .godot/imported/*.tmx-*.md5 .godot/imported/*.tmx-*.tscn
	$(MAKE) assets
```

with:

```makefile
worktree-init:
	cp $(MAIN_REPO)/assets/tilesets/placeholder.png assets/tilesets/
	cp $(MAIN_REPO)/dialogue/*.import dialogue/
	rsync -a --include="*.yarnproject-*" --include="*.yarn-*" --exclude="*" $(MAIN_REPO)/.godot/imported/ .godot/imported/
	rm -f .godot/imported/*.tmx-*.md5 .godot/imported/*.tmx-*.tscn
	dotnet build
	$(MAKE) assets
```

The rsync replaces the old `cp iris.yarnproject-*` line and additionally picks up all `.yarn-*` compiled script imports. Future `.yarn` files are covered automatically without any Makefile edit (AC4).

**Step 2: Verify the rsync pattern covers existing yarn files (AC4)**

```bash
rsync -a --include="*.yarnproject-*" --include="*.yarn-*" --exclude="*" \
    --dry-run --verbose .godot/imported/ /tmp/yarn-dryrun/
```

Expected: lists `iris.yarnproject-*.tres`, `iris.yarnproject-*.md5`, `iris_intro.yarn-*.tres`, `iris_intro.yarn-*.md5`. No filenames are hardcoded — the pattern will pick up any future `.yarn-*` files.

**Step 3: Commit**

```bash
git add Makefile
git commit -m "fix: worktree-init runs dotnet build and rsyncs all yarn import files"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | No dependency; establishes stable Makefile base |
| B (sequential) | Task 2 | Depends on Task 1 — same file, must apply after A commits |

### Smoketest Checkpoint 1 — verify all four ACs

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: all tests pass, zero failures. (No GUT tests were added — this confirms no regressions in existing tests.)

**Step 3: AC1 — fresh worktree end-to-end**

Create a temporary worktree from the feature branch and run `worktree-init`:
```bash
git worktree add /tmp/test-wt-71 feat/issue-71-worktree-init-reliable
cd /tmp/test-wt-71
make worktree-init
```
Expected: `dotnet build` prints build success; headless import completes without error.

Then launch the game:
```bash
DISPLAY=:0 godot --path /tmp/test-wt-71
```
Confirm: no `YarnProject is not set on TextLineProvider` error in the Godot output log.

Cleanup:
```bash
cd /home/mathdaman/code/the-hollow-men
git worktree remove /tmp/test-wt-71
```

**Step 4: Confirm with user**

Tell the user to verify:
- **AC1:** Game launched from fresh worktree without the YarnProject error
- **AC2:** `make import` without DLL printed the correct error (verified in Task 1 step 2)
- **AC3:** `make import` without yarnproject.import printed the correct error (verified in Task 1 step 3)
- **AC4:** rsync dry-run listed all `.yarn-*` and `.yarnproject-*` files without hardcoded filenames

Wait for confirmation before proceeding.
