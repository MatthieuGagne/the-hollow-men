class_name KnownFlags
extends RefCounted

## Manifest of every narrative flag the game uses, with its expected type.
## Seeded from the Yarn completion markers currently in dialogue/*.yarn.
## Grows as new flags are introduced. Numeric flags should use TYPE_FLOAT
## (Yarn numbers arrive as floats through the GameStateVariableStorage bridge).
const MANIFEST: Dictionary = {
	"intro_complete": TYPE_BOOL,
	"case_1_beat3_complete": TYPE_BOOL,
	"case_1_beat4_complete": TYPE_BOOL,
	# Intro Beats 1-2 (#93)
	"rooftop_beat_complete": TYPE_BOOL,
	"beat2_vera_spoken": TYPE_BOOL,
	"heights_notice_examined": TYPE_BOOL,
	"heights_shopfront_examined": TYPE_BOOL,
	"ley_terminal_noticed": TYPE_BOOL,
	# Intro Beats 3-6 (#94)
	"office_encounter1_complete": TYPE_BOOL,
	"office_encounter2_complete": TYPE_BOOL,
	# Pre-existing, previously unregistered: set by the bar ExamineObjects
	"bar_examined": TYPE_BOOL,
	# CutsceneZone auto-flags — set by _fire() for every fire_on_scene_load zone
	"zone_played_rooftop_surveillance": TYPE_BOOL,
	"zone_played_sprawl_aftermath_beat4": TYPE_BOOL,
	"zone_played_iris_intro_exit": TYPE_BOOL,
	"zone_played_intro_four_winds_beat6": TYPE_BOOL,
	# Experience-loop harness (#141)
	"test_room_random_wins": TYPE_INT,
	"test_room_pending_random": TYPE_BOOL,
	"test_room_pending_boss": TYPE_BOOL,
	"test_room_harness_complete": TYPE_BOOL,
}


## Returns {"warnings": Array[String], "errors": Array[String]}.
## Unknown flag (used but not in manifest) -> warning.
## Known flag with wrong value type -> error.
static func validate(flags: Dictionary) -> Dictionary:
	var warnings: Array[String] = []
	var errors: Array[String] = []
	for key: String in flags:
		if not MANIFEST.has(key):
			warnings.append("Unknown flag '%s' not in KnownFlags.MANIFEST" % key)
			continue
		var expected: int = MANIFEST[key]
		var actual: int = typeof(flags[key])
		if actual != expected:
			errors.append(
				"Flag '%s' type mismatch: expected %d, got %d" % [key, expected, actual]
			)
	return {"warnings": warnings, "errors": errors}
