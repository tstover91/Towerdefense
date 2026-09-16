extends Node

const GameStats = preload("res://stat_database.gd")
const WaveDirectorScript = preload("res://wave_director.gd")


func _ready() -> void:
	validate_enemy_lifecycles()
	validate_late_composition()
	var tier_one_by_family := get_tier_one_by_family()
	var families: Array = tier_one_by_family.keys()
	var early_order_count := validate_early_family_orders(
		tier_one_by_family,
		families
	)
	var case_count := 0
	for first_index in range(families.size() - 2):
		for second_index in range(first_index + 1, families.size() - 1):
			for third_index in range(second_index + 1, families.size()):
				var selected_families := [
					StringName(families[first_index]),
					StringName(families[second_index]),
					StringName(families[third_index]),
				]
				var selected_tier_one: Array[StringName] = []
				for family in selected_families:
					selected_tier_one.append(tier_one_by_family[family])
				var tier_three_options := get_tier_three_options()
				var tier_two_pairs := get_tier_two_pairs(selected_families)
				if tier_two_pairs.size() > 3:
					tier_two_pairs = [
						tier_two_pairs.front(),
						tier_two_pairs[floori(tier_two_pairs.size() / 2.0)],
						tier_two_pairs.back(),
					]
				for selected_tier_two in tier_two_pairs:
					var selected_tier_three := tier_three_options[
						case_count % tier_three_options.size()
					]
					validate_roster(
						selected_tier_one,
						selected_tier_two,
						selected_tier_three,
						1000 + case_count
					)
					case_count += 1
	assert(case_count > 0)
	validate_new_wave_shapes()
	print(
		"Wave roster compatibility passed: %d full rosters and %d early orders."
		% [case_count, early_order_count]
	)
	get_tree().quit(0)


func validate_enemy_lifecycles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	var director = WaveDirectorScript.new(rng)
	director.enemy_debut_plan = {
		&"normal": 1,
		&"runner": 4,
		&"rusher": 14,
		&"swarmling": 6,
		&"splitter": 14,
		&"bruiser": 10,
		&"juggernaut": 18,
	}
	director.round_number = 14
	var runner_at_successor_debut := director.get_progression_spawn_weight(&"runner")
	var swarmling_at_splitter_debut := director.get_progression_spawn_weight(&"swarmling")
	director.round_number = 17
	assert(director.get_progression_spawn_weight(&"runner") < runner_at_successor_debut)
	assert(is_equal_approx(
		director.get_progression_spawn_weight(&"swarmling"),
		swarmling_at_splitter_debut
	))
	director.round_number = 21
	assert(is_equal_approx(
		director.get_progression_spawn_weight(&"runner"),
		65.0 * 0.15
	))
	assert(is_equal_approx(
		director.get_progression_spawn_weight(&"normal"),
		100.0 * 0.15
	))


func validate_late_composition() -> void:
	var total_count := 0.0
	var fodder_count := 0.0
	var normal_count := 0.0
	var fodder_threat := 0.0
	var tank_threat := 0.0
	for seed_value in range(1, 9):
		var rng := RandomNumberGenerator.new()
		var director = WaveDirectorScript.new(rng)
		var counts: Dictionary = director.simulate_spawn_counts(
			23,
			&"standard",
			90000 + seed_value,
			&"easy",
			24
		)
		for count_key in counts:
			var enemy_id := StringName(String(count_key).get_slice("|", 0))
			var count := float(counts[count_key])
			var stats := GameStats.get_enemy(enemy_id)
			var role := StringName(stats.get("role", &"fodder"))
			var threat := count * float(stats.get("director_cost", 1))
			total_count += count
			if role == &"fodder":
				fodder_count += count
				fodder_threat += threat
			elif role == &"tank":
				tank_threat += threat
			if enemy_id == &"normal":
				normal_count += count
	assert(total_count > 0.0)
	assert(fodder_count / total_count < 0.20)
	assert(normal_count / total_count < 0.12)
	assert(tank_threat > fodder_threat * 4.0)


