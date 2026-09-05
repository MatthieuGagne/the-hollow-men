---
summary: Project serialization notes — embedding an EnemyAI sub_resource in enemy .tres, the #141 script-override incident (symptoms, fixes, lint test), Windows stale-cache deletion; generic .tres/.tscn format rules, the stale class registry, and YATI/TMX importer behavior promoted to the shared wiki
tags: [godot, tscn, tres, serialization, yati, tmx, import-cache, gotcha]
---

# Scene & Resource Serialization

Project-side `.tscn`/`.tres` notes. The engine-generic rules that used to live here moved to
the shared wiki (see the pointers per section).

## .tres Serialization Gotchas

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-serialization-gotchas.md

- Embedding an EnemyAI: `[sub_resource type="Resource" id="ai_X"]` with `script = ExtResource("N_enemy_ai")`, then `ai = SubResource("ai_X")` on `[resource]` — see [[enemy-ai-dispatch]]

## Stale class registry / import cache (recurring pitfall)

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-stale-class-registry.md

- The project observations backing each rule are preserved in the topic pages: [[combatants-and-definitions]] (CharacterDefinition growth fields, Combatant getters, EnemyDefinition.xp_reward), [[battle-context-and-world-triggers]] (RandomEncounterController, BossTrigger, TestRoom, Player.stepped signal), [[progression-and-party]] (Progression), [[save-system]] (SaveData, KnownFlags MANIFEST, PartyMemberSave), [[battle-scene-state-machine]] (build_victory_text), [[gut-testing]] (BaseRoomTest)
- **`@export` on a `class_name` is a registry-surface change** — headless `--import` must run before the next GUT run or the new property is invisible to tests (`Invalid access to property or key`). Confirmed 2026-08-31 (`CutsceneZone.next_spawn_point`).

## Instanced-scene script override (bug found in #141)

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-serialization-gotchas.md (the property-line-vs-header-attribute rule, how to confirm, the correct general pattern, and the historical wrong-memory note)

- **Symptoms seen (#141):** TestRoom's win counter never incremented (boss never unlocked) and RoomPOC never seeded its full party — both because the header-attribute override was silently ignored, so the override `_ready` never ran
- **Fixes used:** RoomPOC (`fix/roompoc-script-override`) corrected the override to a property line — the root now binds `room_poc.gd`. TestRoom moved the bookkeeping into a child node's `_ready` (`RandomEncounterController`), which always runs — also a valid fix when you don't need the root itself to carry the script (see [[battle-context-and-world-triggers]])
- **Prevention (committed):** `tests/test_room_script_overrides.gd` — a lint test that scans `res://scenes/**/*.tscn` and fails if any `[node ...]` header line contains `script=ExtResource`, plus an assertion that RoomPOC's root carries `room_poc.gd`
- Every working script attachment in this project — Player, BossTrigger, FlickeringLight — uses the property-line form

## YATI / TMX Gotchas

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-yati-tmx.md (import-cache scene location, CollisionShape2D sizing, stale `.tmx` UIDs, Tiled property ordering)

- **Editing a `.tmx` file directly** leaves YATI's cached `.tscn` under `.godot/imported/` stale — `load("res://maps/x.tmx")` in a test returns the OLD scene until `--headless --import` runs. Always reimport after every `.tmx` edit (both a temporary flip and its revert), or a "failing"/"passing" run may be testing stale data (confirmed 2026-09-01, issue #94 task 11).
- **Revert a temporary TMX edit with `git checkout -- <file>`**, not a `cp` backup dance (a `cp` revert silently failed to take effect once) — but only once the real fix is committed: if the fix is still uncommitted, `git checkout` reverts to the last commit and wipes it too. Commit the fix before flip-testing, or hand-edit the single line back (confirmed 2026-09-01, issue #94 final fix wave).
- Use PowerShell `Remove-Item` with wildcards for stale cache deletion (bash `del` doesn't expand globs on Windows paths) — see [[development-environment]]

## Related

- [[ability-effect-system]] — the effect resources these rules serialize
- [[gut-testing]] — how stale-registry failures present in GUT runs
- [[battle-context-and-world-triggers]] — TestRoom.tscn assembly using these rules
- [[dialogue-and-cutscenes]] — TMX meta-properties feeding CutsceneZone/NPC exports
