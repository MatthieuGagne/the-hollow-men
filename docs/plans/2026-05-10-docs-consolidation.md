# Docs Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize all scattered documentation into a clean `docs/` subdirectory tree so Claude sessions can load scoped context and the developer has one logical place for every reference.

**Architecture:** Pure doc migration — no GDScript, no Godot scenes, no GUT tests. All tasks use the Non-Logic template. Order matters: create dirs and migrate plan-file-only content first (Batch 1), then split CHARACTERS.md (Batch 2), then move root-level lore (Batch 3), then clean up (Batch 4), then update the story-lore skill (Batch 5).

**Tech Stack:** Markdown, shell file operations, GitHub CLI (for issue reference only)

## Open questions (must resolve before starting)

- None — all decisions settled in brainstorming session for issue #44.

---

## Target tree (post-migration)

```
docs/
  story/
    story.md          ← STORY.md
    cases.md          ← consolidated from 4 case plan files
  lore/
    concept.md        ← CONCEPT.md
    world.md          ← WORLD.md
    bureau.md         ← 2026-04-16-bureau-psi-corps-design.md
  design/
    mechanics.md      ← MECHANICS.md
    questions.md      ← QUESTIONS.md
    enemy-design.md   ← 2026-04-24-enemy-design.md
  characters/
    reid.md           ┐
    crane.md          │
    iris.md           │  CHARACTERS.md split by section; extended notes
    margot.md         │  merged from respective plan files
    gideon.md         │
    soraya.md         │
    aio.md            │
    kos.md            │
    paz.md            │
    doc-karim.md      │
    vera-gemini.md    │
    casimir-gemini.md │
    holloway.md       │
    kurtz.md          ┘
    summoners.md      ← ## Summoners section
    _overview.md      ← ## Party Roster section
    _differentiation.md ← 2026-04-22-character-differentiation-design.md
  art/
    image-prompts-characters.md
    image-prompts-cinematic.md

CLAUDE.md             ← absorbs net-new content from docs/dev-workflow.md
```

---

## Batch 1: Create directory structure + migrate plan-file-only content

### Task 1: Create new subdirectories

**Files:**
- Create: `docs/story/`, `docs/lore/`, `docs/design/`, `docs/art/`

**Depends on:** none
**Parallelizable with:** none — must complete before all other tasks write into these dirs.

**Step 1: Create directories**

```bash
mkdir -p docs/story docs/lore docs/design docs/art
```

**Step 2: Verify**

```bash
ls docs/
```
Expected output includes: `art  characters  design  lore  plans  story`

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: create docs subdirectory structure"
```

---

### Task 2: Create docs/story/cases.md

**Files:**
- Read: `docs/plans/2026-04-23-case-1-recovery-job-design.md`, `docs/plans/2026-04-24-case-2-design.md`, `docs/plans/2026-04-24-case-3-design.md`, `docs/plans/2026-04-26-dead-signal-game-design-doc.md`
- Create: `docs/story/cases.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 3, 4

**Step 1: Read all four case files**

Read each file in full. Extract the narrative design content — overview, scene beats, party changes, encounter flow. Exclude any executor/plan metadata (e.g., headers saying "For Claude: use executing-plans", task steps, Git commands). The dead-signal file was formatted as an implementation plan; extract only the story/design content, not the implementation tasks.

**Step 2: Write docs/story/cases.md**

Structure:

```markdown
# Cases

## Case 1: The Recovery Job

[full narrative design content from 2026-04-23-case-1-recovery-job-design.md]

---

## Case 2: The Document Case

[full narrative design content from 2026-04-24-case-2-design.md]

---

## Case 3: The Wound

[full narrative design content from 2026-04-24-case-3-design.md]

---

## Case 4: Dead Signal

[story/design content from 2026-04-26-dead-signal-game-design-doc.md — exclude implementation tasks]
```

**Step 3: Verify**

Open `docs/story/cases.md`. Confirm all four cases have content and no executor-only metadata survived (no "Step 1: Write failing test" style content).

