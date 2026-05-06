class_name WorldObject
extends Node2D

const TILE_SIZE: int = 16

@export var examine_text: String = ""
@export var object_name: String = ""
@export var sprite_frame: int = 0
@export var blocks_movement: bool = true


func _ready() -> void:
	examine_text    = get_meta("examine_text",    examine_text)
	object_name     = get_meta("object_name",     object_name)
	sprite_frame    = get_meta("sprite_frame",    sprite_frame)
	blocks_movement = get_meta("blocks_movement", blocks_movement)
	CellRegistry.register(get_cell(), self)


func _exit_tree() -> void:
	CellRegistry.unregister(get_cell())


func get_cell() -> Vector2i:
	return Vector2i(int(position.x) / TILE_SIZE, int(position.y) / TILE_SIZE)


func interact(dialogue_box: Node, _yarn_bridge: Node) -> void:
	if examine_text != "":
		dialogue_box.show_text(examine_text)
