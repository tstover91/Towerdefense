class_name TowerXpCreditService
extends RefCounted

## Stage 1 tuning values. XP levels are telemetry-only for now and do not alter
## tower stats, paid upgrades, paths, or sell prices.
const DAMAGE_XP_PER_POINT := 0.10
const KILL_XP := 5.0


static func get_damage_xp(actual_damage: int, _context: AttackContext = null) -> float:
	return float(maxi(actual_damage, 0)) * DAMAGE_XP_PER_POINT


static func get_kill_xp(_enemy: Node, _context: AttackContext = null) -> float:
	return KILL_XP
