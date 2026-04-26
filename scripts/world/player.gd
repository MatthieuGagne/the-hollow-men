class_name Player
extends CharacterBody2D

const TILE_SIZE: int = 16
const MOVE_DURATION: float = 0.1

var _moving: bool = false

@onready var _walls_layer: TileMapLayer = $"../room_poc/Walls"


func _ready() -> void:
	position = snap_to_grid(position, TILE_SIZE)


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
	if _is_wall(target_pos):
		return
	_moving = true
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, MOVE_DURATION)
	tween.tween_callback(func() -> void: _moving = false)


func _is_wall(world_pos: Vector2) -> bool:
	var cell: Vector2i = _walls_layer.local_to_map(world_pos)
	return _walls_layer.get_cell_source_id(cell) != -1


static func direction_to_offset(action: String) -> Vector2i:
	match action:
		"move_up":    return Vector2i(0, -1)
		"move_down":  return Vector2i(0, 1)
		"move_left":  return Vector2i(-1, 0)
		"move_right": return Vector2i(1, 0)
	return Vector2i.ZERO


static func snap_to_grid(pos: Vector2, tile_size: int) -> Vector2:
	return Vector2(
		roundf(pos.x / tile_size) * tile_size,
		roundf(pos.y / tile_size) * tile_size,
	)
