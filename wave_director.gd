class_name WaveDirector
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const SPAWN_STYLES := {
	&"steady": {
		"minimum_group_size": 6,
		"maximum_group_size": 10,
		"interval": 0.5,
		"gap_after_group": 0.8,
	},
	&"stream": {
		"minimum_group_size": 10,
		"maximum_group_size": 16,
		"interval": 0.15,
		"gap_after_group": 0.8,
	},
	&"burst": {
		"minimum_group_size": 7,
		"maximum_group_size": 11,
		"interval": 0.08,
		"gap_after_group": 1.1,
	},
	&"spaced": {
		"minimum_group_size": 5,
		"maximum_group_size": 8,
		"interval": 0.8,
		"gap_after_group": 0.8,
	},
}
const ROLE_FODDER := &"fodder"
const ROLE_PRESSURE := &"pressure"
const ROLE_TANK := &"tank"
const ROLE_SUPPORT := &"support"
const ROUND_STANDARD := &"standard"
const ROUND_HORDE := &"horde"
const ROUND_ELITE := &"elite"
const ROUND_GAUNTLET := &"gauntlet"
const ROUND_PAYDAY := &"payday"
const VARIANT_NORMAL := &"normal"
const VARIANT_HORDE := &"horde"
const VARIANT_ELITE := &"elite"
const VARIANT_PAYDAY := &"payday"
const HORDE_THREAT_MULTIPLIER := 2.0
const HORDE_GROUP_SIZE_MULTIPLIER := 2.0
const HORDE_SPAWN_DELAY_MULTIPLIER := 0.5
const EARLY_HORDE_THREAT_MULTIPLIER := 1.65
const EARLY_HORDE_GROUP_SIZE_MULTIPLIER := 1.6
const EARLY_HORDE_SPAWN_DELAY_MULTIPLIER := 0.65
const STANDARD_GROUP_SIZE_MULTIPLIER := 1.25
const STANDARD_FORMATION_DELAY_MULTIPLIER := 0.70
const SPACED_FORMATION_DELAY_MULTIPLIER := 0.85
const RANDOM_SPAWN_BREAK_CHANCE := 0.30
const RANDOM_SPAWN_BREAK_MIN_DURATION := 0.75
const RANDOM_SPAWN_BREAK_MAX_DURATION := 1.50
const WAVE_ROLE_WEIGHTS := GameStats.WAVE_ROLE_WEIGHTS
const FORMATION_ROLE_WEIGHTS := GameStats.FORMATION_ROLE_WEIGHTS

var rng: RandomNumberGenerator
var enemy_debut_plan: Dictionary = {}
var round_style_plan: Dictionary = {}
var round_number := 1
var current_round_type: StringName = ROUND_STANDARD
var current_wave_spawn_style: StringName = &"standard"
var last_gauntlet_spawn_style: StringName = &""
var gauntlet_style_repeat_count := 0
var active_enemy_count_provider: Callable


func _init(
	random_source: RandomNumberGenerator,
	count_provider: Callable = Callable()
) -> void:
	rng = random_source
	active_enemy_count_provider = count_provider


func generate_run_plan() -> void:
	enemy_debut_plan = GameStats.build_enemy_debut_plan(rng)
	round_style_plan = GameStats.build_round_style_plan(rng, enemy_debut_plan)


func set_round_context(
	wave: int,
	round_type: StringName,
	spawn_style: StringName
) -> void:
	round_number = wave
	current_round_type = round_type
	current_wave_spawn_style = spawn_style


func reset_round_style_memory() -> void:
	last_gauntlet_spawn_style = &""
	gauntlet_style_repeat_count = 0


func choose_wave_spawn_style(wave: int) -> StringName:
	if round_style_plan.has(wave):
		return StringName(round_style_plan[wave])
	var available := get_available_enemies(wave)
	return GameStats.choose_weighted_wave_style(
		GameStats.get_eligible_wave_styles(wave, available),
		rng
	)


func get_wave_duration(wave: int) -> float:
	return GameStats.get_round_duration(wave)


func get_wave_threat_rate(wave: int) -> float:
	return (
		GameStats.get_round_threat_budget(wave)
		/ maxf(GameStats.get_round_duration(wave), 0.01)
	)