func validate_new_wave_shapes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99173
	var director = WaveDirectorScript.new(rng)
	var escalation_queue: Array[StringName] = []
	for _index in 10:
		escalation_queue.append(&"normal")
	var escalation: Array[Dictionary] = director.build_escalation_schedule(
		escalation_queue
	)
	assert(escalation.size() == 10)
	assert(float(escalation[1]["delay_after"]) > float(escalation[0]["delay_after"]))
	assert(float(escalation[4]["delay_after"]) > float(escalation[3]["delay_after"]))
	assert(float(escalation[5]["delay_after"]) < float(escalation[2]["delay_after"]))

	var second_wind_queue: Array[StringName] = [
		&"normal", &"normal", &"normal", &"normal", &"normal", &"normal",
		&"striker", &"armored", &"heavy_enforcer", &"bulwark",
	]
	var second_wind: Array[Dictionary] = director.build_second_wind_schedule(
		second_wind_queue
	)
	assert(second_wind.size() == 10)
	assert(float(second_wind[5]["delay_after"]) >= 1.9)
	var reserve_ids: Array[StringName] = []
	for index in range(6, second_wind.size()):
		reserve_ids.append(StringName(second_wind[index]["enemy_id"]))
	assert(&"bulwark" in reserve_ids)
	assert(&"heavy_enforcer" in reserve_ids)


func validate_early_family_orders(
	tier_one_by_family: Dictionary,
	families: Array
) -> int:
	var order_count := 0
	for first_family_value in families:
		var first_family := StringName(first_family_value)
		for second_family_value in families:
			var second_family := StringName(second_family_value)
			if second_family == first_family:
				continue
			var plan := {}
			for enemy_key in GameStats.ENEMIES:
				plan[StringName(enemy_key)] = 999
			for enemy_id in GameStats.FIXED_ENEMY_DEBUT_ROUNDS:
				plan[enemy_id] = GameStats.FIXED_ENEMY_DEBUT_ROUNDS[enemy_id]
			plan[tier_one_by_family[first_family]] = 4
			plan[tier_one_by_family[second_family]] = 6
			var rng := RandomNumberGenerator.new()
			rng.seed = 50000 + order_count
			var director = WaveDirectorScript.new(rng)
			director.enemy_debut_plan = plan
			for round_number in [4, 5, 6, 8]:
				var available := GameStats.get_available_enemy_ids(
					round_number,
					plan
				)
				var eligible := GameStats.get_eligible_wave_styles(
					round_number,
					available
				)
				assert(not eligible.is_empty())
				for style_name in eligible:
					validate_style_group(
						director,
						plan,
						round_number,
						style_name,
						[]
					)
				assert_role_style_coverage(round_number, available, eligible)
			order_count += 1
	return order_count


func get_tier_one_by_family() -> Dictionary:
	var result := {}
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		if (
			GameStats.get_enemy_family(enemy_id) != &"general"
			and GameStats.get_enemy_family_tier(enemy_id) == 1
		):
			result[GameStats.get_enemy_family(enemy_id)] = enemy_id
	return result


func get_tier_two_pairs(selected_families: Array) -> Array:
	var selected_options: Array[StringName] = []
	var fallback_options: Array[StringName] = []
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var enemy := GameStats.get_enemy(enemy_id)
		if (
			bool(enemy.get("boss", false))
			or GameStats.get_enemy_family(enemy_id) == &"general"
			or GameStats.get_enemy_family_tier(enemy_id) != 2
		):
			continue
		if GameStats.get_enemy_family(enemy_id) in selected_families:
			selected_options.append(enemy_id)
		else:
			fallback_options.append(enemy_id)
	var pool := selected_options.duplicate()
	if pool.size() < 2:
		pool.append_array(fallback_options)
	var pairs: Array = []
	for first_index in range(pool.size() - 1):
		for second_index in range(first_index + 1, pool.size()):
			var first_id := StringName(pool[first_index])
			var second_id := StringName(pool[second_index])
			if (
				selected_options.size() == 1
				and first_id not in selected_options
				and second_id not in selected_options
			):
				continue
			pairs.append([first_id, second_id])
	if selected_options.size() >= 2:
		pairs = pairs.filter(func(pair: Array) -> bool:
			return pair[0] in selected_options and pair[1] in selected_options
		)
	return pairs


