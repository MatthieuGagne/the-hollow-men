# Index

Catalog of all wiki pages. Every page appears under exactly one category.

## Battle System

- [[combatants-and-definitions]] — CombatantDefinition/Combatant definition-runtime split, growth fields, level-aware stats, xp_reward
- [[ability-effect-system]] — AbilityEffect/DamageEffect/HealEffect/ApplyStatusEffect/SummonEffect, StatusEffect math, issue #125 design decisions
- [[battle-scene-state-machine]] — BattleState, targeting (target_mode, AoE, _target_all), enemy selection UI, victory XP, issue #128 design decisions
- [[enemy-ai-dispatch]] — EnemyAI resolve_action interface, ai_state, the three AI subclasses

## World & Encounters

- [[battle-context-and-world-triggers]] — BattleContext handoff, Player.stepped, RandomEncounterController, BossTrigger, TestRoom
- [[dialogue-and-cutscenes]] — CutsceneZone, NPC hide_when_flag, input blocking, YarnSpinner C# bridge, ExamineObject

## Persistence & Progression

- [[save-system]] — SaveData versions, SaveManager, KnownFlags, runtime snapshot, position/facing restore, debug save driver
- [[progression-and-party]] — Progression XP math, PartyManager progression store, reset_to_new_game

## Godot Engine & Serialization

- [[scene-and-resource-serialization]] — .tscn/.tres gotchas, stale class registry, instanced-scene script override, YATI/TMX

## Testing & GUT

- [[gut-testing]] — GUT API pitfalls, isolation, leaked-coroutine flake, BaseRoomTest fixture, suite baseline history

## Development Environment

- [[development-environment]] — Windows worktree init, gitignored assets, git hygiene, DebugOverlay
