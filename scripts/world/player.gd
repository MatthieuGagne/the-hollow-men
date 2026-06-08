class_name Player
extends CharacterBody2D

const TILE_SIZE: int = 16
const MOVE_DURATION: float = 0.1

var _moving: bool = false
var _facing: Vector2i = Vector2i(0, 1)  # default: facing down
var _input_blocked: bool = false
var _interact_awaiting_release: bool = false
var _world_layer: TileMapLayer


func _ready() -> void:
	position = snap_to_grid(position, TILE_SIZE)
	z_as_relative = false


func setup(layer: TileMapLayer) -> void:
	_world_layer = layer


func _process(_delta: float) -> void:
	z_index = int(position.y) + TILE_SIZE / 2
	if not _moving and not _input_blocked:
		for action: String in ["move_up", "move_down", "move_left", "move_right"]:
			if Input.is_action_pressed(action):
				_try_move(action)
				break
	if _world_layer != null:
		DebugOverlay.notify_position(position, _world_layer.local_to_map(position))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("interact"):
		_interact_awaiting_release = false
	if event.is_action_pressed("interact", false) and _input_blocked:
		_interact_awaiting_release = true
		DialogueManager.skip_or_dismiss()
		return
	if _moving or _input_blocked or _world_layer == null:
		return
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			_try_move(action)
			return
	if event.is_action_pressed("interact", false) and not _interact_awaiting_release:
		_interact_awaiting_release = true
		_try_interact()


func _try_interact() -> void:
	var cell: Vector2i = get_facing_cell()
	var interactable: Node = CellRegistry.get_interactable(cell)
	if interactable == null:
		return
	interactable.interact()


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


func _is_wall(world_pos: Vector2) -> bool:
	var cell: Vector2i = _world_layer.local_to_map(world_pos)
	var td: TileData = _world_layer.get_cell_tile_data(cell)
	if td == null:
		return true
	return td.get_meta("class", "") == "wall"


func get_facing_cell() -> Vector2i:
	return _world_layer.local_to_map(position) + _facing


func _on_dialogue_opened() -> void:
	_input_blocked = true


func _on_dialogue_closed() -> void:
	_input_blocked = false


static func direction_to_offset(action: String) -> Vector2i:
	match action:
		"move_up":    return Vector2i(0, -1)
		"move_down":  return Vector2i(0, 1)
		"move_left":  return Vector2i(-1, 0)
		"move_right": return Vector2i(1, 0)
	return Vector2i.ZERO


static func facing_from_action(action: String) -> Vector2i:
	return direction_to_offset(action)


static func snap_to_grid(pos: Vector2, tile_size: int) -> Vector2:
	return Vector2(
		floorf(pos.x / tile_size) * tile_size + tile_size * 0.5,
		floorf(pos.y / tile_size) * tile_size + tile_size * 0.5,
	)