func get_horde_threat_multiplier(wave: int) -> float:
	return EARLY_HORDE_THREAT_MULTIPLIER if wave <= 6 else HORDE_THREAT_MULTIPLIER


func get_horde_group_size_multiplier(wave: int) -> float:
	return (
		EARLY_HORDE_GROUP_SIZE_MULTIPLIER
		if wave <= 6
		else HORDE_GROUP_SIZE_MULTIPLIER
	)


func get_horde_spawn_delay_multiplier(wave: int) -> float:
	return (
		EARLY_HORDE_SPAWN_DELAY_MULTIPLIER
		if wave <= 6
		else HORDE_SPAWN_DELAY_MULTIPLIER
	)


func get_available_enemies(wave: int) -> Array[StringName]:
	if enemy_debut_plan.is_empty():
		generate_run_plan()
	return GameStats.get_available_enemy_ids(wave, enemy_debut_plan)


func build_director_group() -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	if current_round_type == ROUND_PAYDAY:
		available = available.filter(
			func(enemy_id: StringName) -> bool:
				var role: StringName = GameStats.get_enemy(enemy_id).get(
					"role",
					ROLE_FODDER
				)
				return role in [ROLE_FODDER, ROLE_PRESSURE]
		)
	if available.is_empty():
		return []

	var group_style := current_wave_spawn_style
	if current_round_type == ROUND_GAUNTLET:
		group_style = choose_gauntlet_spawn_style()
	elif current_round_type == ROUND_PAYDAY:
		group_style = choose_payday_spawn_style()
	var group_size := get_director_group_size(group_style)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		group_size = maxi(
			1,
			roundi(group_size * get_horde_group_size_multiplier(round_number))
		)
	var enemy_queue := build_role_based_enemy_queue(
		group_style,
		group_size,
		available
	)

	var schedule: Array[Dictionary]
	match group_style:
		&"pulses":
			schedule = build_pulse_schedule(enemy_queue)
		&"swarm_batch":
			schedule = build_swarm_batch_schedule(enemy_queue)
		&"convoy":
			schedule = build_convoy_schedule(enemy_queue)
		&"hidden_probe":
			schedule = build_hidden_probe_schedule(enemy_queue)
		&"splitter_pack":
			schedule = build_splitter_pack_schedule(enemy_queue)
		&"support_column":
			schedule = build_support_column_schedule(enemy_queue)
		&"rush_screen":
			schedule = build_rush_screen_schedule(enemy_queue)
		&"summoner_escort":
			schedule = build_summoner_escort_schedule(enemy_queue)
		&"elite_escort":
			schedule = build_elite_escort_schedule(enemy_queue)
		&"layered_assault":
			schedule = build_layered_assault_schedule(enemy_queue)
		&"boss_rehearsal":
			schedule = build_boss_rehearsal_schedule(enemy_queue)
		&"stream", &"burst", &"spaced":
			schedule = build_fixed_style_schedule(enemy_queue, group_style)
		_:
			schedule = build_standard_schedule(enemy_queue)
	if current_round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		var spawn_variant := (
			VARIANT_PAYDAY
			if current_round_type == ROUND_PAYDAY
			else VARIANT_HORDE
		)
		apply_spawn_schedule_variant(
			schedule,
			spawn_variant,
			get_horde_spawn_delay_multiplier(round_number)
		)
	apply_random_spawn_break(schedule)
	return schedule


func apply_random_spawn_break(schedule: Array[Dictionary]) -> void:
	if schedule.is_empty() or rng.randf() >= RANDOM_SPAWN_BREAK_CHANCE:
		return
	var break_duration := rng.randf_range(
		RANDOM_SPAWN_BREAK_MIN_DURATION,
		RANDOM_SPAWN_BREAK_MAX_DURATION
	)
	schedule.back()["delay_after"] = (
		float(schedule.back().get("delay_after", 0.1)) + break_duration
	)
	schedule.back()["random_break_after"] = break_duration


