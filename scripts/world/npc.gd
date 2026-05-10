class_name NPC
extends WorldObject

@export var yarn_node_id: String = ""


func _ready() -> void:
	super._ready()
	yarn_node_id = get_meta("yarn_node_id", yarn_node_id)
	CellRegistry.register_interactable(get_cell(), self)


func _exit_tree() -> void:
	super._exit_tree()
	CellRegistry.unregister_interactable(get_cell())


func interact(_dialogue_box: Node, yarn_bridge: Node) -> void:
	if yarn_node_id == "" or yarn_bridge == null:
		return
	yarn_bridge.start_dialogue(yarn_node_id)
