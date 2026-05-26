# Four Winds Bar — First Real Map + BaseRoom Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the Four Winds Bar as the game's first real navigable map and extract a shared BaseRoom architecture that all future rooms will inherit — replacing the ad-hoc RoomPOC structure.

**Architecture:** `BaseRoom.tscn` owns Player, Camera2D, CanvasModulate, and an empty UILayer. `BaseRoom.gd` sets camera limits from the world layer, resolves the spawn point from `SceneManager.pending_spawn_point`, connects `DialogueManager` signals to Player, and plays music. `DialogueManager` is extracted into a persistent `.tscn` autoload that holds DialogueRunner, YarnDialogueBridge, and DialogueBox — plus a C# `GameStateVariableStorage` node that bridges Yarn variables to `GameState` flags in real time.

**Tech Stack:** Godot 4.6 / GDScript / C# (YarnSpinner-Godot); Tiled (`.tmx` maps via YATI); GUT tests; `VariableStorageBehaviour` from `addons/YarnSpinner-Godot/Runtime/VariableStorageBehaviour.cs`

---

## Execution Status (updated 2026-05-25)

| Batch | Status | Notes |
|-------|--------|-------|
| Batch 1 (Tasks 1–3) | ✅ Done | GameState, SceneManager spawn_point, CellRegistry auto-clear |
| Batch 2 (Tasks 4–5) | ✅ Done | Player.setup(), SpawnPoint scene |
| Batch 3 (Tasks 6–8) | ✅ Done | GameStateVariableStorage, DialogueManager autoload, interact() cleanup |
| Batch 4 Tasks 9–11 | ✅ Done | BaseRoom, ExitDoor, RoomPOC refactor |
| Smoketest 4 | ✅ Done | Confirmed by user |
| Batch 5 (Tasks 12–14) | ✅ Done | Four Winds Bar map + scene |
| Smoketest 5 | 🔄 In progress | Game running, awaiting user confirmation |

### Discovered during implementation

**`@export var node: NodeType` does NOT resolve across inherited scene boundaries.**
The plan specified `@export var world_layer: TileMapLayer` in `base_room.gd` and `world_layer = NodePath("room_poc/World")` in `RoomPOC.tscn`. Godot 4 does NOT auto-resolve the NodePath when the referenced node exists only in the child scene. Fix: use `@export_node_path("TileMapLayer") var world_layer_path: NodePath` and resolve manually with `get_node_or_null(world_layer_path)` in `_ready()`. **Update all future room scenes** to use `world_layer_path = NodePath(...)` not `world_layer = NodePath(...)`.

**Camera2D limits must not be set to 0 in BaseRoom.tscn.**
The agent wrote `limit_right = 0`, `limit_bottom = 0`. With all four limits at 0, the camera is pinned to world origin and cannot follow the player even when `_apply_camera_limits()` fires. Fix: omit the limit properties in the .tscn (they default to ±10,000,000 in Godot 4, which is correct for "unlimited").

**YATI bakes TMX object properties as node `metadata/<key>`, not as exported GDScript properties.**
For `type="instance"` objects, YATI sets e.g. `metadata/spawn_id = "default"` rather than the `@export var spawn_id`. Fix: read from metadata in `_ready()` when the export is empty — `if spawn_id == "" and has_meta("spawn_id"): spawn_id = get_meta("spawn_id")`. Apply this pattern to any future scene that reads TMX object properties as exported vars.

**`find_children("*", "SpawnPoint", true, false)` DOES work with GDScript `class_name`.**
A code reviewer claimed it wouldn't. It does — reverting the reviewer's suggested "fix" (changing the type arg to `""`) was the right call: passing `""` returns ALL descendants and causes a null-cast crash on non-SpawnPoint nodes.

**`player.gd` needs `Player.setup()` called by the room.**
After removing the `@onready` world-layer path in Task 4, a bridge call `$Player.setup($"room_poc/World")` was added to `room_poc.gd` for the Batch 2 smoketest. `room_poc.gd` was deleted in Task 11; `BaseRoom._ready()` now handles this via `$Player.setup(_world_layer)`.

---

## Batch 1 — Core state infrastructure

### Task 1: GameState autoload

**Files:**
- Create: `scripts/autoload/game_state.gd`
- Create: `tests/test_game_state.gd`

**Depends on:** none
**Parallelizable with:** Task 2, Task 3

**Step 1: Write the failing GUT test**

