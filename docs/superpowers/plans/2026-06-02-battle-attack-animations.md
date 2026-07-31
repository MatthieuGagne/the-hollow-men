# Battle Attack Animations — Party Lunge & Enemy Hit Flash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tactile visual feedback to battle attacks — party member lunges 20px left at impact, struck enemy flashes white-overbright 2–3 times, damage number spawns at lunge peak, all while ATB and input are frozen.

**Architecture:** `execute_action()` in `battle_scene.gd` becomes an `async` coroutine that sets `_state = ANIMATING` before the first `await`, runs lunge and flash tweens, deals damage at the lunge peak, then calls `_end_turn()` only after the full animation. `ANIMATING` state already exists in the enum and already blocks ATB (via the `_tick_atb` guard), so no structural state machine changes are needed. Healing paths (`confirm_party_target`, `_begin_party_targeting`) are untouched — they never go through the animation branch. Enemy turns (`_begin_enemy_turn`) are also untouched (R6 out of scope).

**Tech Stack:** GDScript 4 / Godot 4.6, GUT headless tests (`godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`)

---

## File Structure

| File | Change |
|------|--------|
| `scripts/battle/battle_scene.gd` | Add animation constants + `_start_enemy_flash()` helper; refactor `execute_action()` to be async with lunge/flash |
| `tests/test_battle_scene.gd` | Add 3 new tests for ANIMATING state transitions; update 10 existing tests to `await` the async action |

---

### Task 1: Write failing tests for ANIMATING state transitions

**Files:**
- Modify: `tests/test_battle_scene.gd`

These three tests verify the state machine behavior that the implementation must satisfy. They fail before Task 2.

- [ ] **Step 1: Add the three new tests at the bottom of `tests/test_battle_scene.gd` (before the final closing line)**

```gdscript
func test_execute_action_enters_animating_state() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_eq(_scene._state, _scene.BattleState.ANIMATING,
		"execute_action must immediately enter ANIMATING before tween completes")


func test_offensive_ability_enters_animating_state() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.ANIMATING,
		"offensive ability must enter ANIMATING state when attacker has enough PP")


func test_healing_confirm_skips_animating_state() -> void:
	var karim := _add_karim_to_party()
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(karim)
	_scene.execute_action("ability")  # enters SELECTING_ALLY (party-targeting path)
	_scene.confirm_party_target(reid)  # healing — must NOT go through ANIMATING
	assert_eq(_scene._state, _scene.BattleState.TICKING,
		"healing via confirm_party_target must go directly to TICKING, never ANIMATING")
```

- [ ] **Step 2: Run GUT to confirm all three new tests fail**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=test_battle_scene
```

Expected: 3 FAILs — `test_execute_action_enters_animating_state` and `test_offensive_ability_enters_animating_state` fail because `execute_action` currently goes to TICKING, not ANIMATING. `test_healing_confirm_skips_animating_state` passes (it's a regression guard — healing never touched ANIMATING). All other existing tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/test_battle_scene.gd
git commit -m "test: add failing tests for ANIMATING state transitions in execute_action"
```

---

### Task 2: Implement async execute_action with lunge and enemy flash

**Files:**
- Modify: `scripts/battle/battle_scene.gd`

This is the core implementation. `execute_action` becomes a coroutine: it sets `ANIMATING` synchronously (before any `await`), tweens the attacker sprite, deals damage and spawns numbers at peak, starts the enemy flash, waits for the return tween and flash completion, then calls `_end_turn()`.

- [ ] **Step 1: Add animation constants after the existing `const PP_COST_COLOR` line (line 39)**

Find this line:
```gdscript
const PP_COST_COLOR := Color(0.55, 0.20, 0.85)
```

Replace with:
```gdscript
const PP_COST_COLOR := Color(0.55, 0.20, 0.85)
const LUNGE_DISTANCE:      float = 20.0
const LUNGE_DURATION:      float = 0.1
const LUNGE_RETURN_DUR:    float = 0.15
const FLASH_PULSE_HALF:    float = 0.05   # each pulse = 2 × this (up + down)
const FLASH_PULSES:        int   = 3      # 3 pulses × 0.1s = 0.3s total
const FLASH_HOLD:          float = 0.15   # remaining flash after return (0.3 - 0.15)
const OVERBRIGHT:          Color = Color(2.0, 2.0, 2.0, 1.0)
```

- [ ] **Step 2: Add `_start_enemy_flash` helper before `_on_combatant_updated`**

