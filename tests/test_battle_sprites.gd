# tests/test_battle_sprites.gd
extends GutTest

var _scene: BattleScene

func before_each() -> void:
    _scene = preload("res://scenes/battle/BattleScene.tscn").instantiate()
    add_child_autofree(_scene)
    await get_tree().process_frame

func test_party_container_has_four_sprite2d_children() -> void:
    var party := _scene.get_node("PartyContainer")
    assert_eq(party.get_child_count(), 4)
    for i in range(4):
        assert_true(party.get_child(i) is Sprite2D,
            "slot %d should be Sprite2D" % i)

func test_karim_and_margot_have_no_color_modulate() -> void:
    # Karim (slot 2) and Margot (slot 3) color is baked into the PNG — modulate must be white
    var party := _scene.get_node("PartyContainer")
    for i in [2, 3]:
        var sprite := party.get_child(i) as Sprite2D
        assert_almost_eq(sprite.modulate.r, 1.0, 0.01,
            "slot %d modulate.r should be 1.0" % i)
        assert_almost_eq(sprite.modulate.g, 1.0, 0.01,
            "slot %d modulate.g should be 1.0" % i)
        assert_almost_eq(sprite.modulate.b, 1.0, 0.01,
            "slot %d modulate.b should be 1.0" % i)
