# Dead Signal — Game Design Doc Update

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update STORY.md, WORLD.md, and CHARACTERS.md to reflect the Case 4 "Dead Signal" design decisions from issue #9.

**Architecture:** Three independent documentation edits — one per file. No GDScript logic involved. Each edit inserts or replaces a specific section; no existing content is deleted except a TBD placeholder in WORLD.md.

**Tech Stack:** Markdown only.

## Open questions (must resolve before starting)

- Āio seed in CHARACTERS.md: name vs. direction TBD in writing — leave as TBD in this doc update, flag it explicitly.

---

## Batch 1 — Core doc updates (all three files)

### Task 1: Update STORY.md — add Case 4 section

**Files:**
- Modify: `STORY.md`

**Depends on:** none
**Parallelizable with:** Task 2, Task 3

**Step 1: Write the content**

Insert the following section after the Case 3 block (after the `---` that follows "The party returns to the hub...") and before `## The Hub — Iris's Apartment`:

```markdown
## Case 4 — Dead Signal

See `docs/plans/2026-04-26-dead-signal-game-design-doc.md` for full structure. Full design: GitHub issue #9.

After Case 3, Kurtz's response to the wound disruption tightens Bureau enforcement across the Sprawl. A Lowline resident with no Bureau file is brought to Karim's clinic — latent output activating in a body that has never expressed it, triggered by forty years of proximity to Junction 9, the Lowline's oldest ley terminal node.

The party goes to the Lowline. So does **Gideon** — Grade III Bureau enforcer, on his own initiative, doing the investigation the Bureau's blunt sweep isn't doing. He and Reid's party work the same blocks from opposite ends of the city's trust hierarchy. In Zone 2 he sees Margot. Neither speaks first.

The dungeon runs four zones through the Lowline, ending at Junction 9 substation. New enemy types introduced: Bureau Regulars (formation-dependent, contrast with Grays), Echoes (mirror practitioner output; Reid's physical attacks bypass the mechanic entirely), The Hollow (data constructs — remnant output signatures of fully-harvested practitioners running as processes in the entity's information layer; Margot reads a case number pre-combat), and The Node (boss; Phase 2 hijacks Gideon's neural interface, redirecting his healing output as self-regeneration).

Post-boss: Margot reads the terminal's output log and finds a message from someone who found Junction 9 from the Grid side. *"I have mapped forty-seven terminals exhibiting this pattern across NOX. I have the map. — S."* No location. No frequency. Open thread.

Gideon fights as a guest in Zone 4. He is cracked by what he sees. He files his report — *investigation ongoing* — and goes back to Bureau blue. He does not join.

After Case 4, the party is still Reid + Karim + Margot + Iris. Three open threads: Kos (deep Meridian), Vesper (glimpsed at the wound), Gideon (Bureau, filing open investigations), and now Soraya (47 terminals, Grid-layer map).
```

**Step 2: Verify**

Read the updated STORY.md and confirm:
- Case 4 section appears between Case 3 and The Hub
- All character names match CHARACTERS.md exactly
- The section follows the same structural pattern as Cases 1–3 (overview paragraph + reference to design doc)

**Step 3: Commit**

```bash
git add STORY.md
git commit -m "docs: add Case 4 Dead Signal to STORY.md"
```

---

### Task 2: Update WORLD.md — add Sprawl district structure

**Files:**
- Modify: `WORLD.md`

**Depends on:** none
**Parallelizable with:** Task 1, Task 3

**Step 1: Write the content**

Replace the existing `## The Sprawl` section (everything from `## The Sprawl` through the end of `### Key Locations` for the Sprawl) with the following:

