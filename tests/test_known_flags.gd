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