```gdscript
# tests/test_game_state.gd
extends GutTest

func before_each() -> void:
    GameState._flags.clear()

func test_set_and_get_flag() -> void:
    GameState.set_flag("met_holloway", true)
    assert_eq(GameState.get_flag("met_holloway"), true)

func test_get_flag_default() -> void:
    assert_eq(GameState.get_flag("missing", false), false)

func test_overwrite_flag() -> void:
    GameState.set_flag("x", 1.0)
    GameState.set_flag("x", 2.0)
    assert_eq(GameState.get_flag("x"), 2.0)

func test_has_flag() -> void:
    assert_false(GameState.has_flag("absent"))
    GameState.set_flag("present", true)
    assert_true(GameState.has_flag("present"))
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_state.gd
```
Expected: FAIL (GameState autoload not registered)

**Step 3: Write minimal implementation**

```gdscript
# scripts/autoload/game_state.gd
extends Node

var _flags: Dictionary = {}


func set_flag(key: String, value: Variant) -> void:
    assert(
        value is bool or value is float or value is int or value is String,
        "GameState.set_flag: value must be bool, float, int, or String — got type %d" % typeof(value)
    )
    _flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
    return _flags.get(key, default)


func has_flag(key: String) -> bool:
    return _flags.has(key)
```

Then register it in `project.godot` under `[autoload]`:

```
GameState="*res://scripts/autoload/game_state.gd"
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_game_state.gd
```
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does this generalize — or did I assume flags are always strings?" Values are Variant; bools and floats are both valid. The assert gates bad types at runtime. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/game_state.gd tests/test_game_state.gd project.godot
git commit -m "feat: add GameState autoload (flat flag store)"
```

---

### Task 2: SceneManager spawn_point parameter

**Files:**
- Modify: `scripts/autoload/scene_manager.gd`
- Modify: `tests/test_scene_manager.gd`

**Depends on:** none
**Parallelizable with:** Task 1, Task 3

**Step 1: Write the failing GUT test**

Add to `tests/test_scene_manager.gd`:

```gdscript
func test_change_scene_stores_spawn_point() -> void:
    # Can't call change_scene (it transitions scene tree), so test the
    # pending_spawn_point field directly.
    SceneManager.pending_spawn_point = ""
    SceneManager.pending_spawn_point = "four_winds_entrance"
    assert_eq(SceneManager.pending_spawn_point, "four_winds_entrance")

func test_pending_spawn_point_defaults_empty() -> void:
    SceneManager.pending_spawn_point = ""
    assert_eq(SceneManager.pending_spawn_point, "")
```

Run to verify fails (field doesn't exist yet).

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_scene_manager.gd
```
Expected: FAIL

**Step 3: Write minimal implementation**

Add to `scripts/autoload/scene_manager.gd`:
- Add `var pending_spawn_point: String = ""` at the top of the class.
- Change `change_scene(path: String)` signature to `change_scene(path: String, spawn_point: String = "")`.
- As the first line inside `change_scene`, add: `pending_spawn_point = spawn_point`.

The full updated function:

```gdscript
var pending_spawn_point: String = ""


func change_scene(path: String, spawn_point: String = "") -> void:
    pending_spawn_point = spawn_point
    pre_scene_change.emit()
    var tween := create_tween()
    tween.tween_property(_overlay, "modulate:a", 1.0, FADE_DURATION)
    await tween.finished
    get_tree().change_scene_to_file(path)
    await get_tree().process_frame
    tween = create_tween()
    tween.tween_property(_overlay, "modulate:a", 0.0, FADE_DURATION)
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_scene_manager.gd
```
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "`pending_spawn_point` is set before `pre_scene_change` is emitted — does that ordering matter?" Yes: CellRegistry clears on pre_scene_change, which should happen after spawn_point is stored. Order is correct. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/scene_manager.gd tests/test_scene_manager.gd
git commit -m "feat: SceneManager.change_scene gains optional spawn_point param"
```

---

### Task 3: CellRegistry auto-clear on scene change

**Files:**
- Modify: `scripts/autoload/cell_registry.gd`
- Modify: `tests/test_cell_registry.gd`

**Depends on:** none
**Parallelizable with:** Task 1, Task 2

**Step 1: Write the failing GUT test**

Add to `tests/test_cell_registry.gd`:

```gdscript
func test_clears_on_pre_scene_change() -> void:
    CellRegistry.register_blocking(Vector2i(1, 1), Node.new())
    assert_true(CellRegistry.is_blocked(Vector2i(1, 1)))
    SceneManager.pre_scene_change.emit()
    assert_false(CellRegistry.is_blocked(Vector2i(1, 1)))
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cell_registry.gd
```
Expected: FAIL (CellRegistry does not clear on signal)

**Step 3: Write minimal implementation**

Add `_ready()` to `scripts/autoload/cell_registry.gd`:

```gdscript
func _ready() -> void:
    SceneManager.pre_scene_change.connect(clear)
```

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_cell_registry.gd
```
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does `clear()` also clear interactables?" Yes — `clear()` clears both `_blocking` and `_interactables`. Correct. Proceed.

**Step 6: Commit**

