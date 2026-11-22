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
| 1 | Guard (STR-focus) + Guard (SPD-focus) | ATB timing, turn order, Reid vs. Iris output |
| 2 | Guard × 2 + Coordinator | Priority targeting — Coordinator buffs allies (ATB boost or DEF up); Iris's Disorientation has a clear use case |
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
- **Command menu** — uniform across all characters: Attack / Abilities / Item / Limit. Differentiation lives inside the Abilities list. Forms, Sets, devices and overdrawn casts are all *entries in that list*, never new top-level menus.
- **Damage amplification is additive, with a cap.** Pressure, Overdraw, Distortion and exposure effects sum rather than multiply; total amplification from all sources is capped (target: +100%). Multiplicative stacking trivializes bosses.

### Physical Attack
- Damage formula: **(STR - enemy DEF) × random(0.9–1.1)**
- **Critical hits** — derived stat, not raw RNG. Crit rate is class-specific, modified by equipment and Sigils.
  - **Attack crits** draw from whichever is higher between STR and SPD.
  - **Ability crits** draw from the ability's defined stat (hardcoded per ability).
- Enemies use the same formula.

---

## Character Abilities

### The Uniqueness Rule

No character is a union of two other characters' lists. Every party member owns a **verb** nobody else has, and is distinguished on three axes: the verb, their relationship to the ATB gauge, and their limit break pair. **No two characters may match on more than one axis.**

The audit: *swap any two party members. If the fight plays out the same way, one of them is a Red Mage and must be redesigned or cut.*

**Hard constraint — no transfer, ever.** There is no universal spell pool and no shared learning system. Abilities are welded to the character. Equipment and Sigils tune numbers; they never grant another character's verb. (This is the FF6 Magicite failure: fourteen unique commands dissolved by one universal learning system.) Kos is the apparent exception and isn't — he learns from *enemies*, never from the party.

Resources stay **HP and PP only**. No per-character bars.

| Character | Class | Verb | ATB tempo |
|-----------|-------|------|-----------|
| Reid | Fighter | **Pressure** — stacks that erode a target's defenses for the whole party | Fills *faster as his HP drops* |
| Iris | Thief | **Steal** — a ladder: Lift → Skim → Strip → Palm | Fastest; 2–3 actions per ally turn |
| Margot | Black Mage | **Overdraw** — cast straight, or at double cost for double damage | Slowest; boom-and-recover |
| Karim | Medic | **Loadout** — equipped devices grant commands | Average; the only in-combat PP restorer |
| Gideon | Defender | **Interpose** — absorbs and redirects damage aimed at allies | Reactive; arms states that resolve on others' turns |
| Vesper | Summoner | **Summon** — alternating turns with the being | Shared/alternating gauge |
| Soraya | Hacker | **Intrusion** — the enemy's own kit becomes your damage | Rides the *enemy's* gauge |
| Paz | Bard | **Set** — layerable, battlefield-wide, dual-sided | Fast; the only ally-gauge accelerator |
| Āio | Martial Artist | **Form** — one stance at a time, reconfigurable mid-fight | Stance-modulated fill |
| Kos | Occultist | **Echo** — learns entity attacks used on him | Normal |

---

### Reid — Fighter

Single-target attrition. He builds a case against one enemy and closes it. Crit stat: STR (or SPD if higher).

**No PP bar.** The only character in the game with one bar instead of two — the man whose output was metered through Bureau-issue equipment his whole career now fights with nothing but himself. Abilities cost HP or nothing. Psychic Drain hits his HP instead of PP and ignores DEF: he bleeds for it rather than going dry. Karim's Stabilize is a dead button on him.

**His gauge fills faster the lower his HP is.** Combined with HP-costed abilities, playing Reid well means deliberately running low.

**Pressure** stacks on a target, eroding its DEF and RES **for the whole party** — "who is Reid working on" organizes every fight. Stacks persist on that enemy for the entire battle.

| Ability | Cost | Effect | Unlock |
|---------|------|--------|--------|
| **Piercing Strike** | HP | Single target, ignores enemy DEF, +1 Pressure | Level 1 |
| **Work the Body** | free | Low damage, fast, +2 Pressure | TBD |
| **Heavy Blow** | HP | High STR multiplier, +2 Pressure | TBD |
| **Close the Case** | HP | Consumes all Pressure; damage scales brutally with the stack | TBD |

