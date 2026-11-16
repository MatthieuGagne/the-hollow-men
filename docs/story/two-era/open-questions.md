# Open Questions

Prioritised. Work from the top. Each question with a `discussions/` file has had argument
put into it already — read that before reopening.

Status: **open** · **in discussion** · **parked** (deliberately deferred)

---

## Tier A — blocking, discuss next

| # | Question | Status | File |
|---|---|---|---|
| A1 | **Travel rules.** Who can cross time, and why doesn't everyone? Proposal on the table: *metered output is a tether*. | in discussion | `discussions/travel-rules.md` |
| A2 | **How much Vesper does the era give back?** Glimpse, conversation, or a playable stretch with the real Vesper. Sets the era's emotional centre and its scope. | in discussion | `discussions/vesper-contact.md` |

---

## Tier B — needed before any writing starts

| # | Question | Status |
|---|---|---|
| B1 | **Reveal ownership.** Does the era take the charter-acronym (*Neural Output eXchange*) reveal from Act 3? Recommended: yes, with Act 3 gaining *WARDEN is still editing*. | open |
| B2 | **Paz's withholding.** She has known about the era for years. Why say nothing? Can she cross back? Her recruitment beat depends on it. | open |
| B3 | **Episode map.** How many episodes, what each covers, where era visits land. Needs A1 and A2 first. | open |
| B4 | **Approve Thibault and Sabine** as temporary era guests, and **Varenne / the Registrar** as era NPCs. | open |

---

## Tier C — can wait

| # | Question | Status |
|---|---|---|
| C1 | **Thibault forward?** Written to stay and be quieted. An alternative extracts him to the present, deliberately breaking the iron rule. Currently not recommended. | parked |
| C2 | **Working names** — Thibault, Sabine, Varenne, the Patrimony, the Accountants, the Registrar, the Office of Civic Output, the quieting, the Deep Patron. | parked |
| C3 | **Era distance from the present** — order of centuries, deliberately unpinned. | parked |
| C4 | **Does the Bureau know time travel is possible?** Falls out of A1. | parked |
| C5 | **The Lieutenant** — optional third era guest. Cut unless the era cast feels thin. | parked |

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
