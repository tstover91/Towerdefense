class_name PrototypeEnemyDirector
extends RefCounted

const EnemyScript = preload("res://prototype/prototype_enemy.gd")

const ROLE_FODDER: StringName = &"fodder"
const ROLE_PRESSURE: StringName = &"pressure"
const ROLE_TANK: StringName = &"tank"
const ROLE_SUPPORT: StringName = &"support"

const MAX_WAVES := 20
const MAX_GROUPS_PER_WAVE := 32
const THREAT_BUDGETS: Array[int] = [
	8, 10, 14, 17, 21,
	25, 30, 36, 43, 52,
	62, 74, 88, 104, 122,
	143, 167, 194, 225, 270,
]
const ENEMY_RULES := {
	EnemyScript.TYPE_SOLDIER: {
		"role": ROLE_FODDER, "cost": 1, "weight": 100.0,
	},
	EnemyScript.TYPE_RUNNER: {
		"role": ROLE_PRESSURE, "cost": 1, "weight": 65.0,
		"successor": EnemyScript.TYPE_CARRIER,
	},
	EnemyScript.TYPE_GIANT: {
		"role": ROLE_TANK, "cost": 7, "weight": 42.0,
		"successor": EnemyScript.TYPE_GOLEM,
	},
	EnemyScript.TYPE_ARMORED: {
		"role": ROLE_TANK, "cost": 4, "weight": 32.0,
	},
	EnemyScript.TYPE_SHIELDED: {
		"role": ROLE_TANK, "cost": 5, "weight": 28.0,
	},
	# Costs include the four Soldiers released when the Carrier is defeated.
	EnemyScript.TYPE_CARRIER: {
		"role": ROLE_PRESSURE, "cost": 9, "weight": 20.0,
	},
	EnemyScript.TYPE_HEALER: {
		"role": ROLE_SUPPORT, "cost": 10, "weight": 16.0,
	},
	# Cost includes the Witch's expected Swarmling output.
	EnemyScript.TYPE_WITCH: {
		"role": ROLE_SUPPORT, "cost": 8, "weight": 18.0,
	},
	# Cost includes both Golemites. Split children spend no additional budget.
	EnemyScript.TYPE_GOLEM: {
		"role": ROLE_TANK, "cost": 55, "weight": 10.0,
	},
}
const STYLE_RULES := {
	&"steady": {"minimum_wave": 1, "weight": 1.4},
	&"burst": {
		"minimum_wave": 2, "maximum_wave": 12, "weight": 1.0,
		"required_roles": [ROLE_PRESSURE],
	},
	&"convoy": {
		"minimum_wave": 4, "weight": 1.0,
		"required_roles": [ROLE_TANK],
	},
	&"support_column": {
		"minimum_wave": 8, "weight": 0.9,
		"required_roles": [ROLE_TANK, ROLE_SUPPORT],
	},
	&"layered_assault": {
		"minimum_wave": 10, "weight": 1.0,
		"required_roles": [ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK],
	},
	&"summoner_escort": {
		"minimum_wave": 8, "weight": 0.75,
		"required_enemies": [EnemyScript.TYPE_WITCH],
		"required_roles": [ROLE_TANK],
	},
}

var rng := RandomNumberGenerator.new()
var run_seed := 1
var roster: Array[StringName] = []
var debut_plan: Dictionary = {}
var wave_plans: Array[Dictionary] = []


func generate_run(seed: int) -> Array[Dictionary]:
	run_seed = maxi(seed, 1)
	rng.seed = run_seed
	_build_roster()
	wave_plans.clear()
	var previous_style: StringName = &""
	for wave in range(1, MAX_WAVES + 1):
		var style := _choose_wave_style(wave, previous_style)
		if wave == MAX_WAVES:
			style = &"layered_assault"
		wave_plans.append(_build_wave_plan(wave, style))
		previous_style = style
	return wave_plans.duplicate(true)


func _build_roster() -> void:
	roster.assign([
		EnemyScript.TYPE_SOLDIER,
		EnemyScript.TYPE_RUNNER,
		EnemyScript.TYPE_GIANT,
		EnemyScript.TYPE_CARRIER,
		EnemyScript.TYPE_GOLEM,
	])
	var defense_choices: Array[StringName] = [
		EnemyScript.TYPE_ARMORED,
		EnemyScript.TYPE_SHIELDED,
	]
	var support_choices: Array[StringName] = [
		EnemyScript.TYPE_HEALER,
		EnemyScript.TYPE_WITCH,
	]
	var defense := defense_choices[rng.randi_range(0, defense_choices.size() - 1)]
	var support := support_choices[rng.randi_range(0, support_choices.size() - 1)]
	roster.append(defense)
	roster.append(support)
	debut_plan = {
		EnemyScript.TYPE_SOLDIER: 1,
		EnemyScript.TYPE_RUNNER: 2,
		EnemyScript.TYPE_GIANT: 4,
		defense: 5,
		EnemyScript.TYPE_CARRIER: 7,
		support: 8,
		EnemyScript.TYPE_GOLEM: 13,
	}