func get_tier_three_options() -> Array[StringName]:
	var options: Array[StringName] = []
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		if (
			GameStats.get_enemy_family(enemy_id) != &"general"
			and GameStats.get_enemy_family_tier(enemy_id) == 3
		):
			options.append(enemy_id)
	return options


func validate_roster(
	selected_tier_one: Array[StringName],
	selected_tier_two_value: Array,
	selected_tier_three: StringName,
	seed_value: int
) -> void:
	var selected_tier_two: Array[StringName] = []
	selected_tier_two.assign(selected_tier_two_value)
	var plan := {}
	for enemy_key in GameStats.ENEMIES:
		plan[StringName(enemy_key)] = 999
	for enemy_id in GameStats.FIXED_ENEMY_DEBUT_ROUNDS:
		plan[enemy_id] = GameStats.FIXED_ENEMY_DEBUT_ROUNDS[enemy_id]
	for index in selected_tier_one.size():
		plan[selected_tier_one[index]] = [6, 8, 10][index]
	for index in selected_tier_two.size():
		plan[selected_tier_two[index]] = [14, 18][index]
	plan[selected_tier_three] = 20

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var director = WaveDirectorScript.new(rng)
	director.enemy_debut_plan = plan
	for round_number in [12, 13]:
		validate_style_group(
			director,
			plan,
			round_number,
			&"mixed_roster",
			selected_tier_one
		)
	var full_roster := selected_tier_one.duplicate()
	full_roster.append_array(selected_tier_two)
	validate_style_group(
		director,
		plan,
		19,
		&"layered_assault",
		full_roster
	)
	full_roster.append(selected_tier_three)
	for round_number in [21, 22, 23]:
		validate_style_group(
			director,
			plan,
			round_number,
			&"layered_assault",
			full_roster
		)

	for round_number in [4, 5, 6, 8, 10, 14, 18, 20, 22]:
		var available := GameStats.get_available_enemy_ids(round_number, plan)
		var eligible := GameStats.get_eligible_wave_styles(round_number, available)
		assert(not eligible.is_empty())
		for style_name in eligible:
			validate_style_group(director, plan, round_number, style_name, [])
		assert_role_style_coverage(round_number, available, eligible)


func validate_style_group(
	director: Variant,
	plan: Dictionary,
	round_number: int,
	style_name: StringName,
	required_enemies: Array
) -> void:
	var available := GameStats.get_available_enemy_ids(round_number, plan)
	assert(style_name in GameStats.get_eligible_wave_styles(round_number, available))
	director.set_round_context(round_number, &"standard", style_name)
	var schedule: Array[Dictionary] = director.build_director_group()
	assert(not schedule.is_empty())
	for event in schedule:
		assert(StringName(event["enemy_id"]) in available)
	for enemy_id in required_enemies:
		assert(schedule.any(func(event: Dictionary) -> bool:
			return StringName(event["enemy_id"]) == StringName(enemy_id)
		))


func assert_role_style_coverage(
	round_number: int,
	available: Array[StringName],
	eligible: Array[StringName]
) -> void:
	var roles := {}
	for enemy_id in available:
		roles[StringName(GameStats.get_enemy(enemy_id).get("role", &"fodder"))] = true
	if round_number >= 5 and roles.has(&"tank"):
		assert(&"spaced" in eligible)
		assert(&"convoy" in eligible)
		assert(&"elite_escort" in eligible)
	if round_number >= 2 and roles.has(&"pressure"):
		assert(&"burst" in eligible)
	if round_number >= 8 and roles.has(&"support"):
		assert(&"support_column" in eligible)
	if round_number >= 9:
		assert(&"escalation" in eligible)
	if round_number >= 14:
		assert(&"second_wind" in eligible)
	if round_number >= 11 and &"hidden" in available:
		assert(&"hidden_probe" in eligible)
	if round_number >= 8 and &"splitter" in available:
		assert(&"splitter_pack" in eligible)
	if round_number >= 14 and &"rusher" in available:
		assert(&"rush_screen" in eligible)
	if round_number >= 14 and &"summoner" in available:
		assert(&"summoner_escort" in eligible)
	if (
		round_number in [22, 23]
		and (&"summoner" in available or &"regenerator" in available)
	):
		assert(&"boss_rehearsal" in eligible)