Find this line:
```gdscript
func _on_combatant_updated(combatant: Combatant) -> void:
```

Insert before it:
```gdscript
func _start_enemy_flash(sprite: Sprite2D) -> void:
	var flash_tween := create_tween()
	for _i in range(FLASH_PULSES):
		flash_tween.tween_property(sprite, "modulate", OVERBRIGHT, FLASH_PULSE_HALF)
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, FLASH_PULSE_HALF)


```

- [ ] **Step 3: Replace `execute_action` entirely**

Find the entire function (lines 241–269):
```gdscript
func execute_action(action_name: String) -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_action_menu.hide()
	if action_name == "ability" \
			and _active != null \
			and _active.ability != null \
			and _active.ability.targets_party:
		_begin_party_targeting()
		return
	if not enemies.is_empty():
		var target: Combatant = enemies[0]
		var damage: int = 0
		match action_name:
			"attack":
				damage = Combatant.calculate_damage(_active, target)
			"ability":
				damage = _resolve_ability(_active, target)
		if damage > 0:
			target.take_damage(damage)
			_spawn_damage_number(damage, $EnemyContainer)
		if action_name == "ability" and _active != null and _active.ability != null:
			combatant_updated.emit(_active)
			var attacker_idx: int = party.find(_active)
			if attacker_idx >= 0:
				_spawn_damage_number(-_active.ability.pp_cost,
					$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
	_end_turn()
	_check_win_loss()
```

Replace with:
```gdscript
func execute_action(action_name: String) -> void:
	if _state != BattleState.AWAITING_INPUT:
		return
	_action_menu.hide()

	# Healing abilities route through party targeting — no animation
	if action_name == "ability" \
			and _active != null \
			and _active.ability != null \
			and _active.ability.targets_party:
		_begin_party_targeting()
		return

	# Resolve damage and PP cost synchronously before any await
	var damage: int = 0
	var target: Combatant = null
	if not enemies.is_empty():
		target = enemies[0]
		match action_name:
			"attack":
				damage = Combatant.calculate_damage(_active, target)
			"ability":
				damage = _resolve_ability(_active, target)

	# Emit PP HUD update now — PP was already spent by _resolve_ability
	if action_name == "ability" and _active != null and _active.ability != null:
		combatant_updated.emit(_active)

	if damage > 0 and target != null:
		var attacker_idx: int = party.find(_active)
		var attacker_sprite: Sprite2D = $PartyContainer.get_child(attacker_idx)
		var target_sprite: Sprite2D = $EnemyContainer.get_child(0)
		_state = BattleState.ANIMATING

		# Lunge toward enemy (negative x = left toward EnemyContainer)
		var origin_x: float = attacker_sprite.position.x
		var lunge_tween := create_tween()
		lunge_tween.tween_property(attacker_sprite, "position:x",
			origin_x - LUNGE_DISTANCE, LUNGE_DURATION)
		await lunge_tween.finished

		# Impact peak: apply damage, spawn numbers, start flash
		target.take_damage(damage)
		combatant_updated.emit(target)
		_spawn_damage_number(damage, $EnemyContainer)
		if action_name == "ability" and _active != null and _active.ability != null:
			_spawn_damage_number(-_active.ability.pp_cost,
				$PartyContainer.get_child(attacker_idx), PP_COST_COLOR)
		_start_enemy_flash(target_sprite)

		# Return to origin — runs concurrently with flash
		var return_tween := create_tween()
		return_tween.tween_property(attacker_sprite, "position:x",
			origin_x, LUNGE_RETURN_DUR)
		await return_tween.finished

		# Wait for the remaining flash time before ending turn (flash = 0.3s, return = 0.15s)
		await get_tree().create_timer(FLASH_HOLD).timeout

	_end_turn()
	_check_win_loss()
```

