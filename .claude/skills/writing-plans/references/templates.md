# Plan Templates

Copy these verbatim into plans, filling in the bracketed parts.

## Parallel Execution Groups table (precedes every Smoketest Checkpoint)

```markdown
#### Parallel Execution Groups — Smoketest Checkpoint N

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2 | Different output files, no shared state |
| B (sequential) | Task 3 | Depends on Group A — must run after both complete |
```

## Smoketest Checkpoint template

````markdown
### Smoketest Checkpoint N — [what to verify]

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```powershell
Start-Process (& ./scripts/godot_path.ps1)
```
(Or use the `/run` skill — it handles worktree pre-flight and cache invalidation.)

**Step 4: Confirm with user**
Tell the user what to verify in the running game. Wait for confirmation before proceeding to the next batch.
````

## GDScript Task Template

Use this template for any task that creates or modifies GDScript logic:

````markdown
### Task N: [Component Name]

**Files:**
- Create/Modify: `scripts/foo.gd`
- Test: `tests/test_foo.gd`

**Depends on:** none   ← or "Task N, Task M"
**Parallelizable with:** none   ← or "Task N, Task M"

**Step 1: Write the failing GUT test**

```gdscript
extends GutTest

func before_each():
    pass  # reset autoload state if needed

func test_foo_initial_state():
    assert_eq(SomeAutoload.get_value(), 0)
```

**Step 2: Run test to verify it fails**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_foo.gd`
Expected: FAIL (undefined method or assertion error)

**Step 3: Write minimal implementation**

```gdscript
# scripts/foo.gd
```

**Step 4: Run tests to verify they pass**

Run: `$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_foo.gd`
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does this implementation generalize, or did I hard-code something that breaks when N > 1?"
- If generalized: proceed.
- If hard-coded and not fixing now: open a follow-up GitHub issue immediately before closing this task.

**Step 6: Commit**

```bash
git add scripts/foo.gd tests/test_foo.gd
git commit -m "feat: add foo"
```
````

## Non-Logic Task Template

Use this template for tasks that do NOT involve GDScript logic (scenes, docs, assets):

````markdown
### Task N: [Component Name]

**Files:**
- Create/Modify: `scenes/foo.tscn`

**Depends on:** none   ← or "Task N, Task M"
**Parallelizable with:** none   ← or "Task N, Task M"

**Step 1: Write the content**

[exact content or description of changes]

**Step 2: Verify**

[manual check or command, e.g. "open in Godot editor and confirm X is visible"]

**Step 3: Commit**

```bash
git add scenes/foo.tscn
git commit -m "feat: add foo scene"
```
````

## Incomplete Warning Block (use when self-review check #3 fails)

```markdown
> ⚠️ **Plan incomplete — unjustified parallelism annotations**
>
> The following tasks have `**Parallelizable with:** none` with no justification sentence:
> - Task N: [task name]
>
> For each: either (a) identify tasks it can parallelize with and update the annotation,
> or (b) add a one-sentence justification explaining why it cannot parallelize
> (e.g., "writes same file as Task M", "requires Task M's output").
>
> Proceed with the plan as-is, or fix these annotations first?
```