func choose_gauntlet_spawn_style() -> StringName:
	var styles: Array[StringName] = [
		&"pulses", &"swarm_batch", &"convoy", &"layered_assault",
		&"elite_escort", &"stream",
	]
	if gauntlet_style_repeat_count >= 2:
		styles.erase(last_gauntlet_spawn_style)
	var selected := styles[rng.randi_range(0, styles.size() - 1)]
	if selected == last_gauntlet_spawn_style:
		gauntlet_style_repeat_count += 1
	else:
		last_gauntlet_spawn_style = selected
		gauntlet_style_repeat_count = 1
	return selected


func choose_payday_spawn_style() -> StringName:
	var styles: Array[StringName] = [&"stream", &"pulses", &"swarm_batch", &"burst"]
	return styles[rng.randi_range(0, styles.size() - 1)]


func apply_spawn_schedule_variant(
	schedule: Array[Dictionary],
	spawn_variant: StringName,
	delay_multiplier: float
) -> void:
	for spawn_event in schedule:
		if not spawn_event.has("variant"):
			spawn_event["variant"] = spawn_variant
		spawn_event["delay_after"] = maxf(
			float(spawn_event.get("delay_after", 0.1)) * delay_multiplier,
			0.01
		)


func build_role_based_enemy_queue(
	style_name: StringName,
	group_size: int,
	available: Array[StringName]
) -> Array[StringName]:
	var group: Array[StringName] = []
	var recipe_style := style_name
	if recipe_style == &"standard" or recipe_style == &"boss_escort":
		recipe_style = &"steady"

	var forced_roles: Array[StringName] = []
	match style_name:
		&"convoy", &"elite_escort":
			forced_roles = [ROLE_TANK]
		&"support_column":
			forced_roles = [ROLE_SUPPORT]
		&"rush_screen", &"layered_assault":
			forced_roles = [ROLE_TANK, ROLE_PRESSURE]

	for forced_role in forced_roles:
		var forced_enemy := choose_enemy_for_role(
			forced_role, available, group, group_size
		)
		if not forced_enemy.is_empty():
			group.append(forced_enemy)
	var forced_enemy_id: StringName = &""
	match style_name:
		&"hidden_probe":
			forced_enemy_id = &"hidden"
		&"splitter_pack":
			forced_enemy_id = &"splitter"
		&"rush_screen":
			forced_enemy_id = &"rusher"
		&"summoner_escort":
			forced_enemy_id = &"summoner"
		&"boss_rehearsal":
			forced_enemy_id = &"summoner" if &"summoner" in available else &"regenerator"
	if not forced_enemy_id.is_empty() and forced_enemy_id in available:
		if forced_enemy_id not in group and group.size() < group_size:
			group.append(forced_enemy_id)

	if style_name == &"standard" or style_name == &"boss_escort":
		var leader_role := choose_formation_role(
			recipe_style, available, group, group_size
		)
		var leader := choose_enemy_for_role(
			leader_role, available, group, group_size
		)
		if not leader.is_empty():
			group.push_front(leader)
			recipe_style = GameStats.get_enemy(leader).get("spawn_style", &"steady")

	while group.size() < group_size:
		var role := choose_formation_role(
			recipe_style, available, group, group_size
		)
		var enemy_id := choose_enemy_for_role(
			role, available, group, group_size
		)
		if enemy_id.is_empty():
			break
		group.append(enemy_id)
	return group


