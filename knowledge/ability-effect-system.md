---
summary: AbilityEffect data-driven ability system — DamageEffect kinds (PHYSICAL/PIERCING/PSYCHIC), HealEffect, ApplyStatusEffect, SummonEffect, StatusEffect stat modifiers, damage variance, issue #125 design decisions (no power field, kind mapping), epic sequencing #125→#126→#127→#128
tags: [battle, godot, gdscript, abilities, design-decisions]
---

# Ability Effect System

Data-driven ability effects: an `Ability` carries a typed array of `AbilityEffect` resources;
the battle scene type-dispatches on each. "Data-driven, not name-driven" is the core invariant.

## AbilityEffect / DamageEffect (issue #125)

- `AbilityEffect` (`scripts/battle/ability_effect.gd`) — empty marker base extending `Resource`; subclasses define `compute(user, target) -> int`
- `DamageEffect` (`scripts/battle/damage_effect.gd`) — `enum Kind { PHYSICAL, PIERCING, PSYCHIC }`; PHYSICAL = STR−DEF, PIERCING = STR (ignores DEF), PSYCHIC = PSY−RES
- `compute()` returns the raw **un-clamped** base (can be negative); variance/clamping happens at resolution time in the caller — intentional
- `static Combatant.apply_damage_variance(base: int) -> int` is the single source of truth for the ±10% roll: `maxi(1, floori(base * randf_range(0.9, 1.1)))` — floors any base ≤ 0 to 1. `calculate_damage` delegates to it
- `Ability.effects: Array[AbilityEffect]` — typed to the base class so DamageEffect/HealEffect/etc. coexist; effects applied in order; PP spent once at ability level before the loop
- `_resolve_ability` type-dispatches with `if effect is DamageEffect`, computes + applies variance per effect, sums total. Empty `effects` array → total 0, no damage — the "data-driven not name-driven" regression test pattern. The 0-damage path skips the animation block: `_end_turn()` runs synchronously and `player_turn_ended` emits before `execute_action` returns. (Note: `_resolve_ability` was later deleted in #128, replaced by `resolve_recipients` + `_perform_ability_on` — see [[battle-scene-state-machine]])
- **Test isolation gotcha:** `Combatant.ability` has NO setter — `reid.ability = reid.ability.duplicate(true)` silently fails, and mutating `effects` then pollutes the cached CharacterDefinition for all later tests. Correct: `var saved := reid.ability.effects.duplicate(); reid.ability.effects = []; ...; reid.ability.effects = saved`

### Issue #125 settled design decisions (merged 2026-06-10 via PR #135)

Non-derivable decisions not recorded elsewhere:

- **No `power` field** on DamageEffect — the PRD never defined it; STR/PSY *is* attack power. Deferred indefinitely.
- **No `target_mode` in #125** — deferred to #128, which ADDED the field (it did not exist post-#125; #128 has since shipped — see [[battle-scene-state-machine]]).
- Kind mapping: Reid/Piercing Strike → PIERCING (STR), Iris/Static Touch → PSYCHIC (PSY−RES), Margot/Void Calculus → PSYCHIC.
- Epic sequencing after #125: #126 (Heal) → #127 (Status) → #128 (Summon + target_mode); persistence track #122 is independent.

## HealEffect (issue #126)

- `HealEffect` (`scripts/battle/heal_effect.gd`) extends `AbilityEffect`; `@export var amount: int = 0`
- `compute_heal(user, target) -> int` returns `amount + user.get_effective_stat(StatusEffect.StatAxis.PSY) / 2` (integer division floors); `target` unused but kept for API consistency
- Heals are NOT randomised — no `apply_damage_variance`. `confirm_party_target` loops `_active.ability.effects`, sums `compute_heal` for each `HealEffect`, calls `target.heal(total)` once
- Karim's Field Suture: `amount=38` so `38 + floor(45/2) = 60` at PSY 45; `targets_party = true` on the ability is independent of effects (note: `targets_party` was later REPLACED by `target_mode` in #128)
- PSY debuff test recipe: `StatusEffect` has no `Kind` enum — set `stat = StatusEffect.StatAxis.PSY; modifier = -10; duration = 3; effect_name = "weaken_psy"` then `apply_effect(debuff)`

## ApplyStatusEffect (issue #127)

- `ApplyStatusEffect` (`scripts/battle/apply_status_effect.gd`) extends `AbilityEffect`; `enum TargetMode { TARGET, SELF }`
- `@export var status: StatusEffect` — the template; `@export var target_mode: TargetMode = TargetMode.TARGET`
- `resolve_recipient(user, target) -> Combatant` — returns `user` if SELF, else `target`
- `make_instance() -> StatusEffect` — returns `status.duplicate(true)` (deep copy, never aliased); returns `null` safely when `status` is unset
- Non-aliasing is the critical invariant: each call to `make_instance()` produces an independent `StatusEffect` so two combatants can't share duration counters

## SummonEffect (issue #128)

- `SummonEffect.make_summon()` builds a Combatant from GameData by id — data-driven summoning
- Enforcer backup is data-driven: `EnemyDefinition.summon` (a SummonEffect on the .tres) read via `Combatant.summon`; no enemy ids in AI scripts (a script-scan test enforces this). See [[enemy-ai-dispatch]]
- `_apply_nondamage_effects_to` in BattleScene handles Heal/ApplyStatus/Summon — see [[battle-scene-state-machine]]

## StatusEffect Integration (issue #86)

- `get_effective_stat(StatAxis)` sums matching-axis modifiers from `active_effects` onto the base stat, clamped `maxi(0, ...)` — individual stats never negative, but DIFFERENCES (e.g. DamageEffect.compute) are unclamped
- `take_damage()` clears `mark_target` effects (iterating backwards with `remove_at`) BEFORE HP deduction — even if the hit kills
- Static `calculate_*` functions use `get_effective_stat` on both sides — buffs/debuffs automatically factored in
- `calculate_damage` does NOT consume `mark_target` (only `take_damage` does)

## Related

- [[combatants-and-definitions]] — the stats these effects compute against
- [[battle-scene-state-machine]] — effect resolution, target_mode, AoE
- [[enemy-ai-dispatch]] — AI-side use of buffs/debuffs/summons
- [[scene-and-resource-serialization]] — `.tres` typed-array and sub-resource gotchas when authoring effects
