# Decision Log

Settled decisions, newest session last. Each entry records **what** and **why**, so a later
session doesn't re-argue it. A decision can be reopened — but only with a reason that
wasn't on the table when it was made.

Status key: **settled** = decided · **provisional** = decided but cheap to revisit ·
**propagated** = written into the authoritative docs (none yet)

---

## Session 1 — 2026-11-05

| # | Decision | Status |
|---|---|---|
| 1 | **Two greatest influences are FF6 and Chrono Trigger.** | settled |
| 2 | **Add a revolution/Napoleon era** the party can travel to. | settled |
| 3 | **The era is a past era of NOX itself** — same city, different century. | settled |
| 4 | **One era, revisitable** — a place returned to, not a one-off chapter. | settled |
| 5 | **Anchored at the revolution proper** — the founding still undecided. | settled |
| 6 | **The past cannot be changed.** Witness and document only; return with knowledge, not a fixed timeline. CT's iron rule. | settled |
| 7 | **Approach 1 — "The Truth Was Once Public."** A lived district, not a single building or a single man's tragedy. | settled |

**FF6 priorities selected:** Kefka-style villain · magic-as-harvest truth · theatrical
set-pieces · bittersweet non-triumphal ending.
**Explicitly not selected:** World-of-Ruin restructure.

**CT priorities selected:** entity as Lavos · eras as living history · past resists change ·
era set-pieces.
**Explicitly not selected:** personal arcs resolved across time.

---

## Session 2 — 2026-11-15

| # | Decision | Status | Why |
|---|---|---|---|
| 8 | **Structure moves from three acts to episodes.** | settled | The midpoint party-break stopped being an obstacle the era had to fit around; episodes break and reform the party as a matter of course (FF6 scenario structure). |
| 9 | **Episode 1 ≈ the existing Act 1** — opening sequence + Cases 1–4, re-cut to end on the time-travel hook. | settled | Preserves shipped work (intro beats 1–6, Four Winds, Iris) and the best-developed material. |
| 10 | **Chrono Trigger topology** — characters recruited in the past come forward and stay. | settled | Proven, keeps one endgame roster, avoids doubling party-building work. |
| 11 | **Roster is open** — cut/merge allowed, new era characters allowed. In practice **zero cuts were needed.** | settled | Relocating two characters rebalanced the cast on its own. |
| 12 | **Permanent roster stays at 10.** Cast grows past ten via temporary and NPC tiers. | settled | Two permanent past recruits felt right; guests carry the rest. |
| 13 | **Āio is past-native.** | settled | Their file already says the tradition predates the Bureau and the entity has no model for it; the Fringe dojo is already described as older than the Bureau. They come forward and find their own school still standing under inheritors who never knew them. |
| 14 | **Āio's wound spans both regimes** — the Patrimony's tithe *and* the founding census. | settled | They watched the regime change and the extraction continue. Makes them the one voice in the era unmoved by the broadsheet. |
| 15 | **Paz is past-native and self-travelled** — from the revolution, crossed forward alone years before Episode 1, built a band in the Sprawl. | settled | Costs nothing from her file: she *arrived* in the Meridian rather than growing up there, so the Kos recognition beat survives. Her Regularization wound strengthens — she has watched the same machine work three times across two centuries. |
| 16 | **Kos cannot travel.** The past is unbearable; what came through his calibration gets louder nearer the entity's surface. | settled | Gives the structure a present-day anchor and a present-side team. Deliberate cruelty: the one place he'd grow strongest is the one place he can't go. |
| 17 | **Vesper appears in the revolution. She went back.** | settled | `story.md` already said she "didn't disappear — she *went*, deliberately." The missing-person case becomes a missing-in-time case. Case 3's existing glimpse beat needs no rewrite. |
| 18 | **Soraya is reworked for the era, not excluded** — the Patrimony's reliquary network is an analog harvest grid; with no Grid to muffle it, the entity's information layer is bare. | settled | Keeps her kit functional in a century with no Grid, and explains her 47 terminals predating their own install dates. |
| 19 | **Design now, build after Episode 1 is playable.** | settled | The era roughly doubles the content footprint of a game that is ~1/3 of Episode 1 on one placeholder tileset. Sequencing, not scope reduction. |

### Proposed in session 2, NOT yet decided

- **Travel rule: "metered output is a tether."** Only the unmetered can cross. → `discussions/travel-rules.md`
- **Thibault and Sabine** as temporary era guests. → `roster.md` Tier 2
- **Varenne and the Registrar** as era NPCs. → `roster.md` Tier 3
- **Reveal ownership** — whether the era takes the charter-acronym reveal from Act 3.
- **Save temporary party members** — an additive `SaveData` field so era guests survive a load.