func choose_formation_role(
	style_name: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> StringName:
	var wave_weights := get_wave_role_weights(round_number)
	var formation_weights: Dictionary = FORMATION_ROLE_WEIGHTS.get(
		style_name,
		FORMATION_ROLE_WEIGHTS[&"steady"]
	)
	var roles: Array[StringName] = [
		ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK, ROLE_SUPPORT,
	]
	var candidates: Array[StringName] = []
	var candidate_weights: Array[float] = []
	var total_weight := 0.0
	for role in roles:
		if role == ROLE_SUPPORT and count_role_in_group(current_group, ROLE_SUPPORT) >= 1:
			continue
		if get_valid_enemies_for_role(
			role, available, current_group, group_size
		).is_empty():
			continue
		var wave_weight := float(wave_weights.get(role, 0.0))
		var formation_weight := float(formation_weights.get(role, 0.0))
		var weight := wave_weight * formation_weight / 100.0
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


func get_wave_role_weights(wave: int) -> Dictionary:
	for entry in WAVE_ROLE_WEIGHTS:
		if wave <= entry["maximum_wave"]:
			return entry["weights"]
	return WAVE_ROLE_WEIGHTS.back()["weights"]


func choose_enemy_for_role(
	role: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> StringName:
	var candidates := get_valid_enemies_for_role(
		role, available, current_group, group_size
	)
	if candidates.is_empty():
		for fallback_role in [ROLE_FODDER, ROLE_PRESSURE, ROLE_TANK, ROLE_SUPPORT]:
			candidates = get_valid_enemies_for_role(
				fallback_role, available, current_group, group_size
			)
			if not candidates.is_empty():
				break
	if candidates.is_empty():
		return &""
	return choose_weighted_enemy(candidates)


func get_valid_enemies_for_role(
	role: StringName,
	available: Array[StringName],
	current_group: Array[StringName],
	group_size: int
) -> Array[StringName]:
	var candidates: Array[StringName] = []
	for enemy_id in available:
		var stats: Dictionary = GameStats.get_enemy(enemy_id)
		if stats.get("role", ROLE_FODDER) != role:
			continue
		if role == ROLE_SUPPORT and count_role_in_group(current_group, ROLE_SUPPORT) >= 1:
			continue
		if enemy_id in [&"buffer", &"summoner"]:
			if get_active_enemy_count(enemy_id) + current_group.count(enemy_id) >= 2:
				continue
		if enemy_id == &"rusher":
			var rusher_limit := maxi(1, floori(float(group_size) * 0.3))
			if current_group.count(&"rusher") >= rusher_limit:
				continue
		candidates.append(enemy_id)
	return candidates


func get_active_enemy_count(enemy_id: StringName) -> int:
	if active_enemy_count_provider.is_valid():
		return int(active_enemy_count_provider.call(enemy_id))
	return 0


func count_role_in_group(group: Array[StringName], role: StringName) -> int:
	var count := 0
	for enemy_id in group:
		if GameStats.get_enemy(enemy_id).get("role", ROLE_FODDER) == role:
			count += 1
	return count


func get_director_group_size(style_name: StringName) -> int:
	var base_size: int
	match style_name:
		&"pulses":
			base_size = rng.randi_range(7, 12)
		&"swarm_batch":
			base_size = rng.randi_range(8, 14)
		&"convoy":
			base_size = 8
		&"elite_escort", &"support_column", &"summoner_escort":
			base_size = 9
		&"hidden_probe", &"splitter_pack", &"rush_screen":
			base_size = rng.randi_range(8, 12)
		&"layered_assault", &"boss_rehearsal":
			base_size = rng.randi_range(10, 14)
		_:
			base_size = rng.randi_range(6, 10)
	return maxi(1, roundi(float(base_size) * STANDARD_GROUP_SIZE_MULTIPLIER))


func build_debut_opening(wave: int) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	var debuts := GameStats.get_debut_enemy_ids(wave, enemy_debut_plan)
	debuts.erase(&"normal")
	if debuts.is_empty():
		return schedule
	var available := get_available_enemies(wave)
	var group: Array[StringName] = debuts.duplicate()
	var escort_pool := available.duplicate()
	for debut_id in debuts:
		escort_pool.erase(debut_id)
	while group.size() < 3 and not escort_pool.is_empty():
		group.append(choose_weighted_enemy(escort_pool))
	GameStats.shuffle_with_rng(group, rng)
	append_enemy_group(schedule, group, 0.22, 1.0, &"debut")
	return schedule


func build_timed_boss_opening() -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	if available.is_empty():
		var boss_only_schedule: Array[Dictionary] = []
		append_enemy_group(
			boss_only_schedule, [&"brute"], 0.2, 2.0, &"boss_escort"
		)
		return boss_only_schedule

	var front_candidates: Array[StringName] = []
	var rear_candidates: Array[StringName] = []
	for enemy_id in available:
		if get_enemy_formation_strength(enemy_id) < 8:
			continue
		var role: StringName = GameStats.get_enemy(enemy_id).get(
			"role", ROLE_FODDER
		)
		if role == ROLE_TANK:
			front_candidates.append(enemy_id)
		elif role in [ROLE_PRESSURE, ROLE_SUPPORT]:
			rear_candidates.append(enemy_id)
	if front_candidates.is_empty():
		front_candidates = available.duplicate()
	if rear_candidates.is_empty():
		rear_candidates = available.duplicate()
	var boss_group: Array[StringName] = [
		choose_weighted_enemy(front_candidates),
		choose_weighted_enemy(front_candidates),
		&"brute",
		choose_weighted_enemy(rear_candidates),
		choose_weighted_enemy(rear_candidates),
	]
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, boss_group, 0.2, 2.0, &"boss_escort")
	return schedule


func build_elite_event_schedule(
	elite_count: int,
	escort_count: int,
	escort_variant: StringName
) -> Array[Dictionary]:
	var available := get_available_enemies(round_number)
	var schedule: Array[Dictionary] = []
	if available.is_empty():
		return schedule
	var elites: Array[StringName] = []
	for _index in elite_count:
		elites.append(choose_elite_enemy(available))
	var escorts: Array[StringName] = []
	for _index in escort_count:
		escorts.append(choose_weighted_enemy(available))
	var front_escort_count := ceili(escorts.size() / 2.0)
	for _index in front_escort_count:
		append_special_spawn_event(
			schedule, escorts.pop_front(), escort_variant, 0.12
		)
	for elite_id in elites:
		append_special_spawn_event(schedule, elite_id, VARIANT_ELITE, 0.18)
		if not escorts.is_empty():
			append_special_spawn_event(
				schedule, escorts.pop_front(), escort_variant, 0.12
			)
	while not escorts.is_empty():
		append_special_spawn_event(
			schedule, escorts.pop_front(), escort_variant, 0.12
		)
	if not schedule.is_empty():
		schedule.back()["delay_after"] = 1.0
	return schedule


func choose_elite_enemy(available: Array[StringName]) -> StringName:
	var preferred: Array[StringName] = []
	for enemy_id in available:
		var role: StringName = GameStats.get_enemy(enemy_id).get(
			"role", ROLE_FODDER
		)
		if role in [ROLE_PRESSURE, ROLE_TANK]:
			preferred.append(enemy_id)
	if preferred.is_empty():
		preferred = available.duplicate()
	return choose_weighted_enemy(preferred)


func append_special_spawn_event(
	schedule: Array[Dictionary],
	enemy_id: StringName,
	spawn_variant: StringName,
	delay_after: float
) -> void:
	schedule.append({
		"enemy_id": enemy_id,
		"delay_after": delay_after,
		"style": &"elite_event",
		"variant": spawn_variant,
		"free_spawn": true,
		"special_event": true,
	})


func build_standard_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var leader_stats: Dictionary = GameStats.get_enemy(enemy_queue[0])
		var style_name: StringName = leader_stats.get("spawn_style", &"steady")
		var style: Dictionary = SPAWN_STYLES.get(style_name, SPAWN_STYLES[&"steady"])
		var requested_size := rng.randi_range(
			int(style["minimum_group_size"]),
			int(style["maximum_group_size"])
		)
		var group := take_front_group(
			enemy_queue, mini(requested_size, enemy_queue.size())
		)
		append_enemy_group(
			schedule,
			group,
			float(style["interval"]),
			float(style["gap_after_group"]),
			style_name
		)
	return schedule


func build_pulse_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group_size := mini(rng.randi_range(7, 12), enemy_queue.size())
		append_enemy_group(
			schedule, take_front_group(enemy_queue, group_size), 0.12, 1.2, &"pulses"
		)
	return schedule


func build_swarm_batch_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group_size := mini(rng.randi_range(8, 14), enemy_queue.size())
		append_enemy_group(
			schedule,
			take_front_group(enemy_queue, group_size),
			0.05,
			1.2,
			&"swarm_batch"
		)
	return schedule


func build_convoy_schedule(enemy_queue: Array[StringName]) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	while not enemy_queue.is_empty():
		var group: Array[StringName] = [take_enemy_by_role(enemy_queue, ROLE_TANK)]
		for _index in mini(7, enemy_queue.size()):
			group.append(take_weakest_enemy(enemy_queue))
		append_enemy_group(schedule, group, 0.2, 1.2, &"convoy")
	return schedule


func build_fixed_style_schedule(
	enemy_queue: Array[StringName],
	style_name: StringName
) -> Array[Dictionary]:
	var style: Dictionary = SPAWN_STYLES.get(
		style_name, SPAWN_STYLES[&"steady"]
	)
	var schedule: Array[Dictionary] = []
	append_enemy_group(
		schedule,
		enemy_queue,
		float(style["interval"]),
		float(style["gap_after_group"]),
		style_name
	)
	return schedule


func build_hidden_probe_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var hidden_enemies := take_all_enemy_id(enemy_queue, &"hidden")
	var group := take_front_group(
		enemy_queue, ceili(float(enemy_queue.size()) * 0.5)
	)
	group.append_array(hidden_enemies)
	group.append_array(enemy_queue)
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.16, 1.1, &"hidden_probe")
	return schedule


