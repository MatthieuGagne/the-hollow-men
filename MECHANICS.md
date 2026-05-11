# Game Mechanics

## DNA & Influences

### Final Fantasy (FF4 / FF5 / FF6 / FF7)
- Fixed party members with defined archetypes — their role IS their identity; each broken in a specific way (FF4 / FF6 ensemble weight)
- The signature **tonal shift**: starts as a personal detective story, ends as something that cannot be fully described
- **Combat: Active Time Battle** — each character has a fixed command set

### Hideo Kojima's Touch
- At least one character who is aware something is wrong with their reality — and has been for a long time
- A secret organization with a grandiose acronym
- The "big twist" reframes everything you thought you understood about the protagonist
- A walking/travel section that is mechanically minimal but emotionally devastating
- Real-world actor likenesses for key characters
- Post-credits scene that raises more questions than answers — and one of the questions is wrong in a way you won't understand until a second playthrough
- A villain whose name, when you finally learn it, hits like a gut punch because you've heard it before without knowing
- Death is thematically central, not just mechanically present

---

## Navigation & Encounter Model

**Two modes. The line between them moves as the story moves.**

**Investigation Mode** — Reid moves through the city between story beats. Shops, NPCs, dialogue, environmental detail. Encounter rate is zero or near-zero. The city breathes. This is NOX as it presents itself.

**Hot Zone Mode** — The investigation takes Reid somewhere he shouldn't be. A Bureau secure floor. A megacorp server room. A contested block in the Sprawl. The Meridian at the wrong hour. Encounter logic activates. The city stops pretending.

Hot zones are telegraphed — the player feels the shift before it happens. Wrong geometry intensifies. The ambient sound changes. Reid's internal monologue goes quieter, then stops.

**The Ruins are the exception.** They are always a dungeon. There is no investigation mode in the Ruins — the moment you descend, encounter logic is live and does not turn off. The Ruins are the game's pure dungeon space: the entity's oldest physical presence, the place first contact was made, the bottom of the vertical stack. Every other hot zone in the city is temporary. The Ruins are permanent. The Ruins are what the whole city is built on top of, and they do not care that you are there.

Encounter density escalates by depth:

| Layer | Encounter Type | Frequency |
|-------|---------------|-----------|
| The Heights | Human — Bureau enforcers, corp security, licensed practitioners pushed too far | Rare, hot zones only |
| The Sprawl | Mixed — gangs, unlicensed practitioners, corp mercs, things that followed someone home from the Meridian | Moderate, contested zones |
| The Meridian | Wrong — entities from adjacent registers, people who went in and came back changed | Frequent, always active |
| The Warrens | Mechanical / ley-based — infrastructure that defends itself, constructs the Bureau built and forgot | Dense |
| The Ruins | Pure — what lives down here has no name in any language Reid speaks | Constant |

---

## Opening Mission — Enemy Encounters

Three waves, escalating. Human enemies only. No PP damage. Pure HP-combat tutorial.

| Wave | Enemies | Mechanical Purpose |
|------|---------|-------------------|
| 1 | Guard (STR-focus) + Guard (SPD-focus) | ATB timing, turn order, Reid vs. Mara output |
| 2 | Guard × 2 + Coordinator | Priority targeting — Coordinator buffs allies (ATB boost or DEF up); Mara's Disorientation has a clear use case |
| 3 | Captain + Guard | Boss-pattern reading, Sigil moment, recoil |

### Wave 2 — Coordinator
Hangs back, low DEF, applies ally buffs on a slow timer. Nameless, no dialogue — a mechanical priority target. The player learns to kill the softest enemy first.

### Wave 3 — Captain
Bureau-adjacent private security, licensed. Grade II — high enough to carry an offensive sigil legally, low enough that it costs them visibly to use it. The defining mechanic of the encounter is that **registered offensive sigil**.

**Sigil behavior:**
- The captain's ATB fills visibly slower than normal — the Sigil is heavy to carry
- They open with physical attacks; the Sigil is held until ~50% HP or if the fight drags
- When fired: significant PSY damage to the full party (or concentrated on Reid)
- After firing: captain takes ~15–20% of their max HP as recoil damage, ATB gauge resets with a penalty — visibly slow on the next action

**Narrative function:** The first time the player sees what official Bureau power costs — and who pays for it. Both sides pay. The player feels the weight of sanctioned power; the captain is visibly spent by it.

**Wave 3 guard:** Same profile as Wave 1 (STR-focus). A resource drain, nothing more. The captain's charging ATB bar is the only tension that matters.

---

## Core Stats