**Step 4: Commit**

```bash
git add docs/story/cases.md
git commit -m "docs: consolidate case beat maps into docs/story/cases.md"
```

---

### Task 3: Create docs/lore/bureau.md

**Files:**
- Read: `docs/plans/2026-04-16-bureau-psi-corps-design.md`
- Create: `docs/lore/bureau.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 2, 4

**Step 1: Read source file**

Read `docs/plans/2026-04-16-bureau-psi-corps-design.md` in full.

**Step 2: Write docs/lore/bureau.md**

Copy the full content. Update the H1 title if it was a plan-style title (e.g. "Bureau Psi-Corps Design") to a clean reference title like `# The Bureau`. Exclude any implementation metadata or plan-format headers.

**Step 3: Verify**

Open `docs/lore/bureau.md`. Confirm it reads as a lore reference document, not a plan.

**Step 4: Commit**

```bash
git add docs/lore/bureau.md
git commit -m "docs: migrate bureau lore to docs/lore/bureau.md"
```

---

### Task 4: Create docs/design/enemy-design.md

**Files:**
- Read: `docs/plans/2026-04-24-enemy-design.md`
- Create: `docs/design/enemy-design.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 2, 3

**Step 1: Read source file**

Read `docs/plans/2026-04-24-enemy-design.md` in full.

**Step 2: Write docs/design/enemy-design.md**

Copy the full content. Clean up any plan-format metadata. Keep the H1 as-is or rename to `# Enemy Design`.

**Step 3: Verify**

Open `docs/design/enemy-design.md`. Confirm content is complete.

**Step 4: Commit**

```bash
git add docs/design/enemy-design.md
git commit -m "docs: migrate enemy design to docs/design/enemy-design.md"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Creates dirs — must run first |
| B (parallel) | Tasks 2, 3, 4 | Different output files, all depend on Task 1 |

### Smoketest Checkpoint 1 — New dirs + plan content migrated

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Verify structure**
```bash
ls docs/story/ docs/lore/ docs/design/ docs/art/
```
Expected: `cases.md` in story/, `bureau.md` in lore/, `enemy-design.md` in design/, art/ exists (empty).

**Step 3: Spot-check content**

Open `docs/story/cases.md` — confirm all 4 cases present. Open `docs/lore/bureau.md` — confirm lore content, no plan artifacts.

**Step 4: Confirm with user**

Tell the user: "Batch 1 complete. New directories created, case beat maps consolidated into docs/story/cases.md, bureau lore and enemy design migrated. Do these look correct before we split CHARACTERS.md?"

---

## Batch 2: Split CHARACTERS.md into individual character files

> **Note:** Read `CHARACTERS.md` once at the start of this batch and keep it in context. All tasks in this batch extract sections from it. The file is deleted in Batch 4 only after all character files are created.

### Task 5: Create docs/characters/_differentiation.md

**Files:**
- Read: `docs/plans/2026-04-22-character-differentiation-design.md`
- Create: `docs/characters/_differentiation.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 6, 7, 8, 9, 10

**Step 1: Read source file**

Read `docs/plans/2026-04-22-character-differentiation-design.md` in full.

**Step 2: Write docs/characters/_differentiation.md**

Copy full content. Update H1 to `# Character Differentiation`. Remove any plan-format metadata.

**Step 3: Verify**

Open file, confirm content.

**Step 4: Commit**

```bash
git add docs/characters/_differentiation.md
git commit -m "docs: migrate character differentiation design to docs/characters/"
```

---

### Task 6: Create docs/characters/_overview.md