func build_splitter_pack_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var splitters := take_all_enemy_id(enemy_queue, &"splitter")
	var group: Array[StringName] = []
	while not splitters.is_empty() or not enemy_queue.is_empty():
		if not enemy_queue.is_empty():
			group.append(take_weakest_enemy(enemy_queue))
		if not splitters.is_empty():
			group.append(splitters.pop_front())
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.12, 1.2, &"splitter_pack")
	return schedule


func build_support_column_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var support := take_enemy_by_role(enemy_queue, ROLE_SUPPORT)
	var tank := take_enemy_by_role(enemy_queue, ROLE_TANK)
	var group: Array[StringName] = []
	append_if_valid(group, tank)
	group.append_array(take_front_group(enemy_queue, mini(2, enemy_queue.size())))
	append_if_valid(group, support)
	group.append_array(enemy_queue)
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.18, 1.3, &"support_column")
	return schedule


func build_rush_screen_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var rushers := take_all_enemy_id(enemy_queue, &"rusher")
	var group: Array[StringName] = []
	append_if_valid(group, take_enemy_by_role(enemy_queue, ROLE_TANK))
	group.append_array(take_front_group(enemy_queue, mini(2, enemy_queue.size())))
	group.append_array(rushers)
	group.append_array(enemy_queue)
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.10, 1.2, &"rush_screen")
	return schedule


