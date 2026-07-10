extends Node

## Versioned save/load. Snapshots GameState flags (Yarn vars included via the
## C# bridge) + world location. State restore is split from navigation so logic
## is unit-testable without real scene transitions.

signal game_saved(slot: int)
signal game_loaded(slot: int)  ## slot == -1 means a fresh new_game()

const CURRENT_VERSION: int = 4
const STARTING_SCENE: String = "res://scenes/world/Rooftop.tscn"
const STARTING_SPAWN: String = ""


func _save_path(slot: int) -> String:
	return "user://hollow_men_save_%d.tres" % slot


## Snapshot current state to a slot. scene/spawn default to the live scene tree
## + SceneManager's pending spawn when omitted (so production callers pass nothing).
## Only succeeds inside a BaseRoom — mid-battle (or any non-room screen) saves are
## rejected with no file written (#146).
func save(slot: int, scene: String = "", spawn: String = "") -> bool:
	var room := get_tree().current_scene
	if not (room is BaseRoom):
		return false

	var data := SaveData.new()
	data.save_version = CURRENT_VERSION
	data.flags = GameState.snapshot_flags()
	data.current_scene = scene if not scene.is_empty() else _current_scene_path()
	data.spawn_point = spawn if not spawn.is_empty() else SceneManager.pending_spawn_point
	data.roster = PartyManager.snapshot_roster()
	data.progression = PartyManager.snapshot_progression()
	data.party_runtime = PartyManager.snapshot_party_runtime()

	var player := room.get_node("Player") as Player
	data.player_position = player.position
	data.player_facing = player.facing
	data.has_player_position = true

	var validation := KnownFlags.validate(data.flags)
	for w: String in validation["warnings"]:
		push_warning("SaveManager: %s" % w)
	for e: String in validation["errors"]:
		push_error("SaveManager: %s" % e)

	var err := ResourceSaver.save(data, _save_path(slot))
	if err != OK:
		push_error("SaveManager.save failed (err %d)" % err)
		return false
	game_saved.emit(slot)
	return true


## Read a slot from disk. Returns null if absent or unreadable. Uses
## CACHE_MODE_IGNORE so each read reflects on-disk bytes, not a cached resource.
func read(slot: int) -> SaveData:
	var path := _save_path(slot)
	if not ResourceLoader.exists(path):
		return null
	var data := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if data == null or not (data is SaveData):
		push_error("SaveManager.read: %s is not a SaveData" % path)
		return null
	if data.save_version > CURRENT_VERSION:
		push_warning(
			"SaveManager.read: save_version %d newer than CURRENT_VERSION %d"
			% [data.save_version, CURRENT_VERSION]
		)
	return data


## Restore a SaveData into the running game. navigate=false (tests) skips the
## scene transition so flag effects are observable without swapping the tree.
func apply(data: SaveData, navigate: bool = true) -> void:
	GameState.restore_flags(data.flags)
	PartyManager.restore_progression(data.progression)
	PartyManager.restore_roster(data.roster)
	PartyManager.restore_party_runtime(data.party_runtime)
	if data.has_player_position:
		SceneManager.pending_position = data.player_position
		SceneManager.pending_facing = data.player_facing
		SceneManager.has_pending_position = true
	if navigate:
		SceneManager.change_scene(data.current_scene, data.spawn_point)


## Convenience: read a slot and apply it. Returns false if the slot is absent.
func load(slot: int) -> bool:
	var data := read(slot)
	if data == null:
		return false
	apply(data)
	game_loaded.emit(slot)
	return true


## Start a fresh game: clear flags directly (the Yarn bridge's Clear() is a
## no-op) and reset to the starting scene. navigate=false (tests) skips travel.
func new_game(navigate: bool = true) -> void:
	GameState.clear_flags()
	PartyManager.reset_to_new_game()
	game_loaded.emit(-1)
	if navigate:
		SceneManager.change_scene(STARTING_SCENE, STARTING_SPAWN)


func _current_scene_path() -> String:
	var current := get_tree().current_scene
	return current.scene_file_path if current else ""
