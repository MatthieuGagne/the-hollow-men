extends BaseRoomTest

const SLOT: int = 0


func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)
	_install_base_room()


func after_each() -> void:
	_teardown_base_room()
	_remove_slot(SLOT)
	GameState.clear_flags()


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_rooftop_beat_complete_round_trips() -> void:
	GameState.set_flag("rooftop_beat_complete", true)
	assert_true(SaveManager.save(SLOT), "save must succeed with a BaseRoom current_scene")
	GameState.clear_flags()

	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_true(data.flags.has("rooftop_beat_complete"))
	assert_eq(data.flags["rooftop_beat_complete"], true)


func test_beat2_vera_spoken_round_trips() -> void:
	GameState.set_flag("beat2_vera_spoken", true)
	assert_true(SaveManager.save(SLOT))
	GameState.clear_flags()

	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_true(data.flags.has("beat2_vera_spoken"))
	assert_eq(data.flags["beat2_vera_spoken"], true)


func test_all_intro_flags_survive_save_without_warnings() -> void:
	var flags: Array[String] = [
		"rooftop_beat_complete",
		"beat2_vera_spoken",
		"heights_notice_examined",
		"heights_shopfront_examined",
		"ley_terminal_noticed",
		"zone_played_rooftop_surveillance",
	]
	for flag: String in flags:
		GameState.set_flag(flag, true)

	var result := KnownFlags.validate(GameState.snapshot_flags())
	assert_eq(result["warnings"], [], "no intro flag may be unregistered")
	assert_eq(result["errors"], [])

	assert_true(SaveManager.save(SLOT))
	var data := SaveManager.read(SLOT)
	assert_eq(data.flags.size(), flags.size())