func build_summoner_escort_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var summoner := take_enemy_by_id(enemy_queue, &"summoner")
	var tank := take_enemy_by_role(enemy_queue, ROLE_TANK)
	return build_centerpiece_escort_schedule(
		enemy_queue, summoner, tank, &"summoner_escort", false
	)


func build_elite_escort_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var elite := take_enemy_by_role(enemy_queue, ROLE_TANK)
	return build_centerpiece_escort_schedule(
		enemy_queue, elite, &"", &"elite_escort", true
	)


func build_layered_assault_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var fodder: Array[StringName] = []
	var pressure: Array[StringName] = []
	var finishers: Array[StringName] = []
	for enemy_id in enemy_queue:
		var role: StringName = GameStats.get_enemy(enemy_id).get(
			"role", ROLE_FODDER
		)
		if role == ROLE_FODDER:
			fodder.append(enemy_id)
		elif role == ROLE_PRESSURE:
			pressure.append(enemy_id)
		else:
			finishers.append(enemy_id)
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, fodder, 0.10, 0.9, &"layered_assault")
	append_enemy_group(schedule, pressure, 0.08, 1.0, &"layered_assault")
	append_enemy_group(schedule, finishers, 0.28, 1.3, &"layered_assault")
	return schedule


func build_boss_rehearsal_schedule(
	enemy_queue: Array[StringName]
) -> Array[Dictionary]:
	var centerpiece := take_enemy_by_id(enemy_queue, &"summoner")
	if centerpiece.is_empty():
		centerpiece = take_enemy_by_id(enemy_queue, &"regenerator")
	return build_centerpiece_escort_schedule(
		enemy_queue, centerpiece, &"", &"boss_rehearsal", true
	)


