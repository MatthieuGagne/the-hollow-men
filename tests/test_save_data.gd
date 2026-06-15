extends GutTest


func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 1)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")


func test_holds_assigned_values() -> void:
	var data := SaveData.new()
	data.flags = {"intro_complete": true}
	data.current_scene = "res://scenes/world/Rooftop.tscn"
	data.spawn_point = "rooftop_start"
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.current_scene, "res://scenes/world/Rooftop.tscn")
	assert_eq(data.spawn_point, "rooftop_start")
