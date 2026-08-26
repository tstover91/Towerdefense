class_name TowerXpCreditService
extends RefCounted

const GameStats = preload("res://stat_database.gd")

## Each enemy supplies a bounded XP pool regardless of round health scaling.
## Director cost lets genuinely tougher archetypes remain more valuable without
## allowing late-wave health multipliers to turn them into XP fountains.
const BASE_ENEMY_DAMAGE_XP_BUDGET := 3.0
const MAXIMUM_STANDARD_DAMAGE_XP_BUDGET := 24.0
const ELITE_XP_MULTIPLIER := 2.0
const HORDE_XP_MULTIPLIER := 0.65
const PAYDAY_XP_MULTIPLIER := 0.65
const BOSS_DAMAGE_XP_BUDGET := 60.0
const KILL_XP_BUDGET_RATIO := 0.15


static func get_damage_xp(
	actual_damage: int,
	enemy: Node,
	_context: AttackContext = null
) -> float:
	if actual_damage <= 0 or not is_instance_valid(enemy):
		return 0.0
	var maximum_health := maxi(int(enemy.get("max_health")), 1)
	return (
		float(actual_damage)
		/ float(maximum_health)
		* get_enemy_damage_xp_budget(enemy)
	)


static func get_kill_xp(enemy: Node, _context: AttackContext = null) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	return get_enemy_damage_xp_budget(enemy) * KILL_XP_BUDGET_RATIO


static func get_enemy_damage_xp_budget(enemy: Node) -> float:
	if not is_instance_valid(enemy):
		return 0.0
	var traits: Array = enemy.get("traits") if enemy.get("traits") is Array else []
	if traits.has(&"boss"):
		return BOSS_DAMAGE_XP_BUDGET
	var director_cost := 1.0
	var enemy_id := StringName(enemy.get("enemy_id"))
	if GameStats.ENEMIES.has(enemy_id):
		director_cost = maxf(
			float(GameStats.get_enemy(enemy_id).get("director_cost", 1)),
			1.0
		)
	var budget := minf(
		BASE_ENEMY_DAMAGE_XP_BUDGET * sqrt(director_cost),
		MAXIMUM_STANDARD_DAMAGE_XP_BUDGET
	)
	if traits.has(&"elite"):
		budget *= ELITE_XP_MULTIPLIER
	if traits.has(&"horde"):
		budget *= HORDE_XP_MULTIPLIER
	if traits.has(&"payday"):
		budget *= PAYDAY_XP_MULTIPLIER
	return budget
