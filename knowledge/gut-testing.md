---
summary: Project GUT suite knowledge — DebugOverlay autoload isolation, floor-tile requirement for committed-move tests, SceneManager change_scene leaked-coroutine flake incident (#128 fix), BaseRoomTest shared fixture, suite baseline history; generic GUT 9.x pitfalls (wait_for_signal, mock nodes, fixture gotchas) promoted to the shared wiki
tags: [testing, gut, godot, gdscript, flake, fixtures]
---

# GUT Testing

Test-infrastructure knowledge for the GUT 9.x suite (`tests/`).

## GUT API & Test Isolation

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-gut-testing.md

- Restore autoload state in `after_each()` — e.g. `DirAccess.remove_absolute("user://debug.cfg")` for DebugOverlay's ConfigFile
- A committed Player move needs a real floor tile in the test TileMapLayer, not just a TileSet (`_is_wall()` treats empty cells as walls) — see [[battle-context-and-world-triggers]] Player.stepped test gotcha

## SceneManager leaked-coroutine flake (fixed in #128)

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-gut-testing.md (the leaked-coroutine flake class and its diagnosis)

A GUT full-suite run intermittently failed an unrelated test (e.g. `test_unblocks_cell_on_exit`)
with "Resource file not found: res://" from `scene_manager.gd` — but that test passed in isolation.

- **Cause:** a unit test calls `SceneManager.change_scene(path)` (which `await`s a fade tween before `get_tree().change_scene_to_file(path)`); the coroutine outlives the test — the shared wiki's leaked-coroutine flake class
- **Fix (shipped in #128):** `SceneManager.change_scene` early-returns on an empty path (`if path.is_empty(): push_warning(...); return`) — changing to an empty scene is always a bug, and the guard stops the leaked coroutine from erroring. Suite went green 10/10 runs after
- Same flake class: the CutsceneZone disconnect-before-dismiss cleanup order ([[dialogue-and-cutscenes]]) and the debug-driver `get_processed_tweens()` kill ([[save-system]]) both exist to prevent leaked async work from swapping the runner scene mid-suite
- **`pending_spawn_point` is not cleared by tween-kill.** `SceneManager.change_scene(path, spawn)` sets `pending_spawn_point` synchronously before the fade `await`, so asserting right after a `change_scene` call is safe without awaiting — but `.kill()`ing the tweens (via `get_processed_tweens()`) does NOT reset it. A later test loading a different `BaseRoom`-based scene then fails `no SpawnPoint with spawn_id=...`. Always set `SceneManager.pending_spawn_point = ""` after the tween-kill in any test that exercised a `change_scene(path, spawn)` call (confirmed 2026-08-31, issue #94 task 1).

## BaseRoomTest shared fixture (issue #93, Task 9, 2026-07-26)

- `tests/fixtures/base_room_test.gd` — `class_name BaseRoomTest extends GutTest`, holds the single copy of `_install_base_room()`/`_teardown_base_room()` + `_room`/`_prev_scene` vars (previously byte-identical in 3 files, inline a 4th). Test files needing a BaseRoom current-scene now do `extends BaseRoomTest` instead of `extends GutTest` — zero call-site changes needed. (The helpers exist because of the `SaveManager.save()` BaseRoom guard — see [[save-system]])
- Filename does NOT start with `test_` (the GUT suite-collection prefix — see the shared wiki) — `tests/fixtures/*.gd` is the established location for non-suite test support scripts (also holds `.tres` fixtures already)
- Confirms the stale-class-registry rule applies to test-only `class_name` scripts too, not just production code: first full-suite run after adding `BaseRoomTest` failed ALL FOUR converted files with `Parse Error: Could not find base class "BaseRoomTest"` — hidden by GUT's silent parse-drop behavior (script count fell 49→45, test count 548→510, suite still reported "All tests passed!"; see the shared wiki) — until `godot_console --headless --import`
- Converted files (`test_save_manager.gd`, `test_party_save.gd`, `test_player_position_save.gd`, `test_debug_overlay.gd`) still legitimately reference the inherited `_prev_scene` in test bodies that swap `current_scene` mid-test (e.g. to a plain `Node2D` to test the BaseRoom guard) — that's correct *usage* of the inherited var, not a forbidden duplicate declaration; only `var _prev_scene =` / `func _install_base_room` count as violations when grepping for leftover copies

## Suite baseline history

> Engine-generic rules promoted to the shared wiki: C:\Code\knowledge\godot-gut-testing.md (headless shutdown "ObjectDB instances leaked" noise)

- Baseline is fully green; do not expect any failures. (Re-verified 2026-06-15 on feat/issue-141: 508 tests, 508 pass. Earlier: master 412; feat/issue-122 448; feat/issue-141 508 after Task 18 added 3 tests to the prior 505. Later counts: 540/540 then 548/548 during issue #93, 2026-07.)
- Always run the full GUT suite as a final gate even when every individual task's targeted tests were green — indirect callers in unrelated test files are what the per-task runs miss (see [[save-system]], issue #146/#147)
- Headless shutdown noise is not always your bug — before flagging `ERROR: N resources still in use at exit` as a regression from your edit, reproduce it against the pre-change tree with `git stash` / `git stash pop` around the same `--quit-after` command (confirmed 2026-09-01, issue #94 tasks 8–9: `FourWindsBar.tscn` printed it with and without the TMX changes)

## Related

- [[scene-and-resource-serialization]] — project serialization warts; the stale-registry rule now lives in the shared wiki
- [[dialogue-and-cutscenes]] — Yarn/dialogue test patterns and cleanup ordering
- [[enemy-ai-dispatch]] — AI test seeding patterns
- [[development-environment]] — headless import/run commands, worktrees