func _build_wave_plan(wave: int, style: StringName) -> Dictionary:
	var budget := THREAT_BUDGETS[wave - 1]
	var remaining := budget
	var groups: Array[Dictionary] = []
	var available := get_available_enemies(wave)
	var debuts := get_debut_enemies(wave)
	for debut in debuts:
		var debut_group := _build_debut_group(debut, available, remaining, wave)
		var debut_cost := get_group_cost(debut_group)
		if not debut_group.is_empty() and debut_cost <= remaining:
			groups.append(_make_group(debut_group, &"debut", groups.size()))
			remaining -= debut_cost
	if wave >= 14 and EnemyScript.TYPE_GOLEM in available:
		# Reserve more of the late budget for durable pushes. This prevents a
		# high threat budget from degenerating into a screen full of cheap units.
		var anchor_count := 1
		if wave >= 17:
			anchor_count = 2
		if wave >= MAX_WAVES:
			anchor_count = 3
		for _anchor in anchor_count:
			var apex_group: Array[StringName] = [EnemyScript.TYPE_GOLEM]
			var apex_cost := get_group_cost(apex_group)
			if apex_cost > remaining:
				break
			groups.append(_make_group(apex_group, &"convoy", groups.size()))
			remaining -= apex_cost

	var attempts := 0
	while remaining >= get_cheapest_cost(available) and groups.size() < MAX_GROUPS_PER_WAVE:
		var group_style := style
		var planning_available := available.duplicate()
		if _count_supports_in_groups(groups) >= _get_support_limit(wave):
			planning_available = planning_available.filter(
				func(enemy: StringName) -> bool:
					return get_enemy_role(enemy) != ROLE_SUPPORT
			)
			if group_style in [&"support_column", &"summoner_escort"]:
				group_style = &"convoy"
		var members := _build_formation(
			group_style, planning_available, wave, remaining
		)
		var group_cost := get_group_cost(members)
		if members.is_empty() or group_cost <= 0 or group_cost > remaining:
			attempts += 1
			if attempts < 4:
				continue
			members = _build_fallback_group(planning_available, remaining)
			group_cost = get_group_cost(members)
		if members.is_empty() or group_cost <= 0 or group_cost > remaining:
			break
		groups.append(_make_group(members, group_style, groups.size()))
		remaining -= group_cost
		attempts = 0

	return {
		"wave": wave,
		"scale": get_health_scale(wave),
		"style": style,
		"threat_budget": budget,
		"threat_spent": budget - remaining,
		"groups": groups,
		"available_enemies": available,
		"debut_enemies": debuts,
		"run_roster": roster.duplicate(),
	}