- [ ] **Step 4: Run GUT — Task 1 tests should now pass; existing tests will break**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=test_battle_scene
```

Expected: The 3 new tests from Task 1 now PASS. Approximately 10 existing tests FAIL — those that call `execute_action` for offensive actions and then immediately assert final state or damage without awaiting the async animation.

- [ ] **Step 5: Commit the implementation**

```bash
git add scripts/battle/battle_scene.gd
git commit -m "feat: async attack animation — party lunge and enemy flash in execute_action"
```

---

### Task 3: Update existing tests broken by the async execute_action

**Files:**
- Modify: `tests/test_battle_scene.gd`

All tests below call `execute_action` for offensive actions where `damage > 0`. Because `execute_action` is now async, state and damage are NOT settled immediately after the call — they settle after the full animation (~0.4s). Each test needs `await wait_for_signal(_scene, "player_turn_ended", 2.0)` to wait for the turn to complete before asserting. Tests that call `execute_action` on the no-PP path (damage == 0) remain synchronous and need no changes.

- [ ] **Step 1: Update `test_execute_action_returns_to_ticking`**

Find:
```gdscript
func test_execute_action_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_eq(_scene._state, _scene.BattleState.TICKING)
```

Replace with:
```gdscript
func test_execute_action_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_eq(_scene._state, _scene.BattleState.TICKING)
```

- [ ] **Step 2: Update `test_execute_action_hides_action_menu`**

No change needed — `_action_menu.hide()` is the first synchronous line in `execute_action`, so the menu is already hidden before any `await`. ✓ Skip this test.

- [ ] **Step 3: Update `test_execute_action_damages_enemy`**

Find:
```gdscript
func test_execute_action_damages_enemy() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_lt(shade.current_hp, hp_before, "Shade HP must decrease after Attack")
```

Replace with:
```gdscript
func test_execute_action_damages_enemy() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_lt(shade.current_hp, hp_before, "Shade HP must decrease after Attack")
```

- [ ] **Step 4: Update `test_execute_action_triggers_win_on_lethal_hit`**

Find:
```gdscript
func test_execute_action_triggers_win_on_lethal_hit() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1  # any hit kills it (min damage = 1)
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_eq(_scene._state, _scene.BattleState.ENDED,
		"State must be ENDED when all enemies are dead")
```

Replace with:
```gdscript
func test_execute_action_triggers_win_on_lethal_hit() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1  # any hit kills it (min damage = 1)
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_eq(_scene._state, _scene.BattleState.ENDED,
		"State must be ENDED when all enemies are dead")
```

- [ ] **Step 5: Update `test_battle_ended_signal_emitted_on_win`**

Find:
```gdscript
func test_battle_ended_signal_emitted_on_win() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1
	var reid: Combatant = _scene.party[0]
	watch_signals(_scene)
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	assert_signal_emitted_with_parameters(_scene, "battle_ended", [true])
```

Replace with:
```gdscript
func test_battle_ended_signal_emitted_on_win() -> void:
	var shade: Combatant = _scene.enemies[0]
	shade.current_hp = 1
	var reid: Combatant = _scene.party[0]
	watch_signals(_scene)
	_scene._begin_player_turn(reid)
	_scene.execute_action("attack")
	await wait_for_signal(_scene, "battle_ended", 2.0)
	assert_signal_emitted_with_parameters(_scene, "battle_ended", [true])
```

- [ ] **Step 6: Update `test_ability_damages_enemy_as_reid`**

Find:
```gdscript
func test_ability_damages_enemy_as_reid() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Piercing Strike must deal damage to Shade")
```

Replace with:
```gdscript
func test_ability_damages_enemy_as_reid() -> void:
	var reid: Combatant = _scene.party[0]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_lt(shade.current_hp, hp_before, "Piercing Strike must deal damage to Shade")
```

- [ ] **Step 7: Update `test_ability_damages_enemy_as_iris`**

Find:
```gdscript
func test_ability_damages_enemy_as_iris() -> void:
	var iris: Combatant = _scene.party[1]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(iris)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before, "Static Touch must deal damage to Shade")
```

Replace with:
```gdscript
func test_ability_damages_enemy_as_iris() -> void:
	var iris: Combatant = _scene.party[1]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(iris)
	_scene.execute_action("ability")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_lt(shade.current_hp, hp_before, "Static Touch must deal damage to Shade")
```

- [ ] **Step 8: Update `test_ability_returns_to_ticking`**

Find:
```gdscript
func test_ability_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_eq(_scene._state, _scene.BattleState.TICKING)
```

Replace with:
```gdscript
func test_ability_returns_to_ticking() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_eq(_scene._state, _scene.BattleState.TICKING)
```

- [ ] **Step 9: Update `test_player_turn_ended_signal_emitted_after_action`**

Find:
```gdscript
func test_player_turn_ended_signal_emitted_after_action() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	watch_signals(_scene)
	_scene.execute_action("attack")
	assert_signal_emitted(_scene, "player_turn_ended")