**Late-game:** when Reid finally takes a sigil, he gains a PP bar. After thirty hours of knowing what that bar means in this world, it reads as a loss, not an upgrade.

---

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

### Iris — Thief (high PSY)

Fastest unit in the cast; tiny costs, high frequency. Crit stat: SPD (abilities crit off PSY).

**Steal is a ladder, not a side action.** It starts classic and escalates into something nobody else can do.

| Tier | Command | Steals | Unlock |
|------|---------|--------|--------|
| 1 | **Lift** | Items | Join |
| 2 | **Skim** | PP, drained from the enemy's pool | Act 1 late |
| 3 | **Strip** | A buff or status off an enemy, transferred to an ally | Act 2 |
| 4 | **Palm** | The enemy's **queued action** — they lose the turn, Iris gets it | Act 3 |

Steal is percentage-based, derived from Iris's SPD vs. the target — high against ordinary enemies, low against rare ones worth re-rolling. **A failed attempt still reveals the target's next action in the turn order**, so a whiffed steal is never a wasted turn. Anything she has stolen from stays revealed permanently.

| Ability | PP Cost | Effect | Unlock |
|---------|---------|--------|--------|
| **Static Touch** | Low | Single target physical hit, applies Disorientation (enemy SPD down) | Level 1 |
| **Psychic Bleed** | Mid | Single target physical hit, siphons PP from enemy | TBD |
| **Overload** | High | Single target psychic burst, bypasses DEF, applies Vulnerability | TBD |

**Limit break:** never registered, so she has no licensed limit at all — only a jailbroken one, from day one.

---

### Margot — Black Mage

The artillery. Biggest single numbers in the game, on the slowest gauge in the cast.

**Overdraw.** Every spell has two entries in her list: the straight cast, and the overdrawn one.

| | PP cost | Damage | After |
|---|---------|--------|-------|
| Straight cast | normal | solid | normal gauge refill |
| **Overdraw** | double | roughly double | ATB gauge resets with a heavy penalty — she's out for a long beat |

This is the Wave 3 Captain's sigil recoil, done on purpose. The player learns what Overdraw costs by watching the Captain pay for it in the tutorial fight. Margot is the Bureau's Grade IV asset deliberately exceeding her metered output — the exact thing the institution exists to prevent.

She is also the **only character who exploits elemental/register weaknesses**, which makes her mandatory in specific fights rather than merely strong. (Full elemental system: TBD, own session.)

| Ability | PP Cost | Effect | Unlock |
|---------|---------|--------|--------|
| **Void Calculus** | Mid | Heavy AoE psychic damage | Level 1 |
| *(overdrawn variants)* | Double | ~2× damage, severe gauge penalty | With each spell |

**Limit break:** licensed is proper Academy technique. Jailbroken is who she actually is under the framework she rebuilt around the grief. The swap is her arc.

---

### Karim — Medic

No healing magic. No innate spell list. Karim carries **devices**, and each equipped device grants a command. **Three slots**, chosen between fights; devices are found, bought and upgraded during investigation. Change the loadout, change the character — he is the one party member whose build is a function of where you've been.

| Device | Command | Effect |
|--------|---------|--------|
| **Stim Injector** | Stim | Large instant HP heal; target's gauge takes a penalty after — the crash |
| **Suture Field** | Suture | Heal over time; while it ticks the target can't be killed below 1 HP |
| **Stabilizer Rig** | Stabilize | **Restores PP** |
| **Defibrillator** | Revive | Returns a downed ally at low HP; long cooldown |
| **Dampener** | Dampen | Shields an ally from Psychic Drain for several ticks |

**Stabilize is structural.** Karim is the only in-combat source of PP restoration (outside the purchasable Psychic Stabilizer item), which makes him essential in exactly the fights that matter — entity encounters, where Psychic Drain is the damage type and running dry reduces the party to basic attacks. The unlicensed doctor is the only thing standing between the party and what the Bureau does to people.

He carries one or two weak offensive devices so he isn't dead weight in trash fights.

---

### Gideon — Defender

Highest HP and DEF in the cast. **No healing** — that was the Red Mage in him and it's gone. A real secondary damage dealer, gated behind a slow gauge.

| Ability | Effect |
|---------|--------|
| **Interpose** | Guards an ally; attacks aimed at them redirect to Gideon at reduced damage until it expires |
| **Bulwark** | Party-wide damage reduction for several ticks |
| **Hold the Line** | Forces enemy targeting onto him; he counterattacks whatever takes the bait |

