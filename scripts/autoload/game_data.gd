extends Node

var _registry: Dictionary = {}

const SCAN_DIRS: Array[String] = [
	"res://characters/",
	"res://characters/enemies/",
]


func _ready() -> void:
	for dir_path: String in SCAN_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			push_warning("GameData: cannot open %s" % dir_path)
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				_try_register(dir_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


func _try_register(path: String) -> void:
	var res := load(path)
	if not res is Combatant:
		return
	var c := res as Combatant
	if c.id == "":
		return
	if _registry.has(c.id):
		push_warning("GameData: duplicate id '%s' found in %s — skipping" % [c.id, path])
		return
	_registry[c.id] = c


func get_combatant(id: String) -> Combatant:
	if not _registry.has(id):
		assert(false, "GameData: unknown combatant id '%s'" % id)
		return null
	return _registry[id]
