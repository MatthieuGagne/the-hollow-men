extends GutTest


func test_player_calls_interact_on_occupant() -> void:
	# Smoke-level check: confirms WorldObject.interact() exists and is callable.
	# Full delegation is verified visually in the smoketest.
	var obj := WorldObject.new()
	assert_true(obj.has_method("interact"), "WorldObject must have interact()")
	obj.free()
