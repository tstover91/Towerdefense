extends Node

const GameStats = preload("res://stat_database.gd")
const CombatSimulator = preload("res://tools/tower_balance_monte_carlo.gd")

const TOWER_DRAFT_ROUNDS := [4, 9, 14]
const RELIC_DRAFT_ROUNDS := [1, 6, 11, 16]
const MAX_TOWERS := 24
const TARGET_WIN_RATE := 0.60
const ACCEPTABLE_WIN_LOW := 0.42
const ACCEPTABLE_WIN_HIGH := 0.78
const DEFAULT_OUTPUT_DIR := "res://balance_reports/overnight"
const TOWER_ENGAGEMENT_COVERAGE := 0.45
const STARTING_ROSTER: Array[StringName] = [&"invader", &"gauss_repeater"]
const TRADE_TOWERS: Array[StringName] = [&"hivemother", &"dronedepot", &"mechbay"]

var preset := "standard"
var population_size := 60
var generations := 8
var runs_per_policy := 10
var final_runs_per_profile := 20
var finalist_count := 12
var combat_samples := 8
var seed_value := 884271
var output_dir := DEFAULT_OUTPUT_DIR
var search_rng := RandomNumberGenerator.new()
var combat: Node
var candidates: Dictionary = {}
var candidates_by_tower: Dictionary = {}
var enemy_scenarios: Dictionary = {}
var sensitivity_profiles: Array[Dictionary] = []
var next_policy_id := 1
var final_results: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("run_optimizer")


func run_optimizer() -> void:
	read_arguments()
	apply_preset()
	search_rng.seed = seed_value
	build_sensitivity_profiles()
	print("Run balance optimizer: preset=%s population=%d generations=%d" % [
		preset, population_size, generations,
	])
	prepare_combat_lookup()
	var population := create_initial_population()
	var ranked: Array[Dictionary] = []
	for generation in generations:
		ranked = evaluate_population(population, runs_per_policy, generation)
		print_generation(generation, ranked)
		if generation < generations - 1:
			print("Breeding generation ", generation + 2, "...")
			population = breed_population(ranked)
			print("Breeding complete: ", population.size(), " policies")
	var finalists: Array[Dictionary] = []
	for index in mini(finalist_count, ranked.size()):
		finalists.append(ranked[index]["policy"])
	evaluate_finalists(finalists)
	write_all_reports(ranked)
	print_final_summary()
	get_tree().quit()


func read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="):
			preset = argument.get_slice("=", 1)
		elif argument.begins_with("--population="):
			population_size = maxi(int(argument.get_slice("=", 1)), 4)
		elif argument.begins_with("--generations="):
			generations = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--runs="):
			runs_per_policy = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--final-runs="):
			final_runs_per_profile = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--finalists="):
			finalist_count = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--combat-samples="):
			combat_samples = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--seed="):
			seed_value = int(argument.get_slice("=", 1))
		elif argument.begins_with("--output-dir="):
			output_dir = argument.get_slice("=", 1)


func apply_preset() -> void:
	match preset:
		"smoke":
			population_size = 10
			generations = 2
			runs_per_policy = 2
			final_runs_per_profile = 2
			finalist_count = 4
			combat_samples = 2
		"overnight":
			population_size = 120
			generations = 16
			runs_per_policy = 20
			final_runs_per_profile = 80
			finalist_count = 16
			combat_samples = 20
		_:
			pass


func build_sensitivity_profiles() -> void:
	sensitivity_profiles = [profile("baseline", "baseline", 1.0)]
	var axis_values := {
		"starting_cash": [0.65, 0.80, 0.90, 1.10, 1.20, 1.40],
		"kill_income": [0.65, 0.80, 0.90, 1.10, 1.20, 1.40],
		"round_income": [0.65, 0.80, 0.90, 1.10, 1.20, 1.40],
		"enemy_health": [0.70, 0.85, 0.95, 1.05, 1.20, 1.40],
		"enemy_armor": [0.50, 0.75, 0.90, 1.10, 1.30, 1.75],
		"enemy_speed": [0.70, 0.85, 0.95, 1.05, 1.20, 1.35],
		"enemy_density": [0.65, 0.80, 0.90, 1.10, 1.25, 1.45],
	}
	for axis in axis_values:
		for value in axis_values[axis]:
			var suffix := str(roundi(float(value) * 100.0))
			sensitivity_profiles.append(profile("%s_%s" % [axis, suffix], axis, value))


func profile(profile_id: String, axis: String, value: float) -> Dictionary:
	var result := {
		"id": profile_id,
		"axis": axis,
		"value": value,
		"starting_cash": 1.0,
		"kill_income": 1.0,
		"round_income": 1.0,
		"enemy_health": 1.0,
		"enemy_armor": 1.0,
		"enemy_speed": 1.0,
		"enemy_density": 1.0,
	}
	if result.has(axis):
		result[axis] = value
	return result


func prepare_combat_lookup() -> void:
	combat = CombatSimulator.new()
	combat.duration = 20.0
	combat.rng.seed = seed_value + 101
	combat.build_enemy_scenarios()
	combat.validate_tower_progression()
	for scenario in combat.scenarios:
		enemy_scenarios[StringName(scenario["id"])] = scenario.duplicate(true)
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		candidates_by_tower[tower_id] = []
		for level in 4:
			add_combat_candidate(tower_id, level, &"")
		var paths: Dictionary = GameStats.get_tower(tower_id).get("paths", {})
		if paths.has("a"):
			add_combat_candidate(tower_id, 3, &"a")
		if paths.has("b"):
			add_combat_candidate(tower_id, 3, &"b")
		if paths.has("a") and paths.has("b"):
			add_combat_candidate(tower_id, 3, &"ab")
	print("Combat lookup: %d variants x %d enemy archetypes" % [
		candidates.size(), enemy_scenarios.size(),
	])


func add_combat_candidate(tower_id: StringName, level: int, path: StringName) -> void:
	var path_ids: Array[StringName] = []
	if path in [&"a", &"ab"]:
		path_ids.append(&"a")
	if path in [&"b", &"ab"]:
		path_ids.append(&"b")
	var stats: Dictionary = combat.get_variant_stats(tower_id, level, path_ids)
	var traits: Dictionary = combat.get_variant_traits(tower_id, level, path_ids)
	var key := candidate_key(tower_id, level, path)
	var dps_by_enemy := {}
	var control_by_enemy := {}
	for enemy_key in enemy_scenarios:
		var scenario: Dictionary = enemy_scenarios[enemy_key]
		var total := 0.0
		for _sample in combat_samples:
			total += combat.simulate_trial(tower_id, stats, traits, scenario)
		dps_by_enemy[enemy_key] = total / float(combat_samples)
		control_by_enemy[enemy_key] = combat.get_control_value(stats, traits, scenario)
	var entry := {
		"key": key,
		"tower_id": tower_id,
		"level": level,
		"path": path,
		"cost": combat.get_variant_cost(tower_id, level, path_ids),
		"stats": stats,
		"traits": traits,
		"tower": GameStats.get_tower(tower_id),
		"dps": dps_by_enemy,
		"control": control_by_enemy,
	}
	candidates[key] = entry
	candidates_by_tower[tower_id].append(key)


func candidate_key(tower_id: StringName, level: int, path: StringName) -> String:
	return "%s:%d:%s" % [tower_id, level, path]


func create_initial_population() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var archetypes := [
		"generalist", "economy", "upgrades", "expansion", "biological",
		"technology", "ballistic", "explosive", "beam", "melee",
		"electric", "control", "critical", "spawner",
	]
	for name in archetypes:
		if result.size() >= population_size:
			break
		result.append(create_policy(name))
	while result.size() < population_size:
		result.append(create_policy("random"))
	return result


