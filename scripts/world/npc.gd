class_name NPC
extends WorldObject

@export var yarn_node_id: String = ""
@export var hide_when_flag: String = ""
@export var show_when_flag: String = ""


func _ready() -> void:
	super._ready()
	yarn_node_id   = get_meta("yarn_node_id",   yarn_node_id)
	hide_when_flag = get_meta("hide_when_flag", hide_when_flag)
	show_when_flag = get_meta("show_when_flag", show_when_flag)
	if hide_when_flag != "" and GameState.has_flag(hide_when_flag):
		queue_free()
		return
	if show_when_flag != "" and not GameState.has_flag(show_when_flag):
		queue_free()
		return
	CellRegistry.register_interactable(get_cell(), self)


func _exit_tree() -> void:
	super._exit_tree()
	CellRegistry.unregister_interactable(get_cell())


func interact() -> void:
	if yarn_node_id == "":
		return
	DialogueManager.run_node(yarn_node_id)
