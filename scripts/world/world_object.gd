class_name WorldObject
extends Node2D

const TILE_SIZE: int = 16

@export var examine_text: String = ""
@export var object_name: String = ""
@export var sprite_texture: String = ""
@export var blocks_movement: bool = true
@export var tile_cols: int = 1
@export var tile_rows: int = 1

var _registered_cells: Array[Vector2i] = []


func _ready() -> void:
	examine_text    = get_meta("examine_text",    examine_text)
	object_name     = get_meta("object_name",     object_name)
	sprite_texture  = get_meta("sprite_texture",  sprite_texture)
	blocks_movement = get_meta("blocks_movement", blocks_movement)
	tile_cols       = get_meta("tile_cols",       tile_cols)
	tile_rows       = get_meta("tile_rows",       tile_rows)
	set_meta("blocks_movement", blocks_movement)
	z_as_relative = false
	z_index = int(global_position.y) + tile_rows * TILE_SIZE

	if sprite_texture != "":
		$Sprite2D.texture = load(sprite_texture)

	var origin: Vector2i = get_cell()
	for row: int in range(tile_rows):
		for col: int in range(tile_cols):
			var cell := origin + Vector2i(col, row)
			_registered_cells.append(cell)
			CellRegistry.register(cell, self)


func _exit_tree() -> void:
	for cell: Vector2i in _registered_cells:
		CellRegistry.unregister(cell)


func get_cell() -> Vector2i:
	return Vector2i(int(position.x) / TILE_SIZE, int(position.y) / TILE_SIZE)


func interact(dialogue_box: Node, _yarn_bridge: Node) -> void:
	if examine_text != "":
		dialogue_box.show_text(examine_text)
