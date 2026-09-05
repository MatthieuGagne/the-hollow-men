---
name: writing-plans
description: The Hollow Men's fork of writing-plans — use instead of superpowers:writing-plans in this project. Turns a spec or GitHub-issue PRD into bite-sized tasks with GUT test gates, smoketest checkpoints, and worktree setup. Use when you have a spec or requirements for a multi-step task, before touching code; works with or without a prior brainstorming session.
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

## Before You Begin

**First action before anything else:** Pull and merge latest master into the current branch:
```bash
git fetch origin && git merge origin/master
```
Resolve any conflicts before proceeding.

**Second: run grilling.** Always invoke the `grilling` skill before writing — it surfaces requirements, acceptance criteria, scope, and constraints. Once grilling is satisfied, continue below.

**Third: create a git worktree.** After grilling and before writing the plan file, create the worktree through Orca: invoke the `orca-cli` skill (exact commands come from `ORCA skills get orca-cli` — never guess flags). Name it after the feature branch:

- **With issue number:** branch = `feat/issue-<N>-<short-description>` — use the GitHub issue number from the arguments; derive the short description from the issue title or grilling output.
- **Without issue number:** branch = `feat/<short-description>` — derive the slug from grilling output.

Orca worktrees live under `~\orca\workspaces\<repo>\<name>`. Never use `git worktree add`, the `EnterWorktree` tool, or `.worktrees/`/`.claude/worktrees/` directories. All subsequent work — including saving the plan file — happens inside the worktree.

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md` (inside the worktree)

## Hard Gate Sequence

Every task that touches GDScript logic MUST follow this exact sequence — no exceptions:

| Step | Action |
|------|--------|
| 1 | Write failing GUT test (`$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/` → FAIL) |
| 2 | Write minimal GDScript implementation |
| 3 | Run tests (`$godot = & ./scripts/godot_path.ps1; & $godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/` → PASS) |
| 4 | Refactor checkpoint ("breaks when N > 1?") |
| 5 | Commit |

Non-logic tasks (scenes, UI, docs, assets): write → verify visually in editor → commit. No test gate.

**Scene/UI gate:** If the plan touches any game state (add/remove autoload state, change signal definitions, change story beat triggers), add a task to verify all existing GUT tests still pass. Always ask the user before modifying existing tests — do not auto-update them.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Smoketestable Batches

**Tasks MUST be grouped into batches of 2-4.** Each batch ends with a **Smoketest Checkpoint** — a point where the game runs and the user confirms it looks correct.

A good batch boundary = any point where the game should visually work end-to-end (even partially). If a batch cannot be independently smoke-tested, the plan must explain why.

### Dependency Analysis (required before writing each smoketest checkpoint block)

After drafting all tasks in a batch and before inserting its Smoketest Checkpoint, run the Dependency Analysis procedure and insert the `#### Parallel Execution Groups` table — see `references/templates.md` (steps 1–5).

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the project `executing-plans` skill (NOT superpowers:executing-plans) to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Open questions (must resolve before starting)

- [Question 1 — or delete this line if none]

---
```

## Task Templates

> Copy the **GDScript Task Template** (6-step TDD cycle) and the **Non-Logic Task Template** (scenes, docs, assets) verbatim from `references/templates.md`. Every GDScript-logic task uses the 6-step template; every non-logic task uses the 3-step template.

## Remember
- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits
- GDScript logic tasks ALWAYS get the 6-step template
- Group tasks into batches of 2-4; each batch MUST end with a Smoketest Checkpoint
- Annotate every task with `**Depends on:**` and `**Parallelizable with:**` — executor reads these; vague hints are not enough
- Insert a `#### Parallel Execution Groups` table before every Smoketest Checkpoint block — this is the executor's source of truth for parallel dispatch

## Lessons Learned Gate

**Note for plan authors:** The `executing-plans` skill includes a final "Lessons Learned" step that runs after the smoketest passes. The implementer will ask the user whether any lessons should be captured as documentation updates (CLAUDE.md, memory, skills, or agents). No action is needed in the plan itself — this gate runs automatically at execution time.

## Plan Self-Review Checklist (HARD STOP before presenting to user)

Before offering the execution handoff, run the checklist in `references/templates.md` and fix any failures before proceeding. If check #3 fails (unjustified `none`), do NOT silently fix — insert the **Incomplete Warning Block** (in `references/templates.md`) immediately after the plan header and present the plan as-is.

## Execution Handoff

After saving the plan, **present the full plan to the user**.

<HARD-GATE>
Do NOT offer execution options until the user gives an explicit affirmative approval (e.g., "yes", "looks good", "let's go", "proceed", or equivalent). Do not interpret silence or continued conversation as approval.
</HARD-GATE>

Only after explicit affirmative, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session
- **REQUIRED SUB-SKILL:** New session uses the project `executing-plans` skill (NOT superpowers:executing-plans)

**Both execution paths work inside a git worktree.** The worktree is created by `writing-plans` (through Orca via the `orca-cli` skill, after grilling) so the plan file lives on the feature branch from day one. Cleanup is handled by `finishing-a-development-branch` after the PR is merged.
