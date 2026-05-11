# Enemy Design

**Scope:** All enemy archetypes for Act 1. Appearance, stat profile (qualitative), and signature actions per entry. Numerical balance and deep-dive mechanics are deferred to implementation sessions.

---

## Stat Axes (reference)

From `scripts/battle/combatant.gd`:

| Stat | Meaning |
|------|---------|
| HP | Health — physical durability |
| PP | Psychic Points — output resource; draining it is the entity and Bureau's shared logic |
| STR | Physical attack power |
| DEF | Physical defense |
| PSY | Psychic attack power |
| RES | Psychic resistance |
| SPD | ATB fill rate |

Stat profiles below use: **Low / Moderate / High / Very High**

---

## Enemy Taxonomy

| Category | Archetypes |
|----------|-----------|
| Faction 1 — Street / Sprawl | Territory Enforcer, Block Captain |
| Faction 2 — Bureau | Gray Field Agent, Gray Assessor, Gold Coat Operative |
| Faction 3 — Megacorp | Corporate Security, Corporate Mage |
| Entity-Adjacent Phenomena | Shade, Vessel, Bloom |
| Boss — Human | Territory Boss, Bureau Commander, Kurtz |
| Boss — Entity | The Crossing, The Wound-Feeder |

---

## Faction 1 — Street / Sprawl

Territory muscle. No Bureau connection, no formal training. Controls blocks through presence and numbers. First encountered in Case 1.

**Design principle:** The danger is the formation, not any individual. Dangerous together; manageable apart.

---

### Territory Enforcer

*The grunt. Controls a block through presence and repetition.*

**Appearance:** Patchwork armor over street clothes. Cheap functional cyberware — a reinforced arm, knockoff optic implant. Gang markings in spray or scarring, never a uniform. Stocky silhouette, one arm heavier than the other. Dominant palette: warm grays and rust.

**Stat profile:**
- HP: Moderate | STR: High | DEF: Low | PSY: Low | RES: Low | SPD: Low-Moderate

**Actions:**
- **Shakedown** — heavy single-target physical strike. Slow windup. Punishing damage.
- **Call Backup** — summons a second Enforcer if the party outnumbers the enemy group; buffs allies' STR if already at full strength. The gang's core logic: control through numbers.

---

### Block Captain

*The one giving orders. Holds the corner through experience and augmentation.*

**Appearance:** More gear than the grunt — better armor plating, full augmented arm running gang comms, crude neural interface at the temple. Slightly wider silhouette than the Enforcer. Reads as the person the others look at before acting.

**Stat profile:**
- HP: High | STR: Moderate | DEF: High | PSY: Very Low | RES: Low | SPD: Low

**Actions:**
- **Heavy Strike** — powerful STR attack, slower than Enforcer's Shakedown.
- **Hold the Line** — raises DEF of all Street-faction allies for 2 turns. Costs a full ATB turn.
- **Mark Target** — lowers one party member's DEF. Directs the gang's focus. Persists until the marked character takes a hit.

**Formation note:** Captain marks a target and holds; Enforcers pile on. The Captain is the inefficient kill target — but leaving them alive makes the Enforcers dangerous.

---

## Faction 2 — Bureau

Two internal tiers: the Grays (Assessment Division field teams) and Gold Coat / WARDEN operatives. Grays are trained practitioners. Gold Coats are something the Bureau doesn't explain.

**Design principle:** Three-tier escalation across Act 1. Field Agents introduce Bureau combat logic. Assessors add PP drain as a resource threat. Gold Coats reframe what "Bureau enemy" means.

---

### Gray Field Agent

*The physical enforcement arm of Assessment Division. Trained, equipped, and thoroughly certain they're doing the right thing.*

**Appearance:** Gray Bureau coat, maintained. Bureau-standard neural interface at the temple, uncovered — part of the uniform. No improvised gear. Everything issued and kept clean. The contrast with Street enemies is immediate: these people are a system. Dominant palette: cold gray / clinical white.

**Stat profile:**
- HP: Moderate | STR: Moderate | DEF: Moderate | PSY: Moderate | RES: Moderate | SPD: Moderate

**Actions:**
- **Bureau Strike** — standard physical attack. Consistent. Nothing fancy.
- **Contain** — applies a slow debuff to one party member's SPD for 2 turns.
- **Cover Formation** — reduces damage to all Bureau-faction allies for one hit. Breaks when the party focuses fire through it.

