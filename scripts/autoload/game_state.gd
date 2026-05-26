extends Node

var _flags: Dictionary = {}


func set_flag(key: String, value: Variant) -> void:
	assert(
		value is bool or value is float or value is int or value is String,
		"GameState.set_flag: value must be bool, float, int, or String — got type %d" % typeof(value)
	)
	_flags[key] = value


func get_flag(key: String, default: Variant = null) -> Variant:
	return _flags.get(key, default)


func has_flag(key: String) -> bool:
	return _flags.has(key)
