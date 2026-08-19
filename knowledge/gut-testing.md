---
summary: GUT test framework pitfalls and isolation — wait_for_signal typed Signal API, autoload state leaks, SceneManager change_scene leaked coroutine flake, BaseRoomTest shared fixture, TileMapLayer TileSet requirement, GDScript mock nodes, TDD red states, suite baseline history
tags: [testing, gut, godot, gdscript, flake, fixtures]
---

# GUT Testing

Test-infrastructure knowledge for the GUT 9.x suite (`tests/`).

## GUT API & Test Isolation

- GUT 9.x `wait_for_signal(sig: Signal, max_time, msg='')` takes a typed Signal: `await wait_for_signal(_scene.player_turn_ended, 2.0)` — the `(obj, "name", timeout)` form is a parse error (that's the deprecated `yield_to`). Works even when the signal fired synchronously before the call
- Autoload singletons persist across all tests in a session — restore state in `after_each()` (e.g. `DirAccess.remove_absolute("user://debug.cfg")` for DebugOverlay's ConfigFile)
- `var enemies: Array[Combatant]` cannot be assigned an untyped literal `= [c]` (runtime "Invalid assignment"); use `.clear()` + `.append()`
- `CollisionShape2D.new()` has `name == ""` — set `col_shape.name = "CollisionShape2D"` before `add_child()` for `$CollisionShape2D` to resolve
- Manually calling `_ready()` on a node already in the tree double-connects signals — guard with `if not signal_name.is_connected(callable):`
- When a shape node has no shape, `shape_node.shape as RectangleShape2D` returns null — assign `RectangleShape2D.new()` before casting
- `TileMapLayer.local_to_map()` requires a TileSet — bare `TileMapLayer.new()` errors in GUT. Fix: `var ts := TileSet.new(); ts.tile_size = Vector2i(16, 16); layer.tile_set = ts` (a committed move additionally needs a real floor tile — see [[battle-context-and-world-triggers]] Player.stepped test gotcha)
- Mock nodes with custom methods in GUT: `var s := GDScript.new(); s.source_code = "extends Node\nfunc m() -> void:\n\tpass\n"; s.reload(); mock.set_script(s)`
- TDD note: a test referencing a not-yet-defined method/class surfaces as a GUT "Parse error / does not extend GutTest / Nothing was run" (not a normal assert failure) — that IS the expected red state. A missing `class_name` gives the same face via the stale registry: see [[scene-and-resource-serialization]]

## SceneManager leaked-coroutine flake (fixed in #128)

A GUT full-suite run intermittently failed an unrelated test (e.g. `test_unblocks_cell_on_exit`)
with "Resource file not found: res://" from `scene_manager.gd` — but that test passed in isolation.

- **Cause:** a unit test calls `SceneManager.change_scene(path)` (which `await`s a fade tween before `get_tree().change_scene_to_file(path)`); the coroutine outlives the test and resumes during a later test's `await`, where GUT attributes the engine error to whichever test is running. Adding new test files perturbs frame timing enough to surface it. It is NOT caused by the code under test
- **Fix (shipped in #128):** `SceneManager.change_scene` early-returns on an empty path (`if path.is_empty(): push_warning(...); return`) — changing to an empty scene is always a bug, and the guard stops the leaked coroutine from erroring. Suite went green 10/10 runs after
- **How to diagnose this class:** run the suspect file alone (passes) vs. the full suite (flakes); the backtrace shows the call resuming past an `await` with no caller frame. The real fix is test isolation (await/stub async singletons), but guarding invalid inputs is a cheap robust mitigation
- Same flake class: the CutsceneZone disconnect-before-dismiss cleanup order ([[dialogue-and-cutscenes]]) and the debug-driver `get_processed_tweens()` kill ([[save-system]]) both exist to prevent leaked async work from swapping the runner scene mid-suite

## BaseRoomTest shared fixture (issue #93, Task 9, 2026-07-26)

- `tests/fixtures/base_room_test.gd` — `class_name BaseRoomTest extends GutTest`, holds the single copy of `_install_base_room()`/`_teardown_base_room()` + `_room`/`_prev_scene` vars (previously byte-identical in 3 files, inline a 4th). Test files needing a BaseRoom current-scene now do `extends BaseRoomTest` instead of `extends GutTest` — zero call-site changes needed. (The helpers exist because of the `SaveManager.save()` BaseRoom guard — see [[save-system]])
- Filename does NOT start with `test_` (GUT's suite-collection prefix) — `tests/fixtures/*.gd` is the established location for non-suite test support scripts (also holds `.tres` fixtures already)
- Confirms the stale-class-registry rule applies to test-only `class_name` scripts too, not just production code: first full-suite run after adding `BaseRoomTest` failed ALL FOUR converted files with `Parse Error: Could not find base class "BaseRoomTest"` (silently dropping them — script count fell 49→45, test count 548→510, suite still reported "All tests passed!" since the 4 broken files were just skipped, not failed) until `godot_console --headless --import`
- Converted files (`test_save_manager.gd`, `test_party_save.gd`, `test_player_position_save.gd`, `test_debug_overlay.gd`) still legitimately reference the inherited `_prev_scene` in test bodies that swap `current_scene` mid-test (e.g. to a plain `Node2D` to test the BaseRoom guard) — that's correct *usage* of the inherited var, not a forbidden duplicate declaration; only `var _prev_scene =` / `func _install_base_room` count as violations when grepping for leftover copies

## Suite baseline history

- Baseline is fully green; do not expect any failures. (Re-verified 2026-06-15 on feat/issue-141: 508 tests, 508 pass. Earlier: master 412; feat/issue-122 448; feat/issue-141 508 after Task 18 added 3 tests to the prior 505. Later counts: 540/540 then 548/548 during issue #93, 2026-07.)
- Benign at exit: "ObjectDB instances leaked" / "N resources still in use at exit" warnings are Godot headless shutdown noise, not test failures
- Always run the full GUT suite as a final gate even when every individual task's targeted tests were green — indirect callers in unrelated test files are what the per-task runs miss (see [[save-system]], issue #146/#147)

## Related

- [[scene-and-resource-serialization]] — the stale-registry pitfall's GUT symptoms
- [[dialogue-and-cutscenes]] — Yarn/dialogue test patterns and cleanup ordering
- [[enemy-ai-dispatch]] — AI test seeding patterns
- [[development-environment]] — headless import/run commands, worktrees
