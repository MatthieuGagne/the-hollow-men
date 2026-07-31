# Debug Overlay Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace scattered debug displays (player coords in `player.gd`, room name in `BaseRoom.tscn`) with a single `DebugOverlay` autoload singleton that shows all debug info top-left, toggled by F3, with state persisted across launches.

**Architecture:** `DebugOverlay` is a new autoload (always in scene tree) that owns a `CanvasLayer` + `Label` at layer 100. `player.gd` calls `DebugOverlay.notify_position()` each frame. Both the player debug canvas and the room name label are removed.

**Tech Stack:** GDScript, Godot 4 `ConfigFile` for persistence, `ProjectSettings` for default, GUT for tests.

---

### Task 1: Wire `project.godot` — autoload, input action, ProjectSetting

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add the `DebugOverlay` autoload**

  In `project.godot`, append to the `[autoload]` section (after the `DialogueManager` line):

  ```ini
  DebugOverlay="*res://scripts/autoload/debug_overlay.gd"
  ```

- [ ] **Step 2: Add the `debug_toggle` input action (F3)**

  In `project.godot`, append to the `[input]` section (after the last existing action):

  ```ini
  debug_toggle={
  "deadzone": 0.5,
  "events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194334,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
  ]
  }
  ```

  (`physical_keycode` 4194334 = `KEY_F3`)

- [ ] **Step 3: Add the `debug/overlay_enabled` ProjectSetting default**

  Append a new `[debug]` section to `project.godot` (after the `[input]` section):

  ```ini
  [debug]

  overlay_enabled=false
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add project.godot
  git commit -m "feat: add DebugOverlay autoload, debug_toggle input action, debug/overlay_enabled setting"
  ```

---

### Task 2: Write failing GUT tests for `DebugOverlay`

**Files:**
- Create: `tests/test_debug_overlay.gd`

- [ ] **Step 1: Create the test file**

  ```gdscript
  extends GutTest


  func test_debug_overlay_is_accessible() -> void:
      assert_not_null(DebugOverlay)


  func test_has_canvas_layer() -> void:
      assert_not_null(DebugOverlay._canvas)


  func test_has_label() -> void:
      assert_not_null(DebugOverlay._label)


  func test_toggle_flips_visible_flag() -> void:
      var original: bool = DebugOverlay._visible_flag
      DebugOverlay._toggle()
      assert_eq(DebugOverlay._visible_flag, not original)
      DebugOverlay._toggle()  # restore


  func test_toggle_updates_canvas_visibility() -> void:
      DebugOverlay._visible_flag = false
      DebugOverlay._canvas.visible = false
      DebugOverlay._toggle()
      assert_true(DebugOverlay._canvas.visible)
      DebugOverlay._toggle()  # restore


  func test_notify_position_no_op_when_hidden() -> void:
      DebugOverlay._visible_flag = false
      DebugOverlay._canvas.visible = false
      DebugOverlay._label.text = ""
      DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
      assert_eq(DebugOverlay._label.text, "")


  func test_notify_position_updates_label_when_visible() -> void:
      DebugOverlay._visible_flag = true
      DebugOverlay._canvas.visible = true
      DebugOverlay.notify_position(Vector2(100, 200), Vector2i(3, 4))
      assert_true(DebugOverlay._label.text.contains("100"),
          "label must show x position")
      assert_true(DebugOverlay._label.text.contains("3"),
          "label must show tile x coordinate")
      DebugOverlay._visible_flag = false  # restore
      DebugOverlay._canvas.visible = false


  func test_save_and_load_config_round_trip() -> void:
      DebugOverlay._visible_flag = true
      DebugOverlay._save_config()
      DebugOverlay._visible_flag = false
      DebugOverlay._canvas.visible = false
      DebugOverlay._load_config()
      assert_true(DebugOverlay._visible_flag,
          "after saving true, _load_config must restore true")
      # Cleanup
      DirAccess.remove_absolute("user://debug.cfg")
      DebugOverlay._visible_flag = false
      DebugOverlay._canvas.visible = false


  func test_load_config_falls_back_to_project_setting_when_no_file() -> void:
      if FileAccess.file_exists("user://debug.cfg"):
          DirAccess.remove_absolute("user://debug.cfg")
      DebugOverlay._load_config()
      # ProjectSettings default is false
      assert_false(DebugOverlay._visible_flag,
          "without a saved config file, overlay must default to ProjectSettings value (false)")
  ```

- [ ] **Step 2: Run tests to confirm they fail (autoload not yet created)**

  ```bash
  godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gtest=res://tests/test_debug_overlay.gd
  ```

  Expected: errors about missing `DebugOverlay` or missing methods.