```markdown
## The Sprawl

The bulk of the city. Megacorp territories carving it up — brand wars, turf disputes, the visible competition. Where people live. Three distinct districts:

### The Market

The economic engine of the Sprawl. Dense street-level commerce — licensed vendors beside grey-market stalls, food, information, everything at a price that doesn't appear on a Bureau form. The Bureau is reactive here, not present: called when needed, not patrolling. Where the city's underside does business openly.

**Key locations:**
- **Karim's Clinic** — unlicensed community healer, no questions asked. Takes anyone. Has been treating the Bureau's damage one patient at a time for decades. The party's first Sprawl contact point.
- **Suzy's operation** — money-lending network, Heights-adjacent. Professional, no sympathy.

### The Lowline

The industrial-residential belt. Named for the low-slung megacorp infrastructure buildings that dominate its skyline: server farms, power substations, data exchanges. Workers' housing grew up around the megacorp facilities decades ago and never moved on. Bureau instruments read the Lowline as stable. That stability is the lie.

The ley terminals here are embedded in the megacorp power infrastructure, indistinguishable from electrical junction boxes. Nobody questions them. They have been there longer than the current megacorp has. The entity's information layer has been bleeding through them for forty years. The residents of the Lowline have been sleeping next to a pipeline their whole lives.

**Key locations:**
- **Junction 9** — the Lowline's oldest power exchange node. A ley terminal embedded in the substation infrastructure, operating since before the current megacorp's ownership. The harvest pipeline running through it has been saturated by the acceleration — it has been broadcasting as well as receiving for 94 days. The dungeon location for Case 4.

### The Fringe

Where the Sprawl meets the Meridian. Buildings that predate the Bureau's current architecture. Streets that run slightly wrong at certain corners without reaching full Meridian geometry. Bureau enforcement patrols less here — the instruments give unreliable readings, the paperwork harder to justify.

Where people who don't want to be found end up. Where the Bureau's administrative reach goes thin.

**Key locations:**
- **Āio's Dojo** — a fighting tradition that predates the Bureau's entire framework, practiced in the one part of the city where Bureau instruments already struggle. Built from grief. Grief made functional. *(First visited: TBD — Case 5 or later.)*

### Key Locations (Sprawl-wide)

- **Iris's Apartment** — a residential floor in a dense Sprawl block. Looks like one apartment among hundreds from the hallway; Bureau instruments pass over it. One of the city's only genuinely off-grid residential spaces — Iris built the infrastructure herself over years, piece by piece. The party's hub from the end of Case 2. The kid lives here. No registry entry, no ley terminal signature. The address has never been given to anyone until Iris gave it to Reid.
```

Also remove from the `## TBD` section at the bottom of WORLD.md the line:
```
- District structure and named neighborhoods within the Sprawl
```
since that is now resolved.

**Step 2: Verify**

Read the updated WORLD.md and confirm:
- Three named Sprawl districts present: The Market, The Lowline, The Fringe
- Junction 9 described under The Lowline
- Āio's Dojo present under The Fringe with "TBD" first-visit note
- Iris's Apartment preserved under Key Locations (Sprawl-wide)
- TBD line for district structure removed from the `## TBD` section

**Step 3: Commit**

```bash
git add WORLD.md
git commit -m "docs: add Sprawl district structure to WORLD.md (The Market, The Lowline, The Fringe)"
```

---

### Task 3: Update CHARACTERS.md — Gideon and Soraya investigation entries

**Files:**
- Modify: `CHARACTERS.md`

**Depends on:** none
**Parallelizable with:** Task 1, Task 2

**Step 1: Write the content**

**Edit 1 — Gideon's Arc section:**

Find the existing paragraph in Gideon's entry:

```
His entry into the party — voluntary defection or pushed out — is TBD, contingent on the broader Act structure.
```

Replace it with:

