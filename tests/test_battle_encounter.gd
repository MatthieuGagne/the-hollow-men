extends GutTest

var _encounter: Area2D


func before_each() -> void:
    _encounter = load("res://scenes/world/BattleEncounter.tscn").instantiate()
    add_child_autofree(_encounter)


func test_encounter_is_area2d() -> void:
    assert_true(_encounter is Area2D)


func test_encounter_has_collision_shape() -> void:
    var shape := _encounter.get_node_or_null("CollisionShape2D")
    assert_not_null(shape, "BattleEncounter must have a CollisionShape2D")


func test_encounter_has_visual_rect() -> void:
    var rect := _encounter.get_node_or_null("ColorRect")
    assert_not_null(rect, "BattleEncounter must have a ColorRect placeholder")
