extends GutTest

const SLOT: int = 0


func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func after_each() -> void:
	_remove_slot(SLOT)
	GameState.clear_flags()
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_save_then_read_round_trips_flags_and_location() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.set_flag("case_1_beat3_complete", false)
	var ok := SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	assert_true(ok, "save() should return true on success")

	# Simulate a restart: wipe in-memory flags, then read from disk.
	GameState.clear_flags()
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_eq(data.flags["intro_complete"], true)
	assert_eq(data.flags["case_1_beat3_complete"], false)
	assert_eq(data.current_scene, "res://scenes/world/Rooftop.tscn")
	assert_eq(data.spawn_point, "rooftop_start")
	assert_eq(data.save_version, SaveManager.CURRENT_VERSION)


func test_read_missing_slot_returns_null() -> void:
	assert_null(SaveManager.read(SLOT))


func test_save_emits_game_saved() -> void:
	watch_signals(SaveManager)
	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	assert_signal_emitted_with_parameters(SaveManager, "game_saved", [SLOT])


func test_apply_restores_flags_without_navigating() -> void:
	var data := SaveData.new()
	data.flags = {"intro_complete": true}
	data.current_scene = "res://scenes/world/Rooftop.tscn"
	SaveManager.apply(data, false)  # navigate = false: no scene swap in tests
	assert_eq(GameState.get_flag("intro_complete"), true)


func test_load_round_trip_restores_into_game_state() -> void:
	GameState.set_flag("intro_complete", true)
	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")
	GameState.clear_flags()

	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	SaveManager.apply(data, false)
	assert_eq(GameState.get_flag("intro_complete"), true)


func test_load_missing_slot_returns_false() -> void:
	assert_false(SaveManager.load(SLOT))


func test_new_game_clears_all_flags() -> void:
	GameState.set_flag("intro_complete", true)
	GameState.set_flag("case_1_beat3_complete", true)
	SaveManager.new_game(false)  # navigate = false: assert state only
	assert_eq(GameState._flags, {})


func test_new_game_emits_game_loaded_sentinel() -> void:
	watch_signals(SaveManager)
	SaveManager.new_game(false)
	assert_signal_emitted_with_parameters(SaveManager, "game_loaded", [-1])


func test_current_version_is_two() -> void:
	assert_eq(SaveManager.CURRENT_VERSION, 2)


func test_save_round_trips_progression_for_party_and_non_party() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	PartyManager.set_progression("reid", 4, 12)
	PartyManager.set_progression("iris", 2, 5)  # iris NOT in the party

	SaveManager.save(SLOT, "res://scenes/world/Rooftop.tscn", "rooftop_start")

	# Simulate a restart: wipe party runtime, then load.
	PartyManager._permanent_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()

	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)  # navigate = false
	assert_eq(PartyManager.get_level("reid"), 4)
	assert_eq(PartyManager.get_xp("reid"), 12)
	assert_eq(PartyManager.get_level("iris"), 2, "non-party progression persists")
	assert_eq(PartyManager.snapshot_roster(), ["reid"])


func test_apply_restores_roster_combatant_at_saved_level_full_hp() -> void:
	var reid: Combatant = Combatant.from_definition(load("res://characters/reid.tres"))
	PartyManager.add_member(reid)
	PartyManager.set_progression("reid", 3, 0)
	SaveManager.save(SLOT)

	PartyManager._permanent_members.clear()
	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)
	var members := PartyManager.get_active_members()
	assert_eq(members[0].level, 3)
	assert_eq(members[0].current_hp, members[0].max_hp, "HP restores to (grown) full on load")


func test_apply_legacy_v1_data_defaults_to_reid_level_one() -> void:
	var data := SaveData.new()  # roster=[] progression={} (legacy shape)
	data.flags = {"intro_complete": true}
	SaveManager.apply(data, false)
	assert_true(PartyManager.has_member("Reid"))
	assert_eq(PartyManager.get_level("reid"), 1)
