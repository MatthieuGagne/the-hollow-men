extends GutTest

## Guards the harness map wiring: the test room map must import as a single
## TileMapLayer named "test_room" (so TestRoom.tscn's world_layer_path resolves)
## with a walkable floor covering the spawn and boss-trigger cells.


func test_map_imports_as_single_tilemaplayer_named_test_room() -> void:
	var packed: PackedScene = load("res://maps/test_room.tmx")
	assert_not_null(packed, "test_room.tmx must import as a PackedScene")
	var root := packed.instantiate()
	assert_true(root is TileMapLayer, "single-layer map root must be a TileMapLayer")
	assert_eq(root.name, "test_room", "root node name must equal the TMX basename")
	root.free()


func test_floor_covers_spawn_and_boss_cells() -> void:
	var root: TileMapLayer = load("res://maps/test_room.tmx").instantiate()
	assert_eq(root.get_used_rect().size, Vector2i(14, 10), "floor rect must be 14x10")
	# Spawn lives at world (120,88) -> cell (7,5); boss marker at (56,88) -> cell (3,5).
	assert_ne(root.get_cell_source_id(Vector2i(7, 5)), -1, "spawn cell must have a floor tile")
	assert_ne(root.get_cell_source_id(Vector2i(3, 5)), -1, "boss cell must have a floor tile")
	root.free()
