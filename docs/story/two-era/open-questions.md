# Open Questions

Prioritised. Work from the top. Each question with a `discussions/` file has had argument
put into it already — read that before reopening.

Status: **open** · **in discussion** · **parked** (deliberately deferred)

---

## Tier A — blocking, discuss next

| # | Question | Status | File |
|---|---|---|---|
| A1 | **Travel rules.** Who can cross, and through what? Session 3 settled the door model: doors are wounds in the entity, cut by the founding harvest during the revolution; crossing needs an absent tether **and** a door; entity awareness is stated-A / actual-B. Three sub-questions remain below (B5–B7). | mostly settled | `discussions/travel-rules.md` |
| A2 | **How much Vesper does the era give back?** **Resolved 2026-11-20** → `discussions/vesper-contact.md`. Glimpses and traces across early visits; **one conversation, late** — brief, unstable, non-clarifying, about the era rather than about her. A playable stretch rejected. | resolved |

---

## Tier B — needed before any writing starts

| # | Question | Status |
|---|---|---|
| B1 | **Reveal ownership.** Does the era take the charter-acronym (*Neural Output eXchange*) reveal from Act 3? Recommended: yes, with Act 3 gaining *WARDEN is still editing*. | open |
| B2 | **Paz's withholding.** **Resolved 2026-11-20** → `discussions/paz.md`. She wrote the first banned song and ran during the purge, before the signing — truth without proof. Her door still works; she has never used it. Remaining: what breaks her silence. | resolved |
| B3 | **Episode map.** Provisional seven-episode arc drafted 2026-11-20 → `discussions/episode-map.md`. Era and present alternate; party breaks in Ep3, Gideon's break is Ep5, the signing is Ep6. Count and Vesper's slot not final. | provisional |
| B4 | **Approve Thibault and Sabine** as temporary era guests, and **Varenne / the Registrar** as era NPCs. | open |
| B5 | **Does WARDEN know the harvest cut the doors?** The founding crime is also the founding security hole. Option (b) — deliberate at the founding — now means the founders knew they were cutting. Supersedes C4. | open |
| B6 | **Margot's residue.** Twelve years metered, then jailbroken. Does prior metering leave something behind? | open |
| B7 | **Does a woundable entity undercut its unknowability?** Project rule is that descriptions break down by design; "it has scars" is very legible. Likely answer: *scar* is the party's inadequate word, not what it is. | open |
| B8 | **Who speaks the prehistory, and where?** It is told aloud (decided), so it needs a mouth and a slot in the episode map. Constraint: delivered as administration, not revelation — never a villain monologue. | open |
| B9 | **Is the prehistory verifiable?** One unverifiable account, or does the party find corroboration in the era? Changes whether the player is allowed to believe it. | open |
| B10 | **`world.md` rewording.** "It wanted to be built around" must become passive drawing if the stranded-entity prehistory is propagated. The fact survives; the intention does not. | open |
| B11 | **The quarantined quarter in the present.** Does the child-tithe district still exist two centuries on, and what is there now? The party coins the game's title standing in it — the present-day counterpart needs an answer. | open |
| B12 | **Is the Night of the Lamps playable or witnessed?** Fought from inside the cordon, or watched from outside it. Decides whether the era's biggest set-piece is a dungeon or a scene. | open |
| B13 | **The survivor's name and the few lines they speak.** Name surfaces in the Accountants' minutes, not their own mouth; the lines must not become a monologue. | open |
| B14 | **Who fires the district** in Lamps beat 4 — Accountants, panicked citizens, or a junior officer. Explicitly not the General. | open |

---

## Tier C — can wait

| # | Question | Status |
|---|---|---|
| C1 | **Thibault forward?** Written to stay and be quieted. An alternative extracts him to the present, deliberately breaking the iron rule. Currently not recommended. | parked |
| C2 | **Working names** — Thibault, Sabine, Varenne, the Patrimony, the Accountants, the Registrar, the Office of Civic Output, the quieting, the Deep Patron. | parked |
| C3 | **Era distance from the present** — order of centuries, deliberately unpinned. | parked |
| C4 | **Does the Bureau know time travel is possible?** Falls out of A1. | parked |
| C5 | **The Lieutenant** — optional third era guest. Cut unless the era cast feels thin. | parked |
| C6 | **When a beat closes a door, then what?** Either the party finds another door (doors plural and findable), or the era is simply unreachable for a stretch (stronger loss, but the era can be taken away). Belongs with B3. | parked |

---

## Engineering questions (not blocking story work)

| # | Question | Status |
|---|---|---|
| E1 | **Save temporary party members.** `snapshot_party_runtime()` covers `_permanent_members` only, so era guests vanish on load. Recommended: additive `SaveData` field mirroring the permanent roster. | open |
| E2 | **`KnownFlags` manifest scaling.** Every `fire_on_scene_load` zone needs a hand-added entry; wildcard matching was deferred "until a 3rd zone-family flag lands." A multi-visit era blows past that. | open |
| E3 | **Era art direction.** New period tileset — note the present day has only `placeholder.png`. Gates any build work. | open |

---

## Resolved — moved to `decisions.md`

Kos travel · Vesper in the revolution · Paz's Meridian childhood · Āio's community wound ·
act structure · party topology · roster size · which approach.
