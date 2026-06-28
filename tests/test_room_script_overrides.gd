extends GutTest

## Regression guard for the script-override-as-header-attribute bug (#141).
##
## A script override on an instanced inherited-scene root MUST be written as a
## property line (`script = ExtResource(...)` below the node header), NOT as a
## `[node ... script=ExtResource(...)]` header attribute. The header form is
## silently ignored on load, so the override never binds and the root keeps the
## base scene's script (e.g. an inherited-BaseRoom scene would keep BaseRoom's
## script and its own `_ready` would never run). This guard scans every scene so
## the pattern stays enforced for all current and future inherited-scene roots.


func test_no_scene_declares_script_as_node_header_attribute() -> void:
	var offenders: Array[String] = []
	for path: String in _all_tscn_paths("res://scenes"):
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("[node") and trimmed.contains("script=ExtResource"):
				offenders.append(path)
				break
	assert_eq(offenders.size(), 0,
		"script overrides must be a `script = ExtResource(...)` property line, " +
		"never a [node ...] header attribute (it is silently ignored). Offenders: %s"
		% str(offenders))


func _all_tscn_paths(root: String) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = root.path_join(entry)
		if dir.current_is_dir():
			result.append_array(_all_tscn_paths(full))
		elif entry.ends_with(".tscn"):
			result.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
