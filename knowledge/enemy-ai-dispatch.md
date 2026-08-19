---
summary: Enemy AI dispatch — EnemyAI Resource virtual resolve_action interface, ai_state per-instance memory, TerritoryEnforcerAI, BlockCaptainAI, SecurityCaptainAI subclasses, data-driven summon, nested lambda gotcha (issue #92)
tags: [battle, godot, gdscript, ai]
---

# Enemy AI Dispatch

## Core interface (issue #92)

- `EnemyAI` (`scripts/battle/enemy_ai.gd`) extends `Resource`; virtual interface `resolve_action(combatant, party, enemies, add_enemy_fn) -> Dictionary`; base class implements attack-random-living-target. `enemies`/`add_enemy_fn` are unused in the base but part of the signature so summoning/ally-checking subclasses match
- Returns `{"action": "attack", "target": t, "damage": d}` or `{}` (buff/summon/no targets) — callers must guard with `result.get("action") == "attack"` before accessing keys
- `_resolve_enemy_action(combatant)` guards `if combatant.ai == null: return {}`; `_begin_enemy_turn` and `_enemy_attack_without_interrupting` both delegate to it
- `Combatant.ai_state: Dictionary` (runtime var, not @export) holds per-instance AI memory; cleared by `reset_runtime_state()` — see [[combatants-and-definitions]]

## Subclasses (`scripts/battle/ai/`)

- `TerritoryEnforcerAI` — summons backup via `Combatant.from_definition(GameData.get_definition("block_captain"))` once, guarded by `ai_state["backup_called"]`, when outnumbered; else Shakedown `STR * 1.5` roll. (Post-#128, Enforcer backup became data-driven: `EnemyDefinition.summon` holds a SummonEffect on the .tres, read via `Combatant.summon`; no enemy ids in AI scripts — a script-scan test enforces this. See [[ability-effect-system]])
- `BlockCaptainAI` — three-phase: hold_the_line buff to all → mark_target debuff → attack; uses `enemies.any(...)` so multi-enemy works
- `SecurityCaptainAI` — one-shot `ai_state["authorised_force_used"]` debuff phase, then `STR * 2.0` attacks

## Testing & gotchas

- Test pattern: `_make_*_scene()` helpers seed effects via `apply_effect` directly before calling `_resolve_enemy_action`; duration-expiry tests call `tick_effects()` directly N times — see [[gut-testing]]
- Nested lambda gotcha: the `)` closing `enemies.any(func(e):` must come AFTER the inner lambda body, not on a new line
- Embedding an EnemyAI in a `.tres`: see [[scene-and-resource-serialization]]

## Related

- [[battle-scene-state-machine]] — where enemy turns execute
- [[ability-effect-system]] — StatusEffect buffs/debuffs the AIs apply; SummonEffect
