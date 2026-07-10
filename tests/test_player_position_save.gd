extends GutTest

const SLOT: int = 0

var _room: BaseRoom = null
var _prev_scene: Node = null


func before_each() -> void:
	_remove_slot(SLOT)
	SceneManager.has_pending_position = false


func after_each() -> void:
	_teardown_base_room()
	_remove_slot(SLOT)
	SceneManager.has_pending_position = false


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _install_base_room() -> BaseRoom:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""  # set BEFORE add: _ready() runs on entering the tree
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(room)
	get_tree().current_scene = room
	_room = room
	return room


func _teardown_base_room() -> void:
	if _room == null:
		return
	get_tree().current_scene = _prev_scene
	_room.free()
	_room = null


func test_position_and_facing_survive_save_read_apply_and_reroom() -> void:
	# 1. Save from a room with the player at a non-default position/facing (AC1).
	var room := _install_base_room()
	var player := room.get_node("Player") as Player
	player.position = Vector2(120, 88)  # already a tile center
	player.set_facing(Vector2i(-1, 0))
	assert_true(SaveManager.save(SLOT))
	_teardown_base_room()

	# 2. Read + apply (navigate=false): arms SceneManager's pending fields.
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_true(data.has_player_position)
	SaveManager.apply(data, false)
	assert_eq(SceneManager.pending_position, Vector2(120, 88))
	assert_eq(SceneManager.pending_facing, Vector2i(-1, 0))
	assert_true(SceneManager.has_pending_position)

	# 3. A fresh destination room resolves spawn from the armed pending fields.
	var dest := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	dest.default_spawn = "unused"  # must be skipped while pending is armed
	add_child(dest)  # _ready() → _resolve_spawn()
	var restored := dest.get_node("Player") as Player
	assert_eq(restored.position, Player.snap_to_grid(Vector2(120, 88), 16))
	assert_eq(restored.facing, Vector2i(-1, 0))
	assert_false(SceneManager.has_pending_position, "pending flag consumed by the destination room")
	dest.queue_free()


func test_legacy_save_without_position_falls_back_to_default_spawn() -> void:
	# AC3: a save with has_player_position=false spawns at default_spawn, unchanged.
	SceneManager.has_pending_position = false
	var data := SaveData.new()  # has_player_position defaults false
	SaveManager.apply(data, false)
	assert_false(SceneManager.has_pending_position, "legacy save leaves pending disarmed")

	var dest := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	dest.default_spawn = "default"
	var sp := SpawnPoint.new()
	sp.spawn_id = "default"
	sp.position = Vector2(64, 48)
	dest.add_child(sp)
	add_child(dest)
	var restored := dest.get_node("Player") as Player
	assert_eq(restored.position, Player.snap_to_grid(Vector2(64, 48), 16),
		"legacy load resolves default_spawn, not a restored position")
	dest.queue_free()
