---
summary: Godot .tscn/.tres serialization and import gotchas — typed array literals, load_steps, sub_resource ordering, stale class registry (reimport after class_name changes), instanced-scene script override must be a property line not a header attribute, tmx uid staleness, YATI import cache and CollisionShape2D sizing
tags: [godot, tscn, tres, serialization, yati, tmx, import-cache, gotcha]
---

# Scene & Resource Serialization

`.tscn`/`.tres` text-format rules, the stale class-registry pitfall, and YATI/TMX import behavior.

## .tres Serialization Gotchas

- Typed array literals must use the EXACT declared type: `effects = Array[AbilityEffect]([SubResource("dmg_reid")])` — `Array[Resource]` can silently load as empty under strict coercion / stale class registry
- `load_steps = ext_resources + sub_resources + 1` (root)
- Forward-reference rule: a `[sub_resource]` referencing another via `SubResource("id")` must appear AFTER the referenced block (e.g. `heal_karim` before `ability_karim`)
- Embedding an EnemyAI: `[sub_resource type="Resource" id="ai_X"]` with `script = ExtResource("N_enemy_ai")`, then `ai = SubResource("ai_X")` on `[resource]` — see [[enemy-ai-dispatch]]

## Stale class registry / import cache (recurring pitfall)

- **Stale import cache:** after adding new `class_name` scripts, `.tres` files referencing them may load with EMPTY typed arrays at GUT runtime until a headless reimport. Always reimport (`godot_console --headless --import`) after adding `class_name` files, before running the full suite — look for "update_scripts_classes | ClassName" in the log to confirm registration. Do not interpret empty typed arrays as bugs until the cache is fresh
- The rule, refined across issues #141/#93/#123 (each observation preserved in the topic pages):
  - New `class_name` script → GUT parse error `Identifier "X" not declared` until reimport (Progression, RandomEncounterController, BossTrigger, TestRoom, BaseRoomTest — the last proving it applies to test-only `class_name` scripts too, see [[gut-testing]])
  - Editing an existing `class_name`'s **exported-property / method / getter / static-func surface** → `Invalid access to property or key 'x'` / "Static function not found" until reimport (CharacterDefinition growth fields, Combatant level getters, EnemyDefinition.xp_reward, BattleScene.build_victory_text, SaveData)
  - Editing only a `const MANIFEST` dictionary body of a `class_name` → NO reimport needed (confirmed twice: KnownFlags #141 Task 12, #93 Task 2)
  - Plain autoload Node methods (no `class_name`: GameData, PartyManager, SaveManager, DialogueManager) → NO reimport needed
  - Script-to-script `class_name` references defined and referenced in the same PR (PartyMemberSave ← SaveData typed array export) → worked immediately, no reimport; the pitfall is about scene/resource FILES referencing a just-added class_name
  - Adding a `signal` to a `class_name` → did not require reimport in the one observed case (Player.stepped, #141 Task 11)
  - Pure `.tres` data edits (no new sub_resource) → no reimport (character growth values, #141 Task 7)

## Instanced-scene script override (bug found in #141)

A script override on the **root node of an instanced inherited scene** in a `.tscn` MUST be
written as a **property line** below the node header:

```
[node name="RoomPOC" instance=ExtResource("1_baseroom")]
script = ExtResource("5_room_poc")
world_layer_path = ...
```

If instead it is written as a **header attribute** on the `[node ...]` line, it is **silently
ignored** — the instantiated root keeps the BASE scene's script and the override's `_ready`
never runs:

```
[node name="RoomPOC" instance=ExtResource("1_baseroom") script=ExtResource("5_room_poc")]   # BROKEN
```

(Every working script attachment in this project — Player, BossTrigger, FlickeringLight — uses
the property-line form. `script` is a node PROPERTY, not a header key.)

- **How to confirm:** instantiate the scene and check `root.get_script().resource_path`. Broken = the base script (e.g. `base_room.gd`); fixed = the override (e.g. `room_poc.gd`)
- **Symptoms seen (#141):** TestRoom's win counter never incremented (boss never unlocked) and RoomPOC never seeded its full party — both because the override `_ready` never ran
- **Fixes used:** RoomPOC (`fix/roompoc-script-override`) corrected the override to a property line — the root now binds `room_poc.gd`. TestRoom moved the bookkeeping into a child node's `_ready` (`RandomEncounterController`), which always runs — also a valid fix when you don't need the root itself to carry the script (see [[battle-context-and-world-triggers]])
- **Prevention (committed):** `tests/test_room_script_overrides.gd` — a lint test that scans `res://scenes/**/*.tscn` and fails if any `[node ...]` header line contains `script=ExtResource`, plus an assertion that RoomPOC's root carries `room_poc.gd`

### Attaching a script to an instanced scene root (the correct general pattern)

- In `.tscn`: `[node name="X" instance=ExtResource("1_base")]` followed by the `script = ExtResource("5_script")` property line; the ext_resource needs `type="Script"`; UIDs optional. Extend by `class_name` (`extends BaseRoom`), not by path
- (Historical note: an earlier memory recorded the header-attribute form `[node ... script=ExtResource(...)]` as the pattern — that form is exactly the silently-ignored one above. The property-line form is the only correct one.)

### Related wart: stale .tmx UIDs

Referencing an imported `.tmx` by a hardcoded `uid=` in a `.tscn` is fragile — `.tmx.import`
is gitignored and its UID regenerates per clone, so the declared UID goes stale and Godot
warns ("invalid UID ... using text path instead"). Reference maps by **path only** (no `uid=`).

## YATI / TMX Gotchas

- YATI generates the runtime scene into `.godot/imported/<map>.tmx-<hash>.tscn` — TMX object nodes (SpawnPoint, NPC, CutsceneZone...) live there, NOT in the hand-authored room `.tscn` (which references the TMX via `instance=ExtResource`). Verify new TMX objects by reading the import-cache TSCN
- YATI sets an imported Area2D's `position` from the TMX object but does NOT resize the instanced scene's CollisionShape2D to the object's width/height — a 224×128 authored region imports as the scene's stock 16×16 shape at the top-left corner. Fix: read object size into an export/meta and resize the shape in `_ready()`. Verify coverage in the import-cache TSCN, not the TMX
- Use PowerShell `Remove-Item` with wildcards for stale cache deletion (bash `del` doesn't expand globs on Windows paths) — see [[development-environment]]
- Alphabetical ordering of `<property>` elements in a TMX `<properties>` block is the Tiled convention

## Related

- [[ability-effect-system]] — the effect resources these rules serialize
- [[gut-testing]] — how stale-registry failures present in GUT runs
- [[battle-context-and-world-triggers]] — TestRoom.tscn assembly using these rules
- [[dialogue-and-cutscenes]] — TMX meta-properties feeding CutsceneZone/NPC exports