---

### Gray Assessor

*Grade III or above practitioner. They can read the party's output signatures before the fight starts.*

**Appearance:** Gray coat with the Bureau sigil glowing cold at the collarbone — the only luminous point on them. Thinner silhouette than the Field Agent. The hands give them away: practitioners hold themselves differently. Dominant palette: cold gray with a thin line of Bureau-blue sigil light.

**Stat profile:**
- HP: Low-Moderate | STR: Low | DEF: Low | PSY: High | RES: Moderate | SPD: Moderate

**Actions:**
- **Output Drain** — drains PP from one party member. The Bureau's harvest made mechanical. Thematic core of the enemy type — mirrors what the entity does naturally.
- **Sigil Strike** — PSY-based attack targeting RES, not DEF.
- **Assessment** — lowers one party member's RES for 2 turns, making all subsequent PSY attacks against them hit harder. Dangerous if two Assessors are present.

---

### Gold Coat Operative

*WARDEN designation. Supersedes all Bureau warrant structures. Seeing one means the threat tier has changed.*

**Appearance:** Full gold coat, worn open. In a city of dark nocturnal uniforms this is aggressive and wrong — institutional authority that doesn't need to conceal itself. WARDEN-spec cyberware, visibly higher grade than Bureau-standard. Larger than a Gray, moves unhurried. Dominant palette: deep charcoal / cold gold.

**Stat profile:**
- HP: High | STR: High | DEF: High | PSY: High | RES: High | SPD: Moderate-High

**Actions:**
- **Gold Edict** — forces one party member to skip their next turn. No damage, no animation. The target's ATB bar fills and empties without acting.
- **WARDEN Strike** — uncapped PSY attack. Unlike Bureau Assessors (capped at 80% limit by their sigil), Gold Coat operatives have no ceiling.
- **Jurisdiction** — passive: while the Gold Coat is alive, all Bureau-faction allies gain a SPD bonus. Removing it first is correct play — they're the hardest target in any formation.

---

## Faction 3 — Megacorp

Corporate security with cyberware plus calibrated practitioners on payroll. Appear in corp-adjacent missions. Function within the Bureau's system rather than enforcing it.

**Design principle:** Expensive, transactional, by-the-book. The Mage's capped limit break makes the Bureau sigil's constraint visible at a glance — reinforcing what Margot's jailbroken sigil means in contrast.

---

### Corporate Security

*A corporate employee, not a true believer. Follows orders until the math stops working.*

**Appearance:** Corporate uniform over heavy cyberware — sleek, expensive, maintained by someone else. Reinforced chassis under the jacket, full optic replacement (both eyes, matching). Heights palette: cold blue and clinical white. Reads as "money" rather than "institution."

**Stat profile:**
- HP: High | STR: Moderate | DEF: Very High | PSY: Low | RES: Low | SPD: Moderate

**Actions:**
- **Protocol Strike** — reliable physical attack. Efficient, nothing creative.
- **Neural Jam** — uses cyberware to interrupt one party member's ability queue, preventing their next ability use. No damage. Pure disruption.
- **Severance** — on death, the cyberware core vents: moderate damage to the entire party. The corporation extracts value even from a dying asset. Incentivizes careful kill order.

---

### Corporate Mage

*Bureau-licensed practitioner on payroll. Academy formation, corporate application. Stopped thinking about it.*

**Appearance:** Corporate uniform with the Bureau sigil at the collarbone — the same cold glow as a Gray Assessor's, but with a corporate logo subtly embossed on the housing. Cleaner than Margot's jailbroken version. Stands slightly apart from Security in formation — they know they're the resource being protected.

**Stat profile:**
- HP: Low | STR: Low | DEF: Low | PSY: High | RES: Moderate | SPD: Moderate-High

**Actions:**
- **Contracted Strike** — standard PSY attack. Bureau-licensed, reliable, no flavor.
- **Asset Transfer** — strips one buff from a party member and applies it to a Corporate ally. The language is financial.
- **Compliance Burst** — the Corporate Mage's limit break, capped at 80% by their Bureau sigil. High PSY damage to a single target; the gray fill bar visibly hits the wall and stops. The cap communicates their position within the system without dialogue.

---

