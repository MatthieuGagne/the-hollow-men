extends GutTest

func _c() -> Combatant:
	return Combatant.from_definition(CombatantDefinition.new())

func test_self_returns_user() -> void:
	var u := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.SELF, false, u, null, [], []), [u])

func test_one_ally_returns_picked() -> void:
	var u := _c(); var p := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ALLY, false, u, p, [u, p], []), [p])

func test_all_allies_returns_living_party() -> void:
	var u := _c(); var p := _c(); var party: Array[Combatant] = [u, p]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ALL_ALLIES, false, u, null, party, []), party)

func test_one_enemy_returns_picked() -> void:
	var u := _c(); var e := _c()
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ENEMY, false, u, e, [], [e]), [e])

func test_all_enemies_returns_living_enemies() -> void:
	var u := _c(); var e := _c(); var foes: Array[Combatant] = [e, _c()]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ALL_ENEMIES, false, u, e, [], foes), foes)

func test_switchable_one_enemy_expanded_returns_all() -> void:
	var u := _c(); var e := _c(); var foes: Array[Combatant] = [e, _c()]
	# expanded=true simulates the player toggling single -> all
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ENEMY, true, u, e, [], foes), foes)

func test_switchable_one_ally_expanded_returns_all() -> void:
	var u := _c(); var party: Array[Combatant] = [u, _c()]
	assert_eq(BattleScene.resolve_recipients(Ability.TargetMode.ONE_ALLY, true, u, party[0], party, []), party)
