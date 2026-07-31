# Party Runtime Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use the project `executing-plans` skill (NOT superpowers:executing-plans) to implement this plan task-by-task.

**Goal:** Persist each permanent party member's volatile runtime state (HP / PP / limit gauge / active status effects) across save and load.

**Architecture:** A new slim `PartyMemberSave` resource holds one member's volatile state. `SaveData` gains a `party_runtime: Array[PartyMemberSave]` field (bumping the save format to v3). `SaveManager.save()` snapshots the permanent roster's runtime into it; `SaveManager.apply()` overlays it onto the members already rebuilt by `restore_roster()`, matched by `definition_id`. `StatusEffect`s serialize inline as sub-resources, so durations survive with no manual rebuild. Ephemeral fields (`atb`, `skip_cooldown`, `ai_state`) are never persisted, so they reset on load by virtue of being absent.

**Tech Stack:** Godot 4.6 / GDScript, GUT (unit tests), Godot `Resource` serialization (`ResourceSaver`/`ResourceLoader`).

## Open questions (must resolve before starting)

None — all four design decisions were resolved during grill-me:
1. **Save version → v3** (the two version-asserting tests are updated; these edits were approved via the version-bump decision).
2. **Snapshot scope: permanent members only** (the exact set `restore_roster()` rebuilds, so every runtime entry overlays a member 1:1).
3. **Overlay match by `definition_id`** (order-independent; rosters hold unique ids).
4. **`active_effects` snapshot uses a shallow `.duplicate()`** of the array (decouples the save object from live state).

## Global Constraints