## Entity-Adjacent Phenomena

The entity-adjacent enemies form a horror gradient: the weakest are people the system emptied. The strongest are what the entity builds when it has had enough time and mass.

**The spectrum:**
- **Tier 1 — Shade:** Completely drained humans. Human silhouette, human clothes. Still recognizable. The horror is what you're looking at.
- **Tier 2 — Vessel:** The entity filling the shell and it doesn't fit. Body horror — wrong limbs, spreading infection, the human form distorting.
- **Tier 3 — Bloom:** Barely human. Aggressive body horror — flesh expanding, anatomy collapsing. The human origin is a detail you have to look for.

**Who they were:** Bureau-calibrated practitioners whose output was fully consumed. Meridian residents who wandered too deep. The people Karim patched up and watched deteriorate. Some of Margot's disappearance cohort are here. The numbers that didn't close in her ledger have faces.

**Design principle:** Each tier teaches the party something different. Shades teach that the rules changed. Vessels escalate the threat and the horror. Blooms break assumptions — Absorb and kill order force tactical rethinking by Zone 3.

---

### Shade *(Tier 1)*

*Used to be human. The output is gone. Something else fills the negative space.*

**Appearance:** Human silhouette, human clothes — Sprawl workers, Meridian residents, Bureau-grey coat remnants. Empty eye sockets: not dark, just absent. Wrong-green bleeding in at the figure's edges. On some of them the Bureau calibration sigil is still bonded at the collarbone — still glowing cold, still routing output that no longer belongs to anyone. They move too smoothly. No weight. Dominant palette: desaturated human tones with wrong-green edge bleed.

**Stat profile:**
- HP: Low | STR: Low | DEF: Low | PSY: Moderate | RES: Low | SPD: Moderate-High

**Actions:**
- **Hollow Touch** — small PP drain on one target. The routing still running with nothing behind it.
- **Vacant Gaze** — one party member skips their next action. Not magical — the weight of recognition. Staring into what's left of someone.

---

### Vessel *(Tier 2)*

*The entity filling the shell. The human is still in there. The entity doesn't understand anatomy.*

**Appearance:** The human shape is still approximately right — you might recognize them if you knew them. Body being rebuilt from inside: limbs at angles the joints don't allow, skin showing spreading infection patterns, eyes returned but filled with wrong-green light. Clothes splitting at the seams. Growing larger than the original person was. Dominant palette: sickly flesh tones with wrong-green infection spread.

**Stat profile:**
- HP: Moderate | STR: Moderate-High | DEF: Moderate | PSY: Moderate | RES: Low | SPD: Low-Moderate

**Actions:**
- **Wrong Grip** — heavy STR attack. The body grabs in a way the joints shouldn't allow.
- **Spread** — applies a damage-over-time infection debuff to one target.
- **Drained Voice** — moderate AoE PSY damage to the whole party. The original person screaming from somewhere inside.

---

### Bloom *(Tier 3)*

*The entity has been building for a long time. You can see a hand in the mass. A jaw. A fragment of coat. That's all.*

**Appearance:** Massive — 64×64px, the largest non-boss enemy. Organic growth that doesn't follow anatomy: flesh expanding in configurations that have no name, limbs merged or multiplied into new structures. Wrong-green pulsing from deep inside. Somewhere in the outer mass: a human hand, the corner of a jacket, something that used to be a face. Dominant palette: deep wrong-green and dark flesh, near-black at the mass's core.

**Stat profile:**
- HP: Very High | STR: High | DEF: High | PSY: Moderate-High | RES: Moderate | SPD: Low

**Actions:**
- **Mass Slam** — devastating STR area attack.
- **Absorb** — feeds on a defeated Shade or Vessel in the same encounter to recover HP. Forces kill order decisions — the party cannot leave downed entity-adjacent enemies on the field.
- **Hollow Pulse** — high AoE PSY damage. The entity radiating outward from the accumulated mass.

---

## Boss Tier — Human

---

### Territory Boss

*The person behind the enforcer teams. Authority earned through violence, displayed through modification.*

**Appearance:** The Street faction's ceiling — heavy augmentation built up over years. Full chrome arm, reinforced torso plating visible under a worn jacket, both eyes replaced with military-spec optics. The Sprawl aesthetic at its limit: not polished, but serious. Dominant palette: worn rust and chrome.