```bash
git add scripts/autoload/cell_registry.gd tests/test_cell_registry.gd
git commit -m "feat: CellRegistry auto-clears stale data on pre_scene_change"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 1, Task 2, Task 3 | All modify different files, no shared state |

### Smoketest Checkpoint 1 — core state compiles and tests pass

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```bash
DISPLAY=:0 godot
```
Expected: RoomPOC loads normally, player can move, Iris dialogue triggers. No visible change yet.

**Step 4: Confirm with user**
Tell the user: "GameState, SceneManager spawn_point, and CellRegistry auto-clear are wired. Game should behave identically to before. Confirm it loads and Iris dialogue works, then I'll continue."

---

## Batch 2 — Player world-layer decoupling + SpawnPoint

### Task 4: player.gd — add setup(layer), remove hardcoded world layer path

**Files:**
- Modify: `scripts/world/player.gd`
- Modify: `tests/test_player.gd`

**Depends on:** none
**Parallelizable with:** Task 5

**Step 1: Write the failing GUT test**

Add to `tests/test_player.gd`:

```gdscript
func test_setup_assigns_world_layer() -> void:
    var player := Player.new()
    add_child(player)
    var mock_layer := TileMapLayer.new()
    player.setup(mock_layer)
    assert_eq(player._world_layer, mock_layer)
    player.free()
    mock_layer.free()
