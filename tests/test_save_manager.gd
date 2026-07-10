extends GutTest

const SLOT: int = 0

var _room: BaseRoom = null
var _prev_scene: Node = null


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


func before_each() -> void:
	GameState.clear_flags()
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()
	_install_base_room()


func after_each() -> void:
	_teardown_base_room()
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


func test_current_version_is_four() -> void:
	assert_eq(SaveManager.CURRENT_VERSION, 4)


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
	reid.set_level(3)  # mirror award_xp: live HP is synced to level before any save (#123)
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


func test_new_game_resets_party_progression_and_roster() -> void:
	PartyManager.set_progression("reid", 5, 30)
	PartyManager.add_member_at_level("iris", 5)
	SaveManager.new_game(false)  # navigate = false
	assert_eq(PartyManager.get_level("reid"), 1, "new game resets Reid to Lv1")
	assert_false(PartyManager.has_member("Iris"), "new game drops recruited members")
	var members := PartyManager.get_active_members()
	assert_eq(members.size(), 1)
	assert_eq(members[0].id, "reid")


func test_save_rejected_when_current_scene_not_base_room() -> void:
	# Swap the before_each room for a non-room scene; save must refuse.
	_teardown_base_room()
	var plain := Node2D.new()
	_prev_scene = get_tree().current_scene
	get_tree().root.add_child(plain)
	get_tree().current_scene = plain
	_remove_slot(SLOT)

	assert_false(SaveManager.save(SLOT), "save must fail when not in a BaseRoom")
	assert_false(
		FileAccess.file_exists(SaveManager._save_path(SLOT)),
		"no file may be written when the guard rejects the save"
	)

	get_tree().current_scene = _prev_scene
	plain.free()


func test_save_captures_player_position_and_facing() -> void:
	var player := _room.get_node("Player") as Player
	player.position = Vector2(120, 88)
	player.set_facing(Vector2i(-1, 0))

	assert_true(SaveManager.save(SLOT), "save succeeds inside a BaseRoom")
	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	assert_eq(data.player_position, Vector2(120, 88))
	assert_eq(data.player_facing, Vector2i(-1, 0))
	assert_true(data.has_player_position)


func test_apply_sets_scene_manager_pending_fields_when_position_saved() -> void:
	var data := SaveData.new()
	data.player_position = Vector2(64, 48)
	data.player_facing = Vector2i(1, 0)
	data.has_player_position = true

	SaveManager.apply(data, false)  # navigate=false: no scene swap in tests

	assert_eq(SceneManager.pending_position, Vector2(64, 48))
	assert_eq(SceneManager.pending_facing, Vector2i(1, 0))
	assert_true(SceneManager.has_pending_position)
	SceneManager.has_pending_position = false  # avoid leaking into other tests


func test_apply_leaves_pending_position_flag_false_for_legacy_save() -> void:
	SceneManager.has_pending_position = false
	var data := SaveData.new()  # has_player_position defaults false (legacy shape)

	SaveManager.apply(data, false)

	assert_false(
		SceneManager.has_pending_position,
		"legacy save must not arm the pending-position path"
	)