```
### Investigation Entry (Case 4 — Dead Signal)

Gideon is in the Lowline on his own initiative — not assigned. He saw the incident report for Junction 9 (involuntary output activity, unregistered practitioners), recognized Assessment Division jurisdiction being bypassed by Kurtz's blunt Bureau sweep, and came to do the investigation correctly. He is doing real police work. He believes the institution's stated purpose, even when the institution isn't following it.

He and Reid's party work the same blocks in Zone 2. He sees Margot. Neither speaks first. The silence is sustained through the entire dungeon.

In Zone 4 he fights alongside the party as a guest — the only option when the Node uses his Bureau-standard neural interface as a relay. Phase 2 of the Node boss fight: it hijacks his Paladin healing output as self-regeneration. The party breaks the relay. He survives. His kit is introduced here: Fighter/Healer hybrid, battlefield positioning, the cyberware that connects him to a machine he still trusts.

Post-boss: one practical exchange with Margot. Neither names what they're carrying.

He files his report. Writes what he can write. *Investigation ongoing.* Puts his badge on — takes a beat longer than usual — and goes back. He does not join.

**Why he stays Bureau:** He can still write the report. After Dead Signal, his framework has a container for what he saw. The container is a stretch. He knows it is a stretch. The moment Gideon can no longer write a report that makes sense to himself is the moment he stops being Bureau. That moment is not here.

**His arc break** — the last report he can't file — is TBD, contingent on act structure. Kurtz will eventually notice his *investigation ongoing* flag.
```

**Edit 2 — Soraya's Investigation Entry section:**

Find the existing line in Soraya's entry:

```
### Investigation Entry
TBD.
```

Replace it with:

```
### Investigation Entry (Case 4 — Dead Signal, partial)

First contact is indirect. After the party defeats The Node at Junction 9, Margot reads the terminal's output log and finds Soraya's notation — advanced Grid-layer analysis syntax, a format beyond Bureau standard that Margot has never encountered. The message:

*"This terminal has been broadcasting for 94 days. You disrupted the activation but the pipeline is intact. I have mapped forty-seven terminals exhibiting this pattern across NOX. This is the first one that tried to push back. If you're reading this, you found it from the physical side. I found it from the other direction. I have the map. You have the investigation. — S."*

No location. No frequency. No meeting offered.

Soraya has been monitoring Junction 9 from the Grid side for months. She knows the party found it from the physical register. She has the Grid-layer map of the entity's information architecture across NOX — forty-seven terminals, decades of mapping. She does not join. She is an open thread.

**Full investigation entry** — how she joins the party — TBD.
```

**Step 2: Verify**

Read the updated CHARACTERS.md and confirm:
- Gideon's investigation entry replaced the TBD arc note
- Soraya's investigation entry replaced the TBD placeholder
- All cross-references (case names, character names) match STORY.md exactly
- No duplicate section headers introduced

**Step 3: Commit**

```bash
git add CHARACTERS.md
git commit -m "docs: update Gideon and Soraya investigation entries for Case 4 Dead Signal"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2, Task 3 | All modify different files; no shared symbols or state |

### Smoketest Checkpoint 1 — design docs consistent and complete

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures. (No GDScript was modified — this is a regression check only.)

**Step 3: Verify docs manually**

Read through the three updated files and confirm:
- `STORY.md`: Case 4 section present between Case 3 and The Hub, consistent with Cases 1–3 pattern
- `WORLD.md`: Three Sprawl districts present with Junction 9 and Āio's Dojo named; TBD line for district structure removed
- `CHARACTERS.md`: Gideon investigation entry complete; Soraya partial contact entry complete; no orphaned TBD placeholders for these two characters

Cross-check: every character name and location name used in STORY.md Case 4 section matches exactly what appears in CHARACTERS.md and WORLD.md.

**Step 4: Confirm with user**

Ask the user:
1. Does the Case 4 summary in STORY.md accurately reflect the design?
2. Does the Sprawl district structure in WORLD.md feel right as a permanent doc entry?
3. Does the Gideon investigation entry capture why he stays Bureau correctly?
4. Does the Soraya partial entry correctly represent her as an open thread?

Wait for confirmation before considering this plan complete.