func _build_debut_group(
	debut: StringName,
	available: Array[StringName],
	max_cost: int,
	wave: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	var debut_cost := get_enemy_cost(debut)
	if debut_cost > max_cost:
		return group
	group.append(debut)
	var remaining := max_cost - debut_cost
	var desired_size := 3 if wave < 13 else 4
	while group.size() < desired_size:
		var escort := _choose_enemy_for_roles(
			[ROLE_FODDER, ROLE_PRESSURE], available, wave, remaining, group
		)
		if escort.is_empty():
			break
		group.append(escort)
		remaining -= get_enemy_cost(escort)
	return group


func _build_formation(
	style: StringName,
	available: Array[StringName],
	wave: int,
	max_cost: int
) -> Array[StringName]:
	match style:
		&"burst":
			return _build_burst(available, wave, max_cost)
		&"convoy":
			return _build_convoy(available, wave, max_cost)
		&"support_column":
			return _build_support_column(available, wave, max_cost, false)
		&"summoner_escort":
			return _build_support_column(available, wave, max_cost, true)
		&"layered_assault":
			return _build_layered_assault(available, wave, max_cost)
		_:
			return _build_steady(available, wave, max_cost)


func _build_steady(
	available: Array[StringName], wave: int, max_cost: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	var remaining := max_cost
	var desired_size := rng.randi_range(4, 7)
	while group.size() < desired_size:
		var role := _choose_role(wave, available, remaining, group)
		var enemy := _choose_enemy_for_roles([role], available, wave, remaining, group)
		if enemy.is_empty():
			enemy = _choose_any_enemy(available, wave, remaining, group)
		if enemy.is_empty():
			break
		group.append(enemy)
		remaining -= get_enemy_cost(enemy)
	return group


func _build_burst(
	available: Array[StringName], wave: int, max_cost: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	var remaining := max_cost
	var leader := _choose_enemy_for_roles(
		[ROLE_PRESSURE], available, wave, remaining, group
	)
	if leader.is_empty():
		return _build_steady(available, wave, max_cost)
	group.append(leader)
	remaining -= get_enemy_cost(leader)
	var desired_size := rng.randi_range(5, 8)
	while group.size() < desired_size:
		var enemy := _choose_enemy_for_roles(
			[ROLE_PRESSURE, ROLE_FODDER], available, wave, remaining, group
		)
		if enemy.is_empty():
			break
		group.append(enemy)
		remaining -= get_enemy_cost(enemy)
	return group


func _build_convoy(
	available: Array[StringName], wave: int, max_cost: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	var remaining := max_cost
	var tank := _choose_enemy_for_roles([ROLE_TANK], available, wave, remaining, group)
	if tank.is_empty():
		return _build_steady(available, wave, max_cost)
	group.append(tank)
	remaining -= get_enemy_cost(tank)
	var desired_size := rng.randi_range(4, 7)
	while group.size() < desired_size:
		var escort := _choose_enemy_for_roles(
			[ROLE_FODDER, ROLE_PRESSURE], available, wave, remaining, group
		)
		if escort.is_empty():
			break
		group.append(escort)
		remaining -= get_enemy_cost(escort)
	return group


func _build_support_column(
	available: Array[StringName],
	wave: int,
	max_cost: int,
	require_witch: bool
) -> Array[StringName]:
	var group: Array[StringName] = []
	var remaining := max_cost
	var support: StringName
	if require_witch and EnemyScript.TYPE_WITCH in available:
		support = EnemyScript.TYPE_WITCH
	elif not require_witch:
		support = _choose_enemy_for_roles(
			[ROLE_SUPPORT], available, wave, remaining, group
		)
	if support.is_empty() or get_enemy_cost(support) > remaining:
		return _build_convoy(available, wave, max_cost)
	var tank := _choose_enemy_for_roles(
		[ROLE_TANK], available, wave, remaining - get_enemy_cost(support), group
	)
	if tank.is_empty():
		return _build_steady(available, wave, max_cost)
	group.append(tank)
	remaining -= get_enemy_cost(tank)
	var front_escort := _choose_enemy_for_roles(
		[ROLE_FODDER, ROLE_PRESSURE], available, wave, remaining - get_enemy_cost(support), group
	)
	if not front_escort.is_empty():
		group.append(front_escort)
		remaining -= get_enemy_cost(front_escort)
	group.append(support)
	remaining -= get_enemy_cost(support)
	while group.size() < 6:
		var escort := _choose_enemy_for_roles(
			[ROLE_FODDER, ROLE_PRESSURE], available, wave, remaining, group
		)
		if escort.is_empty():
			break
		group.append(escort)
		remaining -= get_enemy_cost(escort)
	return group


func _build_layered_assault(
	available: Array[StringName], wave: int, max_cost: int
) -> Array[StringName]:
	var fodder: Array[StringName] = []
	var pressure: Array[StringName] = []
	var finishers: Array[StringName] = []
	var current: Array[StringName] = []
	var remaining := max_cost
	var desired_size := rng.randi_range(6, 9)
	for role in [ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK]:
		var enemy := _choose_enemy_for_roles([role], available, wave, remaining, current)
		if enemy.is_empty():
			continue
		current.append(enemy)
		remaining -= get_enemy_cost(enemy)
		if role == ROLE_FODDER:
			fodder.append(enemy)
		elif role == ROLE_PRESSURE:
			pressure.append(enemy)
		else:
			finishers.append(enemy)
	while current.size() < desired_size:
		var role := _choose_role(wave, available, remaining, current)
		var enemy := _choose_enemy_for_roles([role], available, wave, remaining, current)
		if enemy.is_empty():
			break
		current.append(enemy)
		remaining -= get_enemy_cost(enemy)
		if role == ROLE_FODDER:
			fodder.append(enemy)
		elif role == ROLE_PRESSURE:
			pressure.append(enemy)
		else:
			finishers.append(enemy)
	fodder.append_array(pressure)
	fodder.append_array(finishers)
	return fodder


func _build_fallback_group(
	available: Array[StringName], max_cost: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	var cheapest: StringName
	var cheapest_cost := 1 << 30
	for enemy in available:
		var cost := get_enemy_cost(enemy)
		if cost <= max_cost and cost < cheapest_cost:
			cheapest = enemy
			cheapest_cost = cost
	if not cheapest.is_empty():
		group.append(cheapest)
	return group


func _make_group(
	members: Array[StringName], style: StringName, group_index: int
) -> Dictionary:
	var interval := 0.48
	var gap := 0.90
	match style:
		&"debut":
			interval = 0.50
			gap = 0.95
		&"burst":
			interval = 0.26
			gap = 0.95
		&"convoy":
			interval = 0.52
			gap = 1.00
		&"support_column", &"summoner_escort":
			interval = 0.46
			gap = 1.05
		&"layered_assault":
			interval = 0.36
			gap = 1.05
	return {
		"members": members.duplicate(),
		"interval": interval,
		"gap": 0.0 if group_index == 0 else gap,
		"style": style,
		"threat": get_group_cost(members),
	}


func _choose_wave_style(wave: int, previous_style: StringName) -> StringName:
	var available := get_available_enemies(wave)
	var candidates: Array[StringName] = []
	for style_value in STYLE_RULES:
		var style := StringName(style_value)
		var rule: Dictionary = STYLE_RULES[style]
		if wave < int(rule.get("minimum_wave", 1)):
			continue
		if wave > int(rule.get("maximum_wave", MAX_WAVES)):
			continue
		if not _style_requirements_met(rule, available):
			continue
		candidates.append(style)
	if candidates.is_empty():
		return &"steady"
	# Vary consecutive waves whenever another valid recipe exists. Removing the
	# previous style after collection keeps dictionary order out of the decision.
	if candidates.size() > 1:
		candidates.erase(previous_style)
	var total_weight := 0.0
	for style in candidates:
		total_weight += float(STYLE_RULES[style].get("weight", 1.0))
	var roll := rng.randf_range(0.0, total_weight)
	for style in candidates:
		roll -= float(STYLE_RULES[style].get("weight", 1.0))
		if roll <= 0.0:
			return style
	return candidates.back()


func _style_requirements_met(
	rule: Dictionary, available: Array[StringName]
) -> bool:
	for enemy_value in Array(rule.get("required_enemies", [])):
		if StringName(enemy_value) not in available:
			return false
	for role_value in Array(rule.get("required_roles", [])):
		var role := StringName(role_value)
		if not available.any(
			func(enemy: StringName) -> bool: return get_enemy_role(enemy) == role
		):
			return false
	return true


func _choose_role(
	wave: int,
	available: Array[StringName],
	max_cost: int,
	current_group: Array[StringName]
) -> StringName:
	var weights := get_role_weights(wave)
	var candidates: Array[StringName] = []
	var candidate_weights: Array[float] = []
	var total_weight := 0.0
	for role in [ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK, ROLE_SUPPORT]:
		if role == ROLE_SUPPORT and _count_role(current_group, ROLE_SUPPORT) >= 1:
			continue
		if _enemies_for_roles([role], available, wave, max_cost, current_group).is_empty():
			continue
		var weight := float(weights.get(role, 0.0))
		if weight <= 0.0:
			continue
		candidates.append(role)
		candidate_weights.append(weight)
		total_weight += weight
	if candidates.is_empty():
		return ROLE_FODDER
	var roll := rng.randf_range(0.0, total_weight)
	for index in candidates.size():
		roll -= candidate_weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func _choose_enemy_for_roles(
	roles: Array[StringName],
	available: Array[StringName],
	wave: int,
	max_cost: int,
	current_group: Array[StringName]
) -> StringName:
	var candidates := _enemies_for_roles(
		roles, available, wave, max_cost, current_group
	)
	return _choose_weighted_enemy(candidates, wave)


func _choose_any_enemy(
	available: Array[StringName],
	wave: int,
	max_cost: int,
	current_group: Array[StringName]
) -> StringName:
	return _choose_weighted_enemy(
		_enemies_for_roles(
			[ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK, ROLE_SUPPORT],
			available,
			wave,
			max_cost,
			current_group
		),
		wave
	)


func _enemies_for_roles(
	roles: Array[StringName],
	available: Array[StringName],
	_wave: int,
	max_cost: int,
	current_group: Array[StringName]
) -> Array[StringName]:
	var candidates: Array[StringName] = []
	for enemy in available:
		var role := get_enemy_role(enemy)
		if role not in roles or get_enemy_cost(enemy) > max_cost:
			continue
		if role == ROLE_SUPPORT and _count_role(current_group, ROLE_SUPPORT) >= 1:
			continue
		candidates.append(enemy)
	return candidates


func _choose_weighted_enemy(
	candidates: Array[StringName], wave: int
) -> StringName:
	if candidates.is_empty():
		return &""
	var total_weight := 0.0
	for enemy in candidates:
		total_weight += _get_spawn_weight(enemy, wave)
	if total_weight <= 0.0:
		return candidates[0]
	var roll := rng.randf_range(0.0, total_weight)
	for enemy in candidates:
		roll -= _get_spawn_weight(enemy, wave)
		if roll <= 0.0:
			return enemy
	return candidates.back()


func _get_spawn_weight(enemy: StringName, wave: int) -> float:
	var rule: Dictionary = ENEMY_RULES[enemy]
	var weight := float(rule.get("weight", 1.0))
	var debut := int(debut_plan.get(enemy, wave))
	if wave == debut:
		weight *= 1.25
	if enemy == EnemyScript.TYPE_GOLEM and wave >= debut:
		weight *= lerpf(
			1.0,
			10.0,
			clampf(float(wave - debut) / 7.0, 0.0, 1.0)
		)
	var successor := StringName(rule.get("successor", &""))
	if not successor.is_empty() and debut_plan.has(successor):
		var successor_debut := int(debut_plan[successor])
		if wave >= successor_debut:
			weight *= lerpf(
				1.0,
				0.20,
				clampf(float(wave - successor_debut) / 3.0, 0.0, 1.0)
			)
	return weight


func get_available_enemies(wave: int) -> Array[StringName]:
	var available: Array[StringName] = []
	for enemy in roster:
		if int(debut_plan.get(enemy, MAX_WAVES + 1)) <= wave:
			available.append(enemy)
	return available


func get_debut_enemies(wave: int) -> Array[StringName]:
	var debuts: Array[StringName] = []
	for enemy in roster:
		if int(debut_plan.get(enemy, -1)) == wave:
			debuts.append(enemy)
	return debuts


func get_role_weights(wave: int) -> Dictionary:
	if wave <= 3:
		return {
			ROLE_FODDER: 70.0, ROLE_PRESSURE: 30.0,
			ROLE_TANK: 0.0, ROLE_SUPPORT: 0.0,
		}
	if wave <= 7:
		return {
			ROLE_FODDER: 40.0, ROLE_PRESSURE: 25.0,
			ROLE_TANK: 35.0, ROLE_SUPPORT: 0.0,
		}
	if wave <= 12:
		return {
			ROLE_FODDER: 25.0, ROLE_PRESSURE: 25.0,
			ROLE_TANK: 35.0, ROLE_SUPPORT: 15.0,
		}
	if wave <= 16:
		return {
			ROLE_FODDER: 15.0, ROLE_PRESSURE: 20.0,
			ROLE_TANK: 50.0, ROLE_SUPPORT: 15.0,
		}
	return {
		ROLE_FODDER: 10.0, ROLE_PRESSURE: 15.0,
		ROLE_TANK: 55.0, ROLE_SUPPORT: 20.0,
	}


func get_health_scale(wave: int) -> float:
	if wave <= 5:
		return 1.0
	if wave <= 10:
		return 1.15
	if wave <= 15:
		return 1.35
	return 1.60


func get_enemy_cost(enemy: StringName) -> int:
	return int(ENEMY_RULES.get(enemy, {"cost": 1}).get("cost", 1))


func get_enemy_role(enemy: StringName) -> StringName:
	return StringName(
		ENEMY_RULES.get(enemy, {"role": ROLE_FODDER}).get("role", ROLE_FODDER)
	)


func get_group_cost(members: Array[StringName]) -> int:
	var total := 0
	for enemy in members:
		total += get_enemy_cost(enemy)
	return total


func get_cheapest_cost(available: Array[StringName]) -> int:
	var cheapest := 1 << 30
	for enemy in available:
		cheapest = mini(cheapest, get_enemy_cost(enemy))
	return cheapest


func _count_role(group: Array[StringName], role: StringName) -> int:
	var count := 0
	for enemy in group:
		if get_enemy_role(enemy) == role:
			count += 1
	return count


func _count_supports_in_groups(groups: Array[Dictionary]) -> int:
	var count := 0
	for group in groups:
		for enemy_value in Array(group.get("members", [])):
			if get_enemy_role(StringName(enemy_value)) == ROLE_SUPPORT:
				count += 1
	return count


func _get_support_limit(wave: int) -> int:
	if wave <= 12:
		return 1
	if wave <= 16:
		return 2
	return 3