**Stat profile:**
- HP: High | STR: Very High | DEF: High | PSY: Very Low | RES: Low | SPD: Moderate

**Actions:**
- **Chrome Strike** — devastating cyberware-enhanced STR attack. Single target, maximum damage.
- **Gang Authority** — summons a Block Captain mid-fight. Forces formation management while the boss swings.
- **Last Resort** — at 30% HP: STR and SPD sharply increase, DEF drops entirely. The cyberware venting everything it has. Telegraphed and readable — the party sees it coming.

---

### Bureau Commander

*Senior Assessment Division. Doesn't raise their voice. Doesn't need to.*

**Appearance:** Gray coat, impeccably maintained. Older — seniority visible in posture, in the quality of the Bureau neural interface. Everything is the best issue the Bureau provides, kept in that condition for decades. Dominant palette: cold gray / clinical white, sharper and more severe than a field agent.

**Stat profile:**
- HP: High | STR: Moderate | DEF: Moderate | PSY: Very High | RES: High | SPD: High

**Actions:**
- **Deep Assessment** — reads the whole party: applies a RES debuff to all characters for 3 turns.
- **Bureau Authority** — forces one party member to skip two consecutive turns and reduces their PSY. Institutional authority with teeth.
- **Calibration Protocol** — limit break: massive PP drain on one target, potentially full drain. The threat the Bureau holds over every practitioner in NOX, made direct.

---

### Kurtz — Gold Coat / WARDEN

*The main antagonist. Was on the team the night Reid let Vesper walk. The scar through the left brow is Reid's work. Twenty years of distance have closed.*

**Appearance:** Full gold coat, worn open. Moves like authority rather than fabric. The scar through the left brow catches the battle lighting — the only imperfection on a man who has spent twenty years ensuring nothing else is. WARDEN-spec cyberware: more integrated than Bureau-standard, less visible. He doesn't look like a threat. He looks like a decision. Dominant palette: deep charcoal / cold gold.

**Stat profile:**
- HP: Very High | STR: High | DEF: High | PSY: Very High | RES: Very High | SPD: High
- Multi-phase boss. Phase threshold triggers on a story beat — see below.

**Actions:**
- **Gold Edict (enhanced)** — forces two party members to skip their next turns simultaneously.
- **WARDEN Mandate** — strips all party buffs and applies a party-wide RES debuff. No damage. Pure authority.
- **Calibration Order** — directs the harvest at one party member: massive PP drain and blocks all PP recovery for 3 turns.
- **Phase 2** (HP threshold — the recognition moment): Kurtz's limit bar was never capped. The gold fill bar fills to 100%. His uncapped output hits the entire party. Every other Bureau enemy in the game has a gray bar that stops at 80%. This one doesn't stop. The visual difference communicates what WARDEN means without a word.

**Design note:** The phase shift should be triggered by or coincide with Reid recognizing Kurtz — the scar finally placing the face. The mechanical escalation and the narrative beat land together. Flagged for story/dialogue design session.

---

## Boss Tier — Entity

Full creature bosses. Alien and deeply wrong — but readable as creatures. Strong silhouette, one distinctive color accent, clear at boss sprite scale.

---

### The Crossing

*Case 2, Beat 14. Something that was waiting on the other side. Now it's here.*

**Appearance:** Massive multi-limbed predator — reads immediately as a creature, though nothing in any natural history has anything like it. Central body the size of a room: dark purple-black carapace over bioluminescent tissue that pulses when it breathes. Eight limbs arranged asymmetrically — two too many, placed where they shouldn't be — each ending in something between a claw and a sensory organ. No conventional face: five wrong-green apertures across the upper mass, opening and closing independently, like eyes that evolved somewhere vision works differently. The silhouette at boss scale: massive central oval, radiating asymmetric limbs, cluster of glowing green points where the face should be. Dominant palette: deep purple-black / wrong-green bioluminescence.

**Pixel art read:** Dark mass with asymmetric limb spread. The five apertures are the accent — wrong-green, readable at small scale, immediately wrong.

**Stat profile:**
- HP: Very High | STR: High | DEF: Moderate | PSY: High | RES: Moderate | SPD: Low

