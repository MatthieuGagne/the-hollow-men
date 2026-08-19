---
summary: BattleScene state machine and targeting — BattleState enum order, execute_action coroutines, target_mode TargetMode enum (SELF/ONE_ALLY/ALL_ALLIES/ONE_ENEMY/ALL_ENEMIES), switchable, resolve_recipients, _target_all AoE flag, _perform_ability_on, enemy selection UI cursor, finger targeting cursor, victory XP text (issues #106, #112, #128, #141)
tags: [battle, godot, gdscript, state-machine, targeting, ui]
---

# BattleScene State Machine & Targeting

## BattleState (issue #106; order changed by #128)

- `BattleState` (current order, issue #128): `{ TICKING=0, AWAITING_INPUT=1, ANIMATING=2, ENDED=3, SELECTING_ALLY=4, SELECTING_ENEMY=5, PAUSED=6 }` — do NOT assume the old ordering; reference `BattleState.NAME`, never numeric literals
- AoE / group targeting (issue #128): `_target_all: bool` is the single flag for fixed ALL_* casts. Set true in `_begin_enemy_targeting`/`_begin_party_targeting` when `ability.is_all()`, which then emit `enemy_group_target_changed(true)`/`party_group_target_changed(true)` and `return` (skipping the single-target cursor emit). `_navigate_*_target` early-returns when `_target_all`. Cleared on confirm (emits the group signal with `false`) and unconditionally in `_end_turn`. No cancel/back input exists for SELECTING_* states, so `_target_all` cannot leak into a later turn
- `_perform_ability_on(recipients: Array[Combatant])` is PLAYER-side only (uses `party.find(_active)` for the lunge sprite). Pre-await damage Dictionary keyed by Combatant keeps results stable across the await; recipient→sprite via `enemies.find(r)` is safe because recipients are the living-enemy snapshot and no enemy is removed mid-resolution (`take_damage` doesn't free nodes). The no-damage `else` branch never sets `_state` but is harmless — `_end_turn()` unconditionally sets TICKING. That branch is currently DEAD: every enemy-side player ability in the codebase carries a DamageEffect
- `execute_action("attack"/"ability")` are async coroutines — they set ANIMATING before the first `await`, and damage is applied at the impact peak (after first `await lunge_tween.finished`), not synchronously. Ordering invariant: compute damage and `spend_pp` BEFORE the first `await` — compute → set ANIMATING → await animation → apply effects → end turn
- `confirm_party_target()` (heal path) goes directly to TICKING — no async animation; `_start_enemy_flash(sprite)` is NOT async (its tween runs concurrently; `create_tween()` tweens survive coroutine suspension)
- `_end_turn()` and `_enemy_attack_without_interrupting()` call `tick_effects()` BEFORE `consume_atb()`. Tests that set `_scene._active = c` then call `_end_turn()` must save the ref first — `_active` is nulled inside

## Enemy Selection UI (issue #112)

- `_begin_enemy_targeting(action)` only when 2+ living enemies — single-enemy battles skip the UI; uses `living_enemies[0]` (filtered), never `enemies[0]` (NOTE: the auto-target-single shortcut was later removed in #128 — see below; the cursor now always shows)
- `enemy_target_changed(combatant)` emits `null` to clear the cursor; `enemy_added(combatant)` emitted at end of `add_enemy()` — HUD's `_enemies` IS the same array as `BattleScene.enemies` (typed arrays are reference types), so mid-battle appends are visible automatically; the handler appends a panel only
- `confirm_enemy_target()` resolves damage and spends PP synchronously before the first `await`

## target_mode + AoE (issue #128, Batches 1-3 confirmed 2026-06-14)

- `Ability.target_mode: TargetMode { SELF=0, ONE_ALLY=1, ALL_ALLIES=2, ONE_ENEMY=3, ALL_ENEMIES=4 }` (default ONE_ENEMY) + `switchable: bool`; REPLACES `targets_party`. Helpers: `targets_party_side()`, `targets_enemy_side()`, `is_all()`
- `BattleScene.resolve_recipients(mode, expanded, user, picked, living_party, living_enemies) -> Array[Combatant]` is static + pure; `expanded` only affects switchable ONE_* (returns the living side list)
- `_perform_ability_on(recipients: Array[Combatant])` is N-recipient: spend PP once → pre-await `dmg` map per recipient → if any damage, ONE shared attacker lunge then loop all recipients (take_damage + `_apply_nondamage_effects_to` + per-recipient damage number + `_start_enemy_flash`) simultaneously → one return tween + FLASH_HOLD. Pure buff/heal path skips the lunge (straight to TICKING). Sprite lookup: `enemies.find(r)`→`$EnemyContainer.get_child(idx)`, guard `idx>=0`
- `_target_all: bool` state var: set true in `_begin_enemy_targeting`/`_begin_party_targeting` for fixed `is_all()` abilities (emits `enemy_group_target_changed`/`party_group_target_changed`(true) and RETURNS early — no single cursor); reset false in `_end_turn`; cleared (emit false) on confirm. `_navigate_*_target` early-returns when `_target_all` (group has no per-target cursor)
- `confirm_party_target` dead-pick guard is scoped to single-target only: `if not _target_all and not target.is_alive(): return` (group cast ignores the pick)
- `execute_action` ability branch: SELF→`_cast_self()`; party-side→`_begin_party_targeting()`; enemy-side single-living auto-target shortcut guards `not ab.is_all() and not ab.switchable` so fixed-ALL always routes to group targeting
- HUD group handlers `_on_enemy_group_target_changed`/`_on_party_group_target_changed(active)` set every panel's `CursorLabel.modulate.a`; connected in `hud.gd setup()`. HUD enemy panels = `_enemy_panels`, party = `_panels`
- Fixtures: `tests/fixtures/test_aoe_caster.tres` (target_mode=4, DamageEffect), `test_aoe_healer.tres` (target_mode=2, HealEffect). Smoketest scenes extend `BattleScene`, override `_spawn_enemies()`, add caster via `PartyManager.add_temporary` in `_ready()` before `super._ready()`

### Issue #128 settled design decisions (epic #129; shipped via PR from `worktree-feat+issue-128-summon-target-mode`)

- `BattleScene.resolve_recipients(mode, expanded, user, picked, living_party, living_enemies)` is a **pure static** function mapping mode (+ `_target_all` toggle) → recipient list. Both the ally path (`confirm_party_target`) and enemy path (`confirm_enemy_target`/`_perform_ability_on`) route through it. The old `_resolve_ability` was deleted.
- `_perform_ability_on(recipients)` does one shared lunge then simultaneous flash + per-target damage numbers (AoE); pure heal/buff skips the lunge. `_apply_nondamage_effects_to` handles Heal/ApplyStatus/Summon. `SummonEffect.make_summon()` builds a Combatant from GameData by id — see [[ability-effect-system]].
- Enforcer backup is data-driven: `EnemyDefinition.summon` (a SummonEffect on the .tres) read via `Combatant.summon`; no enemy ids in AI scripts (a script-scan test enforces this) — see [[enemy-ai-dispatch]].
- `_target_all` is set in `_begin_*_targeting` for fixed-ALL abilities and toggled by `expand_target_to_all`/`collapse_target_to_single` (switchable only); reset in `_end_turn`.
- **Always show the targeting cursor**, even for one target — the auto-target-single shortcut was removed at the user's request, so single-target attacks/casts require a confirm press.
- Targeting cursor is a **finger on the target sprite** (placeholder `HAND_BITMAP` baked to a texture at runtime in battle_scene.gd; parented to a dedicated `TargetCursors` layer, NOT the sprite container — whose child order is indexed by combatant index). HUD name-list cursor now only marks the active turn.

## Victory XP award (issue #141, Task 10, 2026-06-15)

- `BattleScene.build_victory_text(total_xp:int, leveled:Array) -> String` — static, pure; builds `"Victory!\nGained N XP"` + one `"%s reached Lv %d!"` line per `{name,to}` entry, joined with `\n`. Placed right after `resolve_recipients`
- `_on_battle_ended(true)` victory branch: sum `e.xp_reward` over `enemies`, filter `party` to living survivors, `PartyManager.award_xp(survivors, total_xp)`, THEN `remove_temporary_members()`, set `_victory_label.text = build_victory_text(...)` BEFORE show + VICTORY_DELAY. Else (defeat) branch untouched
- Adding a static func to `class_name BattleScene` is a registry-surface change — reimport (`--import`) before GUT to dodge the stale-registry "Static function not found" parse error (the red TDD state was exactly that parse error, as expected). See [[scene-and-resource-serialization]]

## Related

- [[ability-effect-system]] — the effects resolved here; issue #125 design decisions
- [[combatants-and-definitions]] — Combatant runtime state, xp_reward
- [[enemy-ai-dispatch]] — the enemy turn's action resolution
- [[battle-context-and-world-triggers]] — how battles are entered and exited
- [[progression-and-party]] — `PartyManager.award_xp`
