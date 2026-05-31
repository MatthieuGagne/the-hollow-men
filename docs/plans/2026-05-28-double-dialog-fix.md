# Double Dialog Fix Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix bug #97 — pressing E to interact causes the dialogue to open, close, then reopen with the same content.

**Architecture:** Two one-line changes in `player.gd:_unhandled_input`. The dismiss path (E pressed while dialogue open) currently (a) allows echo events via default `allow_echo=true`, and (b) does not set `_interact_awaiting_release=true`, leaving the door open for a re-trigger after the user releases E. Both omissions are fixed in place.

**Tech Stack:** GDScript, GUT test framework.

## Open questions (must resolve before starting)

- None.

---

## Batch 1 — Fix the input guard in player.gd

### Task 1: Write the failing GUT tests

**Files:**
- Modify: `tests/test_player.gd`

**Depends on:** none
**Parallelizable with:** none — shares output file with Task 2.

**Step 1: Write the failing GUT tests**

Add these two tests to the bottom of `tests/test_player.gd`:

```gdscript
func test_dismiss_press_sets_awaiting_release() -> void:
	# When E is pressed (non-echo) while dialogue is open, the dismiss path must
	# set _interact_awaiting_release so the user has to release before re-interacting.
	var player := Player.new()
	add_child(player)
	DialogueManager._dialogue_box.dismiss()  # ensure dialogue box starts idle
	player._input_blocked = true
	player._interact_awaiting_release = false

	var event := InputEventKey.new()
	event.physical_keycode = 69  # E key — mapped to "interact" in project.godot
	event.pressed = true
	event.echo = false
	player._unhandled_input(event)

	assert_true(player._interact_awaiting_release,
		"dismiss press must set _interact_awaiting_release=true")
	player.free()


func test_echo_press_does_not_trigger_dismiss_path() -> void:
	# An echo event (key held) must NOT trigger skip_or_dismiss while dialogue is open.
	# Verified by checking that _interact_awaiting_release stays false — the dismiss
	# path would set it to true after the fix.
	var player := Player.new()
	add_child(player)
	DialogueManager._dialogue_box.dismiss()
	player._input_blocked = true
	player._interact_awaiting_release = false

	var event := InputEventKey.new()
	event.physical_keycode = 69  # E key
	event.pressed = true
	event.echo = true  # echo event — should be ignored
	player._unhandled_input(event)

	assert_false(player._interact_awaiting_release,
		"echo press must NOT set _interact_awaiting_release (dismiss path must be skipped)")
	player.free()
```

**Step 2: Run tests to verify they fail**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd
```

Expected: `test_dismiss_press_sets_awaiting_release` FAILS (flag stays false), `test_echo_press_does_not_trigger_dismiss_path` MAY PASS or FAIL depending on current behaviour.

---

### Task 2: Apply the fix in player.gd

**Files:**
- Modify: `scripts/world/player.gd`

**Depends on:** Task 1 (shares `test_player.gd`; complete Task 1 first before committing)
**Parallelizable with:** none — must run after Task 1's tests confirmed failing.

**Step 1: Apply the two-line fix**

In `scripts/world/player.gd`, change lines 76-78 from:

```gdscript
	if event.is_action_pressed("interact") and _input_blocked:
		DialogueManager.skip_or_dismiss()
		return
```

to:

```gdscript
	if event.is_action_pressed("interact", false) and _input_blocked:
		_interact_awaiting_release = true
		DialogueManager.skip_or_dismiss()
		return
```

The two changes:
- `is_action_pressed("interact", false)` — `allow_echo=false` blocks key-repeat echo events from triggering `skip_or_dismiss()` while the dialogue is open.
- `_interact_awaiting_release = true` — after a dismiss press, the user must release E before another interaction is possible.

**Step 2: Run tests to verify they pass**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_player.gd
```

Expected: ALL tests in `test_player.gd` PASS, including the two new ones.

**Step 3: Run full test suite**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```

Expected: ALL tests pass, zero failures.

**Step 4: Refactor checkpoint**

Ask: Does this fix generalise, or did we hardcode something that breaks when N > 1?

The fix is structural (two boolean guards), not hardcoded to any specific interactable. Generalises correctly.

**Step 5: Commit**

```bash
git add scripts/world/player.gd tests/test_player.gd
git commit -m "fix: block echo events and set release guard on dialogue dismiss path"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1, then Task 2 | Task 2 must run after Task 1's tests are confirmed failing; both write to test_player.gd |

### Smoketest Checkpoint 1 — Interact once, dialogue opens and stays

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures.

**Step 3: Launch game and verify visually**
```bash
godot
```

Load `FourWindsBar`. Walk up to Holloway (the NPC at the bar). Press E once:
- Dialogue should open and stay open — no flash-close-reopen.
- Press E to advance or skip typing — dialogue should advance normally, NOT reopen.

Then walk to the desk `ExamineObject`. Press E once:
- Examine text should appear and stay.
- Press E to dismiss — dialogue closes, does NOT reopen.

**Step 4: Confirm with user**

Tell the user: "Walk up to Holloway, press E. Does the dialogue open cleanly and stay? Then walk to the desk, press E — does it open cleanly without a double-flash?" Wait for confirmation before closing the worktree.
