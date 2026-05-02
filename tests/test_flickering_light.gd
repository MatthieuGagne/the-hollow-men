extends GutTest


func test_next_target_in_range() -> void:
	var light: FlickeringLight = FlickeringLight.new()
	add_child_autofree(light)
	for i: int in range(100):
		var target: float = light._next_target()
		assert_true(
			target >= light.min_energy and target <= light.max_energy,
			"_next_target() returned %f, expected in [%f, %f]" % [target, light.min_energy, light.max_energy]
		)


func test_next_duration_in_range() -> void:
	var light: FlickeringLight = FlickeringLight.new()
	add_child_autofree(light)
	for i: int in range(100):
		var duration: float = light._next_duration()
		assert_true(
			duration >= light.flicker_min_duration and duration <= light.flicker_max_duration,
			"_next_duration() returned %f, expected in [%f, %f]" % [duration, light.flicker_min_duration, light.flicker_max_duration]
		)
