class_name ExamineObject
extends Node2D

const TILE_SIZE: int = 16

@export var examine_text: String = ""
@export var sets_flag: String = ""


func _ready() -> void:
	examine_text = get_meta("examine_text", examine_text)
	sets_flag = get_meta("sets_flag", sets_flag)
	CellRegistry.register_interactable(get_cell(), self)


func _exit_tree() -> void:
	CellRegistry.unregister_interactable(get_cell())


func get_cell() -> Vector2i:
	return Vector2i(int(position.x) / TILE_SIZE, int(position.y) / TILE_SIZE)


func interact() -> void:
	if sets_flag != "":
		GameState.set_flag(sets_flag, true)
	if examine_text != "":
		DialogueManager.show_text(examine_text)
