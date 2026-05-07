class_name NPC
extends WorldObject

@export var yarn_node_id: String = ""


func interact(_dialogue_box: Node, yarn_bridge: Node) -> void:
	if yarn_node_id == "" or yarn_bridge == null:
		return
	yarn_bridge.start_dialogue(yarn_node_id)