func build_centerpiece_escort_schedule(
	enemy_queue: Array[StringName],
	centerpiece: StringName,
	frontliner: StringName,
	style_name: StringName,
	make_centerpiece_elite: bool
) -> Array[Dictionary]:
	var escorts := enemy_queue.duplicate()
	var group: Array[StringName] = []
	append_if_valid(group, frontliner)
	group.append_array(
		take_front_group(escorts, ceili(float(escorts.size()) * 0.5))
	)
	var centerpiece_index := group.size()
	append_if_valid(group, centerpiece)
	group.append_array(escorts)
	var schedule: Array[Dictionary] = []
	append_enemy_group(schedule, group, 0.16, 1.3, style_name)
	if make_centerpiece_elite and centerpiece_index < schedule.size():
		schedule[centerpiece_index]["variant"] = VARIANT_ELITE
		schedule[centerpiece_index]["director_cost_multiplier"] = (
			GameStats.get_elite_enemy_health_multiplier(round_number)
		)
	return schedule


func take_front_group(
	enemy_queue: Array[StringName],
	count: int
) -> Array[StringName]:
	var group: Array[StringName] = []
	for _index in mini(count, enemy_queue.size()):
		group.append(enemy_queue.pop_front())
	return group


func take_enemy_by_id(
	enemy_queue: Array[StringName],
	enemy_id: StringName
) -> StringName:
	var index := enemy_queue.find(enemy_id)
	if index < 0:
		return &""
	enemy_queue.remove_at(index)
	return enemy_id


func take_all_enemy_id(
	enemy_queue: Array[StringName],
	enemy_id: StringName
) -> Array[StringName]:
	var selected: Array[StringName] = []
	while enemy_id in enemy_queue:
		take_enemy_by_id(enemy_queue, enemy_id)
		selected.append(enemy_id)
	return selected


func append_if_valid(
	group: Array[StringName],
	enemy_id: StringName
) -> void:
	if not enemy_id.is_empty():
		group.append(enemy_id)


func append_enemy_group(
	schedule: Array[Dictionary],
	group: Array[StringName],
	interval: float,
	gap_after_group: float,
	style_name: StringName
) -> void:
	var delay_multiplier := STANDARD_FORMATION_DELAY_MULTIPLIER
	if style_name == &"boss_escort":
		delay_multiplier = 1.0
	elif style_name == &"spaced":
		delay_multiplier = SPACED_FORMATION_DELAY_MULTIPLIER
	var adjusted_interval := maxf(interval * delay_multiplier, 0.01)
	var adjusted_gap := maxf(gap_after_group * delay_multiplier, 0.01)
	for index in group.size():
		var delay_after := adjusted_interval
		if index == group.size() - 1:
			delay_after = adjusted_gap
		schedule.append({
			"enemy_id": group[index],
			"delay_after": delay_after,
			"style": style_name,
		})


func take_strongest_enemy(enemy_queue: Array[StringName]) -> StringName:
	return take_enemy_by_threat(enemy_queue, true)


func take_enemy_by_role(
	enemy_queue: Array[StringName],
	role: StringName
) -> StringName:
	for index in enemy_queue.size():
		if GameStats.get_enemy(enemy_queue[index]).get("role", ROLE_FODDER) == role:
			var selected := enemy_queue[index]
			enemy_queue.remove_at(index)
			return selected
	return take_strongest_enemy(enemy_queue)


func take_weakest_enemy(enemy_queue: Array[StringName]) -> StringName:
	return take_enemy_by_threat(enemy_queue, false)


func take_enemy_by_threat(
	enemy_queue: Array[StringName],
	take_strongest: bool
) -> StringName:
	if enemy_queue.is_empty():
		return &""
	var selected_index := 0
	var selected_cost := get_enemy_formation_strength(enemy_queue[0])
	for index in range(1, enemy_queue.size()):
		var candidate_cost := get_enemy_formation_strength(enemy_queue[index])
		if (
			(take_strongest and candidate_cost > selected_cost)
			or (not take_strongest and candidate_cost < selected_cost)
		):
			selected_index = index
			selected_cost = candidate_cost
	var selected_enemy := enemy_queue[selected_index]
	enemy_queue.remove_at(selected_index)
	return selected_enemy


