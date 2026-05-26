extends GutTest

func test_spawn_id_from_export() -> void:
	var sp := SpawnPoint.new()
	sp.spawn_id = "entrance"
	add_child(sp)
	assert_eq(sp.spawn_id, "entrance")
	sp.free()

func test_spawn_id_populated_from_metadata() -> void:
	var sp := SpawnPoint.new()
	sp.set_meta("spawn_id", "four_winds_entrance")
	add_child(sp)
	assert_eq(sp.spawn_id, "four_winds_entrance")
	sp.free()

func test_spawn_id_export_takes_priority_over_metadata() -> void:
	var sp := SpawnPoint.new()
	sp.spawn_id = "explicit"
	sp.set_meta("spawn_id", "from_metadata")
	add_child(sp)
	assert_eq(sp.spawn_id, "explicit")
	sp.free()

func test_added_to_spawn_points_group() -> void:
	var sp := SpawnPoint.new()
	add_child(sp)
	assert_true(sp.is_in_group("spawn_points"))
	sp.free()
