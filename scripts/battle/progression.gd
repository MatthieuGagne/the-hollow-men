class_name Progression
extends RefCounted

## Pure XP/level/stat-growth math. No engine or autoload state — fully unit-testable.

const BASE_XP: int = 100
const CURVE_EXPONENT: float = 1.5
const MAX_LEVEL: int = 99


## XP required to advance FROM `level` to `level + 1`. Returns 0 at/after the cap.
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return roundi(BASE_XP * pow(float(level), CURVE_EXPONENT))


## Apply `gain` XP to a (level, xp-progress-into-level) pair.
## Returns {"level": int, "xp": int}. Crosses as many thresholds as the gain allows;
## carries the remainder; clamps to MAX_LEVEL (xp zeroed at the cap).
static func apply_xp(level: int, xp: int, gain: int) -> Dictionary:
	var lvl: int = level
	var pool: int = xp + gain
	while lvl < MAX_LEVEL:
		var needed: int = xp_to_next(lvl)
		if pool < needed:
			break
		pool -= needed
		lvl += 1
	if lvl >= MAX_LEVEL:
		pool = 0
	return {"level": lvl, "xp": pool}


## Level-scaled stat: base at level 1, +growth per level thereafter.
static func grown_stat(base: int, growth: int, level: int) -> int:
	return base + growth * (level - 1)
