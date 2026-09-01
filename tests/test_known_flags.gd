extends GutTest


func test_all_known_flags_correct_type_no_issues() -> void:
	var result := KnownFlags.validate({
		"intro_complete": true,
		"case_1_beat3_complete": false,
	})
	assert_eq(result["warnings"], [])
	assert_eq(result["errors"], [])


func test_unknown_flag_warns_not_errors() -> void:
	var result := KnownFlags.validate({"not_in_manifest": true})
	assert_eq(result["warnings"].size(), 1)
	assert_eq(result["errors"], [])


func test_type_mismatch_is_error() -> void:
	# intro_complete is declared TYPE_BOOL in the manifest; feed a String.
	var result := KnownFlags.validate({"intro_complete": "yes"})
	assert_eq(result["errors"].size(), 1)
	assert_eq(result["warnings"], [])


func test_empty_flags_clean() -> void:
	var result := KnownFlags.validate({})
	assert_eq(result["warnings"], [])
	assert_eq(result["errors"], [])


func test_harness_flags_are_known() -> void:
	var flags := {
		"test_room_random_wins": 3,
		"test_room_pending_random": false,
		"test_room_pending_boss": false,
		"test_room_harness_complete": true,
	}
	var result := KnownFlags.validate(flags)
	assert_eq(result["warnings"].size(), 0, "harness flags must be in the manifest")
	assert_eq(result["errors"].size(), 0, "harness flag types must match")


func test_intro_beat_flags_are_known() -> void:
	var flags := {
		"rooftop_beat_complete": true,
		"beat2_vera_spoken": true,
		"heights_notice_examined": true,
		"heights_shopfront_examined": true,
		"ley_terminal_noticed": true,
	}
	var result := KnownFlags.validate(flags)
	assert_eq(result["warnings"].size(), 0, "intro beat flags must be in the manifest")
	assert_eq(result["errors"].size(), 0, "intro beat flag types must match")


func test_cutscene_zone_auto_flags_are_known() -> void:
	# CutsceneZone._fire() sets "zone_played_<dialogue_node>" for any
	# fire_on_scene_load zone. Every such zone in the game must be registered.
	var flags := {
		"zone_played_rooftop_surveillance": true,
		"zone_played_sprawl_aftermath_beat4": true,
	}
	var result := KnownFlags.validate(flags)
	assert_eq(result["warnings"].size(), 0, "zone auto-flags must be in the manifest")
	assert_eq(result["errors"].size(), 0)


func test_office_encounter_flags_are_known() -> void:
	var result := KnownFlags.validate({
		"office_encounter1_complete": true,
		"office_encounter2_complete": true,
	})
	assert_eq(result["warnings"], [], "office encounter flags must be registered")
	assert_eq(result["errors"], [])


func test_beats_3_6_auto_flags_are_known() -> void:
	# CutsceneZone._fire() sets "zone_played_<dialogue_node>" for every
	# fire_on_scene_load zone; each needs a manifest entry.
	var result := KnownFlags.validate({
		"zone_played_iris_intro_exit": true,
		"zone_played_intro_four_winds_beat6": true,
	})
	assert_eq(result["warnings"], [], "every fire_on_scene_load zone needs a manifest entry")
	assert_eq(result["errors"], [])


func test_bar_examined_is_known() -> void:
	# Set by three ExamineObjects in maps/four_winds_bar.tmx.
	var result := KnownFlags.validate({"bar_examined": true})
	assert_eq(result["warnings"], [], "bar_examined must not warn on save")
