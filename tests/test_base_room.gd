extends GutTest

func test_compute_camera_limits_simple() -> void:
	var limits := BaseRoom.compute_camera_limits(Rect2i(0, 0, 16, 12), Vector2i(16, 16))
	assert_eq(limits, Rect2i(0, 0, 256, 192))

func test_compute_camera_limits_offset() -> void:
	var limits := BaseRoom.compute_camera_limits(Rect2i(2, 1, 10, 8), Vector2i(16, 16))
	assert_eq(limits, Rect2i(32, 16, 160, 128))

func test_get_configuration_warnings_no_default_spawn() -> void:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = ""
	var warnings := room._get_configuration_warnings()
	assert_gt(warnings.size(), 0)
	room.free()

func test_resolve_spawn_snaps_to_tile_center() -> void:
	# Spawn points from YATI land on tile boundaries (multiples of 16).
	# The player must be snapped to the tile center (+8) so sprite feet
	# align with NPC sprites that use the same tile-row convention.
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "test"
	var sp := SpawnPoint.new()
	sp.spawn_id = "test"
	sp.position = Vector2(128, 144)  # tile boundary, not center
	room.add_child(sp)
	add_child(room)
	assert_eq(room.get_node("Player").position, Vector2(136, 152))  # snapped center
	room.queue_free()

func test_get_configuration_warnings_valid_spawn() -> void:
	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "default"
	var sp := SpawnPoint.new()
	sp.spawn_id = "default"
	room.add_child(sp)
	var warnings := room._get_configuration_warnings()
	assert_eq(warnings.size(), 0)
	room.free()

func test_resolve_spawn_uses_pending_position_when_armed() -> void:
	# (120, 88) is already a tile center → snap_to_grid is identity here.
	SceneManager.pending_position = Vector2(120, 88)
	SceneManager.pending_facing = Vector2i(-1, 0)
	SceneManager.has_pending_position = true

	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "unused"  # must be ignored while pending is armed (no SpawnPoint here)
	add_child(room)  # _ready() → _resolve_spawn()

	var player := room.get_node("Player") as Player
	assert_eq(player.position, Player.snap_to_grid(Vector2(120, 88), 16))
	assert_eq(player.facing, Vector2i(-1, 0))
	assert_false(SceneManager.has_pending_position, "flag is consumed after resolve")
	room.queue_free()

func test_resolve_spawn_ignores_pending_position_when_not_armed() -> void:
	SceneManager.has_pending_position = false
	SceneManager.pending_position = Vector2(999, 999)  # must be ignored

	var room := load("res://scenes/world/BaseRoom.tscn").instantiate() as BaseRoom
	room.default_spawn = "default"
	var sp := SpawnPoint.new()
	sp.spawn_id = "default"
	sp.position = Vector2(128, 144)
	room.add_child(sp)
	add_child(room)

	var player := room.get_node("Player") as Player
	assert_eq(player.position, Player.snap_to_grid(Vector2(128, 144), 16),
		"unarmed pending falls back to default_spawn, not pending_position")
	room.queue_free()