- [ ] **Step 3: Commit**

  ```bash
  git add tests/test_debug_overlay.gd
  git commit -m "test: add failing GUT tests for DebugOverlay"
  ```

---

### Task 3: Implement `scripts/autoload/debug_overlay.gd`

**Files:**
- Create: `scripts/autoload/debug_overlay.gd`

- [ ] **Step 1: Create the autoload script**

  ```gdscript
  extends Node

  const CONFIG_PATH: String = "user://debug.cfg"
  const SETTING_KEY: String = "debug/overlay_enabled"

  var _visible_flag: bool = false
  var _canvas: CanvasLayer
  var _label: Label


  func _ready() -> void:
      _setup_ui()
      _load_config()


  func _setup_ui() -> void:
      _canvas = CanvasLayer.new()
      _canvas.layer = 100
      add_child(_canvas)
      _label = Label.new()
      _label.position = Vector2(4, 4)
      _label.add_theme_font_size_override("font_size", 8)
      _canvas.add_child(_label)
      _canvas.visible = false


  func _load_config() -> void:
      var cfg := ConfigFile.new()
      if cfg.load(CONFIG_PATH) == OK:
          _visible_flag = cfg.get_value("debug", "overlay_enabled", false)
      else:
          _visible_flag = ProjectSettings.get_setting(SETTING_KEY, false)
      _canvas.visible = _visible_flag


  func _save_config() -> void:
      var cfg := ConfigFile.new()
      cfg.set_value("debug", "overlay_enabled", _visible_flag)
      cfg.save(CONFIG_PATH)


  func _toggle() -> void:
      _visible_flag = not _visible_flag
      _canvas.visible = _visible_flag
      _save_config()


  func _unhandled_input(event: InputEvent) -> void:
      if event.is_action_pressed("debug_toggle"):
          _toggle()


  func notify_position(pos: Vector2, tile: Vector2i) -> void:
      if not _visible_flag:
          return
      var scene_name: String = ""
      if get_tree().current_scene != null:
          scene_name = get_tree().current_scene.name
      _label.text = "pos: (%.0f, %.0f)\ntile: %s\nscene: %s" % [pos.x, pos.y, tile, scene_name]
  ```

- [ ] **Step 2: Run the DebugOverlay tests — expect all to pass**

  ```bash
  godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -ginclude_subdirs -gtest=res://tests/test_debug_overlay.gd
  ```

  Expected: all 8 tests pass.

