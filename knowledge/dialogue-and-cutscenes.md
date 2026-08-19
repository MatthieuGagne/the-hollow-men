---
summary: Dialogue, cutscenes and YarnSpinner — CutsceneZone patterns (flag gating, pre_battle_guests, fire_on_scene_load, run_node crash gotcha), NPC hide_when_flag, player input blocking, YarnSpinner C# bridge (YarnCommand, GameStateVariableStorage NormalizeKey), ExamineObject narration + sprite_texture (issues #87, #93)
tags: [dialogue, yarnspinner, cutscene, npc, godot, gdscript, csharp]
---

# Dialogue & Cutscenes

## CutsceneZone Patterns

- Guard `DialogueManager.run_node("")` — empty string throws a C# YarnSpinner exception and GUT marks the test FAILED even if assertions pass. Always `if dialogue_node == "": return`
- `set_deferred("monitoring", false)` defers the physics change; observe with `await get_tree().process_frame`
- `CONNECT_ONE_SHOT` is a Godot 4 global constant; `_on_dialogue_closed()` wired one-shot during `_on_body_entered()`
- Flag gating (issue #87): `required_flag`/`forbidden_flag` `@export` strings read from node meta in `_ready()` via `get_meta("required_flag", required_flag)` so TMX properties can set them (see [[scene-and-resource-serialization]] for YATI/TMX). Guard order: `_fired` → `is Player` → required → forbidden; set `_fired = true` only after all pass
- `pre_battle_guests` is a comma-separated string of **combatant ids**: each `strip_edges()`-ed, resolved via `Combatant.from_definition(GameData.get_definition(id))`, then `PartyManager.add_temporary(c)`. `_on_dialogue_closed()` order: add guests → `BattleContext.configure(pre_battle_enemies, "", battle_return_scene, battle_return_spawn_point)` → change scene (the `""` is background_id — no override export). See [[battle-context-and-world-triggers]]
- `fire_on_scene_load` auto-flag: `_fire()` writes persistent flag `"zone_played_" + dialogue_node` before `set_deferred`/`run_node` so it persists even if Yarn throws; guard checked after flag guards, before `_fired = true`. Test reload-guard by pre-setting the flag and asserting `_fire()` leaves `_fired == false`. Each such zone needs a hand-added [[save-system]] KnownFlags manifest entry
- **`run_node()` with an uncompiled dialogue_node crashes the test, not just logs an error (confirmed empirically, issue #93 Task 3):** `_fire()` calling `DialogueManager.run_node(id)` for an `id` not in any `dialogue/*.yarn` file throws `Yarn.DialogueException` deep in `YarnTask.Forget()` — GD.PushError-logged (non-fatal to the engine) but GUT's "Unexpected Errors" gate still marks the test FAILED even when all explicit asserts pass. Never `await` after such a call either — the thrown Task's continuation resumes on a later frame and can attribute the error to an unrelated subsequent test
- **Positive-path fix (issue #93 Task 3 review pass, 2026-07-25): use a compiled Yarn node instead of avoiding `run_node()` entirely.** `dialogue/vera_placeholder.yarn` (one line, body `...`) runs cleanly via `run_node("vera_placeholder")` — no exception, since the guard above only trips for genuinely uncompiled ids. This unblocks testing the actual positive path (`fire_on_scene_load=true` + `next_scene` set, no guard flag pre-set, fresh `_fire()`): assert `_fired`, the `zone_played_<node>` flag, AND `DialogueManager.dialogue_closed.is_connected(_zone._on_dialogue_closed)` — the last one proves the `next_scene` transition is wired and is what a stray-regression would break (confirmed non-vacuous by temporarily removing the `.connect(...)` call in `_fire()` and observing the test fail). Safety-critical cleanup at the end of such a test, in this order: `DialogueManager.dialogue_closed.disconnect(_zone._on_dialogue_closed)` (it's still connected — CONNECT_ONE_SHOT only disconnects when the signal actually fires) THEN `DialogueManager._dialogue_box.dismiss()`. Disconnect-before-dismiss is mandatory — dismiss emits `closed` → `dialogue_closed.emit()`, and if still wired that calls `_on_dialogue_closed()` → `SceneManager.change_scene(next_scene)`, a real scene change mid-suite (known flake source, see [[gut-testing]]). The reload/blocked-path tests (pre-set flag, assert `_fired` stays false) remain the right pattern for testing a NOT-YET-SHIPPED dialogue_node like `rooftop_surveillance` — the compiled-node trick only works once the real Yarn content lands
- Testing "combo didn't accidentally wire the transition": `DialogueManager.dialogue_closed.is_connected(zone._on_dialogue_closed)` after a blocked `_fire()` should be `false` — proves `next_scene`'s dialogue-close wiring never happens when the guard blocks (useful regression check when `next_scene` + `fire_on_scene_load` are combined)
- Tests: `before_each` clears `GameState._flags`, calls `PartyManager.remove_temporary_members()` and `BattleContext.configure()`; `after_each` clears flags again

## NPC hide_when_flag (issue #87)

- `@export var hide_when_flag := ""`, read from node meta in `_ready()`; if flag set → `queue_free()` + `return` (the return skips `CellRegistry.register_interactable`)
- `CellRegistry.unregister_interactable` uses `Dictionary.erase` (no-op on missing keys) — safe from `_exit_tree` even when registration was skipped
- Flag-state isolation: clear `GameState._flags` BEFORE creating the NPC under test (its `_ready()` reads flags)

## Player Input Blocking (confirmed 2026-06-07)

- Set `_input_blocked = true` ONLY in `_on_dialogue_opened()`, never pre-emptively in `_try_interact()` — if `interact()` does nothing (empty yarn node), `dialogue_opened` never fires and the player freezes permanently
- (Test-infrastructure companions to this work — TileMapLayer TileSet requirement, GDScript mock-node pattern — live in [[gut-testing]])

## YarnSpinner C# Bridge

- `[YarnCommand("name")]` on a method of a C# node that IS in the scene tree is the correct registration path (source generator auto-registers at startup). `runner.AddCommandHandler(...)` only works from a node alive in the tree
- The active `DialogueManager.tscn` wires the GDScript `scripts/ui/yarn_dialogue_bridge.gd` — the C# `YarnDialogueBridge.cs` is NOT instantiated by any scene, so code in its `_Ready()` is dead (its two CS8632 warnings are benign). Put `[YarnCommand]` methods on `GameStateVariableStorage` instead
- Unknown command at runtime → `GD.PushError` and dialogue STOPS: later lines/`<<set>>` never execute, the box never dismisses, `dialogue_closed` never emits
- `GameStateVariableStorage.NormalizeKey`: Yarn passes names with leading `$`; GameState stores without. ALL four VariableStorageBehaviour overrides (`TryGetValue`, `SetValue` ×3, `Contains`) must normalize — missing one causes a silent key mismatch between `<<set>>` and `<<if>>`

## ExamineObject.narration + sprite_texture (issue #93, Tasks 1 & 6b, 2026-07-24/26)

- `ExamineObject` (`scripts/world/examine_object.gd`) gained `@export var narration: bool = false`, read via `get_meta("narration", narration)` in `_ready()` (same pattern as `examine_text`/`sets_flag`). `interact()` branches: `narration` true → `DialogueManager.show_narration(examine_text)`, else `show_text(examine_text)`. Restructured trailing `if examine_text != "": ...` into an early `if examine_text == "": return` — behaviour-preserving (guarded by pre-existing `test_interact_with_no_examine_text_does_nothing`)
- `DialogueManager.show_narration`/`DialogueBox._is_narration` already existed pre-task — no autoload changes needed. Test pattern for asserting italic mode: `DialogueManager._dialogue_box._is_narration` after `obj.interact(); DialogueManager.skip_or_dismiss()`
- `ExamineObject.tscn` was a bare `Node2D` with no `Sprite2D` — every examinable in the game was invisible until Task 6b added `@export var sprite_texture: String = ""`, meta-read the same way, and loaded it in `_ready()` via `get_node_or_null("Sprite2D")` (NOT bare `$Sprite2D`) — several pre-existing tests attach the script to a bare `Node2D.new()` with no `Sprite2D` child, and an unguarded lookup crashes them. `ExamineObject.tscn` now has a `Sprite2D` child (`centered = false`, no offset — matches `WorldObject.tscn`'s convention; NPC's `offset` is only for 16×24 character sprites). Do NOT make `ExamineObject` extend `WorldObject` — it deliberately doesn't block movement or register cells, so the two-line sprite-load idiom is duplicated, not shared, by design
- Plain autoload method / exported-property addition to a `class_name` script — did NOT need reimport for either sub-task (contrast the usual class_name pitfall); GUT picked up the new `@export` on the first post-edit run both times. Full suite: 540/540 after Task 1 (535+5), 548/548 after Task 6b (544+4)

## Related

- [[save-system]] — KnownFlags manifest, GameState flags, Yarn TYPE_FLOAT rule
- [[battle-context-and-world-triggers]] — CutsceneZone as BattleContext producer
- [[gut-testing]] — the leaked-coroutine flake this page's cleanup order guards against
- [[scene-and-resource-serialization]] — YATI/TMX meta-property plumbing
