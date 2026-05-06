extends Node

var _cells: Dictionary = {}


func register(cell: Vector2i, node: Node) -> void:
	_cells[cell] = node


func unregister(cell: Vector2i) -> void:
	_cells.erase(cell)


func has(cell: Vector2i) -> bool:
	return _cells.has(cell)


func get_occupant(cell: Vector2i) -> Node:
	return _cells.get(cell, null)


func is_blocked(cell: Vector2i) -> bool:
	var occupant: Node = get_occupant(cell)
	if occupant == null:
		return false
	return occupant.get_meta("blocks_movement", false)


func clear() -> void:
	_cells.clear()