func create_policy(archetype: String) -> Dictionary:
	var tower_weights := {}
	for tower_key in GameStats.TOWERS:
		tower_weights[StringName(tower_key)] = search_rng.randf_range(0.75, 1.25)
	var category_weights := {}
	for category in [
		&"global", &"biological", &"technology", &"ballistic", &"explosive",
		&"beam", &"melee", &"electric", &"critical", &"psionic", &"reveal",
		&"pierce", &"stun", &"spawner",
	]:
		category_weights[category] = search_rng.randf_range(0.75, 1.25)
	var policy := {
		"id": next_policy_id,
		"name": archetype,
		"tower_weights": tower_weights,
		"category_weights": category_weights,
		"upgrade_bias": search_rng.randf_range(0.80, 1.25),
		"expansion_bias": search_rng.randf_range(0.80, 1.25),
		"diversity": search_rng.randf_range(0.0, 1.0),
		"reserve": search_rng.randf_range(0.0, 0.45),
		"patience": search_rng.randf_range(0.55, 0.95),
		"economy_weight": search_rng.randf_range(0.7, 1.4),
		"risk": search_rng.randf_range(0.75, 1.25),
	}
	next_policy_id += 1
	if archetype == "economy":
		policy["economy_weight"] = 1.8
		policy["reserve"] = 0.40
	elif archetype == "upgrades":
		policy["upgrade_bias"] = 1.55
		policy["expansion_bias"] = 0.75
	elif archetype == "expansion":
		policy["upgrade_bias"] = 0.75
		policy["expansion_bias"] = 1.55
	elif archetype == "control":
		category_weights[&"stun"] = 1.7
		category_weights[&"electric"] = 1.4
	elif category_weights.has(StringName(archetype)):
		category_weights[StringName(archetype)] = 1.75
	return policy


func evaluate_population(
	population: Array[Dictionary],
	run_count: int,
	generation: int
) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for policy in population:
		var totals := new_metric_totals()
		for run_index in run_count:
			var profile_data: Dictionary = sensitivity_profiles[
				(run_index + generation + int(policy["id"])) % sensitivity_profiles.size()
			]
			var run_seed := seed_value + generation * 1000003 + int(policy["id"]) * 7919 + run_index * 101
			accumulate_result(totals, simulate_run(policy, profile_data, run_seed))
		var metrics := finalize_metrics(totals, run_count)
		metrics["policy"] = policy
		ranked.append(metrics)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return ranked


func new_metric_totals() -> Dictionary:
	return {"wins": 0, "round": 0.0, "lives": 0.0, "money": 0.0, "leaks": 0.0}


func accumulate_result(totals: Dictionary, result: Dictionary) -> void:
	totals["wins"] += int(result["won"])
	totals["round"] += float(result["round_reached"])
	totals["lives"] += float(result["lives"])
	totals["money"] += float(result["money"])
	totals["leaks"] += float(result["leak_damage"])


func finalize_metrics(totals: Dictionary, count: int) -> Dictionary:
	var divisor := maxf(float(count), 1.0)
	var win_rate := float(totals["wins"]) / divisor
	var average_round := float(totals["round"]) / divisor
	var average_lives := float(totals["lives"]) / divisor
	var average_money := float(totals["money"]) / divisor
	var average_leaks := float(totals["leaks"]) / divisor
	return {
		"win_rate": win_rate,
		"average_round": average_round,
		"average_lives": average_lives,
		"average_money": average_money,
		"average_leaks": average_leaks,
		"score": win_rate * 100.0 + average_round * 2.5 + average_lives * 0.08 + minf(average_money, 2000.0) * 0.002 - average_leaks * 0.01,
	}


