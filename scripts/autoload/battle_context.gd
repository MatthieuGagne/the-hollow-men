extends Node
## Typed transport carrying battle setup across the transition into BattleScene.
## Registered as the BattleContext autoload (/root/BattleContext) so it survives
## change_scene_to_file, which frees the world scene.
##
## An encounter trigger fully populates a FRESH context via configure() before
## SceneManager.change_scene. BattleScene reads these fields NON-DESTRUCTIVELY,
## so a defeat→retry reload (which re-enters BattleScene without re-triggering)
## reuses the same encounter instead of falling back to a default Shade.

## Comma-separated combatant ids (resolved via GameData). "" → BattleScene spawns its default Shade.
var enemies: String = ""
## Battle background id (file stem under assets/battle_backgrounds/). "" → "default".
var background_id: String = ""
## World scene to return to on victory. "" → BattleScene.WORLD_SCENE fallback.
var return_scene: String = ""
## Spawn point name within return_scene.
var return_spawn: String = ""


## Fully populate a fresh context, overwriting every field. Because all four
## fields are always assigned, nothing carries over from a previous encounter.
func configure(p_enemies: String = "", p_background_id: String = "",
		p_return_scene: String = "", p_return_spawn: String = "") -> void:
	enemies = p_enemies
	background_id = p_background_id
	return_scene = p_return_scene
	return_spawn = p_return_spawn
