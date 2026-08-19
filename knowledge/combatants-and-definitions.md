---
summary: Combatant definition/runtime split — CombatantDefinition, CharacterDefinition, EnemyDefinition resources vs Combatant RefCounted runtime; from_definition factory, getter-only delegation, level and growth-aware stats, stat growth fields, xp_reward bounties, GameData.get_player_character_ids (issues #121, #141)
tags: [battle, godot, gdscript, architecture, progression]
---

# Combatants & Definitions

The static-data / runtime-state split at the heart of the battle system.

## Definition/Runtime Split (issue #121)

- `CombatantDefinition` (`scripts/battle/combatant_definition.gd`) extends `Resource`; holds all static fields: `id`, `character_name`, `is_player_controlled`, the stat ints, `sigil_type: SigilType` (enum `{ NONE, BUREAU, JAILBROKEN }` inside the class), `sprite_path`, `sprite_vframes`
- `CharacterDefinition` adds `@export var ability: Ability`; `EnemyDefinition` adds `@export var ai: EnemyAI` (both in `scripts/battle/`). Both satisfy `d is CombatantDefinition` (`is` checks the inheritance chain)
- `Combatant` extends `RefCounted` (NOT `Resource`); holds `var def: CombatantDefinition` and delegates definition fields via **getter-only** computed properties — direct assignment (`c.character_name = "X"`) is a parse error
- Factory: `Combatant.from_definition(d) -> Combatant` — sets `def`, initialises `current_hp`/`current_pp` from max
- `reset_runtime_state()` reads from `def` — never call on a bare `Combatant.new()`
- `.tres` files use `CharacterDefinition`/`EnemyDefinition` as script class — `load("res://characters/reid.tres")` returns a definition, NOT a Combatant. Always `Combatant.from_definition(GameData.get_definition(id))`; no `.duplicate()` needed because `from_definition` creates fresh runtime state
- Test helper pattern: `_make_combatant()` creates a `CombatantDefinition.new()`, sets fields, then `from_definition()`. Tests needing `ability` must use `CharacterDefinition` (the only subclass exposing it)
- Safe optional-subclass-field delegation: `var ability: Ability: get: return (def as CharacterDefinition).ability if def is CharacterDefinition else null`
- All sprite data lives in definitions: `_setup_sprites()` and `add_enemy()` read `member.sprite_path` / `sprite_vframes` directly (no dict lookups, no fallback textures)

## CharacterDefinition Growth Fields (issue #141, Task 2, 2026-06-15)

- `CharacterDefinition` (`scripts/battle/character_definition.gd`) has seven `@export var <stat>_growth: int = 0` fields: `hp_growth`, `pp_growth`, `str_growth`, `def_growth`, `psy_growth`, `res_growth`, `spd_growth`. Default 0 = level-1 behavior unchanged. Pairs with `Progression.grown_stat(base, growth, level)` (base = level-1 .tres value) — see [[progression-and-party]]
- Adding `@export` props to an EXISTING `class_name` triggers the stale-registry pitfall (see [[scene-and-resource-serialization]]): first GUT run failed with `Invalid access to property or key 'hp_growth'` until `godot_console --headless --import` ran (saw "update_scripts_classes | CharacterDefinition"). Reimport after editing a `class_name` script's exported surface, not just after adding a new class

## Combatant level + growth-aware stats (issue #141, Task 3, 2026-06-15)

- `Combatant.level: int = 1` runtime var (in the runtime-state block). `_char_def() -> CharacterDefinition` returns `def as CharacterDefinition` (null for enemies — `EnemyDefinition` is NOT a CharacterDefinition, so the `as` cast yields null, leaving enemies on base stats)
- The seven stat getters (`max_hp/max_pp/str/def/psy/res/spd`) compute `Progression.grown_stat(def.<stat>, cd.<stat>_growth, level) if cd else def.<stat>`. Level 1 → base (growth*0), so existing fixtures unchanged
- `set_level(new_level)` sets level then full-heals current_hp/current_pp to the new grown max; `reset_runtime_state()` seeds current_hp/current_pp from the `max_hp`/`max_pp` getters (was `def.max_hp`). `from_definition` still uses `d.max_hp` directly — fine since fresh combatants are level 1
- Stale-registry pitfall struck again: changing the getter surface of `class_name Combatant` made GUT report `Invalid access to property 'level'`-style errors until `godot_console --headless --import` (saw "update_scripts_classes | Combatant"). Reimport after editing any `class_name` script before running GUT

## EnemyDefinition.xp_reward + bounties (issue #141, Task 4, 2026-06-15)

- `EnemyDefinition` has `@export var xp_reward: int = 0` (after `ai`/`summon`). `Combatant.xp_reward` getter mirrors the `summon` pattern: `(def as EnemyDefinition).xp_reward if def is EnemyDefinition else 0` — players/CharacterDefinition return 0
- Enemy `.tres` bounties: shade 18, private_security_guard 22, territory_enforcer 60, block_captain 45, security_captain 50, security_rookie 22 (Task 18, new weak harness trash: HP65/STR38/DEF12/SPD20, basic enemy_ai.gd, reuses guard sprite, load_steps=3 mirrors private_security_guard.tres). Added as one scalar line in `[resource]` after the last property (`ai`/`summon`); `load_steps` unchanged (no new sub_resource)
- Stale-registry pitfall confirmed again: GUT showed `Invalid access to property 'xp_reward'` until `godot_console --headless --import` registered EnemyDefinition/Combatant. Always reimport after editing a `class_name` script's exported surface

## Character .tres growth values (issue #141, Task 7, 2026-06-15)

- The four player `.tres` (reid/iris/karim/margot) carry the seven `<stat>_growth` scalar lines appended inside `[resource]` after `ability = SubResource(...)`. Reid hp_growth=35/str_growth=5; Iris hp_growth=28/psy_growth=5. Pure data edit (no new sub_resource, load_steps unchanged) → NO reimport needed; tests passed on the first post-edit GUT run

## GameData.get_player_character_ids (issue #141, Task 5, 2026-06-15)

- `GameData` (`scripts/autoload/game_data.gd`) is a PLAIN autoload `Node` (no `class_name`) — adding a method here does NOT hit the stale-class-registry pitfall (no reimport needed for the method to resolve)
- `get_player_character_ids() -> Array[String]` iterates `_registry` and filters `is CharacterDefinition` (excludes EnemyDefinition). Companion to `get_definition(id)`
- TDD note: a test referencing a not-yet-defined method surfaces as a GUT "Parse error / does not extend GutTest / Nothing was run" (not a normal assert failure) — that IS the expected red state. See [[gut-testing]]

## Related

- [[ability-effect-system]] — effects held on `Ability`, damage/heal math against combatant stats
- [[progression-and-party]] — Progression math, PartyManager progression store
- [[enemy-ai-dispatch]] — `EnemyDefinition.ai`, `Combatant.ai_state`
- [[battle-scene-state-machine]] — where combatants act
- [[save-system]] — roster/progression persistence