func breed_population(ranked: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var elite_count := maxi(roundi(float(population_size) * 0.15), 2)
	for index in mini(elite_count, ranked.size()):
		result.append(ranked[index]["policy"].duplicate(true))
	while result.size() < population_size:
		var parent_a: Dictionary = ranked[search_rng.randi_range(0, mini(ranked.size() - 1, elite_count * 2))]["policy"]
		var parent_b: Dictionary = ranked[search_rng.randi_range(0, mini(ranked.size() - 1, elite_count * 2))]["policy"]
		result.append(mutate_policy(crossover_policy(parent_a, parent_b)))
	return result


func crossover_policy(a: Dictionary, b: Dictionary) -> Dictionary:
	var child: Dictionary = a.duplicate(true)
	child["id"] = next_policy_id
	child["name"] = "evolved"
	next_policy_id += 1
	for field in ["upgrade_bias", "expansion_bias", "diversity", "reserve", "patience", "economy_weight", "risk"]:
		child[field] = a[field] if search_rng.randf() < 0.5 else b[field]
	for key in child["tower_weights"]:
		if search_rng.randf() < 0.5:
			child["tower_weights"][key] = b["tower_weights"][key]
	for key in child["category_weights"]:
		if search_rng.randf() < 0.5:
			child["category_weights"][key] = b["category_weights"][key]
	return child


func mutate_policy(policy: Dictionary) -> Dictionary:
	for field in ["upgrade_bias", "expansion_bias", "economy_weight", "risk"]:
		if search_rng.randf() < 0.45:
			policy[field] = clampf(float(policy[field]) * search_rng.randf_range(0.85, 1.15), 0.4, 2.2)
	for field in ["diversity", "reserve", "patience"]:
		if search_rng.randf() < 0.45:
			policy[field] = clampf(float(policy[field]) + search_rng.randf_range(-0.12, 0.12), 0.0, 1.0)
	for key in policy["tower_weights"]:
		if search_rng.randf() < 0.15:
			policy["tower_weights"][key] = clampf(float(policy["tower_weights"][key]) * search_rng.randf_range(0.75, 1.25), 0.35, 2.5)
	for key in policy["category_weights"]:
		if search_rng.randf() < 0.18:
			policy["category_weights"][key] = clampf(float(policy["category_weights"][key]) * search_rng.randf_range(0.75, 1.25), 0.35, 2.5)
	return policy


func simulate_run(policy: Dictionary, profile_data: Dictionary, run_seed: int) -> Dictionary:
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = run_seed
	var mode := GameStats.get_mode(&"easy")
	var state := {
		"money": float(mode["starting_cash"]) * float(profile_data["starting_cash"]),
		"lives": float(mode["starting_lives"]),
		"roster": STARTING_ROSTER.duplicate(),
		"build": [],
		"relics": {},
		"dual_path_used": {&"technology": false, &"biological": false},
		"contraband_tower": &"",
		"leak_damage": 0.0,
		"round_reached": 0,
	}
	for round_number in range(1, int(mode["max_rounds"]) + 1):
		var mix := build_round_mix(round_number, profile_data, mode, run_rng)
		purchase_for_round(state, policy, mix, profile_data, round_number)
		var outcome := resolve_round(state, mix, profile_data, mode, round_number)
		state["round_reached"] = round_number
		state["lives"] = float(state["lives"]) - float(outcome["leak_damage"])
		state["leak_damage"] = float(state["leak_damage"]) + float(outcome["leak_damage"])
		state["money"] = float(state["money"]) + float(outcome["kill_income"])
		if float(state["lives"]) <= 0.0:
			break
		var round_reward := float(20 + round_number * 5) * float(profile_data["round_income"])
		if relic_count(state, &"dividends") > 0:
			round_reward += minf(float(state["money"]) * GameStats.DIVIDENDS_INTEREST_RATE, float(GameStats.DIVIDENDS_INTEREST_CAP))
		state["money"] = float(state["money"]) + round_reward
		if TOWER_DRAFT_ROUNDS.has(round_number):
			resolve_tower_draft(state, policy, run_rng)
		if RELIC_DRAFT_ROUNDS.has(round_number):
			resolve_relic_draft(state, policy, round_number, run_rng)
	return {
		"policy_id": policy["id"],
		"profile": profile_data["id"],
		"won": int(state["round_reached"]) >= int(mode["max_rounds"]) and float(state["lives"]) > 0.0,
		"round_reached": state["round_reached"],
		"lives": maxf(float(state["lives"]), 0.0),
		"money": float(state["money"]),
		"leak_damage": float(state["leak_damage"]),
		"build_signature": get_build_signature(state["build"]),
		"relic_signature": get_relic_signature(state["relics"]),
		"tower_signature": get_tower_signature(state["build"]),
	}


func build_round_mix(
	round_number: int,
	profile_data: Dictionary,
	mode: Dictionary,
	run_rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var duration := (
		float(mode["final_wave_duration"])
		if round_number >= int(mode["max_rounds"])
		else minf(float(mode["wave_duration_start"]) + float(round_number - 1) * float(mode["wave_duration_growth"]), float(mode["wave_duration_max"]))
	)
	var threat_rate := (float(mode["threat_rate_base"]) + float(round_number) * float(mode["threat_rate_growth"]) + float(round_number * round_number) * float(mode["threat_rate_curve"])) * 1.40
	var density_variation := run_rng.randf_range(0.92, 1.08)
	var threat_budget := duration * threat_rate * float(profile_data["enemy_density"]) * density_variation
	if round_number in [6, 11]:
		threat_budget *= run_rng.randf_range(1.0, 1.45)
	elif round_number == 16:
		threat_budget *= 1.55
	elif round_number == 17:
		threat_budget *= 1.35
	var eligible: Array[StringName] = []
	var total_weight := 0.0
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var enemy := GameStats.get_enemy(enemy_id)
		if bool(enemy.get("boss", false)) or int(enemy.get("first_wave", 1)) > round_number:
			continue
		var weight := float(enemy.get("spawn_weight", 0.0))
		if weight <= 0.0:
			continue
		eligible.append(enemy_id)
		total_weight += weight
	var mix: Array[Dictionary] = []
	for enemy_id in eligible:
		var enemy := GameStats.get_enemy(enemy_id)
		var share := float(enemy.get("spawn_weight", 0.0)) / maxf(total_weight, 1.0)
		var count := threat_budget * share / maxf(float(enemy.get("spawn_cost", 1.0)), 1.0)
		mix.append(make_mix_entry(enemy_id, enemy, count, round_number, profile_data, mode, duration))
	if round_number >= int(mode["max_rounds"]):
		var boss := GameStats.get_enemy(&"brute")
		mix.append(make_mix_entry(&"brute", boss, 1.0, round_number, profile_data, mode, duration))
	return mix


func make_mix_entry(
	enemy_id: StringName,
	enemy: Dictionary,
	count: float,
	round_number: int,
	profile_data: Dictionary,
	mode: Dictionary,
	duration: float
) -> Dictionary:
	var health := (float(enemy["health"]) + float(enemy.get("health_per_wave", 0.0)) * float(round_number - 1))
	health *= float(mode["enemy_health_multiplier_base"]) + float(round_number - 1) * float(mode["enemy_health_multiplier_growth"])
	health *= GameStats.STANDARD_ENEMY_HEALTH_MULTIPLIER if not bool(enemy.get("boss", false)) else 1.0
	health *= float(profile_data["enemy_health"])
	var extra_health := 0.0
	if int(enemy.get("split_count", 0)) > 0:
		var child := GameStats.get_enemy(StringName(enemy["split_enemy_id"]))
		extra_health += float(enemy["split_count"]) * (float(child["health"]) + float(child.get("health_per_wave", 0.0)) * float(round_number - 1)) * GameStats.STANDARD_ENEMY_HEALTH_MULTIPLIER
	if int(enemy.get("summon_limit", 0)) > 0:
		var summoned := GameStats.get_enemy(StringName(enemy["summon_enemy_id"]))
		extra_health += float(enemy["summon_limit"]) * (float(summoned["health"]) + float(summoned.get("health_per_wave", 0.0)) * float(round_number - 1)) * GameStats.STANDARD_ENEMY_HEALTH_MULTIPLIER
	var speed := float(enemy["move_speed"]) * GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER * float(profile_data["enemy_speed"])
	return {
		"enemy_id": enemy_id,
		"enemy": enemy,
		"count": count,
		"health": health + extra_health,
		"armor": float(enemy.get("armor", 0.0)) * float(profile_data["enemy_armor"]),
		"speed": speed,
		"duration": duration,
		"reward": float(enemy.get("cash_reward", 0.0)),
		"leak": float(enemy.get("base_damage", 1.0)),
	}


func purchase_for_round(
	state: Dictionary,
	policy: Dictionary,
	mix: Array[Dictionary],
	profile_data: Dictionary,
	round_number: int
) -> void:
	var reserve := float(policy["reserve"]) * float(20 + round_number * 5)
	for _purchase in 64:
		var actions := get_purchase_actions(state, profile_data, round_number)
		if actions.is_empty():
			return
		var scored: Array[Dictionary] = []
		for action in actions:
			var cost := float(action["cost"])
			var gain := get_action_power_gain(state, action, mix)
			var tower_id: StringName = action["tower_id"]
			var bias := float(policy["tower_weights"].get(tower_id, 1.0))
			bias *= float(policy["expansion_bias"] if action["kind"] == &"build" else policy["upgrade_bias"])
			var copies := count_built_tower(state["build"], tower_id)
			bias *= pow(1.0 - 0.08 * float(policy["diversity"]), float(copies))
			scored.append({"action": action, "score": gain * bias / maxf(cost, 1.0), "cost": cost})
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
		var best: Dictionary = scored[0]
		var affordable: Dictionary = {}
		for entry in scored:
			if float(entry["cost"]) <= float(state["money"]) - reserve:
				affordable = entry
				break
		if affordable.is_empty():
			return
		if affordable != best and float(affordable["score"]) < float(best["score"]) * float(policy["patience"]):
			return
		apply_purchase_action(state, affordable["action"])


func get_purchase_actions(state: Dictionary, profile_data: Dictionary, round_number: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if state["build"].size() < MAX_TOWERS:
		for tower_id in state["roster"]:
			var base: Dictionary = candidates[candidate_key(tower_id, 0, &"")]
			var cost := get_adjusted_build_cost(state, tower_id, float(base["cost"]), profile_data, round_number)
			actions.append({"kind": &"build", "tower_id": tower_id, "target_key": base["key"], "cost": cost, "instance": -1})
		if not StringName(state["contraband_tower"]).is_empty():
			var contraband_id: StringName = state["contraband_tower"]
			actions.append({"kind": &"build", "tower_id": contraband_id, "target_key": candidate_key(contraband_id, 0, &""), "cost": 0.0, "instance": -1, "contraband": true})
	for index in state["build"].size():
		var instance: Dictionary = state["build"][index]
		var tower_id: StringName = instance["tower_id"]
		var level := int(instance["level"])
		var path := StringName(instance["path"])
		var current: Dictionary = candidates[instance["candidate_key"]]
		if level < 3:
			var target: Dictionary = candidates[candidate_key(tower_id, level + 1, &"")]
			actions.append({"kind": &"upgrade", "tower_id": tower_id, "target_key": target["key"], "cost": float(target["cost"] - current["cost"]), "instance": index})
		elif path.is_empty():
			for next_path in [&"a", &"b"]:
				var key := candidate_key(tower_id, 3, next_path)
				if candidates.has(key):
					var target: Dictionary = candidates[key]
					actions.append({"kind": &"path", "tower_id": tower_id, "target_key": key, "cost": float(target["cost"] - current["cost"]), "instance": index})
		elif path in [&"a", &"b"] and can_buy_dual_path(state, current):
			var dual_key := candidate_key(tower_id, 3, &"ab")
			if candidates.has(dual_key):
				var dual: Dictionary = candidates[dual_key]
				actions.append({"kind": &"dual_path", "tower_id": tower_id, "target_key": dual_key, "cost": float(dual["cost"] - current["cost"]), "instance": index})
	return actions


func get_adjusted_build_cost(
	state: Dictionary,
	tower_id: StringName,
	base_cost: float,
	_profile_data: Dictionary,
	round_number: int
) -> float:
	var result := base_cost
	if relic_count(state, &"holiday_sale") > 0:
		var roster: Array = state["roster"]
		var sale_id: StringName = roster[round_number % roster.size()]
		result *= GameStats.HOLIDAY_SALE_DISCOUNT_MULTIPLIER if tower_id == sale_id else GameStats.HOLIDAY_SALE_OTHER_COST_MULTIPLIER
	if relic_count(state, &"trade_agreement") > 0 and TRADE_TOWERS.has(tower_id):
		result *= GameStats.TRADE_AGREEMENT_BUILD_COST_MULTIPLIER
	return maxf(roundf(result), 0.0)


func can_buy_dual_path(state: Dictionary, current: Dictionary) -> bool:
	var types: Array = current["tower"].get("type_tags", [])
	if types.has(&"technology") and relic_count(state, &"singularity_core") > 0 and not state["dual_path_used"][&"technology"]:
		return true
	if types.has(&"biological") and relic_count(state, &"perfect_mutation") > 0 and not state["dual_path_used"][&"biological"]:
		return true
	return false


func apply_purchase_action(state: Dictionary, action: Dictionary) -> void:
	state["money"] = float(state["money"]) - float(action["cost"])
	var target: Dictionary = candidates[action["target_key"]]
	if action["kind"] == &"build":
		state["build"].append({
			"tower_id": target["tower_id"], "level": target["level"], "path": target["path"], "candidate_key": target["key"],
		})
		if bool(action.get("contraband", false)):
			state["contraband_tower"] = &""
	else:
		var instance: Dictionary = state["build"][int(action["instance"])]
		instance["level"] = target["level"]
		instance["path"] = target["path"]
		instance["candidate_key"] = target["key"]
		state["build"][int(action["instance"])] = instance
		if action["kind"] == &"dual_path":
			var types: Array = target["tower"].get("type_tags", [])
			var category: StringName = &"technology" if types.has(&"technology") else &"biological"
			state["dual_path_used"][category] = true


func get_action_power_gain(state: Dictionary, action: Dictionary, mix: Array[Dictionary]) -> float:
	var target: Dictionary = candidates[action["target_key"]]
	var gain := get_candidate_mix_power(target, state, mix)
	if int(action["instance"]) >= 0:
		var current_instance: Dictionary = state["build"][int(action["instance"])]
		gain -= get_candidate_mix_power(candidates[current_instance["candidate_key"]], state, mix)
	return maxf(gain, 0.001)


func get_candidate_mix_power(candidate: Dictionary, state: Dictionary, mix: Array[Dictionary]) -> float:
	var total_health := 0.0
	var weighted_power := 0.0
	for entry in mix:
		var demand := float(entry["count"]) * float(entry["health"])
		total_health += demand
		weighted_power += demand * get_candidate_enemy_power(candidate, state, entry)
	return weighted_power / maxf(total_health, 1.0)


func get_candidate_enemy_power(candidate: Dictionary, state: Dictionary, entry: Dictionary) -> float:
	var enemy_id: StringName = entry["enemy_id"]
	var base_scenario: Dictionary = enemy_scenarios[enemy_id]
	var power := float(candidate["dps"].get(enemy_id, 0.0))
	var stats: Dictionary = candidate["stats"]
	var traits: Dictionary = candidate["traits"]
	var primary_type: StringName = traits["primary_type"]
	var range_units := float(stats.get("range", stats.get("deployment_radius", 8.0)))
	power *= clampf(range_units / 10.0, 0.55, 1.30)
	var ignores_armor: bool = (
		primary_type == &"beam"
		or int(stats.get("pierce_count", 0)) > 0
		or bool(traits["flags"].get("infinite_pierce", false))
	)
	if relic_count(state, &"armor_piercing") > 0 and traits["damage_tags"].has(&"ballistic"):
		ignores_armor = true
	if relic_count(state, &"thermite_bombs") > 0 and primary_type == &"explosive":
		ignores_armor = true
	if not ignores_armor:
		var raw_hit := maxf(float(stats.get("damage", 1.0)), 1.0)
		var base_armor := float(base_scenario.get("armor", 0.0))
		var new_armor := float(entry["armor"])
		var armor_factor := GameStats.EXPLOSIVE_ARMOR_MULTIPLIER if primary_type == &"explosive" else 1.0
		var base_after := maxf(raw_hit - base_armor * armor_factor, 1.0)
		var new_after := maxf(raw_hit - new_armor * armor_factor, 1.0)
		power *= clampf(new_after / base_after, 0.10, 2.5)
	if traits["delivery"] == GameStats.DELIVERY_PROJECTILE:
		var speed_ratio := float(entry["speed"]) / maxf(float(base_scenario.get("speed", entry["speed"])), 1.0)
		power *= clampf(pow(speed_ratio, -0.35), 0.65, 1.35)
	var density_ratio := float(entry["count"]) / maxf(float(base_scenario.get("primary_enemies", 1)), 1.0)
	var crowd_factor := get_crowd_scaling_factor(candidate)
	power *= 1.0 + (clampf(density_ratio, 0.5, 2.0) - 1.0) * crowd_factor
	power *= get_relic_combat_multiplier(candidate, state, entry)
	var control := float(candidate["control"].get(enemy_id, 0.0))
	power += control * float(entry["health"]) * 0.04
	return maxf(power, 0.0)


func get_crowd_scaling_factor(candidate: Dictionary) -> float:
	var traits: Dictionary = candidate["traits"]
	var stats: Dictionary = candidate["stats"]
	var factor := 0.0
	if traits["primary_type"] == &"explosive":
		factor += clampf(float(stats.get("splash_radius", 0.0)) * 0.10, 0.15, 0.65)
	factor += clampf(float(stats.get("bounce_count", 0)) * 0.10, 0.0, 0.30)
	factor += clampf(float(stats.get("pierce_count", 0)) * 0.10, 0.0, 0.35)
	factor += clampf(float(stats.get("projectile_count", 1) - 1) * 0.08, 0.0, 0.35)
	return clampf(factor, 0.0, 0.85)


func get_relic_combat_multiplier(candidate: Dictionary, state: Dictionary, entry: Dictionary) -> float:
	var relics: Dictionary = state["relics"]
	var traits: Dictionary = candidate["traits"]
	var tower: Dictionary = candidate["tower"]
	var damage_tags: Array = traits["damage_tags"]
	var bonus_tags: Array = traits["bonus_tags"]
	var types: Array = tower.get("type_tags", [])
	var enemy: Dictionary = entry["enemy"]
	var multiplier := 1.0
	if types.has(&"technology"):
		multiplier *= 1.0 + GameStats.NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK * 2.0 * float(relics.get(&"network_upgrade", 0))
	if types.has(&"biological") and count_built_type(state["build"], &"biological") >= 2:
		multiplier *= 1.0 + GameStats.PACK_HUNTER_DAMAGE_PER_STACK * float(relics.get(&"pack_hunter", 0))
	if types.has(&"biological"):
		multiplier *= 1.0 + 0.25 * GameStats.PREDATORY_INSTINCT_DAMAGE_PER_STACK * float(relics.get(&"predatory_instinct", 0))
	if damage_tags.has(&"beam"):
		multiplier *= pow(1.0 + GameStats.FOCUSED_LENS_DAMAGE_PER_STACK, float(relics.get(&"focused_lens", 0)))
		multiplier *= pow(GameStats.WIDE_LENS_DAMAGE_MULTIPLIER * 1.08, float(relics.get(&"wide_lens", 0)))
		if int(relics.get(&"interference_beam", 0)) > 0 and build_has_control(state["build"]):
			multiplier *= GameStats.INTERFERENCE_BEAM_DAMAGE_MULTIPLIER
		if int(relics.get(&"microwave", 0)) > 0 and float(entry["count"]) >= 3.0:
			multiplier *= 1.18
		if int(relics.get(&"death_ray", 0)) > 0:
			multiplier *= 1.0 + minf(float(entry["count"]) - 1.0, 4.0) * 0.16
	if damage_tags.has(&"ballistic"):
		multiplier *= pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER / GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER, float(relics.get(&"heavy_rounds", 0)))
		multiplier *= pow(GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER / GameStats.LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER, float(relics.get(&"lightweight_ammo", 0)))
		multiplier *= 1.0 + 0.5 * GameStats.HOLLOW_POINT_DAMAGE_PER_STACK * float(relics.get(&"hollow_point", 0))
		multiplier *= 1.0 + 0.5 * GameStats.LONG_BARREL_MAX_DAMAGE_PER_STACK * float(relics.get(&"long_barrel", 0))
		multiplier *= 1.0 + 0.5 * GameStats.POINT_BLANK_MAX_DAMAGE_PER_STACK * float(relics.get(&"point_blank", 0))
		if int(relics.get(&"armor_piercing", 0)) > 0:
			multiplier *= 1.0 + minf(float(entry["count"]) - 1.0, 2.0) * 0.20
		if int(relics.get(&"rubber_bullets", 0)) > 0 and float(entry["count"]) > 1.0:
			multiplier *= 1.65
		if int(relics.get(&"experimental_munitions", 0)) > 0 and not bonus_tags.has(&"critical"):
			multiplier *= 1.10
	if damage_tags.has(&"melee"):
		multiplier *= 1.0 + 0.20 * float(relics.get(&"frenzy", 0))
		multiplier *= 1.0 + 0.18 * float(relics.get(&"duelist", 0))
		if int(relics.get(&"relentless", 0)) > 0:
			multiplier *= 1.25
		if int(relics.get(&"giant_killer", 0)) > 0:
			multiplier *= GameStats.GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER if bool(enemy.get("boss", false)) or enemy.get("traits", []).has(&"elite") else GameStats.GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER
		if int(relics.get(&"strength_in_numbers", 0)) > 0:
			multiplier *= 1.0 + GameStats.STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR * float(mini(count_built_damage_tag(state["build"], &"melee") - 1, 4))
		if int(relics.get(&"lone_wolf", 0)) > 0 and count_built_damage_tag(state["build"], &"melee") <= 1:
			multiplier *= GameStats.LONE_WOLF_DAMAGE_MULTIPLIER * GameStats.LONE_WOLF_ATTACK_SPEED_MULTIPLIER
	if damage_tags.has(&"explosive"):
		multiplier *= pow(GameStats.HIGH_YIELD_DAMAGE_MULTIPLIER * 1.12, float(relics.get(&"high_yield", 0)))
		multiplier *= pow(GameStats.CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER * 0.92, float(relics.get(&"concentrated_charge", 0)))
		if int(relics.get(&"crowd_pleaser", 0)) > 0:
			multiplier *= 1.0 + minf(GameStats.CROWD_PLEASER_DAMAGE_PER_ENEMY * float(entry["count"]), GameStats.CROWD_PLEASER_MAXIMUM_DAMAGE_BONUS)
		if int(relics.get(&"direct_hit", 0)) > 0:
			multiplier *= 1.60 if float(entry["count"]) <= 1.5 else (1.30 if float(entry["count"]) <= 2.5 else 1.15)
		if int(relics.get(&"thermite_bombs", 0)) > 0 and float(entry["armor"]) > 0.0:
			multiplier *= GameStats.THERMITE_BOMBS_DAMAGE_MULTIPLIER
	if damage_tags.has(&"electric") and int(relics.get(&"conductive", 0)) > 0 and float(entry["armor"]) > 0.0:
		var damage := maxf(float(candidate["stats"].get("damage", 1.0)), 1.0)
		multiplier *= (damage + float(entry["armor"])) / maxf(damage - float(entry["armor"]), 1.0)
	var has_critical := bonus_tags.has(&"critical") or int(relics.get(&"experimental_munitions", 0)) > 0
	if has_critical:
		var chance := clampf(GameStats.DEFAULT_CRITICAL_CHANCE + GameStats.LUCKY_SHOT_CHANCE_PER_STACK * float(relics.get(&"lucky_shot", 0)) + 0.5 * GameStats.OPENING_SHOT_CHANCE_PER_STACK * float(relics.get(&"opening_shot", 0)), 0.0, 1.0)
		var crit_multiplier := GameStats.DEFAULT_CRITICAL_MULTIPLIER + GameStats.GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS * float(relics.get(&"glass_cannon", 0)) + GameStats.DEADEYE_CRITICAL_MULTIPLIER_BONUS * float(relics.get(&"deadeye", 0))
		var noncrit := GameStats.GLASS_CANNON_NONCRITICAL_MULTIPLIER if int(relics.get(&"glass_cannon", 0)) > 0 else 1.0
		multiplier *= chance * crit_multiplier + (1.0 - chance) * noncrit
	if bonus_tags.has(&"pierce"):
		multiplier *= 1.0 + 0.12 * float(relics.get(&"deep_penetration", 0))
		if int(relics.get(&"follow_through", 0)) > 0:
			multiplier *= 1.12
	if types.has(&"technology") and TRADE_TOWERS.has(candidate["tower_id"]) and int(relics.get(&"trade_agreement", 0)) > 0:
		multiplier *= float(GameStats.TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER) / GameStats.TRADE_AGREEMENT_SPAWN_INTERVAL_MULTIPLIER
	return maxf(multiplier, 0.0)


func resolve_round(
	state: Dictionary,
	mix: Array[Dictionary],
	profile_data: Dictionary,
	_mode: Dictionary,
	_round_number: int
) -> Dictionary:
	var total_health := 0.0
	var total_reward := 0.0
	var total_leak := 0.0
	var duration := 1.0
	for entry in mix:
		total_health += float(entry["count"]) * float(entry["health"])
		total_reward += float(entry["count"]) * float(entry["reward"])
		total_leak += float(entry["count"]) * float(entry["leak"])
		duration = float(entry["duration"])
	var mixed_dps := 0.0
	for instance in state["build"]:
		mixed_dps += get_candidate_mix_power(candidates[instance["candidate_key"]], state, mix)
	mixed_dps *= TOWER_ENGAGEMENT_COVERAGE
	var average_speed_pressure := 1.0
	if not mix.is_empty():
		var speed_total := 0.0
		for entry in mix:
			speed_total += float(entry["speed"])
		average_speed_pressure = clampf(speed_total / float(mix.size()) / 75.0, 0.65, 1.65)
	var required_dps := total_health / maxf(duration, 1.0) * average_speed_pressure
	var kill_fraction := clampf(mixed_dps / maxf(required_dps, 1.0), 0.0, 1.0)
	var remaining_fraction := pow(1.0 - kill_fraction, 1.35)
	return {
		"leak_damage": remaining_fraction * total_leak,
		"kill_income": kill_fraction * total_reward * float(profile_data["kill_income"]),
		"power_ratio": mixed_dps / maxf(required_dps, 1.0),
	}


func resolve_tower_draft(state: Dictionary, policy: Dictionary, run_rng: RandomNumberGenerator) -> void:
	var available: Array[StringName] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		if not state["roster"].has(tower_id):
			available.append(tower_id)
	var offers: Array[StringName] = []
	while offers.size() < 3 and not available.is_empty():
		offers.append(available.pop_at(run_rng.randi_range(0, available.size() - 1)))
	var best: StringName = offers[0]
	for tower_id in offers:
		if float(policy["tower_weights"].get(tower_id, 1.0)) > float(policy["tower_weights"].get(best, 1.0)):
			best = tower_id
	state["roster"].append(best)


func resolve_relic_draft(state: Dictionary, policy: Dictionary, round_number: int, run_rng: RandomNumberGenerator) -> void:
	var offer_count := 4 if round_number == 16 else 3
	var offers: Array[StringName] = []
	var available := get_available_relics(state)
	while offers.size() < offer_count and not available.is_empty():
		var rarity := roll_relic_rarity(round_number, run_rng)
		var matching: Array[StringName] = []
		for relic_id in available:
			if GameStats.get_relic(relic_id)["rarity"] == rarity:
				matching.append(relic_id)
		if matching.is_empty():
			matching = available.duplicate()
		var chosen: StringName = matching[run_rng.randi_range(0, matching.size() - 1)]
		offers.append(chosen)
		available.erase(chosen)
	var best := offers[0]
	var best_score := -INF
	for relic_id in offers:
		var quantity := 2 if round_number == 16 and relic_id == offers.back() else 1
		var score := get_relic_choice_score(state, policy, relic_id, quantity, round_number)
		if score > best_score:
			best_score = score
			best = relic_id
	var best_quantity := 2 if round_number == 16 and best == offers.back() else 1
	state["relics"][best] = int(state["relics"].get(best, 0)) + best_quantity
	if best == &"contraband_blueprint":
		var outside: Array[StringName] = []
		for tower_key in GameStats.TOWERS:
			var tower_id := StringName(tower_key)
			if not state["roster"].has(tower_id):
				outside.append(tower_id)
		if not outside.is_empty():
			state["contraband_tower"] = outside[run_rng.randi_range(0, outside.size() - 1)]


func get_available_relics(state: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for relic_key in GameStats.RELICS:
		var relic_id := StringName(relic_key)
		var relic := GameStats.get_relic(relic_id)
		if not bool(relic.get("enabled", true)):
			continue
		if not bool(relic.get("stackable", false)) and relic_count(state, relic_id) > 0:
			continue
		result.append(relic_id)
	return result


func roll_relic_rarity(round_number: int, run_rng: RandomNumberGenerator) -> StringName:
	var weights_by_round: Dictionary = {
		1: {&"common": 100.0},
		6: {&"common": 70.0, &"rare": 30.0},
		11: {&"common": 35.0, &"rare": 55.0, &"legendary": 10.0},
		16: {&"rare": 70.0, &"legendary": 30.0},
	}
	var weights: Dictionary = weights_by_round.get(
		round_number,
		{&"common": 1.0}
	)
	var total := 0.0
	for value in weights.values():
		total += float(value)
	var roll := run_rng.randf_range(0.0, total)
	for rarity in weights:
		roll -= float(weights[rarity])
		if roll <= 0.0:
			return rarity
	return weights.keys().back()


func get_relic_choice_score(
	state: Dictionary,
	policy: Dictionary,
	relic_id: StringName,
	quantity: int,
	round_number: int
) -> float:
	var relic := GameStats.get_relic(relic_id)
	var category: StringName = relic["category"]
	var applicability := 0.0
	for instance in state["build"]:
		var candidate: Dictionary = candidates[instance["candidate_key"]]
		if category == &"global" or candidate_has_category(candidate, category):
			applicability += 1.0
	if category == &"global":
		applicability = maxf(applicability, 1.0)
	var score := maxf(applicability, 0.15) * float(policy["category_weights"].get(category, 1.0)) * float(quantity)
	if category == &"global":
		score *= float(policy["economy_weight"]) if relic_id in [&"dividends", &"holiday_sale", &"contraband_blueprint", &"long_term_investment"] else 1.0
	if relic_id == &"dividends":
		score *= 1.0 + float(20 - round_number) * 0.08
	elif relic_id == &"long_term_investment":
		score *= 0.55
	elif relic_id in [&"singularity_core", &"perfect_mutation"]:
		score *= 1.4 if has_eligible_dual_path_tower(state, relic_id) else 0.05
	elif relic_id == &"trade_agreement":
		score *= 1.5 if roster_has_any(state["roster"], TRADE_TOWERS) else 0.10
	return score


func candidate_has_category(candidate: Dictionary, category: StringName) -> bool:
	return (
		candidate["tower"].get("type_tags", []).has(category)
		or candidate["traits"]["damage_tags"].has(category)
		or candidate["traits"]["bonus_tags"].has(category)
		or (category == &"spawner" and candidate["stats"].has("unit_stats"))
	)


func has_eligible_dual_path_tower(state: Dictionary, relic_id: StringName) -> bool:
	var category := &"technology" if relic_id == &"singularity_core" else &"biological"
	for instance in state["build"]:
		var candidate: Dictionary = candidates[instance["candidate_key"]]
		if int(instance["level"]) >= 3 and candidate["tower"].get("type_tags", []).has(category):
			return true
	return false


func relic_count(state: Dictionary, relic_id: StringName) -> int:
	return int(state["relics"].get(relic_id, 0))


func count_built_tower(build: Array, tower_id: StringName) -> int:
	var count := 0
	for instance in build:
		if instance["tower_id"] == tower_id:
			count += 1
	return count


func count_built_type(build: Array, tag: StringName) -> int:
	var count := 0
	for instance in build:
		if candidates[instance["candidate_key"]]["tower"].get("type_tags", []).has(tag):
			count += 1
	return count


func count_built_damage_tag(build: Array, tag: StringName) -> int:
	var count := 0
	for instance in build:
		if candidates[instance["candidate_key"]]["traits"]["damage_tags"].has(tag):
			count += 1
	return count


func build_has_control(build: Array) -> bool:
	for instance in build:
		var traits: Dictionary = candidates[instance["candidate_key"]]["traits"]
		if traits["bonus_tags"].has(&"slow") or traits["bonus_tags"].has(&"stun"):
			return true
		var stats: Dictionary = candidates[instance["candidate_key"]]["stats"]
		if float(stats.get("slow_duration", 0.0)) > 0.0 or float(stats.get("stun_duration", 0.0)) > 0.0:
			return true
	return false


func roster_has_any(roster: Array, desired: Array[StringName]) -> bool:
	for tower_id in desired:
		if roster.has(tower_id):
			return true
	return false


func get_build_signature(build: Array) -> String:
	var counts := {}
	for instance in build:
		var label := "%s-L%d%s" % [instance["tower_id"], int(instance["level"]) + 1, String(instance["path"]).to_upper()]
		counts[label] = int(counts.get(label, 0)) + 1
	var labels: Array = counts.keys()
	labels.sort()
	var parts: Array[String] = []
	for label in labels:
		parts.append("%sx%s" % [label, counts[label]])
	return "+".join(parts)


func get_tower_signature(build: Array) -> String:
	var counts := {}
	for instance in build:
		counts[instance["tower_id"]] = int(counts.get(instance["tower_id"], 0)) + 1
	var labels: Array = counts.keys()
	labels.sort()
	var parts: Array[String] = []
	for label in labels:
		parts.append("%sx%s" % [label, counts[label]])
	return "+".join(parts)


func get_relic_signature(relics: Dictionary) -> String:
	var labels: Array = relics.keys()
	labels.sort()
	var parts: Array[String] = []
	for label in labels:
		parts.append("%sx%s" % [label, relics[label]])
	return "+".join(parts)


func evaluate_finalists(finalists: Array[Dictionary]) -> void:
	final_results.clear()
	var total := finalists.size() * sensitivity_profiles.size() * final_runs_per_profile
	var completed := 0
	for policy in finalists:
		for profile_data in sensitivity_profiles:
			for run_index in final_runs_per_profile:
				var run_seed := seed_value + 900000001 + int(policy["id"]) * 100003 + String(profile_data["id"]).hash() + run_index * 97
				var result := simulate_run(policy, profile_data, run_seed)
				final_results.append(result)
				completed += 1
		if completed % maxi(total / 10, 1) == 0:
			print("Final evaluation: %d/%d" % [completed, total])


func write_all_reports(ranked: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	write_strategy_report(ranked)
	write_policy_json(ranked)
	write_manifest()
	write_run_report()
	write_dominance_report()
	write_relic_report()
	write_tower_report()
	write_sensitivity_report()
	write_recommendation_report()
	write_summary_report()


func write_policy_json(ranked: Array[Dictionary]) -> void:
	var rows: Array[Dictionary] = []
	for index in mini(finalist_count, ranked.size()):
		var entry: Dictionary = ranked[index]
		rows.append({
			"rank": index + 1,
			"metrics": {
				"score": entry["score"],
				"win_rate": entry["win_rate"],
				"average_round": entry["average_round"],
			},
			"policy": entry["policy"],
		})
	var file := FileAccess.open(output_dir.path_join("top_policies.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "  "))
	file.close()


func write_manifest() -> void:
	var manifest := {
		"preset": preset,
		"seed": seed_value,
		"population": population_size,
		"generations": generations,
		"runs_per_policy": runs_per_policy,
		"final_runs_per_profile": final_runs_per_profile,
		"finalists": finalist_count,
		"combat_samples": combat_samples,
		"sensitivity_profiles": sensitivity_profiles,
		"model": {
			"rounds": 20,
			"starting_roster": STARTING_ROSTER,
			"maximum_towers": MAX_TOWERS,
			"engagement_coverage": TOWER_ENGAGEMENT_COVERAGE,
			"notes": [
				"Combat coefficients come from the tower Monte Carlo model.",
				"Purchases are staged as builds, upgrades, and paths.",
				"Relic drafts and major combat/economy effects are modeled.",
				"Map geometry, manual aim skill, selling, and exact spawn timing remain approximations.",
			],
		},
	}
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()


func open_report(filename: String, header: String) -> FileAccess:
	var path := output_dir.path_join(filename)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line(header)
	return file


func csv(value: Variant) -> String:
	var text := str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"%s\"" % text.replace("\"", "\"\"")
	return text


func write_strategy_report(ranked: Array[Dictionary]) -> void:
	var file := open_report("strategy_results.csv", "rank,policy_id,name,score,win_rate,average_round,average_lives,average_money,average_leaks,upgrade_bias,expansion_bias,diversity,reserve,patience,economy_weight")
	for index in ranked.size():
		var row: Dictionary = ranked[index]
		var policy: Dictionary = row["policy"]
		file.store_line(",".join(PackedStringArray([
			str(index + 1), str(policy["id"]), csv(policy["name"]), "%.4f" % row["score"], "%.4f" % row["win_rate"], "%.3f" % row["average_round"], "%.3f" % row["average_lives"], "%.2f" % row["average_money"], "%.2f" % row["average_leaks"], "%.3f" % policy["upgrade_bias"], "%.3f" % policy["expansion_bias"], "%.3f" % policy["diversity"], "%.3f" % policy["reserve"], "%.3f" % policy["patience"], "%.3f" % policy["economy_weight"],
		])))
	file.close()


func write_run_report() -> void:
	var file := open_report("finalist_runs.csv", "policy_id,profile,won,round_reached,lives,money,leak_damage,build,relics,towers")
	for row in final_results:
		file.store_line(",".join(PackedStringArray([
			str(row["policy_id"]), str(row["profile"]), str(int(row["won"])), str(row["round_reached"]), "%.3f" % row["lives"], "%.2f" % row["money"], "%.2f" % row["leak_damage"], csv(row["build_signature"]), csv(row["relic_signature"]), csv(row["tower_signature"]),
		])))
	file.close()


func aggregate_signature(field: String) -> Array[Dictionary]:
	var totals := {}
	for row in final_results:
		var signature: String = row[field]
		if not totals.has(signature):
			totals[signature] = {"signature": signature, "runs": 0, "wins": 0, "round": 0.0, "lives": 0.0, "profiles": {}}
		var entry: Dictionary = totals[signature]
		entry["runs"] += 1
		entry["wins"] += int(row["won"])
		entry["round"] += float(row["round_reached"])
		entry["lives"] += float(row["lives"])
		entry["profiles"][row["profile"]] = true
	var result: Array[Dictionary] = []
	for entry in totals.values():
		entry["win_rate"] = float(entry["wins"]) / maxf(float(entry["runs"]), 1.0)
		entry["average_round"] = float(entry["round"]) / maxf(float(entry["runs"]), 1.0)
		entry["average_lives"] = float(entry["lives"]) / maxf(float(entry["runs"]), 1.0)
		entry["profile_count"] = entry["profiles"].size()
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a["win_rate"]) * log(float(a["runs"]) + 1.0)
		var b_score := float(b["win_rate"]) * log(float(b["runs"]) + 1.0)
		return a_score > b_score
	)
	return result


func write_dominance_report() -> void:
	var rows := aggregate_signature("build_signature")
	var file := open_report("build_dominance.csv", "rank,build,runs,wins,win_rate,average_round,average_lives,profiles_seen,clear_choice_flag")
	var winning_runs := 0
	for row in rows:
		winning_runs += int(row["wins"])
	for index in rows.size():
		var row: Dictionary = rows[index]
		var winning_share := float(row["wins"]) / maxf(float(winning_runs), 1.0)
		var flag := "DOMINANT" if float(row["win_rate"]) >= 0.75 and winning_share >= 0.20 and int(row["profile_count"]) >= sensitivity_profiles.size() / 2 else ""
		file.store_line(",".join(PackedStringArray([
			str(index + 1), csv(row["signature"]), str(row["runs"]), str(row["wins"]), "%.4f" % row["win_rate"], "%.3f" % row["average_round"], "%.3f" % row["average_lives"], str(row["profile_count"]), flag,
		])))
	file.close()


func write_relic_report() -> void:
	var file := open_report("relic_value.csv", "relic,present_runs,present_win_rate,absent_win_rate,win_rate_delta,selection_rate,clear_choice_flag")
	for relic_key in GameStats.RELICS:
		var relic_id := StringName(relic_key)
		if not bool(GameStats.get_relic(relic_id).get("enabled", true)):
			continue
		var present_runs := 0
		var present_wins := 0
		var absent_runs := 0
		var absent_wins := 0
		for row in final_results:
			var present := signature_has_item(row["relic_signature"], String(relic_id))
			if present:
				present_runs += 1
				present_wins += int(row["won"])
			else:
				absent_runs += 1
				absent_wins += int(row["won"])
		var present_rate := float(present_wins) / maxf(float(present_runs), 1.0)
		var absent_rate := float(absent_wins) / maxf(float(absent_runs), 1.0)
		var selection := float(present_runs) / maxf(float(final_results.size()), 1.0)
		var flag := "CLEAR_PICK" if selection >= 0.45 and present_rate - absent_rate >= 0.12 else ("LOW_VALUE" if selection <= 0.04 and absent_runs > 0 else "")
		file.store_line(",".join(PackedStringArray([
			str(relic_id), str(present_runs), "%.4f" % present_rate, "%.4f" % absent_rate, "%.4f" % (present_rate - absent_rate), "%.4f" % selection, flag,
		])))
	file.close()


func write_tower_report() -> void:
	var file := open_report("tower_value.csv", "tower,present_runs,present_win_rate,absent_win_rate,win_rate_delta,usage_rate,clear_choice_flag")
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		var present_runs := 0
		var present_wins := 0
		var absent_runs := 0
		var absent_wins := 0
		for row in final_results:
			var present := signature_has_item(row["tower_signature"], String(tower_id))
			if present:
				present_runs += 1
				present_wins += int(row["won"])
			else:
				absent_runs += 1
				absent_wins += int(row["won"])
		var present_rate := float(present_wins) / maxf(float(present_runs), 1.0)
		var absent_rate := float(absent_wins) / maxf(float(absent_runs), 1.0)
		var usage := float(present_runs) / maxf(float(final_results.size()), 1.0)
		var flag := "CLEAR_PICK" if usage >= 0.60 and present_rate - absent_rate >= 0.10 else ("UNDERUSED" if usage <= 0.05 else "")
		file.store_line(",".join(PackedStringArray([
			str(tower_id), str(present_runs), "%.4f" % present_rate, "%.4f" % absent_rate, "%.4f" % (present_rate - absent_rate), "%.4f" % usage, flag,
		])))
	file.close()


func signature_has_item(signature: String, item: String) -> bool:
	for part in signature.split("+", false):
		if part.begins_with(item + "x") or part.begins_with(item + "-"):
			return true
	return false


func get_sensitivity_rows() -> Array[Dictionary]:
	var totals := {}
	for profile_data in sensitivity_profiles:
		totals[profile_data["id"]] = {"profile": profile_data, "runs": 0, "wins": 0, "round": 0.0, "lives": 0.0, "money": 0.0, "winning_builds": {}}
	for row in final_results:
		var entry: Dictionary = totals[row["profile"]]
		entry["runs"] += 1
		entry["wins"] += int(row["won"])
		entry["round"] += float(row["round_reached"])
		entry["lives"] += float(row["lives"])
		entry["money"] += float(row["money"])
		if bool(row["won"]):
			entry["winning_builds"][row["build_signature"]] = true
	var result: Array[Dictionary] = []
	for entry in totals.values():
		var runs := maxf(float(entry["runs"]), 1.0)
		entry["win_rate"] = float(entry["wins"]) / runs
		entry["average_round"] = float(entry["round"]) / runs
		entry["average_lives"] = float(entry["lives"]) / runs
		entry["average_money"] = float(entry["money"]) / runs
		entry["winning_build_count"] = entry["winning_builds"].size()
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Dictionary = a["profile"]
		var pb: Dictionary = b["profile"]
		return String(pa["axis"]) + "%06.3f" % float(pa["value"]) < String(pb["axis"]) + "%06.3f" % float(pb["value"])
	)
	return result


func write_sensitivity_report() -> void:
	var file := open_report("sensitivity.csv", "profile,axis,multiplier,runs,win_rate,average_round,average_lives,average_money,unique_winning_builds")
	for row in get_sensitivity_rows():
		var profile_data: Dictionary = row["profile"]
		file.store_line(",".join(PackedStringArray([
			str(profile_data["id"]), str(profile_data["axis"]), "%.3f" % profile_data["value"], str(row["runs"]), "%.4f" % row["win_rate"], "%.3f" % row["average_round"], "%.3f" % row["average_lives"], "%.2f" % row["average_money"], str(row["winning_build_count"]),
		])))
	file.close()


func write_recommendation_report() -> void:
	var rows := get_sensitivity_rows()
	var file := open_report("recommended_ranges.csv", "axis,current_value,recommended_low,recommended_high,status,evidence")
	var current_values := {
		"starting_cash": float(GameStats.get_mode(&"easy")["starting_cash"]),
		"kill_income": 1.0,
		"round_income": 1.0,
		"enemy_health": GameStats.STANDARD_ENEMY_HEALTH_MULTIPLIER,
		"enemy_armor": 1.0,
		"enemy_speed": GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER,
		"enemy_density": 1.0,
	}
	for axis in current_values:
		var axis_rows: Array[Dictionary] = []
		for row in rows:
			if row["profile"]["axis"] == axis or (row["profile"]["axis"] == "baseline"):
				axis_rows.append(row)
		var acceptable: Array[float] = []
		var closest: Dictionary = {}
		var closest_distance := INF
		for row in axis_rows:
			var rate := float(row["win_rate"])
			var distance := absf(rate - TARGET_WIN_RATE)
			if distance < closest_distance:
				closest_distance = distance
				closest = row
			if rate >= ACCEPTABLE_WIN_LOW and rate <= ACCEPTABLE_WIN_HIGH and int(row["winning_build_count"]) >= 2:
				acceptable.append(float(row["profile"]["value"]))
		var low_multiplier := float(closest["profile"]["value"])
		var high_multiplier := low_multiplier
		var status := "NARROW_ESTIMATE"
		if not acceptable.is_empty():
			acceptable.sort()
			low_multiplier = acceptable.front()
			high_multiplier = acceptable.back()
			status = "HEALTHY_RANGE"
		var current := float(current_values[axis])
		var low := current * low_multiplier if axis in ["starting_cash", "enemy_health", "enemy_speed"] else low_multiplier
		var high := current * high_multiplier if axis in ["starting_cash", "enemy_health", "enemy_speed"] else high_multiplier
		var evidence := "closest tested win rate %.1f%%; %d winning builds" % [float(closest["win_rate"]) * 100.0, int(closest["winning_build_count"])]
		file.store_line(",".join(PackedStringArray([
			str(axis), "%.3f" % current, "%.3f" % low, "%.3f" % high, status, csv(evidence),
		])))
	file.close()


func write_summary_report() -> void:
	var file := FileAccess.open(output_dir.path_join("summary.txt"), FileAccess.WRITE)
	file.store_line("RUN-LEVEL BALANCE OPTIMIZER")
	file.store_line("Seed: %d | preset: %s | finalist runs: %d" % [seed_value, preset, final_results.size()])
	file.store_line("")
	file.store_line("Top build signatures:")
	var builds := aggregate_signature("build_signature")
	for index in mini(10, builds.size()):
		var row: Dictionary = builds[index]
		file.store_line("%d. %s | win %.1f%% | runs %d | profiles %d" % [index + 1, row["signature"], float(row["win_rate"]) * 100.0, row["runs"], row["profile_count"]])
	file.store_line("")
	file.store_line("Sensitivity:")
	for row in get_sensitivity_rows():
		file.store_line("%s: win %.1f%%, average round %.2f, winning builds %d" % [row["profile"]["id"], float(row["win_rate"]) * 100.0, row["average_round"], row["winning_build_count"]])
	file.store_line("")
	file.store_line("Interpretation: a clear choice should combine high win rate, high winning-run share, and success across many sensitivity profiles. Correlation is not causation; validate flagged finalists in live Godot playtests.")
	file.close()


func print_generation(generation: int, ranked: Array[Dictionary]) -> void:
	var best: Dictionary = ranked[0]
	print("Generation %d/%d: best policy %s score %.2f win %.1f%% round %.2f" % [
		generation + 1, generations, best["policy"]["id"], best["score"], float(best["win_rate"]) * 100.0, best["average_round"],
	])


func print_final_summary() -> void:
	var rows := aggregate_signature("build_signature")
	print("Optimizer reports: ", ProjectSettings.globalize_path(output_dir))
	if not rows.is_empty():
		print("Top discovered build: ", rows[0]["signature"], " | win rate ", "%.1f%%" % (float(rows[0]["win_rate"]) * 100.0))
