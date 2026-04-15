---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute tasks in batches, report for review between batches.

**Core principle:** Batch execution with checkpoints for architect review.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## The Process

### Step 1: Enter Worktree

Before reading the plan or touching any file, check whether you are already inside a worktree:

> **Note:** The `writing-plans` skill creates the worktree before saving the plan file. If this plan was written in a separate session using `writing-plans`, you may already be inside the correct worktree. The check below handles both cases — skip to Step 2 if already inside.

```bash
pwd
git worktree list
```

If `pwd` output is already under `/home/mathdaman/code/worktrees/`, you are in a worktree — skip to Step 2.

Otherwise, determine the feature branch name from the plan (use `feat/issue-<N>-<short-description>` convention, where `<N>` is the GitHub issue number). Then use the `EnterWorktree` tool to create and enter the worktree:

- Worktree path: `/home/mathdaman/code/worktrees/<branch-name-with-slashes-as-dashes>`
- Branch: `feat/issue-<N>-<short-description>`

`EnterWorktree` creates a fresh branch off master — no separate sync step is needed.

### Step 2: Load and Review Plan

1. Read plan file
2. Review critically — identify any questions or concerns about the plan
3. If concerns: raise them with your human partner before starting
4. If no concerns: create TodoWrite tasks and proceed

### Step 3: Execute Batch

**Before dispatching any task, read the parallel dispatch source of truth (priority order):**

1. **Primary:** Find the `#### Parallel Execution Groups` table for the current batch in the plan. Dispatch all tasks in a `(parallel)` group as concurrent implementer Agent calls in a **single message** (max 3).
2. **Fallback:** If no group table exists, scan each task's `**Parallelizable with:**` annotation. Batch tasks that name each other into a single message.
3. **Last resort:** If neither exists, run tasks sequentially.

**Batch atomicity rule (HARD):** If ANY implementer in a parallel group fails, halt the entire batch immediately. Passing implementers MUST discard their in-progress work — do NOT stage or commit partial results. Fix the failure, then re-dispatch the entire group from scratch.

For each task (whether parallel or sequential):
1. Mark as in_progress
2. Determine task type:
   - **GDScript task** (creates or modifies `.gd` files with logic): follow the TDD cycle — write failing GUT test, write implementation, run tests to pass, refactor checkpoint, commit.
   - **Non-logic task** (scenes, docs, assets): follow each step exactly as written in the plan.
3. After completing any GDScript task: run the full test suite to confirm no regressions:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd
   ```
   If any test fails, stop and fix before continuing.
4. Run verifications as specified in the plan
5. Mark as completed

**Parallel reviewer rule (within each batch):**
After each task's work is committed, dispatch spec and quality reviewers as two concurrent Agent calls in a single message. Both must pass before marking the task complete.

### Step 4: Report

When batch complete:
- Show what was implemented
- Show verification output
- Say: "Ready for feedback."

### Step 5: Continue

Based on feedback:
- Apply changes if needed
- Execute next batch
- Repeat until complete

### Step 6: Complete Development

After all tasks complete and verified, announce: "I'm using the finishing-a-development-branch skill to complete this work."

**REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch

Follow that skill to verify tests, run smoketest, present options, execute choice, and clean up.

### Step 7: Lessons Learned — HARD GATE (do not skip)

After the smoketest passes (inside finishing-a-development-branch), **before pushing or creating the PR**, explicitly ask:

> "Any important lessons learned from this implementation? (e.g. surprises, sharp edges, things that should update CLAUDE.md / skills / agents / memory)"

**This step is mandatory — do not skip it, even if the implementation felt smooth.**

- If **yes** or the user provides lessons: invoke the `/prd` skill to create a GitHub issue capturing the needed documentation updates. Save anything session-relevant to memory as well.
- If the user explicitly says **no lessons**: note that in your response and proceed to push/PR.

Do not push or open the PR until you have received an explicit answer to this question.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker mid-batch (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 2) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** — stop and ask.

## Remember
- Enter worktree FIRST before any other action — writing-plans may have already created it; use `EnterWorktree` only if not already inside one
- Review plan critically before starting
- Follow plan steps exactly
- Don't skip verifications
- Between batches: just report and wait
- Stop when blocked, don't guess
- Never start implementation on master branch
- GDScript tasks: TDD cycle — failing test → implementation → passing test → refactor → commit
- Run full test suite after every GDScript task to catch regressions
- When merging (e.g. resolving conflicts): `git fetch origin && git merge origin/master`
- Parallel implementers: read `#### Parallel Execution Groups` table first; dispatch parallel groups as concurrent Agent calls (max 3); batch atomicity — if any fails, ALL discard and retry from scratch
- Parallel reviewers: fire spec + quality in one message after each implementer commit

## Integration

**Required workflow skills:**
- **superpowers:writing-plans** — creates the plan this skill executes
- **superpowers:finishing-a-development-branch** — complete development after all tasks
- **dispatching-parallel-agents** — consult before any agent dispatch decision
