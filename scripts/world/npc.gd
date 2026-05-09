class_name NPC
extends WorldObject

@export var yarn_node_id: String = ""


func _ready() -> void:
	super._ready()
	yarn_node_id = get_meta("yarn_node_id", yarn_node_id)


func interact(_dialogue_box: Node, yarn_bridge: Node) -> void:
	if yarn_node_id == "" or yarn_bridge == null:
		return
	yarn_bridge.start_dialogue(yarn_node_id)
