extends GutTest


func before_each() -> void:
	BattleContext.configure()  # reset to defaults between tests


func after_all() -> void:
	BattleContext.configure()


func test_defaults_are_empty() -> void:
	assert_eq(BattleContext.enemies, "")
	assert_eq(BattleContext.background_id, "")
	assert_eq(BattleContext.return_scene, "")
	assert_eq(BattleContext.return_spawn, "")


func test_configure_sets_all_fields() -> void:
	BattleContext.configure("territory_enforcer,shade", "alley",
		"res://scenes/world/FourWindsBar.tscn", "door")
	assert_eq(BattleContext.enemies, "territory_enforcer,shade")
	assert_eq(BattleContext.background_id, "alley")
	assert_eq(BattleContext.return_scene, "res://scenes/world/FourWindsBar.tscn")
	assert_eq(BattleContext.return_spawn, "door")


func test_reads_are_non_destructive() -> void:
	BattleContext.configure("shade", "alley", "res://world.tscn", "spawn")
	# First read — as BattleScene._spawn_enemies / _load_background would do
	assert_eq(BattleContext.enemies, "shade")
	assert_eq(BattleContext.background_id, "alley")
	# Second read — a retry reload re-enters BattleScene and reads again
	assert_eq(BattleContext.enemies, "shade")
	assert_eq(BattleContext.background_id, "alley")


func test_retry_path_preserves_enemy_list() -> void:
	BattleContext.configure("territory_enforcer,shade", "alley", "res://world.tscn", "spawn")
	var first_read := BattleContext.enemies
	var retry_read := BattleContext.enemies  # no trigger repopulates on retry
	assert_eq(first_read, "territory_enforcer,shade")
	assert_eq(retry_read, "territory_enforcer,shade",
		"retry must reuse the same enemy list (AC2)")


func test_second_configure_overwrites_with_no_leftover() -> void:
	BattleContext.configure("shade", "alley", "res://a.tscn", "spawnA")
	BattleContext.configure("territory_enforcer", "rooftop", "res://b.tscn", "spawnB")
	assert_eq(BattleContext.enemies, "territory_enforcer")
	assert_eq(BattleContext.background_id, "rooftop")
	assert_eq(BattleContext.return_scene, "res://b.tscn")
	assert_eq(BattleContext.return_spawn, "spawnB")


func test_configure_no_args_clears_all_fields() -> void:
	BattleContext.configure("shade", "alley", "res://a.tscn", "spawnA")
	BattleContext.configure()
	assert_eq(BattleContext.enemies, "")
	assert_eq(BattleContext.background_id, "")
	assert_eq(BattleContext.return_scene, "")
	assert_eq(BattleContext.return_spawn, "")