- Godot 4.6 / GDScript runtime only (no C# for this feature).
- Static typing throughout: `var foo: int = 0`, typed `@export`s, typed return values.
- TDD for all GDScript logic: failing GUT test first, then minimal implementation.
- GUT run command (all tests): `godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- GUT run command (single file): `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd`
- Commit after every task; every commit message ends with ` (#123)`.
- **Test-edit gate:** Tasks 2 and 4 modify existing tests (`test_defaults`, `test_loads_legacy_save_defaults_party_runtime`, `test_current_version_is_two`). These edits are a direct consequence of the user-approved v3 version bump. The executor must still surface them to the user before applying (per the project test-edit rule) — do not silently rewrite.

---

## Batch 1 — Party runtime persistence (Tasks 1–4)

### Task 1: `PartyMemberSave` resource

**Files:**
- Create: `scripts/save/party_member_save.gd`
- Test: `tests/test_party_member_save.gd`

**Interfaces:**
- Consumes: `StatusEffect` (existing `class_name`, `scripts/battle/status_effect.gd`).
- Produces: `class_name PartyMemberSave extends Resource` with `@export` fields:
  - `definition_id: String`
  - `current_hp: int`
  - `current_pp: int`
  - `limit_gauge: float`
  - `active_effects: Array[StatusEffect]`

**Depends on:** none
**Parallelizable with:** none — it is the foundational `PartyMemberSave` type that Tasks 2 and 3 import, so it must land first.

- [ ] **Step 1: Write the failing GUT test**

Create `tests/test_party_member_save.gd`:

```gdscript
extends GutTest


func test_defaults() -> void:
	var pms := PartyMemberSave.new()
	assert_eq(pms.definition_id, "")
	assert_eq(pms.current_hp, 0)
	assert_eq(pms.current_pp, 0)
	assert_eq(pms.limit_gauge, 0.0)
	assert_eq(pms.active_effects, [])


func test_holds_assigned_values_including_active_effects() -> void:
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -3
	effect.duration = 2

	var pms := PartyMemberSave.new()
	pms.definition_id = "reid"
	pms.current_hp = 12
	pms.current_pp = 4
	pms.limit_gauge = 55.0
	pms.active_effects = [effect]

	assert_eq(pms.definition_id, "reid")
	assert_eq(pms.current_hp, 12)
	assert_eq(pms.current_pp, 4)
	assert_eq(pms.limit_gauge, 55.0)
	assert_eq(pms.active_effects.size(), 1)
	assert_eq(pms.active_effects[0].effect_name, "weakened")
	assert_eq(pms.active_effects[0].duration, 2)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_member_save.gd`
Expected: FAIL — `PartyMemberSave` is not a known class (parse/identifier error).

- [ ] **Step 3: Write minimal implementation**

Create `scripts/save/party_member_save.gd`:

```gdscript
class_name PartyMemberSave
extends Resource

## Slim snapshot of one permanent party member's volatile runtime state (#123).
## Ephemeral fields (atb, skip_cooldown, ai_state) are deliberately excluded, so
## they reset to defaults on load. active_effects serialize natively as inline
## StatusEffect sub-resources (durations preserved) — no manual rebuild needed.

@export var definition_id: String = ""
@export var current_hp: int = 0
@export var current_pp: int = 0
@export var limit_gauge: float = 0.0
@export var active_effects: Array[StatusEffect] = []
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_member_save.gd`
Expected: PASS (2 tests).

- [ ] **Step 5: Refactor checkpoint**

Ask: "Does this generalize, or did I hard-code something that breaks when N > 1?" — Pure data resource, nothing to generalize. Proceed.

- [ ] **Step 6: Commit**

```bash
git add scripts/save/party_member_save.gd tests/test_party_member_save.gd
git commit -m "feat: add PartyMemberSave runtime-state resource (#123)"
```

---

### Task 2: `SaveData.party_runtime` field + save format v3

**Files:**
- Modify: `scripts/save/save_data.gd`
- Test: `tests/test_save_data.gd` (modify `test_defaults` and `test_loads_legacy_save_defaults_party_runtime`)

**Interfaces:**
- Consumes: `PartyMemberSave` (Task 1).
- Produces: `SaveData.party_runtime: Array[PartyMemberSave]` (default `[]`); `SaveData.save_version` default is now `3`.

**Depends on:** Task 1
**Parallelizable with:** Task 3 — different files (`save_data.gd` / `test_save_data.gd` vs `party_manager.gd` / `test_party_save.gd`); both need only Task 1.

> **Test-edit gate:** This task changes two existing assertions in `tests/test_save_data.gd`. Surface the diff to the user before applying (the change follows from the approved v3 bump).

- [ ] **Step 1: Write/adjust the failing GUT test**

In `tests/test_save_data.gd`, change `test_defaults` to expect v3 and the new field. Replace the existing `test_defaults`:

```gdscript
func test_defaults() -> void:
	var data := SaveData.new()
	assert_eq(data.save_version, 3)
	assert_eq(data.flags, {})
	assert_eq(data.current_scene, "")
	assert_eq(data.spawn_point, "")
	assert_eq(data.roster, [])
	assert_eq(data.progression, {})
	assert_eq(data.party_runtime, [])
```

In the same file, extend `test_loads_legacy_save_defaults_party_runtime` to also assert the new field defaults to `[]` for a legacy save. Add this assertion immediately after the existing `progression` assertion (before `_cleanup_legacy()`):

```gdscript
	assert_eq(data.party_runtime, [], "missing party_runtime must default to []")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: FAIL — `test_defaults` fails on `save_version` (still 2) and on the missing `party_runtime` property.

- [ ] **Step 3: Write minimal implementation**

Replace the full contents of `scripts/save/save_data.gd` with:

```gdscript
class_name SaveData
extends Resource

## Versioned save container.
## v2 (#141): adds party runtime — active roster + per-character progression.
## v3 (#123): adds party_runtime — per-member volatile state (HP/PP/limit/status).

@export var save_version: int = 3
@export var flags: Dictionary = {}
@export var current_scene: String = ""
@export var spawn_point: String = ""

## Active permanent-party member ids, in order.
@export var roster: Array[String] = []
## Per-character progression: { "<id>": {"level": int, "xp": int} } for all known characters.
@export var progression: Dictionary = {}
## Per-member volatile runtime state, one entry per permanent member (#123).
@export var party_runtime: Array[PartyMemberSave] = []
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_data.gd`
Expected: PASS (all tests in the file, including the two legacy-load tests).

- [ ] **Step 5: Refactor checkpoint**

Ask: "Does this generalize?" — Additive field with a safe default; legacy saves deserialize `party_runtime` to `[]`. Proceed.

- [ ] **Step 6: Commit**

```bash
git add scripts/save/save_data.gd tests/test_save_data.gd
git commit -m "feat: add SaveData.party_runtime field, bump save format to v3 (#123)"
```

---

### Task 3: `PartyManager` snapshot / restore of runtime

**Files:**
- Modify: `scripts/autoload/party_manager.gd` (add two methods under the existing `# --- Save/restore ---` section)
- Test: `tests/test_party_save.gd` (create)

**Interfaces:**
- Consumes: `PartyMemberSave` (Task 1); existing `Combatant`, `GameData.get_definition(id)`, `PartyManager._permanent_members`.
- Produces:
  - `PartyManager.snapshot_party_runtime() -> Array[PartyMemberSave]` — one entry per permanent member.
  - `PartyManager.restore_party_runtime(runtime: Array) -> void` — overlays onto already-rebuilt permanent members, matched by `definition_id`; call AFTER `restore_roster()`.

**Depends on:** Task 1
**Parallelizable with:** Task 2 — different files; both need only Task 1.

- [ ] **Step 1: Write the failing GUT test**

Create `tests/test_party_save.gd`:

```gdscript
extends GutTest

const SLOT: int = 0


func before_each() -> void:
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func after_each() -> void:
	_remove_slot(SLOT)
	PartyManager._permanent_members.clear()
	PartyManager._temporary_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()


func _remove_slot(slot: int) -> void:
	var path := SaveManager._save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func test_snapshot_captures_runtime_for_permanent_members_only() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	reid.current_hp = 7
	reid.current_pp = 3
	reid.limit_gauge = 42.0
	PartyManager.add_member(reid)

	var temp: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_temporary(temp)

	var snap := PartyManager.snapshot_party_runtime()
	assert_eq(snap.size(), 1, "only permanent members are snapshotted")
	assert_eq(snap[0].definition_id, "reid")
	assert_eq(snap[0].current_hp, 7)
	assert_eq(snap[0].current_pp, 3)
	assert_eq(snap[0].limit_gauge, 42.0)


func test_snapshot_active_effects_array_is_decoupled_from_live_member() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.duration = 2
	reid.active_effects = [effect]
	PartyManager.add_member(reid)

	var snap := PartyManager.snapshot_party_runtime()
	assert_eq(snap[0].active_effects.size(), 1)

	# Mutating the live member's array must not affect the snapshot (.duplicate()).
	reid.active_effects.append(StatusEffect.new())
	assert_eq(snap[0].active_effects.size(), 1, "snapshot array is decoupled")


func test_restore_overlays_runtime_onto_rebuilt_member_by_id() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_member(reid)
	var full_hp := reid.max_hp

	var entry := PartyMemberSave.new()
	entry.definition_id = "reid"
	entry.current_hp = 9
	entry.current_pp = 2
	entry.limit_gauge = 30.0
	var effect := StatusEffect.new()
	effect.effect_name = "weakened"
	effect.stat = StatusEffect.StatAxis.DEF
	effect.modifier = -4
	effect.duration = 3
	entry.active_effects = [effect]

	PartyManager.restore_party_runtime([entry])

	var m := PartyManager.get_active_members()[0]
	assert_ne(full_hp, 9, "precondition: saved HP differs from full HP")
	assert_eq(m.current_hp, 9)
	assert_eq(m.current_pp, 2)
	assert_eq(m.limit_gauge, 30.0)
	assert_eq(m.active_effects.size(), 1)
	assert_eq(m.active_effects[0].effect_name, "weakened")
	assert_eq(m.active_effects[0].duration, 3)


func test_restore_skips_entry_with_no_matching_member() -> void:
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	PartyManager.add_member(reid)
	var full_hp := reid.max_hp

	var entry := PartyMemberSave.new()
	entry.definition_id = "iris"  # not in the roster
	entry.current_hp = 1
	PartyManager.restore_party_runtime([entry])

	assert_eq(PartyManager.get_active_members().size(), 1)
	assert_eq(PartyManager.get_active_members()[0].current_hp, full_hp, "unmatched entry skipped")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_save.gd`
Expected: FAIL — `snapshot_party_runtime` / `restore_party_runtime` are undefined methods.

- [ ] **Step 3: Write minimal implementation**

In `scripts/autoload/party_manager.gd`, append these two methods at the end of the file (under the existing `# --- Save/restore ---` section, after `restore_roster`):

```gdscript
# Snapshot volatile runtime state (HP/PP/limit/status) for each permanent member.
# Ephemeral fields (atb, skip_cooldown, ai_state) are intentionally excluded, so
# they reset to defaults on the next load.
func snapshot_party_runtime() -> Array[PartyMemberSave]:
	var result: Array[PartyMemberSave] = []
	for m: Combatant in _permanent_members:
		var pms := PartyMemberSave.new()
		pms.definition_id = m.id
		pms.current_hp = m.current_hp
		pms.current_pp = m.current_pp
		pms.limit_gauge = m.limit_gauge
		pms.active_effects = m.active_effects.duplicate()
		result.append(pms)
	return result


# Overlay saved runtime state onto already-rebuilt permanent members, matched by
# definition_id. Call AFTER restore_roster(). Entries with no matching member are
# skipped; members with no entry keep their full-HP rebuilt state (legacy saves).
func restore_party_runtime(runtime: Array) -> void:
	for entry: PartyMemberSave in runtime:
		for m: Combatant in _permanent_members:
			if m.id == entry.definition_id:
				m.current_hp = entry.current_hp
				m.current_pp = entry.current_pp
				m.limit_gauge = entry.limit_gauge
				m.active_effects = entry.active_effects
				break
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_save.gd`
Expected: PASS (4 tests).

- [ ] **Step 5: Refactor checkpoint**

Ask: "Does this generalize when N > 1?" — `snapshot` iterates all permanent members; `restore` matches each entry by `definition_id` across the roster, so it is order-independent and works for any roster size. Proceed.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/party_manager.gd tests/test_party_save.gd
git commit -m "feat: snapshot/restore party runtime state in PartyManager (#123)"
```

---

### Task 4: Wire snapshot/restore into `SaveManager` + bump `CURRENT_VERSION`

**Files:**
- Modify: `scripts/autoload/save_manager.gd` (`CURRENT_VERSION`, `save()`, `apply()`)
- Test: `tests/test_save_manager.gd` (update the version test)
- Test: `tests/test_party_save.gd` (append end-to-end round-trip tests)

**Interfaces:**
- Consumes: `SaveData.party_runtime` (Task 2); `PartyManager.snapshot_party_runtime()` / `restore_party_runtime()` (Task 3).
- Produces: `SaveManager.CURRENT_VERSION == 3`; `save()` writes `data.party_runtime`; `apply()` overlays it after `restore_roster()`.

**Depends on:** Task 2, Task 3
**Parallelizable with:** none — it wires both prior tasks together and appends to `tests/test_party_save.gd` (Task 3's file).

> **Test-edit gate:** This task renames/edits `test_current_version_is_two` in `tests/test_save_manager.gd`. Surface the diff to the user before applying (follows from the approved v3 bump).

- [ ] **Step 1: Write the failing tests**

In `tests/test_save_manager.gd`, replace `test_current_version_is_two` with:

```gdscript
func test_current_version_is_three() -> void:
	assert_eq(SaveManager.CURRENT_VERSION, 3)
```

Append the following end-to-end tests to `tests/test_party_save.gd`:

```gdscript
func test_full_round_trip_restores_hp_pp_limit_and_debuff_duration() -> void:
	# AC1 + AC4
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	reid.current_hp = 8
	reid.current_pp = 3
	reid.limit_gauge = 50.0
	var debuff := StatusEffect.new()
	debuff.effect_name = "weakened"
	debuff.stat = StatusEffect.StatAxis.DEF
	debuff.modifier = -5
	debuff.duration = 2
	reid.active_effects = [debuff]
	PartyManager.add_member(reid)

	SaveManager.save(SLOT)

	# Simulate a restart: wipe party runtime, then read + apply from disk.
	PartyManager._permanent_members.clear()
	PartyManager._progression.clear()
	PartyManager._seed_progression()

	var data := SaveManager.read(SLOT)
	assert_not_null(data)
	SaveManager.apply(data, false)  # navigate = false: no scene swap in tests

	var m := PartyManager.get_active_members()[0]
	assert_eq(m.current_hp, 8, "HP restored")
	assert_eq(m.current_pp, 3, "PP restored")
	assert_eq(m.limit_gauge, 50.0, "limit restored")
	assert_eq(m.active_effects.size(), 1, "debuff restored")
	assert_eq(m.active_effects[0].effect_name, "weakened")
	assert_eq(m.active_effects[0].modifier, -5)
	assert_eq(m.active_effects[0].duration, 2, "remaining duration preserved")


func test_ephemeral_atb_and_skip_cooldown_reset_on_load() -> void:
	# AC2
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	reid.atb = 90.0
	reid.skip_cooldown = 4.0
	reid.current_hp = 5
	PartyManager.add_member(reid)
	SaveManager.save(SLOT)

	PartyManager._permanent_members.clear()
	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)

	var m := PartyManager.get_active_members()[0]
	assert_eq(m.atb, 0.0, "atb not persisted — resets to 0")
	assert_eq(m.skip_cooldown, 0.0, "skip_cooldown not persisted — resets to 0")
	assert_eq(m.current_hp, 5, "HP still restored alongside reset ephemerals")


func test_restored_member_is_independent_instance() -> void:
	# AC3
	var reid: Combatant = Combatant.from_definition(GameData.get_definition("reid"))
	reid.current_hp = 6
	PartyManager.add_member(reid)
	SaveManager.save(SLOT)

	var data := SaveManager.read(SLOT)
	SaveManager.apply(data, false)
	var restored := PartyManager.get_active_members()[0]

	assert_ne(restored, reid, "restored member is a fresh instance, not the saved object")
	restored.current_hp = 1
	assert_eq(reid.current_hp, 6, "original combatant is unaffected by the restored instance")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd`
Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_save.gd`
Expected: FAIL — `CURRENT_VERSION` is still 2; round-trip tests fail because `save()` does not yet write `party_runtime` and `apply()` does not overlay it (restored HP equals full HP, not the saved value).

- [ ] **Step 3: Write minimal implementation**

In `scripts/autoload/save_manager.gd`:

(a) Bump the version constant:

```gdscript
const CURRENT_VERSION: int = 3
```

(b) In `save()`, add the snapshot line immediately after `data.progression = PartyManager.snapshot_progression()`:

```gdscript
	data.party_runtime = PartyManager.snapshot_party_runtime()
```

(c) In `apply()`, add the overlay call immediately after `PartyManager.restore_roster(data.roster)`:

```gdscript
	PartyManager.restore_party_runtime(data.party_runtime)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_save_manager.gd`
Run: `godot_console --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_party_save.gd`
Expected: PASS in both files.

- [ ] **Step 5: Refactor checkpoint**

Ask: "Does this generalize when N > 1?" — `save()`/`apply()` delegate to the roster-wide PartyManager methods, so multiple members are handled uniformly. Proceed.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/save_manager.gd tests/test_save_manager.gd tests/test_party_save.gd
git commit -m "feat: persist party runtime through SaveManager, bump CURRENT_VERSION to 3 (#123)"
```

---

#### Parallel Execution Groups — Smoketest Checkpoint 1

| Group | Tasks | Notes |
|-------|-------|-------|
| A (sequential) | Task 1 | Foundational `PartyMemberSave` type; Tasks 2 & 3 import it — must complete first |
| B (parallel) | Task 2, Task 3 | Different files (`save_data.gd`/`test_save_data.gd` vs `party_manager.gd`/`test_party_save.gd`); both depend only on Task 1 |
| C (sequential) | Task 4 | Depends on Task 2 (`party_runtime` field) and Task 3 (PartyManager methods + appends to `test_party_save.gd`) |

### Smoketest Checkpoint 1 — save/load round-trips runtime state without errors

> **Smoketest scope note:** The exact HP/PP/limit/duration restoration is verified by GUT (AC1–AC4) because the overworld has no on-screen readout that survives a scene reload. The in-game smoketest is therefore a **regression + round-trip-without-error** check: the game boots, a battle runs, and the F5/F9 debug save/load round-trip completes cleanly.

**Step 1: Fetch and merge latest master**
```bash
git fetch origin && git merge origin/master
```

**Step 2: Run all GUT tests**
```bash
godot_console --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/
```
Expected: All tests pass, zero failures (new files `test_party_member_save.gd`, `test_party_save.gd` plus the updated `test_save_data.gd` / `test_save_manager.gd`).

**Step 3: Launch game and verify visually**

Use the `/run` skill (it handles worktree pre-flight — `make worktree-init` — and cache invalidation). Then, in the running game:
1. Walk in the TestRoom until a random encounter starts; let Reid take some damage, then finish the battle (return to the overworld).
2. Press **F5** to save → console prints `[debug] save slot 0: OK (...)`.
3. Press **F9** to load → console prints `[debug] loaded slot 0 (...)`.
4. Confirm the console shows **no** `push_error`/red errors during save or load, and the game remains stable and playable afterward.

**Step 4: Confirm with user**

Tell the user: "GUT covers the HP/PP/limit/status restoration (AC1–AC4). In-game, confirm F5 save and F9 load both print OK with no red errors and the game stays stable." Wait for confirmation before finishing the branch.

---

## Spec Coverage Map

| Requirement / AC | Task |
|---|---|
| R1 — `PartyMemberSave` resource with the five fields | Task 1 |
| R2 — `SaveData.party_runtime: Array[PartyMemberSave]` | Task 2 |
| R3 — Save snapshots each member, slim (no `atb`/`skip_cooldown`) | Task 3 (`snapshot_party_runtime`) + Task 4 (wiring) |
| R4 — Load rebuilds via `from_definition`, overlays hp/pp/limit, assigns `active_effects` | Task 3 (`restore_party_runtime` overlays onto roster rebuilt via `from_definition`) + Task 4 (wiring) |
| R5 — `active_effects` serialize natively as `StatusEffect` sub-resources | Task 1 (`@export Array[StatusEffect]`), verified by Task 4 round-trip |
| AC1 — Damage + debuff + limit → save → load restores all | Task 4 `test_full_round_trip_restores_hp_pp_limit_and_debuff_duration` |
| AC2 — `atb`/`skip_cooldown` not persisted | Task 4 `test_ephemeral_atb_and_skip_cooldown_reset_on_load` |
| AC3 — Restored members are independent instances | Task 4 `test_restored_member_is_independent_instance` |
| AC4 — GUT round-trip incl. `active_effects` durations; ephemerals excluded | Task 4 round-trip + Task 3 snapshot tests |