Interpose consumes his turn — he is never simultaneously the wall and the hammer. Mid-game he gains tools that function against entities; nothing in his kit goes dark.

**Limit break:** Grade III, licensed and capped. The most interesting pair in the cast, because the jailbroken one may be a thing he never fires.

---

### Paz — Bard

Timed, layerable, battlefield-wide. Every Set buffs all allies and debuffs all enemies **in the same action** — nobody else touches both sides. Two or three can run at once; the skill is building the right combination before a boss opens up, and choosing between refreshing an expiring Set and adding a new one.

| Set | Allies | Enemies | Duration |
|-----|--------|---------|----------|
| **Uptempo** | gauges fill faster | gauges fill slower | Short |
| **Distortion** | psychic damage up | RES down | Medium |
| **Low End** | damage reduction | STR down | Medium |
| **Feedback** | PP regen | psychic damage per tick | Long, weak |

Uptempo does not stack with itself and its magnitude stays small — Iris's action economy plus Karim's Adrenaline compound dangerously. Between Sets, Paz fights normally for modest damage.

**Theme:** her output goes out through a channel the Bureau never considered a channel. The ley terminals register *something* and the assessment protocol has no idea what to do with it. The one party member whose power is public, loud, and performed in front of people.

---

### Āio — Martial Artist

Always in exactly one Form. The Form changes what her basic attack *is* and what she resists. Switching costs a turn and a little PP — the only thing she spends PP on. Attacking inside a Form is free.

| Form | Attack becomes | She gains |
|------|----------------|-----------|
| **Still Water** | Counterattacks anything that hits her | High DEF and RES, slow gauge |
| **Running** | Three fast light hits | Fastest gauge, low defense |
| **Breaking** | One heavy armor-piercing hit | Ignores DEF, slowest gauge |

Three to start; a fourth and fifth are learned later. She is the only character who can change her own gauge speed mid-fight.

**Versus Reid:** Reid commits to a *target* and escalates against it. Āio commits to a *configuration* and answers the fight's shape. Reid's decisions are about who; Āio's are about how.

**Entity interaction:** her tradition predates the Bureau's framework and was never contaminated by the entity's machine, so she takes **reduced** Psychic Drain and partially ignores entity resistances. In the Ruins, where everyone else's output is being eaten, the woman who never put anything out keeps working.

---

### Kos — Occultist

**Echo.** Kos learns abilities by having them used on him — entity and entity-adjacent attacks only. Learning is automatic: if it hits him and he survives, it's in his list. Learned abilities cost PP like anything else. (Full learnable list: TBD.)

He **joins late**, already carrying a meaningful starting list, plus a thin base kit — a basic attack and one self-protective ability. Joining late is the fix for the death spiral: a party member who is useless for ten hours gets benched, and a benched character learns nothing.

His list isn't a collection, it's a record of contact. His power curve is tied to where the story has taken you, not to a level table. *What has been done to Kos, Kos can do.*

---

### Soraya — Hacker

Almost no direct damage. She makes enemies do the damage.

| Ability | Effect |
|---------|--------|
| **Hijack** | The target's next action fires at its own allies instead |
| **Misfire** | The target's next ability backfires — the caster eats it |
| **Lockout** | Target loses access to abilities entirely; basic attacks only |
| **Cascade** | A hack spreads from one enemy to adjacent systems |

**Her effects don't resolve on her turn — they fire when the hacked target acts.** She plays the enemy's clock, not her own. She carries a weak direct attack as a fallback for when nothing is hackable or the hacked target dies first.

**Against entities she doesn't go dark.** They have no cyberware, so her Intrusions retarget to the information layer she spent decades mapping — same abilities, entity-flavored effects, no second kit.

**Versus Kos:** Kos is passive acquisition, absorbing what is done to him and turning it outward. Soraya is active redirection, turning the enemy's systems against themselves.

---

### Limit Breaks for the Unlicensed

`combatant.gd` caps Bureau sigils at 80% (`LIMIT_CAP_BUREAU`). Reid (stripped), Iris (never registered), Soraya (no file), Āio (unmeterable) and Paz (no Grade) have no licensed sigil at all — **they are uncapped from the start.** Mechanically strong early, and it says the thing the game is about: the only people the system never skimmed are the ones it never got its hands on.

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