**Files:**
- Read: `CHARACTERS.md` (## Party Roster section, line 518 onward)
- Create: `docs/characters/_overview.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 5, 7, 8, 9, 10

**Step 1: Extract Party Roster section**

From `CHARACTERS.md`, copy everything under `## Party Roster` (line 518 to end of file).

**Step 2: Write docs/characters/_overview.md**

```markdown
# Party Overview

[content from ## Party Roster section]
```

**Step 3: Verify**

Confirm file exists with party roster content.

**Step 4: Commit**

```bash
git add docs/characters/_overview.md
git commit -m "docs: extract party roster to docs/characters/_overview.md"
```

---

### Task 7: Create simple character files (no extended notes)

**Files:**
- Read: `CHARACTERS.md`
- Create: `docs/characters/reid.md`, `docs/characters/crane.md`, `docs/characters/margot.md`, `docs/characters/gideon.md`, `docs/characters/vera-gemini.md`, `docs/characters/casimir-gemini.md`, `docs/characters/holloway.md`, `docs/characters/kurtz.md`, `docs/characters/summoners.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 5, 6, 8, 9, 10

**Step 1: Extract each section from CHARACTERS.md**

Section boundaries (by header — use these as anchors, not line numbers):

| File | Section header | Ends before |
|------|---------------|-------------|
| `reid.md` | `## Reid — Protagonist` | `## Crane` |
| `crane.md` | `## Crane — Retired Enforcer` | `## Iris` |
| `summoners.md` | `## Summoners` | `## Margot` |
| `margot.md` | `## Margot — Black Mage` | `## Gideon` |
| `gideon.md` | `## Gideon — Paladin` | `## Soraya` |
| `vera-gemini.md` | `## Vera Gemini — Catalyst` | `## Casimir Gemini` |
| `casimir-gemini.md` | `## Casimir Gemini — Catalyst` | `## Holloway` |
| `holloway.md` | `## Holloway — Bureau Contact` | `## Kurtz` |
| `kurtz.md` | `## Kurtz — Main Antagonist` | `## Party Roster` |

**Step 2: Write each file**

Each file starts with the section header as H1. Example for reid.md:

```markdown
# Reid — Protagonist

[content from ## Reid section]
```

Promote the `##` header to `#` in each file. Keep all sub-sections (###, ####) as-is.

**Step 3: Verify**

```bash
ls docs/characters/
```
Expected: reid.md, crane.md, margot.md, gideon.md, vera-gemini.md, casimir-gemini.md, holloway.md, kurtz.md, summoners.md present.

**Step 4: Commit**

```bash
git add docs/characters/
git commit -m "docs: split CHARACTERS.md into individual character files"
```

---

### Task 8: Update docs/characters/iris.md (merge stub)

**Files:**
- Read: `CHARACTERS.md` (## Iris section, lines 69–80), `docs/characters/iris.md`
- Modify: `docs/characters/iris.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 5, 6, 7, 9, 10

**Step 1: Read both sources**

Read the `## Iris — Grey-Market Fixer` section from `CHARACTERS.md` (the short stub). Read the existing `docs/characters/iris.md` in full.

**Step 2: Identify net-new content**

The stub in CHARACTERS.md contains a brief summary paragraph plus a link to iris.md. Extract any details from the stub that are NOT already in iris.md (e.g., Class, Bureau status if not covered).

**Step 3: Prepend or merge into iris.md**

If the stub has net-new facts, add them to iris.md in an appropriate spot (e.g., a brief header section with Class/Bureau status). Remove the link reference (`Full profile: [docs/characters/iris.md]`) — it's now redundant. Update the H1 to `# Iris — Grey-Market Fixer` if it doesn't already have that format.

**Step 4: Verify**

Open `docs/characters/iris.md`. Confirm it reads as one coherent document with no dangling link references.

**Step 5: Commit**

```bash
git add docs/characters/iris.md
git commit -m "docs: merge iris stub from CHARACTERS.md into iris.md"
```

---

### Task 9: Create soraya.md, aio.md, kos.md with extended notes

**Files:**
- Read: `CHARACTERS.md` (## Soraya, ## Āio, ## Kos sections), `docs/plans/2026-04-22-soraya-design.md`, `docs/plans/2026-04-22-aio-kos-design.md`
- Create: `docs/characters/soraya.md`, `docs/characters/aio.md`, `docs/characters/kos.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 5, 6, 7, 8, 10

**Step 1: Read all source files**

Read the three CHARACTERS.md sections. Read `soraya-design.md` in full. Read `aio-kos-design.md` in full (note: this file covers both Āio and Kos — split content accordingly).

**Step 2: Create soraya.md**

```markdown
# Soraya — Hacker

[## Soraya section from CHARACTERS.md, promoted to H1]

---

[net-new content from soraya-design.md not already in the CHARACTERS.md section]
```

Remove plan-format metadata from soraya-design.md content. Do not duplicate facts already stated in the CHARACTERS.md section.

**Step 3: Create aio.md**

```markdown
# Āio — Martial Artist

[## Āio section from CHARACTERS.md, promoted to H1]

---

[Āio-specific content from aio-kos-design.md]
```

**Step 4: Create kos.md**

```markdown
# Kos — Occultist

[## Kos section from CHARACTERS.md, promoted to H1]

---

[Kos-specific content from aio-kos-design.md]
```

**Step 5: Verify**

Open all three files. Confirm each reads as one coherent profile with no duplicate facts or plan metadata.

**Step 6: Commit**

```bash
git add docs/characters/soraya.md docs/characters/aio.md docs/characters/kos.md
git commit -m "docs: create soraya, aio, kos character files with extended notes merged"
```

---

### Task 10: Create paz.md and doc-karim.md with extended notes

**Files:**
- Read: `CHARACTERS.md` (## Paz, ## Doc Karim sections), `docs/plans/2026-04-22-paz-doc-karim-design.md`
- Create: `docs/characters/paz.md`, `docs/characters/doc-karim.md`

**Depends on:** Task 1
**Parallelizable with:** Tasks 5, 6, 7, 8, 9

**Step 1: Read all source files**

Read the two CHARACTERS.md sections and `paz-doc-karim-design.md` in full. The design file covers both characters — split content accordingly.

**Step 2: Create paz.md**

```markdown
# Paz — Bard

[## Paz section from CHARACTERS.md, promoted to H1]

---

[Paz-specific content from paz-doc-karim-design.md, deduplicated]
```

**Step 3: Create doc-karim.md**

```markdown
# Doc Karim — White Mage

[## Doc Karim section from CHARACTERS.md, promoted to H1]

---

[Karim-specific content from paz-doc-karim-design.md, deduplicated]
```

**Step 4: Verify**

Open both files. Confirm coherent profiles with no plan metadata.

**Step 5: Commit**

```bash
git add docs/characters/paz.md docs/characters/doc-karim.md
git commit -m "docs: create paz and doc-karim character files with extended notes merged"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Tasks 5, 6, 7, 8, 9, 10 | All write different files in docs/characters/; all depend on Task 1 |

### Smoketest Checkpoint 2 — docs/characters/ complete

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Verify all character files present**
```bash
ls docs/characters/
```
Expected files: `_differentiation.md  _overview.md  aio.md  casimir-gemini.md  crane.md  doc-karim.md  gideon.md  holloway.md  iris.md  kos.md  kurtz.md  margot.md  paz.md  reid.md  soraya.md  summoners.md  vera-gemini.md`

**Step 3: Spot-check**

Open `docs/characters/reid.md` — confirm character content with H1 header. Open `docs/characters/soraya.md` — confirm CHARACTERS.md section + extended notes are present as one document with no plan artifacts.

**Step 4: Confirm with user**

Tell the user: "Batch 2 complete. docs/characters/ has 17 files. Check that the character profiles look right before we move the root-level lore docs."

---

## Batch 3: Move root-level lore docs into docs/ tree

### Task 11: Move story + lore docs

**Files:**
- Read: `STORY.md`, `CONCEPT.md`, `WORLD.md`
- Create: `docs/story/story.md`, `docs/lore/concept.md`, `docs/lore/world.md`
- (Source files deleted in Batch 4 — do NOT delete here)

**Depends on:** Task 1
**Parallelizable with:** Tasks 12, 13

**Step 1: Copy each file**

```bash
cp STORY.md docs/story/story.md
cp CONCEPT.md docs/lore/concept.md
cp WORLD.md docs/lore/world.md
```

**Step 2: Verify**

```bash
wc -l docs/story/story.md docs/lore/concept.md docs/lore/world.md
```
Expected line counts roughly match the originals (STORY.md ≈ 160, CONCEPT.md ≈ 107, WORLD.md ≈ 195).

**Step 3: Commit**

```bash
git add docs/story/story.md docs/lore/concept.md docs/lore/world.md
git commit -m "docs: move story, concept, world docs into docs/ tree"
```

---

### Task 12: Move design docs

**Files:**
- Read: `MECHANICS.md`, `QUESTIONS.md`
- Create: `docs/design/mechanics.md`, `docs/design/questions.md`
- (Source files deleted in Batch 4)

**Depends on:** Task 1
**Parallelizable with:** Tasks 11, 13

**Step 1: Copy files**

```bash
cp MECHANICS.md docs/design/mechanics.md
cp QUESTIONS.md docs/design/questions.md
```

**Step 2: Verify**

```bash
wc -l docs/design/mechanics.md docs/design/questions.md
```
Expected: mechanics ≈ 158 lines, questions ≈ 29 lines.

**Step 3: Commit**

```bash
git add docs/design/mechanics.md docs/design/questions.md
git commit -m "docs: move mechanics and questions into docs/design/"
```

---

### Task 13: Move art files into docs/art/

**Files:**
- Existing: `docs/image-prompts-characters.md`, `docs/image-prompts-cinematic.md`
- Create: `docs/art/image-prompts-characters.md`, `docs/art/image-prompts-cinematic.md`
- (Source files deleted in Batch 4)

**Depends on:** Task 1
**Parallelizable with:** Tasks 11, 12

**Step 1: Copy files**

```bash
cp docs/image-prompts-characters.md docs/art/image-prompts-characters.md
cp docs/image-prompts-cinematic.md docs/art/image-prompts-cinematic.md
```

**Step 2: Verify**

```bash
ls docs/art/
```
Expected: both image-prompts files present.

**Step 3: Commit**

```bash
git add docs/art/
git commit -m "docs: move image prompt files into docs/art/"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Tasks 11, 12, 13 | Different output dirs, all depend on Task 1 |

### Smoketest Checkpoint 3 — Lore docs in place (originals still present)

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Verify new locations**
```bash
ls docs/story/ docs/lore/ docs/design/ docs/art/
```
Expected:
- `story/`: `cases.md story.md`
- `lore/`: `bureau.md concept.md world.md`
- `design/`: `enemy-design.md mechanics.md questions.md`
- `art/`: `image-prompts-characters.md image-prompts-cinematic.md`

**Step 3: Verify originals still present (not deleted yet)**
```bash
ls STORY.md CONCEPT.md WORLD.md MECHANICS.md QUESTIONS.md CHARACTERS.md
```
Expected: all six files present (they are deleted in Batch 4).

**Step 4: Confirm with user**

Tell the user: "Batch 3 complete. All docs are now in the new tree. Originals still present — Batch 4 will delete them. Ready to proceed with cleanup?"

---

## Batch 4: Cleanup — delete old files + update CLAUDE.md

### Task 14: Merge dev-workflow.md into CLAUDE.md

**Files:**
- Read: `docs/dev-workflow.md`, `CLAUDE.md`
- Modify: `CLAUDE.md`
- (dev-workflow.md deleted in Task 15)

**Depends on:** none (independent of Batch 3 file moves)
**Parallelizable with:** none — Task 15 depends on this completing first.

**Step 1: Read both files**

Read `docs/dev-workflow.md` in full. Read `CLAUDE.md` in full.

**Step 2: Identify net-new content**

Content already in CLAUDE.md (do NOT duplicate):
- Worktree branch naming and base path
- `make worktree-init` instruction
- TDD + GUT run command
- PR-only integration rule
- Map pipeline details (already in Architecture section)
- Skills list, Agents list

Net-new content to add from dev-workflow.md:
- **Feature lifecycle numbered flow** (steps 1–6: brainstorm → PRD → plan → worktree → implement → finish)
- **Worktree init troubleshooting table** (missing artifact table + stale TMX cache fix commands)
- **`/run` skill** for launching the game
- **Skills table** with descriptions (replace the bare list in CLAUDE.md with the table from dev-workflow.md)
- **Agents table** with descriptions (replace the bare list)

**Step 3: Update CLAUDE.md**

Add a `## Feature Lifecycle` section after the existing `## Dev Workflow` section containing the numbered flow. Replace the bare skills/agents lists in `## Skills & Agents` with the tables from dev-workflow.md. Add a `## Running the Game` note pointing to `/run`. Add the worktree init troubleshooting table under `## Dev Workflow`.

Keep CLAUDE.md concise — it is loaded on every session. Do not copy large blocks verbatim if a one-line summary covers it.

**Step 4: Verify**

Read `CLAUDE.md`. Confirm no duplicate content, no broken references, and the file remains under ~80 lines if possible. The feature lifecycle, /run note, and tables should be present.

**Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: merge dev-workflow into CLAUDE.md"
```

---

### Task 15: Delete all old files

> **This task deletes the plan file you are currently working from.** That is intentional — execution is complete by this point and the plan is preserved in git history. Do not re-read the plan after this task starts.

**Files to delete:**

Root-level lore MDs (content now in docs/):
```bash
rm CHARACTERS.md CONCEPT.md MECHANICS.md QUESTIONS.md STORY.md WORLD.md
```

Old docs/ root files (content now in docs/art/ or merged):
```bash
rm docs/image-prompts-characters.md docs/image-prompts-cinematic.md docs/dev-workflow.md
```

All plan files (content migrated in Batch 1, implementation plans have no surviving content):
```bash
rm docs/plans/*.md
rmdir docs/plans/
```

**Depends on:** Tasks 5–13 (all character files and moved docs created), Task 14 (dev-workflow merged)
**Parallelizable with:** none — this is the final cleanup.

**Step 1: Run deletions**

```bash
rm CHARACTERS.md CONCEPT.md MECHANICS.md QUESTIONS.md STORY.md WORLD.md
rm docs/image-prompts-characters.md docs/image-prompts-cinematic.md docs/dev-workflow.md
rm docs/plans/*.md
rmdir docs/plans/
```

**Step 2: Verify**

```bash
ls *.md
```
Expected: only `CLAUDE.md` remains at root.

```bash
find docs/ -name "*.md" | sort
```
Expected: only files in the new tree (story/, lore/, design/, characters/, art/).

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: delete old doc files after migration"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 14 | Must complete before Task 15 (dev-workflow.md deleted in 15) |
| B (sequential) | Task 15 | Depends on Task 14 + all Batch 2–3 tasks |

### Smoketest Checkpoint 4 — Old files gone, CLAUDE.md updated

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Verify root is clean**
```bash
ls *.md
```
Expected: `CLAUDE.md` only.

**Step 3: Verify docs/ tree is complete**
```bash
find docs/ -name "*.md" | sort
```
Expected 20 files total across story/(2), lore/(3), design/(3), characters/(17), art/(2). No docs/plans/ directory. No docs/*.md at docs root.

**Step 4: Check CLAUDE.md**

Open CLAUDE.md. Confirm feature lifecycle section, /run note, and skills/agents tables are present.

**Step 5: Confirm with user**

Tell the user: "Batch 4 complete. Old files deleted, CLAUDE.md updated. Last step is updating the story-lore skill with new paths."

---

## Batch 5: Update story-lore.md skill

### Task 16: Update .claude/skills/story-lore.md source document table

**Files:**
- Modify: `.claude/skills/story-lore.md`

**Depends on:** Tasks 11–15 (all final paths must be settled before updating refs)
**Parallelizable with:** none — final step, no other tasks.

**Step 1: Read current skill file**

Read `.claude/skills/story-lore.md` in full.

**Step 2: Update the source documents table (Section 1)**

Replace the entire table with:

| Document | Contains |
|---|---|
| `docs/lore/concept.md` | Pitch, tone, four lenses, philosophical backbone |
| `docs/story/story.md` | Act structure, opening sequence, case outlines |
| `docs/lore/world.md` | NOX vertical geography, power structure, Bureau, locations |
| `docs/lore/bureau.md` | Bureau as total institution — ideology, calibration, Grays |
| `docs/characters/` | Individual character profiles — one file per character |
| `docs/characters/_differentiation.md` | Silhouette design, psychological axes, key dynamics |
| `docs/design/mechanics.md` | Combat, sigil system, PP drain, navigation modes |
| `docs/design/enemy-design.md` | Full enemy taxonomy and thematic connections |
| `docs/story/cases.md` | All four case beat maps (Cases 1–4) |

**Step 3: Update all inline path references in the skill body**

Search the skill file for any remaining references to old paths and update them:

| Old path | New path |
|----------|----------|
| `docs/CONCEPT.md` | `docs/lore/concept.md` |
| `docs/STORY.md` | `docs/story/story.md` |
| `docs/WORLD.md` | `docs/lore/world.md` |
| `docs/CHARACTERS.md` | `docs/characters/` |
| `docs/MECHANICS.md` | `docs/design/mechanics.md` |
| `docs/QUESTIONS.md` | `docs/design/questions.md` |
| `docs/plans/2026-04-16-bureau-psi-corps-design.md` | `docs/lore/bureau.md` |
| `docs/plans/2026-04-22-character-differentiation-design.md` | `docs/characters/_differentiation.md` |
| `docs/plans/2026-04-24-case-*.md` | `docs/story/cases.md` |
| `docs/plans/2026-04-26-dead-signal*.md` | `docs/story/cases.md` |
| `docs/plans/2026-04-24-enemy-design.md` | `docs/design/enemy-design.md` |
| `docs/plans/2026-04-22-paz-doc-karim-design.md` | `docs/characters/paz.md`, `docs/characters/doc-karim.md` |
| `docs/plans/2026-04-22-soraya-design.md` | `docs/characters/soraya.md` |
| `docs/plans/2026-04-22-aio-kos-design.md` | `docs/characters/aio.md`, `docs/characters/kos.md` |

Also update the Section 7 reference: `docs/QUESTIONS.md` → `docs/design/questions.md`.

**Step 4: Verify**

```bash
grep -r "docs/plans" .claude/skills/story-lore.md
```
Expected: no output (no remaining plan file references).

```bash
grep -r "docs/CHARACTERS\|docs/CONCEPT\|docs/STORY\|docs/WORLD\|docs/MECHANICS" .claude/skills/story-lore.md
```
Expected: no output (no remaining uppercase root-doc references).

**Step 5: Commit**

```bash
git add .claude/skills/story-lore.md
git commit -m "docs: update story-lore skill with new doc paths"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 5

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 16 | Single task; no parallelism possible |

### Smoketest Checkpoint 5 — story-lore skill updated, migration complete

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Verify no stale paths in story-lore skill**
```bash
grep -n "docs/plans\|docs/CHARACTERS\|docs/CONCEPT\|docs/STORY\|docs/WORLD\|docs/MECHANICS" .claude/skills/story-lore.md
```
Expected: no output.

**Step 3: Verify final doc tree**
```bash
find docs/ -name "*.md" | sort
find . -maxdepth 1 -name "*.md" | sort
```
Expected: only CLAUDE.md at root; 20 doc files in the new tree.

**Step 4: Note on active worktree**

The worktree `feat+issue-38-battle-foundation` (at `.claude/worktrees/feat+issue-38-battle-foundation`) has stale doc paths. After this PR merges, that branch needs a rebase from master before finishing:

```bash
git -C .claude/worktrees/feat+issue-38-battle-foundation rebase origin/master
```

**Step 5: Confirm with user**

Tell the user: "Migration complete. All 5 batches done. Run /finishing-a-development-branch to submit the PR."
