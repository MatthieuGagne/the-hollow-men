class_name CutsceneZone
extends Area2D

@export var dialogue_node: String = ""
@export var next_scene: String = ""
@export var required_flag: String = ""
@export var forbidden_flag: String = ""
@export var pre_battle_guests: String = ""
@export var pre_battle_enemies: String = ""
@export var battle_return_scene: String = ""
@export var battle_return_spawn_point: String = ""
@export var fire_on_scene_load: bool = false

var _fired: bool = false


func _ready() -> void:
	dialogue_node       = get_meta("dialogue_node",       dialogue_node)
	next_scene          = get_meta("next_scene",          next_scene)
	required_flag       = get_meta("required_flag",       required_flag)
	forbidden_flag      = get_meta("forbidden_flag",      forbidden_flag)
	pre_battle_guests   = get_meta("pre_battle_guests",   pre_battle_guests)
	pre_battle_enemies  = get_meta("pre_battle_enemies",  pre_battle_enemies)
	battle_return_scene       = get_meta("battle_return_scene",       battle_return_scene)
	battle_return_spawn_point = get_meta("battle_return_spawn_point", battle_return_spawn_point)
	fire_on_scene_load        = get_meta("fire_on_scene_load",        fire_on_scene_load)
	var w: float = get_meta("width", 0.0)
	var h: float = get_meta("height", 0.0)
	if w > 0.0 and h > 0.0:
		var shape_node := $CollisionShape2D
		if shape_node.shape == null:
			shape_node.shape = RectangleShape2D.new()
		var rect := shape_node.shape as RectangleShape2D
		if rect != null:
			rect.size = Vector2(w, h)
		shape_node.position = Vector2(w / 2.0, h / 2.0)
	if fire_on_scene_load:
		_check_load_trigger.call_deferred()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _check_load_trigger() -> void:
	_fire()


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_fire()


func _fire() -> void:
	if _fired:
		return
	if required_flag != "" and not GameState.has_flag(required_flag):
		return
	if forbidden_flag != "" and GameState.has_flag(forbidden_flag):
		return
	var _auto_flag := "zone_played_" + dialogue_node
	if fire_on_scene_load and dialogue_node != "" and GameState.has_flag(_auto_flag):
		return
	_fired = true
	if fire_on_scene_load and dialogue_node != "":
		GameState.set_flag(_auto_flag, true)
	set_deferred("monitoring", false)
	if dialogue_node == "":
		return
	DialogueManager.dialogue_closed.connect(_on_dialogue_closed, CONNECT_ONE_SHOT)
	DialogueManager.run_node(dialogue_node)


func _on_dialogue_closed() -> void:
	if pre_battle_guests != "":
		for path: String in pre_battle_guests.split(","):
			var c: Combatant = (load(path.strip_edges()) as Combatant).duplicate()
			c.reset_runtime_state()
			PartyManager.add_temporary(c)
	# Fully populate a FRESH battle context so nothing carries over from a
	# previous encounter (stale enemy table, background, or return scene).
	# CutsceneZone has no background override, so background_id stays "" → default.
	BattleContext.configure(pre_battle_enemies, "", battle_return_scene, battle_return_spawn_point)
	if next_scene.is_empty():
		return
	SceneManager.change_scene(next_scene)