- [ ] **Step 3: Run the full test suite to check for regressions**

  ```bash
  godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
  ```

  Expected: all tests pass.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/autoload/debug_overlay.gd
  git commit -m "feat: implement DebugOverlay autoload singleton"
  ```

---

### Task 4: Clean up `player.gd`

Remove all debug-specific state, the overlay setup, the `_draw` rectangles, and wire in `DebugOverlay.notify_position()`.

**Files:**
- Modify: `scripts/world/player.gd`

- [ ] **Step 1: Remove debug fields and `_setup_debug_overlay()`**

  Remove these four variable declarations at the top of the class:

  ```gdscript
  var _dbg_target_offset: Vector2 = Vector2.ZERO
  var _dbg_is_wall: bool = false
  var _dbg_has_target: bool = false
  var _dbg_label: Label
  ```

  Remove the `_setup_debug_overlay()` method entirely:

  ```gdscript
  func _setup_debug_overlay() -> void:
      var canvas := CanvasLayer.new()
      canvas.layer = 100
      add_child(canvas)

      _dbg_label = Label.new()
      _dbg_label.position = Vector2(4, 4)
      _dbg_label.add_theme_font_size_override("font_size", 8)
      canvas.add_child(_dbg_label)
  ```

  Remove the call to it in `_ready()`:

  ```gdscript
  _setup_debug_overlay()
  ```

- [ ] **Step 2: Replace the debug label update in `_process` with `notify_position`**

  Remove `queue_redraw()` and the debug label block. Replace the tail of `_process` with a single `notify_position` call:

  Old tail of `_process` (lines 47–58):

  ```gdscript
      queue_redraw()
      if _world_layer == null:
          return
      var tile: Vector2i = _world_layer.local_to_map(position)
      var lines: PackedStringArray = [
          "pos: (%.0f, %.0f)" % [position.x, position.y],
          "tile: %s" % [tile],
      ]
      if _dbg_has_target:
          var target_tile: Vector2i = _world_layer.local_to_map(position + _dbg_target_offset)
          lines.append("target: %s  wall=%s" % [target_tile, _dbg_is_wall])
      _dbg_label.text = "\n".join(lines)
  ```

  Replace with:

  ```gdscript
      if _world_layer != null:
          DebugOverlay.notify_position(position, _world_layer.local_to_map(position))
  ```

- [ ] **Step 3: Remove `_draw()` entirely**

  Remove the whole method:

  ```gdscript
  func _draw() -> void:
      var half: float = TILE_SIZE / 2.0
      var tile_rect := Rect2(-half, -half, TILE_SIZE, TILE_SIZE)
      draw_rect(tile_rect, Color(0.0, 1.0, 0.0, 0.25), true)
      draw_rect(tile_rect, Color(0.0, 1.0, 0.0, 0.9), false)
      if _dbg_has_target:
          var t := Rect2(_dbg_target_offset.x - half, _dbg_target_offset.y - half, TILE_SIZE, TILE_SIZE)
          var col := Color(1.0, 0.1, 0.1, 0.35) if _dbg_is_wall else Color(0.0, 0.8, 1.0, 0.35)
          draw_rect(t, col, true)
          draw_rect(t, col + Color(0, 0, 0, 0.5), false)
  ```

- [ ] **Step 4: Simplify `_try_move` — remove debug state writes, inline the wall check**

  Old `_try_move` (lines 100–113):

  ```gdscript
  func _try_move(action: String) -> void:
      var offset: Vector2i = direction_to_offset(action)
      _facing = offset
      var target_pos: Vector2 = position + Vector2(offset) * TILE_SIZE
      var target_cell: Vector2i = _world_layer.local_to_map(target_pos)
      _dbg_target_offset = Vector2(offset) * TILE_SIZE
      _dbg_is_wall = _is_wall(target_pos) or CellRegistry.is_blocked(target_cell)
      _dbg_has_target = true
      if _dbg_is_wall:
          return
      _moving = true
      var tween: Tween = create_tween()
      tween.tween_property(self, "position", target_pos, MOVE_DURATION)
      tween.tween_callback(func() -> void: _moving = false)
  ```

  Replace with:

  ```gdscript
  func _try_move(action: String) -> void:
      var offset: Vector2i = direction_to_offset(action)
      _facing = offset
      var target_pos: Vector2 = position + Vector2(offset) * TILE_SIZE
      var target_cell: Vector2i = _world_layer.local_to_map(target_pos)
      if _is_wall(target_pos) or CellRegistry.is_blocked(target_cell):
          return
      _moving = true
      var tween: Tween = create_tween()
      tween.tween_property(self, "position", target_pos, MOVE_DURATION)
      tween.tween_callback(func() -> void: _moving = false)
  ```

- [ ] **Step 5: Run all tests**

  ```bash
  godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
  ```

  Expected: all tests pass (existing player tests still pass because they don't test `_draw` or the removed debug vars).

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/world/player.gd
  git commit -m "refactor: remove player debug overlay; wire DebugOverlay.notify_position"
  ```

---

### Task 5: Remove room name label from `BaseRoom.tscn` and `base_room.gd`

**Files:**
- Modify: `scenes/world/BaseRoom.tscn`
- Modify: `scripts/world/base_room.gd`

- [ ] **Step 1: Remove the `RoomLabelLayer` and `RoomLabel` nodes from `BaseRoom.tscn`**

  Remove the `LabelSettings_1` sub-resource and the two node entries. The file currently ends with:

  ```
  [sub_resource type="LabelSettings" id="LabelSettings_1"]
  font_size = 8
  outline_size = 1
  outline_color = Color(0, 0, 0, 1)
  ```

  and:

  ```
  [node name="RoomLabelLayer" type="CanvasLayer" parent="."]
  layer = 100

  [node name="RoomLabel" type="Label" parent="RoomLabelLayer"]
  anchor_left = 1.0
  anchor_right = 1.0
  offset_left = -120.0
  offset_right = -4.0
  offset_top = 4.0
  offset_bottom = 16.0
  label_settings = SubResource("LabelSettings_1")
  horizontal_alignment = 2
  ```

  Delete both blocks entirely.

- [ ] **Step 2: Remove the room label assignment in `base_room.gd`**

  In `scripts/world/base_room.gd`, remove line 17:

  ```gdscript
  $RoomLabelLayer/RoomLabel.text = name
  ```

- [ ] **Step 3: Run all tests**

  ```bash
  godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
  ```

  Expected: all tests pass.

- [ ] **Step 4: Commit**

  ```bash
  git add scenes/world/BaseRoom.tscn scripts/world/base_room.gd
  git commit -m "refactor: remove RoomLabelLayer from BaseRoom; scene name now in DebugOverlay"
  ```