```

**Step 2: Run test to verify it fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd
```
Expected: FAIL (setup() doesn't exist)

**Step 3: Write minimal implementation**

In `scripts/world/player.gd`:

1. Remove: `@onready var _world_layer: TileMapLayer = $"../room_poc/World"`
2. Add field declaration: `var _world_layer: TileMapLayer`
3. Add `setup()` method:
```gdscript
func setup(layer: TileMapLayer) -> void:
    _world_layer = layer
```

**Leave untouched for now:** `_dialogue_box`, `_yarn_bridge`, `interactable.interact(_dialogue_box, _yarn_bridge)`, and `_dialogue_box.skip_or_dismiss()`. Those are cleaned up in Task 8 once DialogueManager is registered.

**Step 4: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd
```
Expected: PASS

**Step 5: Refactor checkpoint**

Ask: "Does player.gd still reference any scene-specific paths?" It should have zero `@onready` with hardcoded node paths. Verify. Proceed.

**Step 6: Commit**

```bash
git add scripts/world/player.gd tests/test_player.gd
git commit -m "feat: player.gd — add setup(layer), remove hardcoded onready paths"
```

---

### Task 5: SpawnPoint scene + script

**Files:**
- Create: `scripts/world/spawn_point.gd`
- Create: `scenes/world/SpawnPoint.tscn`

**Depends on:** none
**Parallelizable with:** Task 4

**Step 1: Write the content**

`scripts/world/spawn_point.gd`:
```gdscript
@tool
class_name SpawnPoint
extends Node2D

@export var spawn_id: String = ""


func _ready() -> void:
    add_to_group("spawn_points")
```

`scenes/world/SpawnPoint.tscn`: Create in Godot editor as a Node2D with `spawn_point.gd` attached. Save. (No child nodes needed.)

**Step 2: Verify**

Open the scene in Godot editor. Confirm:
- Node type is Node2D
- Script is `spawn_point.gd`
- `spawn_id` export appears in the inspector

**Step 3: Commit**

```bash
git add scripts/world/spawn_point.gd scenes/world/SpawnPoint.tscn
git commit -m "feat: add SpawnPoint scene and script"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 2

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 4, Task 5 | Different output files, no shared state |

### Smoketest Checkpoint 2 — player decoupling + SpawnPoint

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 3: Launch game and verify visually**
```bash
DISPLAY=:0 godot
```
Expected: RoomPOC loads, player moves, Iris dialogue still works (UILayer refs unchanged).

**Step 4: Confirm with user**
Tell the user: "Player world-layer decoupling is in place and SpawnPoint scene is ready. Game should be identical to before. Confirm RoomPOC loads and dialogue works, then I'll continue."

---

## Batch 3 — Dialogue system

### Task 6: GameStateVariableStorage (C#)

**Files:**
- Create: `scripts/autoload/GameStateVariableStorage.cs`

**Depends on:** Task 1 (GameState must be registered as autoload)
**Parallelizable with:** Task 5 — but must run AFTER Task 1 completes

**Step 1: Write the content**

Reference: `addons/YarnSpinner-Godot/Runtime/VariableStorageBehaviour.cs` for the abstract base. The abstract methods to implement: `TryGetValue<T>`, `SetValue(string, bool)`, `SetValue(string, float)`, `SetValue(string, string)`, `Clear()`, `Contains()`, `SetAllVariables()`, `GetAllVariables()`.

```csharp
// scripts/autoload/GameStateVariableStorage.cs
#nullable disable
using Godot;
using YarnSpinnerGodot;

namespace TheHollowMen;

[GlobalClass]
public partial class GameStateVariableStorage : VariableStorageBehaviour
{
    private GodotObject GameState => Engine.GetSingleton("GameState");

    public override bool TryGetValue<T>(string variableName, out T result)
    {
        if (!Contains(variableName))
        {
            result = default;
            return false;
        }
        var raw = GameState.Call("get_flag", variableName, default(T));
        if (raw.Obj is T typed)
        {
            result = typed;
            return true;
        }
        GD.PushError($"GameStateVariableStorage: type mismatch for '{variableName}' — expected {typeof(T).Name}");
        result = default;
        return false;
    }

    public override void SetValue(string variableName, bool boolValue) =>
        GameState.Call("set_flag", variableName, boolValue);

    public override void SetValue(string variableName, float floatValue) =>
        GameState.Call("set_flag", variableName, floatValue);

    public override void SetValue(string variableName, string stringValue) =>
        GameState.Call("set_flag", variableName, stringValue);

    public override void Clear() { }

    public override bool Contains(string variableName) =>
        GameState.Call("has_flag", variableName).AsBool();

    public override void SetAllVariables(
        System.Collections.Generic.Dictionary<string, float> floats,
        System.Collections.Generic.Dictionary<string, string> strings,
        System.Collections.Generic.Dictionary<string, bool> bools,
        bool clear = true)
    {
        foreach (var kv in floats) SetValue(kv.Key, kv.Value);
        foreach (var kv in strings) SetValue(kv.Key, kv.Value);
        foreach (var kv in bools) SetValue(kv.Key, kv.Value);
    }

    public override (
        System.Collections.Generic.Dictionary<string, float>,
        System.Collections.Generic.Dictionary<string, string>,
        System.Collections.Generic.Dictionary<string, bool>) GetAllVariables()
    {
        return (new(), new(), new());
    }
}
```

**Step 2: Build C# to verify no compiler errors**

```bash
dotnet build
```
Expected: Build succeeded, 0 errors.

**Step 3: Commit**

```bash
git add scripts/autoload/GameStateVariableStorage.cs
git commit -m "feat: GameStateVariableStorage — live Yarn↔GameState variable bridge"
```

---

### Task 7: DialogueManager autoload (tscn + gd)

**Files:**
- Create: `scripts/autoload/dialogue_manager.gd`
- Create: `scenes/autoload/DialogueManager.tscn`

**Depends on:** Task 6 (GameStateVariableStorage must be compiled)
**Parallelizable with:** none (sequential after Task 6)

**Step 1: Write `dialogue_manager.gd`**

```gdscript
# scripts/autoload/dialogue_manager.gd
extends Node

signal dialogue_opened
signal dialogue_closed

@onready var _dialogue_box: DialogueBox = $CanvasLayer/DialogueBox
@onready var _yarn_bridge: Node = $CanvasLayer/YarnDialogueBridge


func _ready() -> void:
    _dialogue_box.opened.connect(func() -> void: dialogue_opened.emit())
    _dialogue_box.closed.connect(func() -> void: dialogue_closed.emit())


func run_node(yarn_node_id: String) -> void:
    _yarn_bridge.start_dialogue(yarn_node_id)


func show_text(text: String) -> void:
    _dialogue_box.show_text(text)


func skip_or_dismiss() -> void:
    _dialogue_box.skip_or_dismiss()
```

**Step 2: Build `DialogueManager.tscn` in the Godot editor**

Create `scenes/autoload/DialogueManager.tscn`:

```
DialogueManager (Node) ← dialogue_manager.gd
  CanvasLayer (layer = 10)
    DialogueBox  ← instance of scenes/ui/DialogueBox.tscn
    DialogueRunner (Control, script = addons/YarnSpinner-Godot/Runtime/DialogueRunner.cs)
      yarnProject = res://dialogue/iris.yarnproject
      dialoguePresenters = [NodePath("../YarnDialogueBridge")]
      variableStorage = NodePath("../GameStateVariableStorage")
    YarnDialogueBridge (Node) ← scripts/ui/yarn_dialogue_bridge.gd
    GameStateVariableStorage (GameStateVariableStorage C# node)
      runner = NodePath("../DialogueRunner")  [if the C# class needs it]
```

Note: Copy these nodes from `RoomPOC.tscn`'s UILayer — move them here rather than duplicating.

**Step 3: Register DialogueManager as autoload in `project.godot`**

Under `[autoload]`, add:
```
DialogueManager="*res://scenes/autoload/DialogueManager.tscn"
```

**Step 4: Remove UILayer dialogue nodes from `RoomPOC.tscn`**

In the Godot editor, open `scenes/world/RoomPOC.tscn`. Delete from UILayer:
- DialogueBox
- DialogueRunner
- YarnDialogueBridge

The UILayer node itself can remain (it will be replaced by BaseRoom's UILayer in Batch 4).

**Step 5: Verify build**

```bash
dotnet build && make import
```
Expected: No errors.

**Step 6: Commit**

```bash
git add scripts/autoload/dialogue_manager.gd scenes/autoload/DialogueManager.tscn project.godot scenes/world/RoomPOC.tscn
git commit -m "feat: extract DialogueManager as persistent autoload tscn"
```

---

### Task 8: Update all interactable interact() signatures

**Files:**
- Modify: `scripts/world/npc.gd`
- Modify: `scripts/world/examine_object.gd`
- Modify: `scripts/world/player.gd`
- Modify: `tests/test_npc.gd`

**Depends on:** Task 7 (DialogueManager must be registered as autoload)
**Parallelizable with:** none (sequential after Task 7)

**Step 1: Write failing GUT tests**

Update `tests/test_npc.gd` — add a test that verifies `interact()` takes no args:

```gdscript
func test_interact_calls_dialogue_manager() -> void:
    var npc := NPC.new()
    npc.yarn_node_id = "test_node"
    add_child(npc)
    # If DialogueManager.run_node is called without error, the method is wired correctly.
    # We verify by checking no exception is thrown (yarn_node_id is set).
    assert_true(npc.yarn_node_id != "")
    npc.free()
```

**Step 2: Run to verify (existing tests still pass structure)**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_npc.gd
```

**Step 3: Update npc.gd**

Change `interact()` signature and body:

```gdscript
func interact() -> void:
    if yarn_node_id == "":
        return
    DialogueManager.run_node(yarn_node_id)
```

**Step 4: Update examine_object.gd**

```gdscript
func interact() -> void:
    if examine_text != "":
        DialogueManager.show_text(examine_text)
```

**Step 5: Update player.gd — full dialogue ref cleanup**

1. Remove: `@onready var _dialogue_box: DialogueBox = $"../UILayer/DialogueBox"`
2. Remove: `@onready var _yarn_bridge: Node = $"../UILayer/YarnDialogueBridge"`
3. In `_try_interact()`, change `interactable.interact(_dialogue_box, _yarn_bridge)` to `interactable.interact()`
4. In `_unhandled_input`, change `_dialogue_box.skip_or_dismiss()` to `DialogueManager.skip_or_dismiss()`

**Step 6: Run all GUT tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 7: Commit**

```bash
git add scripts/world/npc.gd scripts/world/examine_object.gd scripts/world/player.gd tests/test_npc.gd
git commit -m "feat: drop dialogue refs from interact() — all interactables call DialogueManager directly"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 3

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 6 → Task 7 → Task 8 | Each depends on the previous |

### Smoketest Checkpoint 3 — DialogueManager wired, dialogue still works

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 3: Launch game and verify visually**
```bash
DISPLAY=:0 godot
```

**Step 4: Confirm with user**
Tell the user: "Walk up to Iris and press E. Dialogue should open, block movement, and close cleanly. The dialogue system now runs through the DialogueManager autoload instead of UILayer nodes." Wait for confirmation.

---

## Batch 4 — BaseRoom architecture + RoomPOC refactor

### Task 9: BaseRoom.tscn + base_room.gd

**Files:**
- Create: `scripts/world/base_room.gd`
- Create: `scenes/world/BaseRoom.tscn`
- Create: `tests/test_base_room.gd`

**Depends on:** Task 2 (pending_spawn_point), Task 4 (player.setup()), Task 5 (SpawnPoint), Task 7 (DialogueManager)
**Parallelizable with:** Task 10

**Step 1: Write failing GUT tests**

```gdscript
# tests/test_base_room.gd
extends GutTest

func test_compute_camera_limits_simple() -> void:
    var limits := BaseRoom.compute_camera_limits(Rect2i(0, 0, 16, 12), Vector2i(16, 16))
    assert_eq(limits, Rect2i(0, 0, 256, 192))

func test_compute_camera_limits_offset() -> void:
    var limits := BaseRoom.compute_camera_limits(Rect2i(2, 1, 10, 8), Vector2i(16, 16))
    assert_eq(limits, Rect2i(32, 16, 160, 128))

func test_get_configuration_warnings_no_default_spawn() -> void:
    var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
    room.default_spawn = ""
    var warnings := room._get_configuration_warnings()
    assert_gt(warnings.size(), 0)
    room.free()

func test_get_configuration_warnings_valid_spawn() -> void:
    var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
    room.default_spawn = "default"
    var sp := SpawnPoint.new()
    sp.spawn_id = "default"
    room.add_child(sp)
    var warnings := room._get_configuration_warnings()
    assert_eq(warnings.size(), 0)
    room.free()
```

**Step 2: Run to verify fails**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_base_room.gd
```
Expected: FAIL

**Step 3: Write `base_room.gd`**

```gdscript
@tool
class_name BaseRoom
extends Node2D

@export var world_layer: TileMapLayer
@export var music_path: String = ""
@export var battle_background: String = "default"
@export var default_spawn: String = "default"
@export var ambient_color: Color = Color(0.08, 0.08, 0.12, 1.0)


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    $CanvasModulate.color = ambient_color
    if music_path != "":
        AudioManager.play_music(music_path)
    if world_layer:
        _apply_camera_limits()
        $Player.setup(world_layer)
    _resolve_spawn()
    DialogueManager.dialogue_opened.connect($Player._on_dialogue_opened)
    DialogueManager.dialogue_closed.connect($Player._on_dialogue_closed)


func _resolve_spawn() -> void:
    var target_id: String = SceneManager.pending_spawn_point
    if target_id == "":
        target_id = default_spawn
    SceneManager.pending_spawn_point = ""
    if target_id == "":
        return
    var sp := _find_spawn_point(target_id)
    assert(sp != null, "BaseRoom: no SpawnPoint with spawn_id='%s' in scene '%s'" % [target_id, name])
    $Player.position = sp.position


func _find_spawn_point(spawn_id: String) -> SpawnPoint:
    for node: Node in get_tree().get_nodes_in_group("spawn_points"):
        if node is SpawnPoint and node.spawn_id == spawn_id:
            return node
    return null


func _apply_camera_limits() -> void:
    var limits := compute_camera_limits(
        world_layer.get_used_rect(),
        world_layer.tile_set.tile_size
    )
    var cam: Camera2D = $Player/Camera2D
    cam.limit_left   = limits.position.x
    cam.limit_top    = limits.position.y
    cam.limit_right  = limits.position.x + limits.size.x
    cam.limit_bottom = limits.position.y + limits.size.y


func _get_configuration_warnings() -> PackedStringArray:
    var warnings: PackedStringArray = []
    if default_spawn == "":
        warnings.append("default_spawn is empty — player has no fallback spawn point.")
        return warnings
    var found := false
    for child: Node in find_children("*", "SpawnPoint", true, false):
        if (child as SpawnPoint).spawn_id == default_spawn:
            found = true
            break
    if not found:
        warnings.append("No SpawnPoint with spawn_id='%s' found in scene." % default_spawn)
    return warnings


static func compute_camera_limits(used_rect: Rect2i, tile_size: Vector2i) -> Rect2i:
    return Rect2i(
        used_rect.position.x * tile_size.x,
        used_rect.position.y * tile_size.y,
        used_rect.size.x * tile_size.x,
        used_rect.size.y * tile_size.y
    )
```

**Step 4: Build `BaseRoom.tscn` in Godot editor**

Create `scenes/world/BaseRoom.tscn` as a new scene:

```
BaseRoom (Node2D, y_sort_enabled=true) ← base_room.gd
  Player (CharacterBody2D) ← scripts/world/player.gd
    CollisionShape2D (RectangleShape2D, size=(12,12), pos=(0,-6))
    Sprite2D (texture=assets/sprites/characters/reid.png, offset=(0,-4), vframes=8)
    Camera2D (position_smoothing_enabled=true)
  CanvasModulate
  UILayer (CanvasLayer, layer=10)  ← empty; future HUD goes here
```

Set `world_layer` export to null (each inherited scene sets this).

**Step 5: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_base_room.gd
```
Expected: PASS

**Step 6: Refactor checkpoint**

Ask: "Does `_find_spawn_point` search recursively across the scene tree — could it find SpawnPoints from a different room if two rooms were loaded simultaneously?" It uses `get_tree().get_nodes_in_group()` which is global. In practice, only one room is ever loaded at a time. Acceptable for now. Proceed.

**Step 7: Commit**

```bash
git add scripts/world/base_room.gd scenes/world/BaseRoom.tscn tests/test_base_room.gd
git commit -m "feat: add BaseRoom — shared room architecture with @tool spawn validation"
```

---

### Task 10: ExitDoor scene + script

**Files:**
- Create: `scripts/world/exit_door.gd`
- Create: `scenes/world/ExitDoor.tscn`

**Depends on:** Task 2 (SceneManager.change_scene with spawn_point param)
**Parallelizable with:** Task 9

**Step 1: Write the content**

```gdscript
# scripts/world/exit_door.gd
class_name ExitDoor
extends Area2D

@export var target_path: String = ""
@export var spawn_point: String = ""


func _ready() -> void:
    target_path = get_meta("target_path", target_path)
    spawn_point  = get_meta("spawn_point",  spawn_point)
    body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
    if not body is Player:
        return
    SceneManager.change_scene(target_path, spawn_point)
```

`scenes/world/ExitDoor.tscn`: Create in Godot editor as an `Area2D` with `exit_door.gd` attached. Add a `CollisionShape2D` child with a `RectangleShape2D` (size 16×16). Set collision layer/mask so it detects the Player body.

**Step 2: Verify**

Open scene in Godot. Confirm: Area2D root, CollisionShape2D child, `target_path` and `spawn_point` exports visible in inspector.

**Step 3: Commit**

```bash
git add scripts/world/exit_door.gd scenes/world/ExitDoor.tscn
git commit -m "feat: add ExitDoor — auto-trigger area that calls SceneManager.change_scene"
```

---

### Task 11: Refactor RoomPOC to inherit BaseRoom

**Files:**
- Modify: `scenes/world/RoomPOC.tscn` (inherit BaseRoom, set exports, remove duplicate nodes)
- Delete: `scripts/world/room_poc.gd`
- Modify: `maps/room_poc.tmx` (add SpawnPoint in Interactions layer)

**Depends on:** Task 9 (BaseRoom must exist)
**Parallelizable with:** none (sequential after Task 9)

**Step 1: Delete `room_poc.gd`**

```bash
rm scripts/world/room_poc.gd
```

**Step 2: Refactor `RoomPOC.tscn` in Godot editor**

1. Open `scenes/world/RoomPOC.tscn`.
2. Change the root node's base scene to `BaseRoom.tscn` (Scene → Change Type or re-parent via inheritance).
3. Remove from RoomPOC: Player, Camera2D (they come from BaseRoom), CanvasModulate, UILayer.
4. Keep: `room_poc` (TMX instance), `FlickeringLight`.
5. Add: instance of `SpawnPoint.tscn`, set `spawn_id = "default"`, place at a sensible starting position (e.g., 120, 88 — where Player was before).
6. Set BaseRoom exports in inspector:
   - `world_layer`: drag the `room_poc/World` TileMapLayer node
   - `music_path`: `res://assets/audio/music/NoirCafe.ogg`
   - `battle_background`: `alley`
   - `default_spawn`: `default`
   - `ambient_color`: `Color(0.08, 0.08, 0.12, 1.0)`

**Step 3: Add SpawnPoint to `room_poc.tmx`**

Open `maps/room_poc.tmx` in Tiled. In the Interactions layer, add an object:
```xml
<object id="N" type="instance" x="48" y="112" width="16" height="16">
  <properties>
    <property name="spawn_id" value="four_winds_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
  </properties>
</object>
```
Position this near a logical "entrance from Four Winds Bar" spot.

**Step 4: Re-import the map**

```bash
make import
```

**Step 5: Run all GUT tests**

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 6: Commit**

```bash
git add scenes/world/RoomPOC.tscn maps/room_poc.tmx
git rm scripts/world/room_poc.gd
git commit -m "refactor: RoomPOC inherits BaseRoom — rm room_poc.gd, add spawn points"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 4

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 9, Task 10 | Different output files, no shared state |
| B (sequential) | Task 11 | Depends on Task 9 (BaseRoom must exist) |

### Smoketest Checkpoint 4 — RoomPOC works via BaseRoom, no regression

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass.

**Step 3: Launch game and verify visually**
```bash
DISPLAY=:0 godot
```

**Step 4: Confirm with user**
Tell the user:
- Player spawns at the `"default"` SpawnPoint position in RoomPOC
- Camera limits auto-fit the map (no black border scrolling past edges)
- Iris dialogue opens, blocks movement, closes cleanly
- BattleEncounter still triggers correctly
- No visual regression vs before

Wait for confirmation.

---

## Batch 5 — Four Winds Bar

### Task 12: Holloway dialogue stub

**Files:**
- Create: `dialogue/holloway_four_winds_act1.yarn`

**Depends on:** none
**Parallelizable with:** Task 13, Task 14

**Step 1: Write the content**

```yarn
title: holloway_four_winds_act1
---
Holloway: You look lost, kid. This ain't the place for sightseeing.
===
```

**Step 2: Verify**

The yarn file will be picked up by `iris.yarnproject` automatically (it imports all `.yarn` files in the `dialogue/` folder). After import, confirm the node appears in the Godot editor's YarnSpinner project view.

```bash
make import
```

**Step 3: Commit**

```bash
git add dialogue/holloway_four_winds_act1.yarn
git commit -m "feat: add Holloway Four Winds Act 1 dialogue stub"
```

---

### Task 13: four_winds_bar.tmx

**Files:**
- Create: `maps/four_winds_bar.tmx`

**Depends on:** Task 10 (ExitDoor.tscn must exist), Task 5 (SpawnPoint.tscn must exist)
**Parallelizable with:** Task 12

**Step 1: Create the map in Tiled**

Create `maps/four_winds_bar.tmx` with:
- Size: 16 × 12 tiles (256 × 192 px)
- Tile size: 16 × 16 px
- Tilesets: `placeholder.tsx`, `objects.tsx`
- Three layers: `World`, `Objects`, `Interactions`

**World layer:** Fill the interior (tiles 2-14 wide, 1-10 tall) with floor tiles. Surround with wall tiles (class="wall" in placeholder.tsx). Leave a 1-tile gap in the south wall for the exit.

**Objects layer:** 
- Place a tile for Holloway NPC (use the same NPC tile gid as in room_poc.tmx) somewhere mid-bar.
- Place a tile for the exit door at the south gap position.

**Interactions layer:**
```xml
<!-- Holloway NPC -->
<object id="1" type="instance" x="80" y="64" width="16" height="16">
  <properties>
    <property name="yarn_node_id" value="holloway_four_winds_act1"/>
    <property name="res_path" type="file" value="res://scenes/world/NPC.tscn"/>
  </properties>
</object>

<!-- Exit door to RoomPOC -->
<object id="2" type="instance" x="128" y="176" width="16" height="16">
  <properties>
    <property name="target_path" value="res://scenes/world/RoomPOC.tscn"/>
    <property name="spawn_point" value="four_winds_entrance"/>
    <property name="res_path" type="file" value="res://scenes/world/ExitDoor.tscn"/>
  </properties>
</object>

<!-- Default spawn point -->
<object id="3" type="instance" x="128" y="88" width="16" height="16">
  <properties>
    <property name="spawn_id" value="default"/>
    <property name="res_path" type="file" value="res://scenes/world/SpawnPoint.tscn"/>
  </properties>
</object>
```

**Step 2: Import**

```bash
make import
```
Expected: `four_winds_bar.tmx` imports cleanly into `.godot/imported/`.

**Step 3: Commit**

```bash
git add maps/four_winds_bar.tmx
git commit -m "feat: add four_winds_bar.tmx — 16x12 placeholder map with Holloway + exit"
```

---

### Task 14: FourWindsBar.tscn + set as main scene

**Files:**
- Create: `scenes/world/FourWindsBar.tscn`
- Modify: `project.godot` (update main scene)

**Depends on:** Task 9 (BaseRoom), Task 13 (four_winds_bar.tmx)
**Parallelizable with:** Task 12

**Step 1: Build `FourWindsBar.tscn` in Godot editor**

Create `scenes/world/FourWindsBar.tscn` inheriting `BaseRoom.tscn`:

```
FourWindsBar (BaseRoom) ← no custom script needed; uses base_room.gd
  four_winds_bar (instance of maps/four_winds_bar.tmx)
  FlickeringLight (PointLight2D) — copy settings from RoomPOC for atmosphere
```

Set BaseRoom exports in inspector:
- `world_layer`: drag `four_winds_bar/World` TileMapLayer node
- `music_path`: `res://assets/audio/music/NoirCafe.ogg`
- `battle_background`: `alley`
- `default_spawn`: `default`
- `ambient_color`: `Color(0.08, 0.08, 0.12, 1.0)`

**Step 2: Update main scene in `project.godot`**

Change:
```
run/main_scene="res://scenes/world/RoomPOC.tscn"
```
To:
```
run/main_scene="res://scenes/world/FourWindsBar.tscn"
```

**Step 3: Verify**

```bash
make import
```
Expected: No errors.

**Step 4: Commit**

```bash
git add scenes/world/FourWindsBar.tscn project.godot
git commit -m "feat: add FourWindsBar.tscn as first real map, set as main scene"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 5

| Group | Tasks | Notes |
|-------|-------|-------|
| A (parallel) | Task 12, Task 13 | Different output files |
| B (sequential) | Task 14 | Depends on Task 13 (needs four_winds_bar.tmx) |

### Smoketest Checkpoint 5 — Full acceptance criteria

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify all acceptance criteria**
```bash
DISPLAY=:0 godot
```

**Step 4: Confirm with user**
Tell the user to verify each acceptance criterion:

- [ ] Player spawns in Four Winds Bar at the `"default"` SpawnPoint
- [ ] Walls block movement; floor tiles allow it
- [ ] Walk up to Holloway, press E → dialogue opens ("You look lost, kid...")
- [ ] Dialogue blocks movement while open
- [ ] Press E again → dialogue closes, movement resumes
- [ ] Walk to the south exit door → screen fades, transitions to RoomPOC
- [ ] Player spawns at `"four_winds_entrance"` position in RoomPOC (not at the default position)
- [ ] Camera limits auto-fit both rooms (no black scrolling past edges)
- [ ] CellRegistry clears between rooms (no phantom blocked cells)
- [ ] Iris dialogue in RoomPOC still works after the transition

Wait for confirmation before finishing.
