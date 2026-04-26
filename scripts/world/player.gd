class_name Player
extends CharacterBody2D

const TILE_SIZE: int = 16
const MOVE_DURATION: float = 0.1

var _moving: bool = false

@onready var _world_layer: TileMapLayer = $"../room_poc"

# Debug state
var _dbg_target_offset: Vector2 = Vector2.ZERO
var _dbg_is_wall: bool = false
var _dbg_has_target: bool = false
var _dbg_label: Label


func _ready() -> void:
	position = snap_to_grid(position, TILE_SIZE)
	_setup_debug_overlay()


func _setup_debug_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_dbg_label = Label.new()
	_dbg_label.position = Vector2(4, 4)
	_dbg_label.add_theme_font_size_override("font_size", 8)
	canvas.add_child(_dbg_label)


func _process(_delta: float) -> void:
	if not _moving:
		for action: String in ["move_up", "move_down", "move_left", "move_right"]:
			if Input.is_action_pressed(action):
				_try_move(action)
				break
	queue_redraw()
	var tile: Vector2i = _world_layer.local_to_map(position)
	var lines: PackedStringArray = [
		"pos: (%.0f, %.0f)" % [position.x, position.y],
		"tile: %s" % [tile],
	]
	if _dbg_has_target:
		var target_tile: Vector2i = _world_layer.local_to_map(position + _dbg_target_offset)
		lines.append("target: %s  wall=%s" % [target_tile, _dbg_is_wall])
	_dbg_label.text = "\n".join(lines)


func _draw() -> void:
	var half: float = TILE_SIZE / 2.0
	var tile_rect := Rect2(-half, -half, TILE_SIZE, TILE_SIZE)
	# Current tile — green outline
	draw_rect(tile_rect, Color(0.0, 1.0, 0.0, 0.25), true)
	draw_rect(tile_rect, Color(0.0, 1.0, 0.0, 0.9), false)
	# Target tile — red if wall, cyan if free
	if _dbg_has_target:
		var t := Rect2(_dbg_target_offset.x - half, _dbg_target_offset.y - half, TILE_SIZE, TILE_SIZE)
		var col := Color(1.0, 0.1, 0.1, 0.35) if _dbg_is_wall else Color(0.0, 0.8, 1.0, 0.35)
		draw_rect(t, col, true)
		draw_rect(t, col + Color(0, 0, 0, 0.5), false)


func _unhandled_input(event: InputEvent) -> void:
	if _moving:
		return
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			_try_move(action)
			return


func _try_move(action: String) -> void:
	var offset: Vector2i = direction_to_offset(action)
	var target_pos: Vector2 = position + Vector2(offset) * TILE_SIZE
	_dbg_target_offset = Vector2(offset) * TILE_SIZE
	_dbg_is_wall = _is_wall(target_pos)
	_dbg_has_target = true
	if _dbg_is_wall:
		return
	_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	tween.tween_callback(func() -> void: _moving = false)


func _is_wall(world_pos: Vector2) -> bool:
	var cell: Vector2i = _world_layer.local_to_map(world_pos)
	var td: TileData = _world_layer.get_cell_tile_data(cell)
	if td == null:
		return true
	return td.get_meta("class", "") == "wall"


static func direction_to_offset(action: String) -> Vector2i:
	match action:
		"move_up":    return Vector2i(0, -1)
		"move_down":  return Vector2i(0, 1)
		"move_left":  return Vector2i(-1, 0)
		"move_right": return Vector2i(1, 0)
	return Vector2i.ZERO


static func snap_to_grid(pos: Vector2, tile_size: int) -> Vector2:
	var half: float = tile_size * 0.5
	return Vector2(
		floorf(pos.x / tile_size) * tile_size + half,
		floorf(pos.y / tile_size) * tile_size + half,
	)
