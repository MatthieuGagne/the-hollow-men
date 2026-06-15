extends GutTest

func test_target_mode_defaults_one_enemy() -> void:
	var a := Ability.new()
	assert_eq(a.target_mode, Ability.TargetMode.ONE_ENEMY,
		"default target_mode must be ONE_ENEMY (preserves old targets_party=false default)")

func test_switchable_defaults_false() -> void:
	assert_false(Ability.new().switchable, "switchable must default to false")

func test_party_side_modes() -> void:
	var a := Ability.new()
	for m in [Ability.TargetMode.SELF, Ability.TargetMode.ONE_ALLY, Ability.TargetMode.ALL_ALLIES]:
		a.target_mode = m
		assert_true(a.targets_party_side(), "mode %d must be party-side" % m)
		assert_false(a.targets_enemy_side(), "mode %d must not be enemy-side" % m)

func test_enemy_side_modes() -> void:
	var a := Ability.new()
	for m in [Ability.TargetMode.ONE_ENEMY, Ability.TargetMode.ALL_ENEMIES]:
		a.target_mode = m
		assert_true(a.targets_enemy_side(), "mode %d must be enemy-side" % m)
		assert_false(a.targets_party_side(), "mode %d must not be party-side" % m)

func test_is_all() -> void:
	var a := Ability.new()
	a.target_mode = Ability.TargetMode.ALL_ENEMIES
	assert_true(a.is_all())
	a.target_mode = Ability.TargetMode.ONE_ENEMY
	assert_false(a.is_all())

func test_no_targets_party_property() -> void:
	# Regression: the boolean must be gone (capability replaced by target_mode).
	assert_false("targets_party" in Ability.new(),
		"targets_party must be removed in favor of target_mode")