**Actions:**
- **Limb Surge** — multiple physical hits distributed across the party. Too many limbs, all swinging.
- **Membrane Scream** — high AoE PSY damage. The sound of something crossing over, forced into physical space.
- **Anchor** — pins one party member: cannot act for 2 turns, HP drains slowly. Priority target to free them — killing the Anchor source releases immediately.
- **Phase 2** (HP threshold): The Crossing stops holding a stable form. SPD dramatically increases as it partially retreats back through the membrane — faster, less coherent, harder to hit. The fight becomes about landing hits on something that is only partially present.

---

### The Wound-Feeder

*Zone 4, Case 3. Ancient. Has been here long enough that it and the wound are not two things.*

**Appearance:** Elongated, serpentine, vast — coiled so that only part of it is visible in the battle frame, the rest disappearing into the wound behind it. Dark as between-space, no reflective surface. The ley conduit lines of the wound run through its body the way blood vessels do — woven into the tissue, glowing red-gold from inside. The maw is the face: enormous, forward-facing, ringed with layers of inward-curling teeth and bioluminescent fronds that serve as lures. No eyes. It found this place through something other than sight. The silhouette reads as: a massive coiled dark form with a huge central maw aperture, red-gold light bleeding through the body where the conduit lines thread. Dominant palette: near-black / red-gold conduit glow.

**Pixel art read:** Coiled mass with the maw as the visual anchor. The red-gold conduit-glow is the accent — distinct from the wrong-green of every other entity-adjacent enemy. This one has been integrated with the Bureau's architecture long enough to carry its color.

**Stat profile:**
- HP: Massive | STR: Moderate | DEF: Very High | PSY: Very High | RES: Very High | SPD: Very Low

**Actions:**
- **Conduit Pulse** — drains PP from the entire party simultaneously and heals itself for the amount drained. The harvest mechanism, embodied. The most resource-threatening action in Act 1.
- **Geometry Rupture** — AoE PSY damage that also randomizes all party members' ATB bars.
- **Between Pull** — massive PSY damage on one target plus a stacking debuff increasing all damage they take. Stacks up to 3 — at 3 stacks the character is knocked out regardless of remaining HP.
- **Phase 2** (50% HP): The wound opens wider. All entity-adjacent enemies in the fight are healed. The party's DEF stats are halved by the wrong architecture pressing in.
- **Phase 3** (25% HP): The Wound-Feeder begins retreating into the wound. Each turn it doesn't act, it heals. The party has a limited window to finish it. Time pressure imposed by the entity's survival instinct.

**Thematic note:** Conduit Pulse draining PP to heal itself closes the thematic loop — Karim's patients, Margot's disappearance cohort, Casimir's entity-contact scarring, the Bureau's calibration procedure — all roads lead here. This is where the output goes.

---

## Thematic Connections

- **PP drain as the shared logic of Bureau and entity:** Gray Assessors drain PP. Shades drain PP. The Wound-Feeder drains PP and heals from it. The Bureau built the harvest architecture on top of what the entity does naturally. The mechanic makes this visible without dialogue.
- **The Bloom's Absorb mechanic:** Forces kill order decisions by letting the Bloom feed on defeated Shades and Vessels. Thematically: the entity consolidating what it's already consumed.
- **Kurtz's uncapped limit bar:** Every Bureau enemy has a gray bar that stops at 80%. Kurtz's fills to 100%. This communicates WARDEN without explanation.
- **The Wound-Feeder's red-gold conduit glow:** Wrong-green is the entity's color throughout. The Wound-Feeder carries red-gold — the Bureau's architecture's color — because it and the wound are continuous. The entity has been here long enough to absorb the system built on top of it.
- **Corporate Security's Severance:** The corporation extracts value even from a dying asset. The mechanic is the ideology.

---

## Deferred

- Numerical stat balancing for all entries — separate implementation session
- Specific ability costs (PP spend, ATB weight) — separate implementation session
- Kurtz recognition scene: mechanical beat coinciding with narrative moment — story/dialogue design session
- Margot recognizes a disappearance cohort member in a Vessel's face — story/dialogue design session
- Additional entity-adjacent enemy variants if Act 1 encounter density requires them
- Megacorp boss (corp division head) — not designed this session; placeholder for corp-heavy missions
- Entity boss for Acts 2–3 beyond the Wound-Feeder — TBD in later design sessions
- Enemy sprite commission briefs — separate art session per faction
