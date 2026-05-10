extends Node

var _blocking: Dictionary = {}
var _interactables: Dictionary = {}


func register_blocking(cell: Vector2i, node: Node) -> void:
	_blocking[cell] = node


func unregister_blocking(cell: Vector2i) -> void:
	_blocking.erase(cell)


func is_blocked(cell: Vector2i) -> bool:
	return _blocking.has(cell)


func register_interactable(cell: Vector2i, node: Node) -> void:
	_interactables[cell] = node


func unregister_interactable(cell: Vector2i) -> void:
	_interactables.erase(cell)


func get_interactable(cell: Vector2i) -> Node:
	return _interactables.get(cell, null)


func clear() -> void:
	_blocking.clear()
	_interactables.clear()
