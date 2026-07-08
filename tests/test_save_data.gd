extends GutTest


func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 3)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")
	assert_eq(data.roster, [])
	assert_eq(data.progression, {})
	assert_eq(data.party_runtime, [])


func test_holds_assigned_values() -> void:
	var data := SaveData.new()
	data.flags = {"intro_complete": true}
	data.current_scene = "res://scenes/world/Rooftop.tscn"
	data.spawn_point = "rooftop_start"
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.current_scene, "res://scenes/world/Rooftop.tscn")
	assert_eq(data.spawn_point, "rooftop_start")


const _LEGACY_PATH: String = "user://test_legacy_save.tres"

# A hand-authored save resource that predates current_scene/spawn_point.
const _LEGACY_TRES: String = """[gd_resource type="Resource" script_class="SaveData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/save/save_data.gd" id="1"]

[resource]
script = ExtResource("1")
save_version = 1
flags = {
"intro_complete": true
}
"""


func _cleanup_legacy() -> void:
	if FileAccess.file_exists(_LEGACY_PATH):
		DirAccess.remove_absolute(_LEGACY_PATH)


func test_loads_legacy_save_missing_newer_fields_with_defaults() -> void:
	_cleanup_legacy()
	var f := FileAccess.open(_LEGACY_PATH, FileAccess.WRITE)
	f.store_string(_LEGACY_TRES)
	f.close()

	var data: SaveData = ResourceLoader.load(
		_LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(data)
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.current_scene, "", "missing field must default to \"\"")
	assert_eq(data.spawn_point, "", "missing field must default to \"\"")
	_cleanup_legacy()


func test_loads_legacy_save_defaults_party_runtime() -> void:
	_cleanup_legacy()
	var f := FileAccess.open(_LEGACY_PATH, FileAccess.WRITE)
	f.store_string(_LEGACY_TRES)
	f.close()

	var data: SaveData = ResourceLoader.load(
		_LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_not_null(data)
	assert_eq(data.roster, [], "missing roster must default to []")
	assert_eq(data.progression, {}, "missing progression must default to {}")
	assert_eq(data.party_runtime, [], "missing party_runtime must default to []")
	_cleanup_legacy()
