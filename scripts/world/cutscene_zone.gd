class_name CutsceneZone
extends Area2D

@export var dialogue_node: String = ""
@export var next_scene: String = ""
@export var required_flag: String = ""
@export var forbidden_flag: String = ""

var _fired: bool = false


func _ready() -> void:
	dialogue_node  = get_meta("dialogue_node",  dialogue_node)
	next_scene     = get_meta("next_scene",     next_scene)
	required_flag  = get_meta("required_flag",  required_flag)
	forbidden_flag = get_meta("forbidden_flag", forbidden_flag)
	var w: float = get_meta("width", 0.0)
	var h: float = get_meta("height", 0.0)
	if w > 0.0 and h > 0.0:
		var shape_node := $CollisionShape2D
		if shape_node.shape == null:
			shape_node.shape = RectangleShape2D.new()
		var rect := shape_node.shape as RectangleShape2D
		if rect != null:
			rect.size = Vector2(w, h)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _fired or not body is Player:
		return
	if required_flag != "" and not GameState.has_flag(required_flag):
		return
	if forbidden_flag != "" and GameState.has_flag(forbidden_flag):
		return
	_fired = true
	set_deferred("monitoring", false)
	if dialogue_node == "":
		return
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)
	DialogueManager.run_node(dialogue_node)


func _on_dialogue_closed() -> void:
	if next_scene.is_empty():
		return
	SceneManager.change_scene(next_scene)