```

Replace with:
```gdscript
func test_player_turn_ended_signal_emitted_after_action() -> void:
	var reid: Combatant = _scene.party[0]
	_scene._begin_player_turn(reid)
	watch_signals(_scene)
	_scene.execute_action("attack")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_signal_emitted(_scene, "player_turn_ended")
```

- [ ] **Step 10: Update `test_margot_ability_deals_psy_damage`**

Find:
```gdscript
func test_margot_ability_deals_psy_damage() -> void:
	var margot: Combatant = _scene.party[3]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(margot)
	_scene.execute_action("ability")
	assert_lt(shade.current_hp, hp_before,
		"Void Calculus must deal PSY damage to Shade")
```

Replace with:
```gdscript
func test_margot_ability_deals_psy_damage() -> void:
	var margot: Combatant = _scene.party[3]
	var shade: Combatant = _scene.enemies[0]
	var hp_before: int = shade.current_hp
	_scene._begin_player_turn(margot)
	_scene.execute_action("ability")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_lt(shade.current_hp, hp_before,
		"Void Calculus must deal PSY damage to Shade")
```

- [ ] **Step 11: Update `test_ability_spawns_pp_cost_label_over_attacker`**

Find:
```gdscript
func test_ability_spawns_pp_cost_label_over_attacker() -> void:
	var reid: Combatant = _scene.party[0]
	var reid_sprite: Node2D = _scene.get_node("PartyContainer").get_child(0)
	var child_count_before: int = reid_sprite.get_child_count()
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	assert_gt(reid_sprite.get_child_count(), child_count_before,
		"a floating PP cost label must be spawned over the attacker's sprite after ability use")
```

Replace with:
```gdscript
func test_ability_spawns_pp_cost_label_over_attacker() -> void:
	var reid: Combatant = _scene.party[0]
	var reid_sprite: Node2D = _scene.get_node("PartyContainer").get_child(0)
	var child_count_before: int = reid_sprite.get_child_count()
	_scene._begin_player_turn(reid)
	_scene.execute_action("ability")
	await wait_for_signal(_scene, "player_turn_ended", 2.0)
	assert_gt(reid_sprite.get_child_count(), child_count_before,
		"a floating PP cost label must be spawned over the attacker's sprite after ability use")
```

- [ ] **Step 12: Run GUT — all tests must pass**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gtest=test_battle_scene
```

Expected: All tests PASS. Confirm by count — there should be 3 more tests than before Task 1 (the 3 new animation state tests).

- [ ] **Step 13: Run the full test suite to check for regressions**

```
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: All tests pass. No regressions in other test files.

- [ ] **Step 14: Commit**

```bash
git add tests/test_battle_scene.gd
git commit -m "test: update existing tests to await async execute_action animation"
```

---

## Tests NOT needing changes (reference)

These call `execute_action` but remain synchronous — either because they test the `damage == 0` no-animation path, or because the property they assert settles synchronously before the first `await`:

| Test | Reason stays sync |
|------|-------------------|
| `test_execute_action_hides_action_menu` | `_action_menu.hide()` is the 2nd line of `execute_action` — before any `await` |
| `test_ability_spends_pp` | PP spent by `_resolve_ability` — before any `await` |
| `test_margot_ability_spends_pp` | Same — PP spent sync |
| `test_ability_emits_combatant_updated_for_attacker` | `combatant_updated.emit(_active)` moved to sync position — before any `await` |
| `test_ability_does_not_damage_when_pp_insufficient` | PP = 0 → `damage == 0` → no animation → `_end_turn()` runs synchronously |
| `test_margot_ability_does_not_damage_when_pp_insufficient` | Same — no-PP path skips animation entirely |
| `test_party_ability_spawns_pp_cost_label_over_attacker` | Uses `confirm_party_target` — never goes through `execute_action` animation |

---

## Smoketest (manual)

After all tests pass:
1. Launch the game: `/run`
2. Walk into an enemy encounter to start a battle
3. Select "Attack" — Reid should visibly lunge left ~20px, pause at peak, the enemy flashes white 2–3 times, a damage number appears, then Reid returns to position before ATB resumes
4. Select "Ability" with Reid (Piercing Strike) — same lunge/flash sequence
5. Select "Ability" with Karim (Field Suture) → choose party target — no lunge, no flash
6. Let an enemy attack — no lunge from the enemy side
7. Verify ATB bars do not advance mid-animation (watch the bottom HUD)