| Stat | What it is |
|------|------------|
| **HP** | Health |
| **PP** | Psychic Points — the mana equivalent. Powers abilities, Sigil use, Summoning |
| **STR** | Physical attack power |
| **DEF** | Physical damage reduction |
| **PSY** | Psychic attack/ability power |
| **RES** | Psychic damage reduction. Also resists entity effects |
| **SPD** | Determines turn order in ATB |

---

## Sigils — Bureau vs. Jailbroken

Both types provide stat bonuses. The meaningful difference is the **limit break**:

- **Bureau Sigils** — licensed limit break. Controlled, sanctioned, exactly what the Bureau trained you to do. Ceiling is capped. Tiered by Grade — the sigil you're sold matches your registered Grade. Grade IV hardware exists. You need the license to buy it legally.
- **Jailbroken Sigils** — true limit break. Full unmetered output. Reflects who the character actually is without the system skimming off the top. Possessing one is an Assessment Division matter.

The same character has two different limit breaks depending on what they're wearing. Equipping a jailbroken Sigil is a statement.

For the Black Mage, swapping mid-game *is* their arc — the moment they defect from the system, their limit break changes. The player feels the arc through the combat system.

---

## Combat Loop

### Structure
- **ATB** — every unit has a gauge that fills based on SPD. When full, they act. No pause when in menus.
- **4 active party members** at a time.
- **Command menu** — uniform across all characters: Attack / Abilities / Item / Limit. Differentiation lives inside the Abilities list.

### Physical Attack
- Damage formula: **(STR - enemy DEF) × random(0.9–1.1)**
- **Critical hits** — derived stat, not raw RNG. Crit rate is class-specific, modified by equipment and Sigils.
  - **Attack crits** draw from whichever is higher between STR and SPD.
  - **Ability crits** draw from the ability's defined stat (hardcoded per ability).
- Enemies use the same formula.

---

## Character Abilities

### Reid — Fighter
Pure single-target damage dealer. Crit stat: STR (or SPD if higher).

| Ability | PP Cost | Effect | Unlock |
|---------|---------|--------|--------|
| **Piercing Strike** | Low | Single target, ignores enemy DEF | Level 1 |
| **Heavy Blow** | Mid | Single target, high STR multiplier | TBD |
| **Brutal Strike** | High | Single target, maximum STR multiplier | TBD |
| **TBD** | TBD | Bonus damage against specific enemy state | TBD |

### Vesper — Summoner

Single party slot shared between Vesper and the being. Turns alternate 1-1; the sprite changes to show which is acting.

**Vesper's turns (PP cost):** Control/utility. Her actions spend her own PP — the power was always hers, never the being's. Spending it moves her toward transformation.

**The being's turns (PP-free):** Damage. Acts on its own register at no cost to Vesper's pool. The being is trying to keep her alive.

**Transformation — entity mode:** When PP bottoms out, Vesper becomes the entity. Player retains control; command set changes to the entity's abilities.

| State | PP cost | Role |
|-------|---------|------|
| Vesper | Spends PP | Control/utility |
| The being | Free | Damage |
| Entity (PP = 0) | Drains remaining PP | PP drain from allies |

**Entity mode rules:**
- PP does not regenerate while in entity mode
- When entity burns the last PP, Vesper snaps back with empty PP — no abilities until restored
- Entity abilities: PP drain from allies (the entity feeds the way the Bureau feeds)

**Sigil:** Vesper joins sigil-less. Bureau revoked her anchor when she went dark; her arc is forging a jailbroken sigil on her own terms. Limit break TBD.

---

### Mara — Thief (high PSY)
Hybrid: fast physical hits that apply psychic marks on contact. Crit stat: SPD (abilities crit off PSY).

| Ability | PP Cost | Effect | Unlock |
|---------|---------|--------|--------|
| **Static Touch** | Low | Single target physical hit, applies Disorientation (enemy SPD down) | Level 1 |
| **Psychic Bleed** | Mid | Single target physical hit, siphons PP from enemy | TBD |
| **Overload** | High | Single target psychic burst, bypasses DEF, applies Vulnerability (enemy takes increased PSY damage) | TBD |
| **TBD** | TBD | Conditional damage | TBD |

---

## Lovecraftian Combat — Psychic Drain

Entity-type enemies deal **PP damage** (Psychic Drain) instead of HP damage. No extra bar or stat — just a damage type that targets a different resource.

Running low on PP:
- Abilities go dark — only basic attacks available
- Limit break gauge is unreachable without PP to fuel it
- For Vesper: low PP means proximity to transformation — the entity is close

Recovery items are split:

| Item | Restores |
|------|----------|
| Medkit / Stim | HP |
| Psychic Stabilizer | PP |
| Full Restore (rare) | Both |

**The late-game reframe:** the entity draining PP in combat is mechanically identical to what the Bureau does administratively. The mechanic was always telling the story. The player just didn't have the language for it yet.