func get_enemy_formation_strength(enemy_id: StringName) -> int:
	return GameStats.get_enemy(enemy_id).get("formation_strength", 1)


func get_enemy_director_cost(enemy_id: StringName) -> int:
	return GameStats.get_enemy(enemy_id).get("director_cost", 1)


func get_spawn_event_director_cost(spawn_event: Dictionary) -> float:
	return (
		float(get_enemy_director_cost(StringName(spawn_event["enemy_id"])))
		* float(spawn_event.get("director_cost_multiplier", 1.0))
	)


func choose_weighted_enemy(available: Array[StringName]) -> StringName:
	if available.is_empty():
		return &""
	var total_weight := 0
	for enemy_id in available:
		total_weight += GameStats.get_enemy(enemy_id).get("spawn_weight", 1)
	if total_weight <= 0:
		return available[0]
	var roll := rng.randi_range(1, total_weight)
	for enemy_id in available:
		roll -= GameStats.get_enemy(enemy_id).get("spawn_weight", 1)
		if roll <= 0:
			return enemy_id
	return available[0]


func simulate_spawn_counts(
	wave: int,
	round_type: StringName,
	seed: int,
	mode_id: StringName,
	max_rounds: int,
	regenerate_plan := true
) -> Dictionary:
	rng.seed = seed
	if regenerate_plan or enemy_debut_plan.is_empty() or round_style_plan.is_empty():
		generate_run_plan()
	round_number = wave
	current_round_type = round_type
	current_wave_spawn_style = choose_wave_spawn_style(wave)
	if wave == max_rounds:
		current_wave_spawn_style = &"boss_escort"
	var duration := get_wave_duration(wave)
	var simulated_threat_rate := get_wave_threat_rate(wave)
	if round_type in [ROUND_HORDE, ROUND_GAUNTLET, ROUND_PAYDAY]:
		simulated_threat_rate *= get_horde_threat_multiplier(wave)
	var mode := GameStats.get_mode(mode_id)
	var available_threat := float(mode.get("starting_spawn_threat", 1.0))
	var continuous_ratio := float(mode.get("threat_continuous_ratio", 1.0))
	var chunk_ratio := float(mode.get("threat_chunk_ratio", 0.0))
	var chunk_interval := maxf(
		float(mode.get("threat_chunk_interval", 4.0)), 0.01
	)
	var chunk_elapsed := 0.0
	var cooldown := 0.0
	var event_wait := 0.0
	var schedule: Array[Dictionary] = (
		build_timed_boss_opening()
		if wave == max_rounds
		else build_debut_opening(wave)
	)
	var counts := {}
	var elapsed := 0.0
	const DIRECTOR_STEP := 0.05
	while elapsed < duration:
		var delta := minf(DIRECTOR_STEP, duration - elapsed)
		available_threat += simulated_threat_rate * continuous_ratio * delta
		chunk_elapsed += delta
		while chunk_elapsed >= chunk_interval:
			chunk_elapsed -= chunk_interval
			available_threat += simulated_threat_rate * chunk_interval * chunk_ratio
		cooldown = maxf(cooldown - delta, 0.0)
		event_wait = maxf(event_wait - delta, 0.0)
		if schedule.is_empty() and cooldown <= 0.0 and event_wait <= 0.0:
			schedule = build_director_group()
		if not schedule.is_empty() and event_wait <= 0.0:
			var spawn_event: Dictionary = schedule.front()
			var enemy_id := StringName(spawn_event["enemy_id"])
			var spawn_cost := get_spawn_event_director_cost(spawn_event)
			if available_threat >= spawn_cost:
				schedule.pop_front()
				available_threat -= spawn_cost
				var spawn_variant := StringName(
					spawn_event.get("variant", VARIANT_NORMAL)
				)
				var count_key := "%s|%s" % [enemy_id, spawn_variant]
				counts[count_key] = float(counts.get(count_key, 0.0)) + 1.0
				var delay := float(spawn_event.get("delay_after", 0.1))
				if schedule.is_empty():
					cooldown = delay
				else:
					event_wait = delay
		elapsed += delta
	return counts
