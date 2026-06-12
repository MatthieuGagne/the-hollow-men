---
name: finishing-a-development-branch
description: The Hollow Men's fork of finishing-a-development-branch — use instead of superpowers:finishing-a-development-branch in this project. Use when implementation is complete — verifies GUT tests headlessly, runs the visual smoketest, presents PR/keep/discard options (PR-only integration), and cleans up the worktree.
---

# Finishing a Development Branch

## Overview

Verify tests → smoketest → present options → execute choice → clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Fetch and Merge Master

```bash
git fetch origin && git merge origin/master
```

If merge conflicts occur: resolve them, commit the merge, then continue.

### Step 2: Run GUT Tests

```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

If tests fail: stop, show failures. Do not proceed until they pass.

### Step 3: Smoketest

Launch the game in the background (always run this step, even when called from executing-plans):

```bash
Start-Process godot_console
```

Tell the user what to look for. Then ask:

> "Does the game look correct? Please confirm before I continue."

**STOP. Wait for explicit confirmation.**

- If issues found: work with user to fix before continuing.
- If confirmed: continue to Step 4.

### Step 4: Present Options

```
Implementation complete. What would you like to do?

1. Push and create a Pull Request  ← default
2. Keep the branch as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Never offer "merge to main locally"** — all work integrates via PR.

### Step 5: Execute Choice

First determine the worktree path with `git worktree list` (normally `.worktrees\<branch>` in the repo root; tool-managed worktrees may be under `.claude\worktrees\`). Use that path wherever `<worktree-path>` appears below.

#### Option 1: Push and Create PR

Infer issue number from branch name (e.g. `feat/issue-42-foo` → `#42`). If not inferable, ask user.

```bash
git push -u origin <feature-branch>

gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<2-3 bullets>

## Test Plan
- [ ] GUT tests pass headlessly
- [ ] Visual smoketest confirmed

Closes #N
EOF
)"
```

After PR is created, report:

> "PR created: <URL>
> When the PR is merged, let me know and I'll clean up the worktree at `<worktree-path>`."

**Do NOT run Step 6 yet.** Cleanup only happens after the user confirms the merge.

#### Option 2: Keep As-Is

Report: "Keeping branch `<name>`. Worktree preserved at `<worktree-path>`."

**Do NOT run Step 6.**

#### Option 3: Discard

**Confirm first:**

```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <worktree-path>

Type 'discard' to confirm.
```

Wait for exact confirmation. If confirmed:

```bash
git branch -D <feature-branch>
```

(Use `-D` directly — user has explicitly confirmed deletion of unmerged work. No `-d` first.)

Then run Step 6 immediately.

### Step 6: Cleanup Worktree

#### After merge confirmation (Option 1 only)

Only run after the user explicitly confirms the PR was merged — **never preemptively**.

**Step 6-pre: Close linked issue**

Parse the issue number from the branch name and close the issue if found:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" =~ feat/issue-([0-9]+)- ]]; then
  gh issue close "${BASH_REMATCH[1]}"
  echo "Closed issue #${BASH_REMATCH[1]}"
else
  echo "No issue number in branch name — skipping issue close."
fi
```

**Step 6a: Exit EnterWorktree session if active**

If the current session was started with `EnterWorktree` and is still inside the worktree, use `ExitWorktree` first:

```
ExitWorktree(action="remove", discard_changes=true)
```

After `ExitWorktree` returns, skip to Step 6d — the worktree is already removed.

If not inside an active `EnterWorktree` session, continue to Step 6b.

**Step 6b: cd to main repo root**

Always `cd` OUT of the worktree first, before any remove command — if the session CWD is inside a deleted worktree, git panics with "Unable to read current working directory":

```bash
cd C:\Code\the-hollow-men
```

**Step 6c: Remove the worktree**

Use the path from `git worktree list`:

```bash
git worktree remove <worktree-path>
```

If that fails (dirty working tree):
```bash
git worktree remove --force <worktree-path>
# Warn: "Worktree had uncommitted changes — removed with --force."
```

If `--force` also fails (directory already deleted from disk, stale git ref):
```bash
Remove-Item -Recurse -Force <worktree-path>
git worktree prune
# Note: "Worktree directory was already gone — pruned stale ref."
```
Skip Step 6d in this case (prune already ran).

**Step 6d: Prune stale refs**

```bash
git worktree prune
```

**Step 6e: Delete local branch**

```bash
git branch -d <feature-branch>
```

If that fails (not fully merged — e.g. squash merge):
```bash
git branch -D <feature-branch>
# Warn: "Branch was not fully merged — deleted with -D."
```

Report: "Worktree and branch cleaned up. Back on master."

#### Immediately after discard (Option 3)

Run Step 6a → 6b → 6c → 6d in sequence. Skip 6e (branch already deleted with `-D` in Step 5).

#### Option 2: Keep As-Is

**Do NOT run Step 6.**

## Worktree Path Convention

Worktrees live at `.worktrees\<branch>` in the repo root (created via `git worktree add .worktrees/<branch> -b <branch>` then `make worktree-init`). Tool-managed worktrees (`EnterWorktree`) may instead live under `.claude\worktrees\` — always detect the actual path with `git worktree list` rather than assuming.

## Quick Reference

| Option | Push | Close Issue | Delete Branch | Cleanup Worktree |
|--------|------|-------------|--------------|-----------------|
| 1. Push and Create PR | ✓ | After merge confirmed (if branch has issue number) | `git branch -d` → `-D` fallback, after merge | After merge confirmed |
| 2. Keep as-is | — | — | — | Never |
| 3. Discard | — | — | `git branch -D` (immediate) | Immediately |

## Integration

**Called by:**
- **executing-plans** (Step 6) — after all batches complete and smoketest passes
- Can also be called standalone at any point
