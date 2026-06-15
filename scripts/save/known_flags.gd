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
