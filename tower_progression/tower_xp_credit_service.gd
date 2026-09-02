class_name TowerXpCreditService
extends RefCounted

const GameStats = preload("res://stat_database.gd")

## Director threat is the stable currency shared by every enemy pool. Awarding
## XP linearly from it keeps equivalent waves valuable regardless of whether
## their threat is concentrated in a few heavies or many cheap enemies, while
## remaining independent from late-wave health scaling.
const DAMAGE_XP_PER_DIRECTOR_THREAT := 1.75
const ELITE_XP_MULTIPLIER := 2.0
const HORDE_XP_MULTIPLIER := 0.50
const PAYDAY_XP_MULTIPLIER := 0.50
const PRIMARY_DESCENDANT_XP_RATIO := 0.75
const KILL_XP_BUDGET_RATIO := 0.05
const SUPPORT_XP_CAP_RATIOS := {
	&"slow": 0.20,
	&"stun": 0.25,
	&"displacement": 0.30,
	&"reveal": 0.25,
	&"vulnerability": 0.35,
}
const SUPPORT_XP_RATE_RATIOS := {
	&"slow": 0.04,
	&"stun": 0.08,
	&"displacement": 0.04,
}


static func get_damage_xp(
	actual_damage: int,
	enemy: Node,
	_context: AttackContext = null
) -> float:
	if actual_damage <= 0 or not is_instance_valid(enemy):
		return 0.0
	var maximum_health_value: Variant = enemy.get("max_health")
	var maximum_health := maxi(
		int(maximum_health_value) if maximum_health_value != null else actual_damage,
		1
	)
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
	var director_cost := 1.0
	var enemy_id_value: Variant = enemy.get("enemy_id")
	var enemy_id := (
		StringName(enemy_id_value) if enemy_id_value != null else &""
	)
	var enemy_data: Dictionary = {}
	if GameStats.ENEMIES.has(enemy_id):
		enemy_data = GameStats.get_enemy(enemy_id)
		director_cost = maxf(float(enemy_data.get("director_cost", 1)), 1.0)
	var budget := DAMAGE_XP_PER_DIRECTOR_THREAT * director_cost
	if (
		int(enemy_data.get("split_count", 0)) > 0
		or int(enemy_data.get("summon_limit", 0)) > 0
	):
		budget *= PRIMARY_DESCENDANT_XP_RATIO
	if traits.has(&"elite"):
		budget *= ELITE_XP_MULTIPLIER
	if traits.has(&"horde"):
		budget *= HORDE_XP_MULTIPLIER
	if traits.has(&"payday"):
		budget *= PAYDAY_XP_MULTIPLIER
	var instance_multiplier_value: Variant = enemy.get("xp_budget_multiplier")
	if instance_multiplier_value != null:
		budget *= maxf(float(instance_multiplier_value), 0.0)
	return budget


static func award_control_xp(
	enemy: Node,
	attack_context: AttackContext,
	effect_id: StringName,
	effective_amount: float
) -> float:
	if (
		not is_instance_valid(enemy)
		or attack_context == null
		or effective_amount <= 0.0
		or not SUPPORT_XP_CAP_RATIOS.has(effect_id)
		or not SUPPORT_XP_RATE_RATIOS.has(effect_id)
	):
		return 0.0
	var budget := get_enemy_damage_xp_budget(enemy)
	return _claim_and_award_support_xp(
		enemy,
		attack_context,
		effect_id,
		budget * float(SUPPORT_XP_RATE_RATIOS[effect_id]) * effective_amount,
		budget * float(SUPPORT_XP_CAP_RATIOS[effect_id])
	)


static func award_reveal_xp(
	enemy: Node,
	attack_context: AttackContext
) -> float:
	if not is_instance_valid(enemy) or attack_context == null:
		return 0.0
	var budget := get_enemy_damage_xp_budget(enemy)
	var cap := budget * float(SUPPORT_XP_CAP_RATIOS[&"reveal"])
	return _claim_and_award_support_xp(
		enemy, attack_context, &"reveal", cap, cap
	)


static func award_vulnerability_xp(
	enemy: Node,
	support_context: AttackContext,
	assisted_damage: int,
	damage_context: AttackContext = null
) -> float:
	if (
		not is_instance_valid(enemy)
		or support_context == null
		or assisted_damage <= 0
		or (
			damage_context != null
			and damage_context.root_tower_instance_id
				== support_context.root_tower_instance_id
		)
	):
		return 0.0
	var budget := get_enemy_damage_xp_budget(enemy)
	var maximum_health_value: Variant = enemy.get("max_health")
	var maximum_health := maxi(
		int(maximum_health_value) if maximum_health_value != null else assisted_damage,
		1
	)
	var requested := (
		float(assisted_damage)
		/ float(maximum_health)
		* budget
	)
	return _claim_and_award_support_xp(
		enemy,
		support_context,
		&"vulnerability",
		requested,
		budget * float(SUPPORT_XP_CAP_RATIOS[&"vulnerability"])
	)


static func _claim_and_award_support_xp(
	enemy: Node,
	attack_context: AttackContext,
	effect_id: StringName,
	requested_xp: float,
	maximum_xp: float
) -> float:
	var root_tower := attack_context.get_root_tower()
	if (
		not is_instance_valid(root_tower)
		or not root_tower.has_method("award_support_xp")
		or not enemy.has_method("claim_support_xp")
	):
		return 0.0
	var awarded := float(enemy.claim_support_xp(
		attack_context.root_tower_instance_id,
		effect_id,
		maxf(requested_xp, 0.0),
		maxf(maximum_xp, 0.0)
	))
	if awarded > 0.0:
		root_tower.award_support_xp(awarded)
	return awarded
