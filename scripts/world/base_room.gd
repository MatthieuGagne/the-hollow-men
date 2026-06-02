@tool
class_name BaseRoom
extends Node2D

@export_node_path("TileMapLayer") var world_layer_path: NodePath = NodePath("")
@export var music_path: String = ""
@export var battle_background: String = "default"
@export var default_spawn: String = "default"
@export var ambient_color: Color = Color(0.08, 0.08, 0.12, 1.0)

var _world_layer: TileMapLayer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	$RoomLabelLayer/RoomLabel.text = name
	$CanvasModulate.color = ambient_color
	if music_path != "":
		AudioManager.play_music(music_path)
	_world_layer = get_node_or_null(world_layer_path) as TileMapLayer
	if _world_layer:
		_apply_camera_limits()
		$Player.setup(_world_layer)
	_resolve_spawn()
	DialogueManager.dialogue_opened.connect($Player._on_dialogue_opened)
	DialogueManager.dialogue_closed.connect($Player._on_dialogue_closed)


func _resolve_spawn() -> void:
	var target_id: String = SceneManager.pending_spawn_point
	if target_id == "":
		target_id = default_spawn
	SceneManager.pending_spawn_point = ""
	if target_id == "":
		return
	var sp := _find_spawn_point(target_id)
	assert(sp != null, "BaseRoom: no SpawnPoint with spawn_id='%s' in scene '%s'" % [target_id, name])
	$Player.position = Player.snap_to_grid(sp.position, 16)


func _find_spawn_point(spawn_id: String) -> SpawnPoint:
	for node: Node in get_tree().get_nodes_in_group("spawn_points"):
		if node is SpawnPoint and node.spawn_id == spawn_id:
			return node
	return null


func _apply_camera_limits() -> void:
	var limits := compute_camera_limits(
		_world_layer.get_used_rect(),
		_world_layer.tile_set.tile_size
	)
	var cam: Camera2D = $Player/Camera2D
	cam.limit_left   = limits.position.x
	cam.limit_top    = limits.position.y
	cam.limit_right  = limits.position.x + limits.size.x
	cam.limit_bottom = limits.position.y + limits.size.y


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if default_spawn == "":
		warnings.append("default_spawn is empty — player has no fallback spawn point.")
		return warnings
	var found := false
	for child: Node in find_children("*", "SpawnPoint", true, false):
		if (child as SpawnPoint).spawn_id == default_spawn:
			found = true
			break
	if not found:
		warnings.append("No SpawnPoint with spawn_id='%s' found in scene." % default_spawn)
	return warnings


static func compute_camera_limits(used_rect: Rect2i, tile_size: Vector2i) -> Rect2i:
	return Rect2i(
		used_rect.position.x * tile_size.x,
		used_rect.position.y * tile_size.y,
		used_rect.size.x * tile_size.x,
		used_rect.size.y * tile_size.y
	)
