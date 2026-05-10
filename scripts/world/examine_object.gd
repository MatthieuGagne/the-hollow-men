class_name ExamineObject
extends Node2D

const TILE_SIZE: int = 16

@export var examine_text: String = ""


func _ready() -> void:
	examine_text = get_meta("examine_text", examine_text)
	CellRegistry.register_interactable(get_cell(), self)


func _exit_tree() -> void:
	CellRegistry.unregister_interactable(get_cell())


func get_cell() -> Vector2i:
	return Vector2i(int(position.x) / TILE_SIZE, int(position.y) / TILE_SIZE)


func interact(dialogue_box: Node, _yarn_bridge: Node) -> void:
	if examine_text != "":
		dialogue_box.show_text(examine_text)
