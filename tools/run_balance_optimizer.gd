extends Node

const GameStats = preload("res://stat_database.gd")
const MapData = preload("res://map_database.gd")
const CombatSimulator = preload("res://tools/tower_balance_monte_carlo.gd")
const MainScene = preload("res://main.tscn")
const DraftManagerScript = preload("res://draft_manager.gd")

const TOWER_DRAFT_ROUNDS := [3, 8, 12]
const RELIC_DRAFT_ROUNDS: Array[int] = []
const MAX_TOWERS := 128
const TARGET_WIN_RATE := 0.60
const ACCEPTABLE_WIN_LOW := 0.42
const ACCEPTABLE_WIN_HIGH := 0.78
const DEFAULT_OUTPUT_DIR := "res://balance_reports/overnight"
const CHECKPOINT_VERSION := 11
const CHECKPOINT_FILE_A := "optimizer_checkpoint_a.dat"
const CHECKPOINT_FILE_B := "optimizer_checkpoint_b.dat"
const TOWER_ENGAGEMENT_COVERAGE := 0.45
const STARTER_ROSTER_SIZE := 2
const STARTER_CALIBRATION_TOWERS: Array[StringName] = [
	&"invader", &"reaver", &"slinger", &"gauss_repeater",
]
const PURCHASE_LOOKAHEAD_STEPS := 3
const FUTURE_POWER_DISCOUNT := 0.82
const FUTURE_FUNDING_DISCOUNT := 0.80
const MAP_PLACEMENT_SNAP := 16.0
const MAP_RANGE_PIXELS_PER_UNIT := 12.9
const MAP_PATH_SAMPLE_INTERVAL := 8.0
const MAP_COMBAT_SEGMENT_STRIDE := 4
const MAP_COMBAT_TIME_STEP := 0.25
const MIDWAVE_PURCHASE_INTERVAL := 1.0
const MAP_COMBAT_MAX_EXTRA_TIME := 4.0
const MAP_COMBAT_EPSILON := 0.0001
const COMBAT_HEALTH_MULTIPLIERS: Array[float] = [
	0.50, 1.00, 1.50, 2.00, 3.00, 5.00, 8.00, 12.00,
]
const MAP_MINIMUM_ENGAGEMENT := 0.25
const MAP_MAXIMUM_ENGAGEMENT := 0.70
const MAP_COVERAGE_ENGAGEMENT_SCALE := 0.85
const TRADE_TOWERS: Array[StringName] = [&"hivemother", &"dronedepot", &"mechbay"]
const EXCLUDED_TOWERS: Array[StringName] = [
	&"hivemother", &"dronedepot", &"mechbay",
]
const EXCLUDED_RELICS: Array[StringName] = [
	&"trade_agreement",
]

var preset := "standard"
var population_size := 60
var generations := 8
var runs_per_policy := 10
var final_runs_per_profile := 20
var finalist_count := 12
var combat_samples := 8
var seed_value := 884271
var output_dir := DEFAULT_OUTPUT_DIR
var resume_from_checkpoint := true
var search_rng := RandomNumberGenerator.new()
var combat: Node
var candidates: Dictionary = {}
var candidates_by_tower: Dictionary = {}
var enemy_scenarios: Dictionary = {}
var sensitivity_profiles: Array[Dictionary] = []
var next_policy_id := 1
var final_results: Array[Dictionary] = []
var checkpoint_sequence := 0
var worker_count := maxi(OS.get_processor_count() - 1, 1)
var starting_rosters: Array = []
var focused_early_test := false
var simulation_round_limit := 20
var record_round_history := false
var source_policy_path := "res://balance_reports/overnight/top_policies.json"
var source_policy_limit := 0
var focused_starter_tower: StringName = &"invader"
var focused_starter_pool: Array[StringName] = []
var evolve_focused_test := false
var use_map_geometry := false
var selected_map_id: StringName = MapData.DEFAULT_MAP_ID
var map_path_samples: PackedVector2Array = []
var map_combat_samples: PackedVector2Array = []
var map_path_length := 0.0
var map_combat_segment_length := 1.0
var map_placements: Array[Dictionary] = []
var placement_rankings: Dictionary = {}
var placement_coverages: Dictionary = {}
var starter_calibration := false
var live_build_benchmark := false
# The optimizer's old global-relic model is retained only for historical report
# compatibility. Current runs always use per-tower items instead.
var disable_relics := true
var director_count_templates: Dictionary = {}


func _ready() -> void:
	call_deferred("run_optimizer")


func run_optimizer() -> void:
	read_arguments()
	apply_preset()
	# Reapply explicit command-line overrides after the preset supplies defaults.
	read_arguments()
	search_rng.seed = seed_value
	build_sensitivity_profiles()
	build_starting_rosters()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	if not resume_from_checkpoint:
		clear_checkpoints()
	print("Run balance optimizer: preset=%s population=%d generations=%d workers=%d starter_rosters=%d" % [
		preset, population_size, generations, worker_count, starting_rosters.size(),
	])
	prepare_combat_lookup()
	prepare_director_count_templates()
	if use_map_geometry:
		prepare_map_geometry()
	if live_build_benchmark:
		run_live_build_benchmark()
		return
	if starter_calibration:
		run_starter_calibration()
		return
	if focused_early_test and not evolve_focused_test:
		run_focused_early_test()
		return
	var checkpoint := load_checkpoint() if resume_from_checkpoint else {}
	var population: Array[Dictionary] = []
	var ranked: Array[Dictionary] = []
	var finalists: Array[Dictionary] = []
	var next_generation := 0
	var next_final_index := 0
	if not checkpoint.is_empty():
		ranked.assign(checkpoint.get("ranked", []))
		population.assign(checkpoint.get("population", []))
		finalists.assign(checkpoint.get("finalists", []))
		final_results.assign(checkpoint.get("final_results", []))
		next_generation = int(checkpoint.get("next_generation", 0))
		next_final_index = int(checkpoint.get("next_final_index", 0))
		print("Resuming checkpoint: stage=%s, generation=%d/%d, finalist runs=%d" % [
			checkpoint.get("stage", "evolution"), next_generation, generations, next_final_index,
		])
	else:
		population = create_initial_population()
		save_checkpoint("evolution", population, ranked, finalists, 0, 0)

	if finalists.is_empty():
		for generation in range(next_generation, generations):
			ranked = evaluate_population(population, runs_per_policy, generation)
			print_generation(generation, ranked)
			if generation < generations - 1:
				print("Breeding generation ", generation + 2, "...")
				population = breed_population(ranked)
				print("Breeding complete: ", population.size(), " policies")
				save_checkpoint("evolution", population, ranked, finalists, generation + 1, 0)
		for index in mini(finalist_count, ranked.size()):
			finalists.append(ranked[index]["policy"])
		save_checkpoint("finalists", [], ranked, finalists, generations, 0)

	evaluate_finalists(finalists, next_final_index, ranked)
	write_all_reports(ranked)
	clear_checkpoints()
	print_final_summary()
	finish_optimizer()


func run_focused_early_test() -> void:
	var finalists := load_source_policies()
	assert(not finalists.is_empty(), "Focused early test requires at least one source policy")
	finalist_count = finalists.size()
	print("Focused early test: %d policies, baseline only, rounds 1-%d" % [
		finalists.size(), simulation_round_limit,
	])
	evaluate_finalists(finalists, 0, [])
	write_run_report()
	write_early_round_trace_report()
	write_manifest()
	clear_checkpoints()
	print("Early-round reports: ", ProjectSettings.globalize_path(output_dir))
	finish_optimizer()


func run_starter_calibration() -> void:
	var policies := create_starter_calibration_policies()
	var challenges: Array[StringName] = [&"horde", &"elite"]
	var repeats := maxi(final_runs_per_profile, 1)
	var jobs_per_policy := starting_rosters.size() * challenges.size() * repeats
	var total := policies.size() * jobs_per_policy
	var results: Array = []
	results.resize(total)
	print("Starter calibration: %d fixed strategies x %d rosters x 2 round-6 variants x %d repeats = %d runs" % [
		policies.size(), starting_rosters.size(), repeats, total,
	])
	var task_id := WorkerThreadPool.add_group_task(
		_run_starter_calibration_task.bind(
			policies, challenges, repeats, jobs_per_policy, results
		),
		total,
		mini(worker_count, total)
	)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	final_results.clear()
	for result in results:
		final_results.append(result)
	var ranked: Array[Dictionary] = []
	for policy in policies:
		var totals := new_metric_totals()
		var count := 0
		for result in final_results:
			if int(result["policy_id"]) == int(policy["id"]):
				accumulate_result(totals, result)
				count += 1
		var metrics := finalize_metrics(totals, count)
		metrics["policy"] = policy
		ranked.append(metrics)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	finalist_count = policies.size()
	write_all_reports(ranked)
	write_starter_calibration_report()
	print("Starter calibration reports: ", ProjectSettings.globalize_path(output_dir))
	finish_optimizer()


func run_live_build_benchmark() -> void:
	var policies: Array[Dictionary] = []
	for third_invader_level in [2, 3]:
		var policy := create_policy("generalist")
		policy["name"] = "live_invader_l%d" % third_invader_level
		policy["live_build_third_invader_level"] = third_invader_level
		policies.append(policy)
	var challenges: Array[StringName] = [&"horde", &"elite"]
	var repeats := maxi(final_runs_per_profile, 1)
	final_results.clear()
	for policy in policies:
		for challenge_index in challenges.size():
			for repeat_index in repeats:
				var run_seed := (
					seed_value + 810000001 + challenge_index * 1000003
					+ repeat_index * 97
				)
				final_results.append(simulate_run(
					policy,
					sensitivity_profiles[0],
					run_seed,
					[&"invader", &"gauss_repeater"],
					challenges[challenge_index]
				))
	var ranked: Array[Dictionary] = []
	for policy in policies:
		var totals := new_metric_totals()
		var count := 0
		for result in final_results:
			if int(result["policy_id"]) == int(policy["id"]):
				accumulate_result(totals, result)
				count += 1
		var metrics := finalize_metrics(totals, count)
		metrics["policy"] = policy
		ranked.append(metrics)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	finalist_count = policies.size()
	write_all_reports(ranked)
	print("Live-build benchmark reports: ", ProjectSettings.globalize_path(output_dir))
	finish_optimizer()


func create_starter_calibration_policies() -> Array[Dictionary]:
	var definitions := [
		{"name": "build_emphasis", "upgrade": 0.72, "expansion": 1.42, "reserve": 0.05, "patience": 0.70},
		{"name": "upgrade_emphasis", "upgrade": 1.42, "expansion": 0.72, "reserve": 0.05, "patience": 0.70},
		{"name": "balanced", "upgrade": 1.00, "expansion": 1.00, "reserve": 0.10, "patience": 0.78},
		{"name": "save_future", "upgrade": 1.12, "expansion": 0.88, "reserve": 2.50, "patience": 0.96},
	]
	var result: Array[Dictionary] = []
	for definition in definitions:
		var policy := create_policy("generalist")
		policy["name"] = definition["name"]
		policy["upgrade_bias"] = definition["upgrade"]
		policy["expansion_bias"] = definition["expansion"]
		policy["reserve"] = definition["reserve"]
		policy["patience"] = definition["patience"]
		policy["diversity"] = 0.50
		policy["economy_weight"] = 1.0
		for tower_id in policy["tower_weights"]:
			policy["tower_weights"][tower_id] = 1.0
		for category in policy["category_weights"]:
			policy["category_weights"][category] = 1.0
		result.append(policy)
	return result


func _run_starter_calibration_task(
	job_index: int,
	policies: Array[Dictionary],
	challenges: Array[StringName],
	repeats: int,
	jobs_per_policy: int,
	results: Array
) -> void:
	var policy_index := floori(float(job_index) / float(jobs_per_policy))
	var within_policy := job_index % jobs_per_policy
	var jobs_per_challenge := starting_rosters.size() * repeats
	var challenge_index := floori(float(within_policy) / float(jobs_per_challenge))
	var within_challenge := within_policy % jobs_per_challenge
	var roster_index := floori(float(within_challenge) / float(repeats))
	var repeat_index := within_challenge % repeats
	# Strategies see identical waves for the same roster, challenge, and repeat.
	var run_seed := (
		seed_value + 700000001 + challenge_index * 1000003
		+ roster_index * 3571 + repeat_index * 97
	)
	results[job_index] = simulate_run(
		policies[policy_index],
		sensitivity_profiles[0],
		run_seed,
		starting_rosters[roster_index],
		challenges[challenge_index]
	)


func finish_optimizer() -> void:
	if is_instance_valid(combat):
		combat.free()
	combat = null
	get_tree().quit()


func load_source_policies() -> Array[Dictionary]:
	assert(FileAccess.file_exists(source_policy_path), "Missing source policy file: %s" % source_policy_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_policy_path))
	assert(parsed is Array, "Source policy file must contain a JSON array")
	var policies: Array[Dictionary] = []
	for entry in parsed:
		if entry is Dictionary and entry.has("policy"):
			policies.append(Dictionary(entry["policy"]).duplicate(true))
			if source_policy_limit > 0 and policies.size() >= source_policy_limit:
				break
	return policies


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
		elif argument.begins_with("--workers="):
			worker_count = clampi(
				int(argument.get_slice("=", 1)),
				1,
				maxi(OS.get_processor_count(), 1)
			)
		elif argument == "--fresh":
			resume_from_checkpoint = false
		elif argument.begins_with("--round-limit="):
			simulation_round_limit = clampi(int(argument.get_slice("=", 1)), 1, 20)
		elif argument.begins_with("--source-policies="):
			source_policy_path = argument.get_slice("=", 1)
		elif argument.begins_with("--source-policy-limit="):
			source_policy_limit = maxi(int(argument.get_slice("=", 1)), 0)
		elif argument.begins_with("--forced-starter="):
			focused_starter_tower = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--starter-pool="):
			focused_starter_pool.clear()
			for tower_label in argument.get_slice("=", 1).split(",", false):
				focused_starter_pool.append(StringName(tower_label))
		elif argument == "--evolve-focused":
			evolve_focused_test = true
		elif argument == "--map-geometry":
			use_map_geometry = true
		elif argument.begins_with("--map-id="):
			selected_map_id = StringName(argument.get_slice("=", 1))
			assert(MapData.has_map(selected_map_id), "Unknown map ID: %s" % selected_map_id)
		elif argument == "--record-round-history":
			record_round_history = true
		elif argument == "--starter-calibration":
			starter_calibration = true
			focused_early_test = true
			focused_starter_tower = &""
			focused_starter_pool = STARTER_CALIBRATION_TOWERS.duplicate()
			disable_relics = true
			record_round_history = true
			simulation_round_limit = 7
			resume_from_checkpoint = false
		elif argument == "--live-build-benchmark":
			live_build_benchmark = true
			focused_early_test = true
			focused_starter_tower = &""
			disable_relics = true
			record_round_history = true
			simulation_round_limit = 7
			resume_from_checkpoint = false


func apply_preset() -> void:
	match preset:
		"smoke":
			population_size = 10
			generations = 2
			runs_per_policy = 2
			final_runs_per_profile = 2
			finalist_count = 4
			combat_samples = 2
		"early":
			focused_early_test = true
			simulation_round_limit = 10
			record_round_history = true
			final_runs_per_profile = 100
			combat_samples = 8
			resume_from_checkpoint = false
		"overnight":
			population_size = 120
			generations = 16
			runs_per_policy = 110
			final_runs_per_profile = 220
			finalist_count = 16
			combat_samples = 20
		_:
			pass


func build_sensitivity_profiles() -> void:
	sensitivity_profiles = [profile("baseline", "baseline", 1.0)]
	if focused_early_test:
		return
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


func get_test_tower_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		if not EXCLUDED_TOWERS.has(tower_id):
			result.append(tower_id)
	return result


func build_starting_rosters() -> void:
	starting_rosters.clear()
	if starter_calibration:
		for tower_id in STARTER_CALIBRATION_TOWERS:
			starting_rosters.append([tower_id])
		for first_index in STARTER_CALIBRATION_TOWERS.size():
			for second_index in range(first_index + 1, STARTER_CALIBRATION_TOWERS.size()):
				starting_rosters.append([
					STARTER_CALIBRATION_TOWERS[first_index],
					STARTER_CALIBRATION_TOWERS[second_index],
				])
		return
	var tower_ids := get_test_tower_ids()
	tower_ids.sort()
	for first_index in tower_ids.size():
		for second_index in range(first_index + 1, tower_ids.size()):
			if focused_early_test:
				if not focused_starter_pool.is_empty():
					if not focused_starter_pool.has(tower_ids[first_index]) or not focused_starter_pool.has(tower_ids[second_index]):
						continue
				elif not focused_starter_tower.is_empty() and tower_ids[first_index] != focused_starter_tower and tower_ids[second_index] != focused_starter_tower:
					continue
			starting_rosters.append([
				tower_ids[first_index],
				tower_ids[second_index],
			])
	assert(
		not starting_rosters.is_empty(),
		"At least %d towers are required for starter-roster testing"
			% STARTER_ROSTER_SIZE
	)


func get_starting_roster_signature(roster: Array) -> String:
	var labels := PackedStringArray()
	for tower_id in roster:
		labels.append(String(tower_id))
	labels.sort()
	return "+".join(labels)


func get_starting_roster_signatures() -> Array[String]:
	var result: Array[String] = []
	for roster in starting_rosters:
		result.append(get_starting_roster_signature(roster))
	return result


func prepare_combat_lookup() -> void:
	combat = CombatSimulator.new()
	combat.duration = 20.0
	combat.rng.seed = seed_value + 101
	combat.build_enemy_scenarios()
	combat.validate_tower_progression()
	for scenario in combat.scenarios:
		enemy_scenarios[StringName(scenario["id"])] = scenario.duplicate(true)
	for tower_id in get_test_tower_ids():
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


func prepare_director_count_templates() -> void:
	var director := MainScene.instantiate()
	const SAMPLE_COUNT := 6
	for round_number in range(1, 21):
		var round_types: Array[StringName] = [&"standard"]
		if round_number in [8, 16]:
			round_types.append_array([&"horde", &"elite"])
		for round_type in round_types:
			var totals := {}
			for sample_index in SAMPLE_COUNT:
				var counts: Dictionary = director.simulate_director_spawn_counts(
					round_number,
					round_type,
					seed_value + round_number * 104729 + sample_index * 7919
				)
				for enemy_id in counts:
					totals[enemy_id] = float(totals.get(enemy_id, 0.0)) + float(counts[enemy_id])
			var averages := {}
			for enemy_id in totals:
				averages[enemy_id] = float(totals[enemy_id]) / float(SAMPLE_COUNT)
			director_count_templates["%d:%s" % [round_number, round_type]] = averages
	director.free()
	print("Director lookup: %d round/type templates using live formation timing" % director_count_templates.size())
	for key in ["1:standard", "8:horde", "8:elite", "16:horde", "16:elite"]:
		var total := 0.0
		for count in Dictionary(director_count_templates.get(key, {})).values():
			total += float(count)
		print("Director template %s: %.1f base enemies" % [key, total])


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
	var dps_health_curves := {}
	var revealed_dps_health_curves := {}
	var control_by_enemy := {}
	var saucer_abduction_by_enemy := {}
	var saucer_abduction_health_curves := {}
	for enemy_key in enemy_scenarios:
		var scenario: Dictionary = enemy_scenarios[enemy_key]
		var health_curve := PackedFloat32Array()
		var revealed_health_curve := PackedFloat32Array()
		var abduction_curve := PackedFloat32Array()
		for health_multiplier in COMBAT_HEALTH_MULTIPLIERS:
			var scaled_scenario := get_health_scaled_scenario(
				scenario,
				health_multiplier
			)
			var total := 0.0
			for _sample in combat_samples:
				total += combat.simulate_trial(
					tower_id,
					stats,
					traits,
					scaled_scenario
				)
			health_curve.append(total / float(combat_samples))
			if bool(scenario.get("hidden", false)):
				var revealed_scenario := scaled_scenario.duplicate(true)
				revealed_scenario["hidden"] = false
				var revealed_total := 0.0
				for _sample in combat_samples:
					revealed_total += combat.simulate_trial(
						tower_id,
						stats,
						traits,
						revealed_scenario
					)
				revealed_health_curve.append(
					revealed_total / float(combat_samples)
				)
			else:
				revealed_health_curve.append(health_curve[-1])
			if tower_id == &"saucer":
				abduction_curve.append(
					combat.get_saucer_abduction_total(stats, scaled_scenario)
					/ maxf(float(combat.duration), 1.0)
				)
		dps_health_curves[enemy_key] = health_curve
		revealed_dps_health_curves[enemy_key] = revealed_health_curve
		dps_by_enemy[enemy_key] = health_curve[
			COMBAT_HEALTH_MULTIPLIERS.find(1.0)
		]
		control_by_enemy[enemy_key] = combat.get_control_value(stats, traits, scenario)
		if tower_id == &"saucer":
			saucer_abduction_health_curves[enemy_key] = abduction_curve
			saucer_abduction_by_enemy[enemy_key] = abduction_curve[
				COMBAT_HEALTH_MULTIPLIERS.find(1.0)
			]
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
		"dps_health_curves": dps_health_curves,
		"revealed_dps_health_curves": revealed_dps_health_curves,
		"control": control_by_enemy,
		"saucer_abduction": saucer_abduction_by_enemy,
		"saucer_abduction_health_curves": saucer_abduction_health_curves,
	}
	candidates[key] = entry
	candidates_by_tower[tower_id].append(key)


func get_health_scaled_scenario(
	base_scenario: Dictionary,
	health_multiplier: float
) -> Dictionary:
	var result := base_scenario.duplicate(true)
	result["health"] = maxf(
		float(base_scenario.get("health", 1.0)) * health_multiplier,
		1.0
	)
	result["spawned_health_per_primary"] = maxf(
		float(base_scenario.get("spawned_health_per_primary", 0.0))
			* health_multiplier,
		0.0
	)
	return result


func interpolate_health_curve(
	curve: PackedFloat32Array,
	health_multiplier: float
) -> float:
	if curve.is_empty():
		return 0.0
	if health_multiplier <= COMBAT_HEALTH_MULTIPLIERS[0]:
		return float(curve[0])
	for upper_index in range(1, COMBAT_HEALTH_MULTIPLIERS.size()):
		var upper_multiplier := COMBAT_HEALTH_MULTIPLIERS[upper_index]
		if health_multiplier <= upper_multiplier:
			var lower_index := upper_index - 1
			var lower_multiplier := COMBAT_HEALTH_MULTIPLIERS[lower_index]
			var weight := inverse_lerp(
				lower_multiplier,
				upper_multiplier,
				health_multiplier
			)
			return lerpf(
				float(curve[lower_index]),
				float(curve[upper_index]),
				weight
			)
	return float(curve[-1])


func prepare_map_geometry() -> void:
	var scene_instance := MapData.instantiate_map(selected_map_id)
	var path_node := scene_instance.get_enemy_path()
	assert(path_node != null and path_node.curve != null, "Map requires a Path2D curve")
	var curve := path_node.curve
	var map_bounds := scene_instance.native_build_bounds
	var path_length := curve.get_baked_length()
	map_path_length = path_length
	var distance := 0.0
	while distance < path_length:
		map_path_samples.append(curve.sample_baked(distance, true))
		distance += MAP_PATH_SAMPLE_INTERVAL
	map_path_samples.append(curve.sample_baked(path_length, true))
	map_combat_samples.clear()
	for sample_index in range(0, map_path_samples.size(), MAP_COMBAT_SEGMENT_STRIDE):
		map_combat_samples.append(map_path_samples[sample_index])
	if map_combat_samples.is_empty() or map_combat_samples[-1] != map_path_samples[-1]:
		map_combat_samples.append(map_path_samples[-1])
	map_combat_segment_length = map_path_length / maxf(float(map_combat_samples.size() - 1), 1.0)
	map_placements.clear()
	var footprint_definition: Vector2i = GameStats.get_tower(
		get_test_tower_ids()[0]
	).get("footprint_cells", Vector2i.ONE)
	for tower_id in get_test_tower_ids():
		assert(
			GameStats.get_tower(tower_id).get("footprint_cells", Vector2i.ONE)
				== footprint_definition,
			"Shared placement lookup requires equal tower footprints"
		)
	var footprint_size := Vector2(footprint_definition) * GameStats.BUILD_CELL_SIZE
	var placement_cell_size := Vector2i(
		roundi(footprint_size.x / MAP_PLACEMENT_SNAP),
		roundi(footprint_size.y / MAP_PLACEMENT_SNAP)
	)
	var placement_index := 0
	for origin_y in range(
		int(map_bounds.position.y),
		int(map_bounds.end.y - footprint_size.y) + 1,
		int(MAP_PLACEMENT_SNAP)
	):
		for origin_x in range(
			int(map_bounds.position.x),
			int(map_bounds.end.x - footprint_size.x) + 1,
			int(MAP_PLACEMENT_SNAP)
		):
			var center := Vector2(origin_x, origin_y) + footprint_size * 0.5
			var cells: Array[Vector2i] = []
			var blocked := false
			for cell_y in placement_cell_size.y:
				for cell_x in placement_cell_size.x:
					var cell := Vector2i(
						floori(origin_x / MAP_PLACEMENT_SNAP) + cell_x,
						floori(origin_y / MAP_PLACEMENT_SNAP) + cell_y
					)
					cells.append(cell)
					var cell_center := Vector2(cell) * MAP_PLACEMENT_SNAP + Vector2.ONE * MAP_PLACEMENT_SNAP * 0.5
					if (
						get_closest_sample_distance(cell_center)
						<= scene_instance.path_no_build_radius
					):
						blocked = true
			if blocked:
				continue
			map_placements.append({"index": placement_index, "position": center, "cells": cells})
			placement_index += 1
	for candidate_key_value in candidates:
		var ranking: Array[Dictionary] = []
		var coverages := PackedFloat32Array()
		coverages.resize(map_placements.size())
		var candidate: Dictionary = candidates[candidate_key_value]
		for placement in map_placements:
			var coverage := get_map_coverage(candidate, placement["position"])
			coverages[int(placement["index"])] = coverage
			ranking.append({
				"index": placement["index"],
				"coverage": coverage,
			})
		ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["coverage"]) > float(b["coverage"])
		)
		placement_rankings[candidate_key_value] = ranking
		placement_coverages[candidate_key_value] = coverages
	scene_instance.free()
	print("Map geometry: %d path samples, %d combat segments, %d legal placements" % [
		map_path_samples.size(), map_combat_samples.size(), map_placements.size(),
	])
	for tower_id in get_test_tower_ids():
		var base_key := candidate_key(tower_id, 0, &"")
		var top_ranking: Array = placement_rankings.get(base_key, [])
		if not top_ranking.is_empty():
			print("Map coverage %s: best %.1f%%, engagement %.1f%%" % [
				tower_id,
				float(top_ranking[0]["coverage"]) * 100.0,
				get_map_engagement_from_coverage(float(top_ranking[0]["coverage"])) * 100.0,
			])


func get_closest_sample_distance(position: Vector2) -> float:
	var closest := INF
	for sample in map_path_samples:
		closest = minf(closest, position.distance_to(sample))
	return closest


func get_map_coverage(candidate: Dictionary, position: Vector2) -> float:
	if map_path_samples.is_empty():
		return TOWER_ENGAGEMENT_COVERAGE
	var stats: Dictionary = candidate["stats"]
	var maximum_range := float(stats.get("range", stats.get("deployment_radius", 8.0))) * MAP_RANGE_PIXELS_PER_UNIT
	var minimum_range := float(stats.get("minimum_range", candidate["tower"].get("minimum_range", 0.0))) * MAP_RANGE_PIXELS_PER_UNIT
	var covered := 0
	for sample in map_path_samples:
		var distance := position.distance_to(sample)
		if distance <= maximum_range and distance >= minimum_range:
			covered += 1
	return float(covered) / maxf(float(map_path_samples.size()), 1.0)


func get_map_engagement_from_coverage(coverage: float) -> float:
	return clampf(
		MAP_MINIMUM_ENGAGEMENT
		+ sqrt(maxf(coverage, 0.0)) * MAP_COVERAGE_ENGAGEMENT_SCALE,
		MAP_MINIMUM_ENGAGEMENT,
		MAP_MAXIMUM_ENGAGEMENT
	)


func get_covered_combat_segments(
	candidate: Dictionary,
	placement_index: int,
	state: Dictionary = {}
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not use_map_geometry or placement_index < 0 or placement_index >= map_placements.size():
		return result
	var position: Vector2 = map_placements[placement_index]["position"]
	var stats: Dictionary = candidate["stats"]
	var maximum_range := float(stats.get("range", stats.get("deployment_radius", 8.0)))
	var traits: Dictionary = candidate["traits"]
	if not state.is_empty() and traits["damage_tags"].has(&"beam"):
		maximum_range *= pow(
			GameStats.FOCUSED_LENS_RANGE_MULTIPLIER,
			float(relic_count(state, &"focused_lens"))
		)
		maximum_range *= (
			1.0
			+ GameStats.WIDE_LENS_RANGE_PER_STACK
				* float(relic_count(state, &"wide_lens"))
		)
	if (
		not state.is_empty()
		and traits["damage_tags"].has(&"melee")
		and relic_count(state, &"lone_wolf") > 0
		and count_built_tower(state["build"], candidate["tower_id"]) <= 1
	):
		maximum_range *= GameStats.LONE_WOLF_RANGE_MULTIPLIER
	maximum_range *= MAP_RANGE_PIXELS_PER_UNIT
	var minimum_range := float(stats.get("minimum_range", candidate["tower"].get("minimum_range", 0.0))) * MAP_RANGE_PIXELS_PER_UNIT
	for segment_index in map_combat_samples.size():
		var distance := position.distance_to(map_combat_samples[segment_index])
		if distance <= maximum_range and distance >= minimum_range:
			result.append(segment_index)
	return result


func candidate_key(tower_id: StringName, level: int, path: StringName) -> String:
	return "%s:%d:%s" % [tower_id, level, path]


func create_initial_population() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var archetypes := [
		"generalist", "economy", "upgrades", "expansion", "biological",
		"technology", "ballistic", "explosive", "beam", "melee",
		"electric", "control", "critical",
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
	for tower_id in get_test_tower_ids():
		tower_weights[tower_id] = search_rng.randf_range(0.75, 1.25)
	var category_weights := {}
	for category in [
		&"global", &"biological", &"technology", &"ballistic", &"explosive",
		&"beam", &"melee", &"electric", &"critical", &"psionic", &"reveal",
		&"pierce", &"stun",
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
	var evaluation_runs := maxi(run_count, starting_rosters.size())
	var results: Array = []
	results.resize(population.size())
	print("Evaluating %d policies x %d runs across %d workers..." % [
		population.size(), evaluation_runs, worker_count,
	])
	var task_id := WorkerThreadPool.add_group_task(
		_evaluate_policy_task.bind(
			population,
			evaluation_runs,
			generation,
			results
		),
		population.size(),
		mini(worker_count, population.size())
	)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	var ranked: Array[Dictionary] = []
	for result in results:
		ranked.append(result)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return ranked


func _evaluate_policy_task(
	policy_index: int,
	population: Array[Dictionary],
	evaluation_runs: int,
	generation: int,
	results: Array
) -> void:
	var policy: Dictionary = population[policy_index]
	var totals := new_metric_totals()
	for run_index in evaluation_runs:
		var profile_data: Dictionary = sensitivity_profiles[
			(run_index + generation + int(policy["id"]))
			% sensitivity_profiles.size()
		]
		var roster_index := (
			run_index + generation + int(policy["id"])
		) % starting_rosters.size()
		var run_seed := (
			seed_value
			+ generation * 1000003
			+ int(policy["id"]) * 7919
			+ run_index * 101
			+ roster_index * 3571
		)
		accumulate_result(
			totals,
			simulate_run(
				policy,
				profile_data,
				run_seed,
				starting_rosters[roster_index]
			)
		)
	var metrics := finalize_metrics(totals, evaluation_runs)
	metrics["policy"] = policy
	results[policy_index] = metrics


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


func simulate_run(
	policy: Dictionary,
	profile_data: Dictionary,
	run_seed: int,
	starting_roster: Array,
	special_round_one_override: StringName = &""
) -> Dictionary:
	var run_rng := RandomNumberGenerator.new()
	run_rng.seed = run_seed
	var mode := GameStats.get_mode(&"easy")
	var special_round_one_type: StringName = special_round_one_override
	if special_round_one_type.is_empty():
		special_round_one_type = &"horde" if run_rng.randf() < 0.5 else &"elite"
	var challenge_rounds := {
		8: special_round_one_type,
		16: &"elite" if special_round_one_type == &"horde" else &"horde",
	}
	var enemy_progression := GameStats.build_normal_enemy_progression(run_rng)
	var state := {
		"money": float(mode["starting_cash"]) * float(profile_data["starting_cash"]),
		"lives": float(mode["starting_lives"]),
		"roster": starting_roster.duplicate(),
		"build": [],
		"occupied_cells": {},
		"relics": {},
		"recent_relic_offers": [],
		"dual_path_used": {&"technology": false, &"biological": false},
		"contraband_tower": &"",
		"holiday_sale_tower": &"",
		"leak_damage": 0.0,
		"round_reached": 0,
		"challenge_rounds": challenge_rounds,
		"enemy_debut_plan": enemy_progression["debut_plan"],
		"first_tower_built": &"",
		"upgrade_purchases": 0,
		"total_spent": 0.0,
	}
	if focused_early_test and not focused_starter_tower.is_empty():
		assert(state["roster"].has(focused_starter_tower), "Focused roster is missing forced starter %s" % focused_starter_tower)
		var forced_key := candidate_key(focused_starter_tower, 0, &"")
		var forced_candidate: Dictionary = candidates[forced_key]
		var forced_cost := float(forced_candidate["cost"])
		assert(float(state["money"]) >= forced_cost, "Forced starter %s costs more than starting cash" % focused_starter_tower)
		apply_purchase_action(state, {
			"kind": &"build",
			"tower_id": focused_starter_tower,
			"target_key": forced_key,
			"cost": forced_cost,
			"instance": -1,
			"placement_index": get_best_available_placement_index(state, forced_candidate),
		})
	var round_history: Array[Dictionary] = []
	var round_limit := mini(simulation_round_limit, int(mode["max_rounds"]))
	for round_number in range(1, round_limit + 1):
		var mix := build_round_mix(
			round_number,
			profile_data,
			mode,
			run_rng,
			StringName(challenge_rounds.get(round_number, &"standard")),
			state["enemy_debut_plan"]
		)
		var starting_money := float(state["money"])
		var spent_before_round := float(state["total_spent"])
		if live_build_benchmark:
			purchase_live_build_for_round(state, policy, profile_data, round_number)
		else:
			purchase_for_round(state, policy, mix, profile_data, round_number)
		var post_purchase_money := float(state["money"])
		var prewave_spent := float(state["total_spent"]) - spent_before_round
		var outcome := resolve_round(
			state, mix, profile_data, mode, round_number, policy
		)
		state["round_reached"] = round_number
		state["lives"] = float(state["lives"]) - float(outcome["leak_damage"])
		state["leak_damage"] = float(state["leak_damage"]) + float(outcome["leak_damage"])
		if not bool(outcome.get("kill_income_credited", false)):
			state["money"] = float(state["money"]) + float(outcome["kill_income"])
		var survived := float(state["lives"]) > 0.0
		var round_reward := 0.0
		if survived:
			round_reward = (
				float(GameStats.get_round_cash_reward(round_number))
				* float(profile_data["round_income"])
			)
			if relic_count(state, &"dividends") > 0:
				round_reward += minf(
					floorf(float(state["money"]) * GameStats.DIVIDENDS_INTEREST_RATE),
					float(GameStats.DIVIDENDS_INTEREST_CAP)
				)
			state["money"] = float(state["money"]) + round_reward
			# Gameplay rolls the next sale before opening this round's draft.
			# A newly drafted Holiday Sale therefore starts affecting builds one
			# full round later, not immediately on the following build phase.
			roll_holiday_sale_tower(state, run_rng)
			if TOWER_DRAFT_ROUNDS.has(round_number):
				if live_build_benchmark and round_number == 4:
					if not state["roster"].has(&"longshot"):
						state["roster"].append(&"longshot")
				else:
					resolve_tower_draft(state, policy, run_rng)
			if not disable_relics and RELIC_DRAFT_ROUNDS.has(round_number):
				resolve_relic_draft(state, policy, round_number, run_rng)
		if record_round_history:
			round_history.append({
				"round": round_number,
				"survived": survived,
				"starting_money": starting_money,
				"spent": prewave_spent,
				"post_purchase_money": post_purchase_money,
				"midwave_spent": (
					float(state["total_spent"])
					- spent_before_round
					- prewave_spent
				),
				"kill_income": float(outcome["kill_income"]),
				"round_reward": round_reward,
				"ending_money": float(state["money"]),
				"round_leak_damage": float(outcome["leak_damage"]),
				"lives": maxf(float(state["lives"]), 0.0),
				"build_signature": get_build_signature(state["build"]),
				"tower_signature": get_tower_signature(state["build"]),
			})
		if not survived:
			break
	return {
		"policy_id": policy["id"],
		"policy_name": policy["name"],
		"run_seed": run_seed,
		"special_round_one_type": special_round_one_type,
		"forced_starter": focused_starter_tower,
		"starter_calibration": starter_calibration,
		"relics_disabled": disable_relics,
		"starter_pool": focused_starter_pool,
		"profile": profile_data["id"],
		"won": int(state["round_reached"]) >= round_limit and float(state["lives"]) > 0.0,
		"round_reached": state["round_reached"],
		"lives": maxf(float(state["lives"]), 0.0),
		"money": float(state["money"]),
		"leak_damage": float(state["leak_damage"]),
		"build_signature": get_build_signature(state["build"]),
		"relic_signature": get_relic_signature(state["relics"]),
		"tower_signature": get_tower_signature(state["build"]),
		"first_tower": state["first_tower_built"],
		"upgrade_purchases": state["upgrade_purchases"],
		"total_spent": state["total_spent"],
		"path_coverage": get_build_path_coverage(state["build"]),
		"tower_count": state["build"].size(),
		"starting_roster": get_starting_roster_signature(starting_roster),
		"round_history": round_history,
	}


func build_round_mix(
	round_number: int,
	profile_data: Dictionary,
	mode: Dictionary,
	run_rng: RandomNumberGenerator,
	round_type: StringName = &"standard",
	enemy_debut_plan: Dictionary = {}
) -> Array[Dictionary]:
	var duration := GameStats.get_round_duration(round_number)
	var threat_rate := (
		GameStats.get_round_threat_budget(round_number)
		/ maxf(duration, 0.01)
	)
	if round_type in [&"horde", &"gauntlet", &"payday"]:
		threat_rate *= 2.0
	var chunk_interval := maxf(float(mode.get("threat_chunk_interval", 4.0)), 0.01)
	var chunk_count := floori(duration / chunk_interval)
	var generated_threat := threat_rate * (
		duration * float(mode.get("threat_continuous_ratio", 1.0))
		+ float(chunk_count)
			* chunk_interval
			* float(mode.get("threat_chunk_ratio", 0.0))
	)
	var threat_budget := (
		(float(mode.get("starting_spawn_threat", 1.0)) + generated_threat)
		* float(profile_data["enemy_density"])
	)
	var eligible: Array[StringName] = []
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var enemy := GameStats.get_enemy(enemy_id)
		var debut_round := int(enemy_debut_plan.get(
			enemy_id,
			enemy.get("earliest_debut_round", 1)
		))
		if bool(enemy.get("boss", false)) or debut_round > round_number:
			continue
		var weight := float(enemy.get("spawn_weight", 0.0))
		if weight <= 0.0:
			continue
		if (
			round_type == &"payday"
			and StringName(enemy.get("role", &"fodder")) not in [&"fodder", &"pressure"]
		):
			continue
		eligible.append(enemy_id)
	var role_weights := get_expected_director_role_weights(
		round_number,
		round_type,
		eligible
	)
	var enemy_weights := {}
	var total_weight := 0.0
	for enemy_id in eligible:
		var enemy := GameStats.get_enemy(enemy_id)
		var role := StringName(enemy.get("role", &"fodder"))
		var role_spawn_total := 0.0
		for peer_id in eligible:
			var peer := GameStats.get_enemy(peer_id)
			if StringName(peer.get("role", &"fodder")) == role:
				role_spawn_total += float(peer.get("spawn_weight", 0.0))
		var enemy_weight := (
			float(role_weights.get(role, 0.0))
			* float(enemy.get("spawn_weight", 0.0))
			/ maxf(role_spawn_total, 1.0)
		)
		enemy_weights[enemy_id] = enemy_weight
		total_weight += enemy_weight
	var mix: Array[Dictionary] = []
	var director_counts: Dictionary = {}
	if enemy_debut_plan.is_empty():
		director_counts = director_count_templates.get(
			"%d:%s" % [round_number, round_type],
			{}
		)
	var base_variant: StringName = (
		&"horde" if round_type in [&"horde", &"gauntlet"]
		else (&"payday" if round_type == &"payday" else &"normal")
	)
	if not director_counts.is_empty():
		for director_key in director_counts:
			var key_parts := String(director_key).split("|", false, 1)
			var enemy_id := StringName(key_parts[0])
			if not GameStats.ENEMIES.has(enemy_id):
				continue
			var enemy := GameStats.get_enemy(enemy_id)
			if bool(enemy.get("boss", false)):
				continue
			var spawn_variant := (
				StringName(key_parts[1])
				if key_parts.size() > 1
				else base_variant
			)
			var count := (
				float(director_counts[director_key])
				* float(profile_data["enemy_density"])
			)
			if count <= 0.0:
				continue
			mix.append(make_mix_entry(
				enemy_id, enemy, count, round_number, profile_data, mode,
				duration, spawn_variant
			))
	else:
		for enemy_id in eligible:
			var enemy := GameStats.get_enemy(enemy_id)
			var share := (
				float(enemy_weights.get(enemy_id, 0.0))
				/ maxf(total_weight, 1.0)
			)
			var count := (
				threat_budget * share
				/ maxf(float(enemy.get("director_cost", 1.0)), 1.0)
			)
			if count <= 0.0:
				continue
			mix.append(make_mix_entry(
				enemy_id, enemy, count, round_number, profile_data, mode,
				duration, base_variant
			))
	if round_type in [&"elite", &"gauntlet"]:
		append_elite_challenge_entries(
			mix, eligible, round_number, profile_data, mode, duration,
			run_rng, round_type == &"gauntlet"
		)
	if round_number >= int(mode["max_rounds"]):
		var boss := GameStats.get_enemy(&"brute")
		mix.append(make_mix_entry(
			&"brute", boss, 1.0, round_number, profile_data, mode,
			duration, &"normal"
		))
	return mix


func get_expected_director_role_weights(
	round_number: int,
	round_type: StringName,
	eligible: Array[StringName]
) -> Dictionary:
	var wave_weights: Dictionary = GameStats.WAVE_ROLE_WEIGHTS.back()["weights"]
	for entry in GameStats.WAVE_ROLE_WEIGHTS:
		if round_number <= int(entry["maximum_wave"]):
			wave_weights = entry["weights"]
			break
	var styles: Array[StringName] = [&"steady"]
	if round_type == &"gauntlet":
		styles = [
			&"pulses", &"swarm_batch", &"convoy",
			&"layered_assault", &"elite_escort", &"stream",
		]
	elif round_type == &"payday":
		styles = [&"stream", &"pulses", &"swarm_batch", &"burst"]
	else:
		styles = GameStats.get_eligible_wave_styles(round_number, eligible)
	var available_roles := {}
	for enemy_id in eligible:
		available_roles[StringName(
			GameStats.get_enemy(enemy_id).get("role", &"fodder")
		)] = true
	var result := {}
	for role in [&"fodder", &"pressure", &"tank", &"support"]:
		if not available_roles.has(role):
			continue
		var formation_average := 0.0
		for style_name in styles:
			var recipe_style := &"steady" if style_name == &"standard" else style_name
			var formation: Dictionary = GameStats.FORMATION_ROLE_WEIGHTS.get(
				recipe_style,
				GameStats.FORMATION_ROLE_WEIGHTS[&"steady"]
			)
			formation_average += float(formation.get(role, 0.0))
		formation_average /= maxf(float(styles.size()), 1.0)
		result[role] = (
			float(wave_weights.get(role, 0.0)) * formation_average / 100.0
		)
	return result


func append_elite_challenge_entries(
	mix: Array[Dictionary],
	eligible: Array[StringName],
	round_number: int,
	profile_data: Dictionary,
	mode: Dictionary,
	duration: float,
	run_rng: RandomNumberGenerator,
	is_gauntlet: bool
) -> void:
	if eligible.is_empty():
		return
	var elite_candidates: Array[StringName] = []
	for enemy_id in eligible:
		var role: StringName = GameStats.get_enemy(enemy_id).get(
			"role", &"fodder"
		)
		if role in [&"pressure", &"tank"]:
			elite_candidates.append(enemy_id)
	if elite_candidates.is_empty():
		elite_candidates = eligible.duplicate()
	var event_counts := {}
	var next_event_time := run_rng.randf_range(
		10.0 if is_gauntlet else 15.0,
		18.0 if is_gauntlet else 25.0
	)
	var final_event_time := duration * 0.80
	while next_event_time < final_event_time:
		var elite_count := (
			run_rng.randi_range(1, 3)
			if is_gauntlet
			else (
				2 if round_number == 6 and run_rng.randf() < 0.25
				else (1 if round_number == 6 else run_rng.randi_range(1, 2))
			)
		)
		var escort_count := run_rng.randi_range(
			4 if is_gauntlet else 3,
			8 if is_gauntlet else 6
		)
		add_challenge_enemy_counts(
			event_counts, elite_candidates, elite_count, &"elite", run_rng
		)
		add_challenge_enemy_counts(
			event_counts, eligible, escort_count,
			&"horde" if is_gauntlet else &"normal", run_rng
		)
		next_event_time += run_rng.randf_range(
			10.0 if is_gauntlet else 15.0,
			18.0 if is_gauntlet else 25.0
		)
	add_challenge_enemy_counts(
		event_counts,
		elite_candidates,
		3 if round_number >= 11 else 2,
		&"elite",
		run_rng
	)
	add_challenge_enemy_counts(
		event_counts,
		eligible,
		run_rng.randi_range(6, 10) if is_gauntlet else run_rng.randi_range(4, 7),
		&"horde" if is_gauntlet else &"normal",
		run_rng
	)
	for event_key in event_counts:
		var parts := String(event_key).split(":", false, 1)
		var variant := StringName(parts[0])
		var enemy_id := StringName(parts[1])
		mix.append(make_mix_entry(
			enemy_id,
			GameStats.get_enemy(enemy_id),
			float(event_counts[event_key]),
			round_number,
			profile_data,
			mode,
			duration,
			variant
		))


func add_challenge_enemy_counts(
	counts: Dictionary,
	candidates_for_event: Array[StringName],
	amount: int,
	spawn_variant: StringName,
	run_rng: RandomNumberGenerator
) -> void:
	for _index in amount:
		var enemy_id := choose_weighted_simulation_enemy(
			candidates_for_event,
			run_rng
		)
		var key := "%s:%s" % [spawn_variant, enemy_id]
		counts[key] = int(counts.get(key, 0)) + 1


func choose_weighted_simulation_enemy(
	available: Array[StringName],
	run_rng: RandomNumberGenerator
) -> StringName:
	var total_weight := 0.0
	for enemy_id in available:
		total_weight += maxf(
			float(GameStats.get_enemy(enemy_id).get("spawn_weight", 0.0)),
			0.0
		)
	if total_weight <= 0.0:
		return available[run_rng.randi_range(0, available.size() - 1)]
	var roll := run_rng.randf_range(0.0, total_weight)
	for enemy_id in available:
		roll -= maxf(
			float(GameStats.get_enemy(enemy_id).get("spawn_weight", 0.0)),
			0.0
		)
		if roll <= 0.0:
			return enemy_id
	return available.back()


func make_mix_entry(
	enemy_id: StringName,
	enemy: Dictionary,
	count: float,
	round_number: int,
	profile_data: Dictionary,
	_mode: Dictionary,
	duration: float,
	spawn_variant: StringName = &"normal"
) -> Dictionary:
	var unit_health := (
		float(enemy["health"])
		+ float(enemy.get("health_per_wave", 0.0))
			* float(round_number - 1)
	)
	var round_health_multiplier := GameStats.get_enemy_health_multiplier(
		round_number,
		enemy_id
	)
	var variant_health_multiplier := 1.0
	var variant_speed_multiplier := 1.0
	var variant_reward_multiplier := 1.0
	var variant_damage_multiplier := 1.0
	var variant_armor_bonus := 0.0
	match spawn_variant:
		&"horde":
			variant_health_multiplier = GameStats.HORDE_ENEMY_HEALTH_MULTIPLIER
			variant_reward_multiplier = 0.55
			variant_damage_multiplier = 0.70
		&"elite":
			variant_health_multiplier = GameStats.get_elite_enemy_health_multiplier(
				round_number
			)
			variant_speed_multiplier = GameStats.get_elite_enemy_speed_multiplier(
				round_number
			)
			variant_reward_multiplier = 3.0
			variant_damage_multiplier = 1.50
			variant_armor_bonus = 6.0
		&"payday":
			variant_health_multiplier = GameStats.PAYDAY_ENEMY_HEALTH_MULTIPLIER
			variant_damage_multiplier = 0.50
	var spawned_variant_health_multiplier := (
		1.0 if spawn_variant == &"elite" else variant_health_multiplier
	)
	var spawned_variant_reward_multiplier := (
		1.0 if spawn_variant == &"elite" else variant_reward_multiplier
	)
	unit_health = float(maxi(roundi(unit_health * (
		round_health_multiplier
		* float(profile_data["enemy_health"])
		* variant_health_multiplier
	)), 1))
	var extra_health := 0.0
	var extra_reward := 0.0
	if int(enemy.get("split_count", 0)) > 0:
		var child := GameStats.get_enemy(StringName(enemy["split_enemy_id"]))
		var child_health := float(maxi(roundi(
			(
				float(child["health"])
				+ float(child.get("health_per_wave", 0.0))
					* float(round_number - 1)
			)
			* GameStats.get_enemy_health_multiplier(
				round_number,
				StringName(enemy["split_enemy_id"])
			)
			* float(profile_data["enemy_health"])
			* spawned_variant_health_multiplier
		), 1))
		extra_health += float(enemy["split_count"]) * child_health
		extra_reward += (
			float(enemy["split_count"])
			* get_enemy_kill_reward(child)
			* spawned_variant_reward_multiplier
		)
	if int(enemy.get("summon_limit", 0)) > 0:
		var summoned := GameStats.get_enemy(StringName(enemy["summon_enemy_id"]))
		var summoned_health := float(maxi(roundi(
			(
				float(summoned["health"])
				+ float(summoned.get("health_per_wave", 0.0))
					* float(round_number - 1)
			)
			* GameStats.get_enemy_health_multiplier(
				round_number,
				StringName(enemy["summon_enemy_id"])
			)
			* float(profile_data["enemy_health"])
			* spawned_variant_health_multiplier
		), 1))
		extra_health += float(enemy["summon_limit"]) * summoned_health
		extra_reward += (
			float(enemy["summon_limit"])
			* get_enemy_kill_reward(summoned)
			* spawned_variant_reward_multiplier
		)
	var standard_speed_multiplier := (
		1.0 if bool(enemy.get("boss", false))
		else GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER
	)
	var speed := float(enemy["move_speed"]) * standard_speed_multiplier
	var enemy_traits: Array = enemy.get("traits", [])
	if enemy_traits.has(&"rushes"):
		var rush_start := clampf(float(enemy.get("rush_start_ratio", 0.7)), 0.0, 1.0)
		var rush_multiplier := maxf(float(enemy.get("rush_speed_multiplier", 1.0)), 1.0)
		speed /= maxf(rush_start + (1.0 - rush_start) / rush_multiplier, 0.01)
	speed *= float(profile_data["enemy_speed"]) * variant_speed_multiplier
	var composite_reward := (
		get_enemy_kill_reward(enemy) * variant_reward_multiplier
		+ extra_reward
	)
	return {
		"enemy_id": enemy_id,
		"enemy": enemy,
		"count": count,
		"health": unit_health + extra_health,
		"unit_health": unit_health,
		"spawned_health": extra_health,
		"armor": (
			float(enemy.get("armor", 0.0)) + variant_armor_bonus
		) * float(profile_data["enemy_armor"]),
		"speed": speed,
		"duration": duration,
		"reward": composite_reward,
		"leak": maxf(roundf(
			float(enemy.get("base_damage", 1.0))
			* variant_damage_multiplier
		), 1.0),
		"variant": spawn_variant,
	}


func get_enemy_kill_reward(enemy: Dictionary) -> float:
	return float(maxi(roundi(
		float(enemy.get("cash_reward", 0.0))
		* GameStats.KILL_REWARD_MULTIPLIER
	), 1))


func purchase_for_round(
	state: Dictionary,
	policy: Dictionary,
	mix: Array[Dictionary],
	profile_data: Dictionary,
	round_number: int
) -> void:
	var reserve := (
		float(policy["reserve"])
		* float(GameStats.get_round_cash_reward(round_number))
		* float(profile_data["round_income"])
	)
	# A viable saving strategy still establishes an initial defense. Applying
	# its reserve before the first build can otherwise make it hold affordable
	# starting cash while leaking out with an empty map.
	if state["build"].is_empty():
		reserve = 0.0
	var planning_mixes: Array = []
	for _purchase in 64:
		var actions := get_purchase_actions(state, profile_data, round_number)
		if actions.is_empty():
			return
		var has_affordable_action := false
		for action in actions:
			if float(action["cost"]) <= float(state["money"]) - reserve:
				has_affordable_action = true
				break
		if not has_affordable_action:
			return
		if planning_mixes.is_empty():
			planning_mixes = build_purchase_planning_mixes(
				mix,
				profile_data,
				round_number,
				state["challenge_rounds"],
				state["enemy_debut_plan"]
			)
		var scored: Array[Dictionary] = []
		for action in actions:
			var cost := float(action["cost"])
			var tower_id: StringName = action["tower_id"]
			var bias := float(policy["tower_weights"].get(tower_id, 1.0))
			bias *= float(policy["expansion_bias"] if action["kind"] == &"build" else policy["upgrade_bias"])
			var copies := count_built_tower(state["build"], tower_id)
			bias *= pow(1.0 - 0.08 * float(policy["diversity"]), float(copies))
			var planned_efficiency := get_planned_action_efficiency(
				state,
				action,
				planning_mixes,
				round_number,
				profile_data
			)
			scored.append({"action": action, "score": planned_efficiency * bias, "cost": cost})
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


func build_purchase_planning_mixes(
	current_mix: Array[Dictionary],
	profile_data: Dictionary,
	round_number: int,
	challenge_rounds: Dictionary,
	enemy_debut_plan: Dictionary
) -> Array:
	var result: Array = [current_mix]
	var mode := GameStats.get_mode(&"easy")
	for offset in range(1, PURCHASE_LOOKAHEAD_STEPS):
		var future_round := round_number + offset
		if future_round > simulation_round_limit:
			break
		var planning_rng := RandomNumberGenerator.new()
		planning_rng.seed = seed_value + future_round * 104729
		result.append(build_round_mix(
			future_round,
			profile_data,
			mode,
			planning_rng,
			StringName(challenge_rounds.get(future_round, &"standard")),
			enemy_debut_plan
		))
	return result


func get_planned_action_efficiency(
	state: Dictionary,
	action: Dictionary,
	planning_mixes: Array,
	round_number: int,
	profile_data: Dictionary
) -> float:
	var target: Dictionary = candidates[action["target_key"]]
	var previous: Dictionary = {}
	var placement_index := int(action.get("placement_index", -1))
	if int(action["instance"]) >= 0:
		var current_instance: Dictionary = state["build"][int(action["instance"])]
		previous = candidates[current_instance["candidate_key"]]
		placement_index = int(current_instance.get("placement_index", -1))
	var immediate_gain := get_positioned_candidate_power(
		target,
		state,
		planning_mixes[0],
		placement_index
	) - get_optional_candidate_power(previous, state, planning_mixes[0], placement_index)
	var immediate_efficiency := maxf(immediate_gain, 0.001) / maxf(float(action["cost"]), 1.0)
	var expected_kill_income := 0.0
	for entry in planning_mixes[0]:
		expected_kill_income += float(entry["count"]) * float(entry["reward"])
	var expected_income := maxf(
		(
			float(GameStats.get_round_cash_reward(round_number))
			* float(profile_data["round_income"])
		)
		+ expected_kill_income * float(profile_data["kill_income"]),
		1.0
	)
	return maxf(
		immediate_efficiency,
		get_best_upgrade_chain_efficiency(
			state,
			target,
			previous,
			float(action["cost"]),
			maxf(immediate_gain, 0.001),
			planning_mixes,
			1,
			expected_income,
			placement_index
		)
	)


func get_best_upgrade_chain_efficiency(
	state: Dictionary,
	current: Dictionary,
	previous: Dictionary,
	total_cost: float,
	discounted_gain: float,
	planning_mixes: Array,
	step: int,
	expected_income: float,
	placement_index: int
) -> float:
	var funding_gap := maxf(total_cost - float(state["money"]), 0.0)
	var funding_rounds := funding_gap / expected_income
	var best := (
		discounted_gain
		/ maxf(total_cost, 1.0)
		* pow(FUTURE_FUNDING_DISCOUNT, funding_rounds)
	)
	if step >= PURCHASE_LOOKAHEAD_STEPS:
		return best
	var next_candidates := get_candidate_upgrade_options(current)
	for next_candidate in next_candidates:
		var future_mix: Array = planning_mixes[mini(step, planning_mixes.size() - 1)]
		var incremental_gain := maxf(
			get_positioned_candidate_power(next_candidate, state, future_mix, placement_index)
			- get_positioned_candidate_power(current, state, future_mix, placement_index),
			0.001
		)
		var incremental_cost := maxf(
			float(next_candidate["cost"]) - float(current["cost"]),
			1.0
		)
		best = maxf(best, get_best_upgrade_chain_efficiency(
			state,
			next_candidate,
			current,
			total_cost + incremental_cost,
			discounted_gain + incremental_gain * pow(FUTURE_POWER_DISCOUNT, float(step)),
			planning_mixes,
			step + 1,
			expected_income,
			placement_index
		))
	return best


func get_candidate_upgrade_options(current: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tower_id: StringName = current["tower_id"]
	var level := int(current["level"])
	var path := StringName(current["path"])
	if level < 3:
		result.append(candidates[candidate_key(tower_id, level + 1, &"")])
	elif path.is_empty():
		for next_path in [&"a", &"b"]:
			var key := candidate_key(tower_id, 3, next_path)
			if candidates.has(key):
				result.append(candidates[key])
	return result


func get_optional_candidate_power(
	candidate: Dictionary,
	state: Dictionary,
	mix: Array[Dictionary],
	placement_index: int
) -> float:
	if candidate.is_empty():
		return 0.0
	return get_positioned_candidate_power(candidate, state, mix, placement_index)


func get_positioned_candidate_power(
	candidate: Dictionary,
	state: Dictionary,
	mix: Array[Dictionary],
	placement_index: int
) -> float:
	var power := get_candidate_mix_power(candidate, state, mix, placement_index)
	if not use_map_geometry or placement_index < 0:
		return power
	var covered_segments := get_covered_combat_segments(
		candidate,
		placement_index,
		state
	)
	var coverage := (
		float(covered_segments.size())
		/ maxf(float(map_combat_samples.size()), 1.0)
	)
	return power * get_map_engagement_from_coverage(coverage)


func get_purchase_actions(state: Dictionary, profile_data: Dictionary, round_number: int) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if state["build"].size() < MAX_TOWERS:
		for tower_id in state["roster"]:
			var base: Dictionary = candidates[candidate_key(tower_id, 0, &"")]
			var cost := get_adjusted_build_cost(state, tower_id, float(base["cost"]), profile_data, round_number)
			var placement_index := get_best_available_placement_index(state, base)
			if not use_map_geometry or placement_index >= 0:
				actions.append({"kind": &"build", "tower_id": tower_id, "target_key": base["key"], "cost": cost, "instance": -1, "placement_index": placement_index})
		if not StringName(state["contraband_tower"]).is_empty():
			var contraband_id: StringName = state["contraband_tower"]
			var contraband_candidate: Dictionary = candidates[candidate_key(contraband_id, 0, &"")]
			var contraband_placement := get_best_available_placement_index(state, contraband_candidate)
			if not use_map_geometry or contraband_placement >= 0:
				actions.append({"kind": &"build", "tower_id": contraband_id, "target_key": contraband_candidate["key"], "cost": 0.0, "instance": -1, "contraband": true, "placement_index": contraband_placement})
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


func purchase_live_build_for_round(
	state: Dictionary,
	policy: Dictionary,
	profile_data: Dictionary,
	round_number: int
) -> void:
	# Replays the player's reported opening. Longshot is selected after round 4,
	# so its build and first upgrade occur in the round-5 shopping phase.
	if round_number >= 1:
		live_build_ensure_count(state, &"invader", 1, profile_data, round_number)
		live_build_upgrade_copy(state, &"invader", 0, 3)
	if round_number >= 2:
		live_build_ensure_count(state, &"invader", 2, profile_data, round_number)
		live_build_upgrade_copy(state, &"invader", 1, 2)
	if round_number >= 3:
		live_build_ensure_count(state, &"invader", 3, profile_data, round_number)
		live_build_upgrade_copy(
			state,
			&"invader",
			2,
			int(policy.get("live_build_third_invader_level", 2))
		)
		live_build_ensure_count(state, &"gauss_repeater", 1, profile_data, round_number)
	if round_number >= 5 and state["roster"].has(&"longshot"):
		live_build_ensure_count(state, &"longshot", 1, profile_data, round_number)
		live_build_upgrade_copy(state, &"longshot", 0, 2)


func live_build_ensure_count(
	state: Dictionary,
	tower_id: StringName,
	target_count: int,
	profile_data: Dictionary,
	round_number: int
) -> void:
	var current_count := 0
	for instance in state["build"]:
		if StringName(instance["tower_id"]) == tower_id:
			current_count += 1
	while current_count < target_count:
		var base: Dictionary = candidates[candidate_key(tower_id, 0, &"")]
		var cost := get_adjusted_build_cost(
			state, tower_id, float(base["cost"]), profile_data, round_number
		)
		if float(state["money"]) < cost:
			return
		var placement_index := get_best_available_placement_index(state, base)
		if use_map_geometry and placement_index < 0:
			return
		apply_purchase_action(state, {
			"kind": &"build",
			"tower_id": tower_id,
			"target_key": base["key"],
			"cost": cost,
			"instance": -1,
			"placement_index": placement_index,
		})
		current_count += 1


func live_build_upgrade_copy(
	state: Dictionary,
	tower_id: StringName,
	copy_index: int,
	target_level: int
) -> void:
	var matching_indices: Array[int] = []
	for index in state["build"].size():
		if StringName(state["build"][index]["tower_id"]) == tower_id:
			matching_indices.append(index)
	if copy_index >= matching_indices.size():
		return
	var instance_index := matching_indices[copy_index]
	while int(state["build"][instance_index]["level"]) + 1 < target_level:
		var instance: Dictionary = state["build"][instance_index]
		var current: Dictionary = candidates[instance["candidate_key"]]
		var next_level := int(instance["level"]) + 1
		var target: Dictionary = candidates[candidate_key(tower_id, next_level, &"")]
		var cost := float(target["cost"] - current["cost"])
		if float(state["money"]) < cost:
			return
		apply_purchase_action(state, {
			"kind": &"upgrade",
			"tower_id": tower_id,
			"target_key": target["key"],
			"cost": cost,
			"instance": instance_index,
		})


func get_best_available_placement_index(state: Dictionary, candidate: Dictionary) -> int:
	if not use_map_geometry:
		return -1
	var traits: Dictionary = candidate["traits"]
	var tower: Dictionary = candidate["tower"]
	var needs_dynamic_ranking: bool = (
		(traits["damage_tags"].has(&"beam") and (
			relic_count(state, &"focused_lens") > 0
			or relic_count(state, &"wide_lens") > 0
		))
		or (traits["damage_tags"].has(&"melee") and (
			relic_count(state, &"lone_wolf") > 0
			or relic_count(state, &"strength_in_numbers") > 0
		))
		or (tower.get("type_tags", []).has(&"technology")
			and relic_count(state, &"network_upgrade") > 0)
	)
	var best_index := -1
	var best_score := -INF
	var available_checked := 0
	for ranked in placement_rankings.get(candidate["key"], []):
		var placement_index := int(ranked["index"])
		var placement: Dictionary = map_placements[placement_index]
		var available := true
		for cell in placement["cells"]:
			if state["occupied_cells"].has(cell):
				available = false
				break
		if available:
			if not needs_dynamic_ranking:
				return placement_index
			var covered := get_covered_combat_segments(
				candidate,
				placement_index,
				state
			)
			var score := get_map_engagement_from_coverage(
				float(covered.size())
				/ maxf(float(map_combat_samples.size()), 1.0)
			)
			if tower.get("type_tags", []).has(&"technology"):
				score *= (
					1.0
					+ GameStats.NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK
						* float(count_towers_within_footprint_gap(
							state, placement_index, &"technology"
						))
						* float(relic_count(state, &"network_upgrade"))
				)
			if traits["damage_tags"].has(&"melee"):
				score *= (
					1.0
					+ GameStats.STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR
						* float(mini(
							count_nearby_towers(
								state, placement_index,
								1.5 * GameStats.BUILD_CELL_SIZE, &"melee"
							),
							GameStats.STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS
						))
						* float(mini(relic_count(state, &"strength_in_numbers"), 1))
				)
				if (
					relic_count(state, &"lone_wolf") > 0
					and count_built_tower(
						state["build"], candidate["tower_id"]
					) <= 1
				):
					score *= (
						GameStats.LONE_WOLF_DAMAGE_MULTIPLIER
						* GameStats.LONE_WOLF_ATTACK_SPEED_MULTIPLIER
					)
			if score > best_score:
				best_score = score
				best_index = placement_index
			available_checked += 1
			if available_checked >= 256:
				break
	return best_index


func get_adjusted_build_cost(
	state: Dictionary,
	tower_id: StringName,
	base_cost: float,
	_profile_data: Dictionary,
	_round_number: int
) -> float:
	var result := base_cost
	if relic_count(state, &"holiday_sale") > 0:
		var sale_id := StringName(state.get("holiday_sale_tower", &""))
		result *= GameStats.HOLIDAY_SALE_DISCOUNT_MULTIPLIER if tower_id == sale_id else GameStats.HOLIDAY_SALE_OTHER_COST_MULTIPLIER
	return maxf(roundf(result), 0.0)


func roll_holiday_sale_tower(
	state: Dictionary,
	run_rng: RandomNumberGenerator
) -> void:
	state["holiday_sale_tower"] = &""
	var roster: Array = state["roster"]
	if relic_count(state, &"holiday_sale") <= 0 or roster.is_empty():
		return
	state["holiday_sale_tower"] = roster[
		run_rng.randi_range(0, roster.size() - 1)
	]


func can_buy_dual_path(state: Dictionary, current: Dictionary) -> bool:
	var types: Array = current["tower"].get("type_tags", [])
	if types.has(&"technology") and relic_count(state, &"singularity_core") > 0 and not state["dual_path_used"][&"technology"]:
		return true
	if types.has(&"biological") and relic_count(state, &"perfect_mutation") > 0 and not state["dual_path_used"][&"biological"]:
		return true
	return false


func apply_purchase_action(state: Dictionary, action: Dictionary) -> void:
	state["money"] = float(state["money"]) - float(action["cost"])
	state["total_spent"] = float(state.get("total_spent", 0.0)) + float(action["cost"])
	var target: Dictionary = candidates[action["target_key"]]
	if action["kind"] == &"build":
		if StringName(state.get("first_tower_built", &"")).is_empty():
			state["first_tower_built"] = target["tower_id"]
		var placement_index := int(action.get("placement_index", -1))
		state["build"].append({
			"tower_id": target["tower_id"], "level": target["level"], "path": target["path"], "candidate_key": target["key"],
			"placement_index": placement_index,
			"covered_segments": get_covered_combat_segments(target, placement_index),
		})
		if placement_index >= 0:
			for cell in map_placements[placement_index]["cells"]:
				state["occupied_cells"][cell] = true
		if bool(action.get("contraband", false)):
			state["contraband_tower"] = &""
	else:
		state["upgrade_purchases"] = int(state.get("upgrade_purchases", 0)) + 1
		var instance: Dictionary = state["build"][int(action["instance"])]
		instance["level"] = target["level"]
		instance["path"] = target["path"]
		instance["candidate_key"] = target["key"]
		instance["covered_segments"] = get_covered_combat_segments(
			target,
			int(instance.get("placement_index", -1))
		)
		state["build"][int(action["instance"])] = instance
		if action["kind"] == &"dual_path":
			var types: Array = target["tower"].get("type_tags", [])
			var category: StringName = &"technology" if types.has(&"technology") else &"biological"
			state["dual_path_used"][category] = true


func get_candidate_mix_power(
	candidate: Dictionary,
	state: Dictionary,
	mix: Array[Dictionary],
	placement_index: int = -1
) -> float:
	var total_health := 0.0
	var weighted_power := 0.0
	for entry in mix:
		var demand := float(entry["count"]) * float(entry["health"])
		total_health += demand
		weighted_power += demand * get_candidate_enemy_power(
			candidate,
			state,
			entry,
			-1.0,
			placement_index
		)
	return weighted_power / maxf(total_health, 1.0)


func get_candidate_enemy_power(
	candidate: Dictionary,
	state: Dictionary,
	entry: Dictionary,
	engagement_count: float = -1.0,
	placement_index: int = -1
) -> float:
	var enemy_id: StringName = entry["enemy_id"]
	var base_scenario: Dictionary = enemy_scenarios[enemy_id]
	var stats: Dictionary = candidate["stats"]
	var traits: Dictionary = candidate["traits"]
	var primary_type: StringName = traits["primary_type"]
	var can_attack_hidden: bool = (
		traits["bonus_tags"].has(&"reveal")
		or (
			build_has_reveal(state["build"])
			and (
				relic_count(state, &"spotter") > 0
				or relic_count(state, &"perfect_intelligence") > 0
			)
		)
	)
	var curve_map: Dictionary = (
		candidate["revealed_dps_health_curves"]
		if can_attack_hidden
		else candidate["dps_health_curves"]
	)
	var curve: PackedFloat32Array = curve_map.get(
		enemy_id,
		PackedFloat32Array()
	)
	var base_health := maxf(float(base_scenario.get("health", 1.0)), 1.0)
	var health_multiplier := float(entry.get("unit_health", entry["health"])) / base_health
	var power := interpolate_health_curve(curve, health_multiplier)
	var target_count := (
		engagement_count
		if engagement_count >= 0.0
		else minf(
			float(entry.get("count", 1.0)),
			float(base_scenario.get("enemies", 1))
		)
	)
	target_count = maxf(target_count, 1.0)
	if candidate["tower_id"] == &"saucer":
		var abduction_curves: Dictionary = candidate[
			"saucer_abduction_health_curves"
		]
		power -= interpolate_health_curve(
			abduction_curves.get(enemy_id, PackedFloat32Array()),
			health_multiplier
		)
		power += get_saucer_abduction_power(candidate, entry)
	if not use_map_geometry:
		var range_units := float(stats.get("range", stats.get("deployment_radius", 8.0)))
		power *= clampf(range_units / 10.0, 0.55, 1.30)
	var ignores_armor: bool = (
		primary_type == &"beam"
		or int(stats.get("pierce_count", 0)) > 0
		or bool(traits["flags"].get("infinite_pierce", false))
	)
	if relic_count(state, &"armor_piercing") > 0 and traits["damage_tags"].has(&"ballistic"):
		ignores_armor = true
	if not ignores_armor:
		var raw_hit := maxf(float(stats.get("damage", 1.0)), 1.0)
		var base_armor := float(base_scenario.get("armor", 0.0))
		var new_armor := float(entry["armor"])
		var base_after := raw_hit * GameStats.get_armor_damage_multiplier(
			base_armor, primary_type
		)
		var new_after := raw_hit * GameStats.get_armor_damage_multiplier(
			new_armor, primary_type
		)
		power *= clampf(new_after / base_after, 0.10, 2.5)
	if traits["delivery"] == GameStats.DELIVERY_PROJECTILE:
		var speed_ratio := float(entry["speed"]) / maxf(float(base_scenario.get("speed", entry["speed"])), 1.0)
		power *= clampf(pow(speed_ratio, -0.35), 0.65, 1.35)
	power *= get_relic_combat_multiplier(
		candidate,
		state,
		entry,
		target_count,
		placement_index
	)
	if not use_map_geometry:
		var control := float(candidate["control"].get(enemy_id, 0.0))
		power += control * float(entry["health"]) * 0.04
	return maxf(power, 0.0)


func get_saucer_abduction_power(
	candidate: Dictionary,
	entry: Dictionary
) -> float:
	var stats: Dictionary = candidate["stats"]
	var threshold := float(stats.get("abduction_health_threshold", 0.0))
	var enemy: Dictionary = entry["enemy"]
	if threshold <= 0.0 or bool(enemy.get("boss", false)):
		return 0.0
	var duration := maxf(float(entry.get("duration", 1.0)), 1.0)
	var cooldown := maxf(float(stats.get("abduction_cooldown", 16.0)), 0.1)
	var possible_uses := floori(duration / cooldown)
	var eligible_targets := maxi(floori(float(entry.get("count", 0.0))), 0)
	var pursuit_uptime := clampf(
		0.55
		+ float(stats.get("flyer_attack_radius", 5.0)) * 0.04
		+ float(stats.get("flyer_move_speed", 165.0)) / 1000.0
		- float(entry.get("speed", 75.0)) / 1000.0,
		0.55,
		0.96
	)
	var expected_uses: float = (
		float(mini(possible_uses, eligible_targets))
		* pursuit_uptime
		* 0.80
	)
	var removed_health: float = (
		float(entry.get("unit_health", 1.0)) * threshold
		+ float(entry.get("spawned_health", 0.0))
	)
	return expected_uses * removed_health / duration


func get_relic_combat_multiplier(
	candidate: Dictionary,
	state: Dictionary,
	entry: Dictionary,
	engagement_count: float,
	placement_index: int = -1
) -> float:
	var relics: Dictionary = state["relics"]
	var traits: Dictionary = candidate["traits"]
	var tower: Dictionary = candidate["tower"]
	var stats: Dictionary = candidate["stats"]
	var primary_type: StringName = traits["primary_type"]
	var damage_tags: Array = traits["damage_tags"]
	var bonus_tags: Array = traits["bonus_tags"]
	var types: Array = tower.get("type_tags", [])
	var enemy: Dictionary = entry["enemy"]
	var multiplier := 1.0
	if types.has(&"technology"):
		var adjacent_technology := count_towers_within_footprint_gap(
			state,
			placement_index,
			&"technology"
		)
		multiplier *= (
			1.0
			+ GameStats.NETWORK_UPGRADE_SPEED_PER_NEIGHBOR_PER_STACK
				* float(adjacent_technology)
				* float(relics.get(&"network_upgrade", 0))
		)
	if types.has(&"biological") and count_built_type(state["build"], &"biological") >= 2:
		multiplier *= 1.0 + GameStats.PACK_HUNTER_DAMAGE_PER_STACK * float(relics.get(&"pack_hunter", 0))
	if types.has(&"biological"):
		multiplier *= 1.0 + 0.25 * GameStats.PREDATORY_INSTINCT_DAMAGE_PER_STACK * float(relics.get(&"predatory_instinct", 0))
	if damage_tags.has(&"beam"):
		multiplier *= pow(1.0 + GameStats.FOCUSED_LENS_DAMAGE_PER_STACK, float(relics.get(&"focused_lens", 0)))
		multiplier *= pow(GameStats.WIDE_LENS_DAMAGE_MULTIPLIER * 1.08, float(relics.get(&"wide_lens", 0)))
		if int(relics.get(&"interference_beam", 0)) > 0 and build_has_control(state["build"]):
			multiplier *= GameStats.INTERFERENCE_BEAM_DAMAGE_MULTIPLIER
		if int(relics.get(&"microwave", 0)) > 0 and engagement_count >= 3.0:
			# Explosion value is tempered by the post-explosion attack pause.
			multiplier *= 1.10
		if int(relics.get(&"death_ray", 0)) > 0:
			var death_ray_uptime := (
				GameStats.DEATH_RAY_OVERCHARGE_DURATION
				/ GameStats.DEATH_RAY_CYCLE_DURATION
			)
			multiplier *= (
				1.0
				+ death_ray_uptime
					* (GameStats.DEATH_RAY_DAMAGE_MULTIPLIER - 1.0)
			)
			multiplier *= (
				1.0
				+ minf(engagement_count - 1.0, 4.0)
					* 0.16
					* death_ray_uptime
			)
	if damage_tags.has(&"ballistic"):
		multiplier *= pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER / GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER, float(relics.get(&"heavy_rounds", 0)))
		multiplier *= pow(GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER / GameStats.LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER, float(relics.get(&"lightweight_ammo", 0)))
		multiplier *= 1.0 + 0.25 * GameStats.HOLLOW_POINT_DAMAGE_PER_STACK * float(relics.get(&"hollow_point", 0))
		multiplier *= 1.0 + 0.5 * GameStats.LONG_BARREL_MAX_DAMAGE_PER_STACK * float(relics.get(&"long_barrel", 0))
		multiplier *= 1.0 + 0.5 * GameStats.POINT_BLANK_MAX_DAMAGE_PER_STACK * float(relics.get(&"point_blank", 0))
		if int(relics.get(&"armor_piercing", 0)) > 0:
			multiplier *= 1.0 + minf(engagement_count - 1.0, 2.0) * 0.20
		if int(relics.get(&"rubber_bullets", 0)) > 0 and engagement_count > 1.0:
			multiplier *= 1.65
	if damage_tags.has(&"melee"):
		multiplier *= (
			1.0
			+ GameStats.FRENZY_SPEED_PER_ENEMY_PER_STACK
				* minf(engagement_count, float(GameStats.FRENZY_MAXIMUM_ENEMY_COUNT))
				* float(relics.get(&"frenzy", 0))
		)
		var duelist_stacks := float(relics.get(&"duelist", 0))
		if engagement_count <= 1.5:
			multiplier *= 1.0 + GameStats.DUELIST_ONE_ENEMY_DAMAGE_PER_STACK * duelist_stacks
		elif engagement_count <= 2.5:
			multiplier *= 1.0 + GameStats.DUELIST_TWO_ENEMY_DAMAGE_PER_STACK * duelist_stacks
		if int(relics.get(&"relentless", 0)) > 0:
			multiplier *= 1.25
		if int(relics.get(&"giant_killer", 0)) > 0:
			var special_target := (
				bool(enemy.get("boss", false))
				or StringName(entry.get("variant", &"normal")) == &"elite"
			)
			multiplier *= GameStats.GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER if special_target else GameStats.GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER
		if int(relics.get(&"strength_in_numbers", 0)) > 0:
			multiplier *= (
				1.0
				+ GameStats.STRENGTH_IN_NUMBERS_DAMAGE_PER_NEIGHBOR
					* float(mini(
						count_nearby_towers(
							state,
							placement_index,
							1.5 * GameStats.BUILD_CELL_SIZE,
							&"melee"
						),
						GameStats.STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS
					))
			)
		if (
			int(relics.get(&"lone_wolf", 0)) > 0
			and count_built_tower(
				state["build"], candidate["tower_id"]
			) <= 1
		):
			multiplier *= GameStats.LONE_WOLF_DAMAGE_MULTIPLIER * GameStats.LONE_WOLF_ATTACK_SPEED_MULTIPLIER
	if damage_tags.has(&"explosive"):
		multiplier *= pow(GameStats.HIGH_YIELD_DAMAGE_MULTIPLIER * 1.12, float(relics.get(&"high_yield", 0)))
		multiplier *= pow(GameStats.CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER * 0.92, float(relics.get(&"concentrated_charge", 0)))
		if int(relics.get(&"crowd_pleaser", 0)) > 0:
			multiplier *= 1.0 + minf(GameStats.CROWD_PLEASER_DAMAGE_PER_ENEMY * engagement_count, GameStats.CROWD_PLEASER_MAXIMUM_DAMAGE_BONUS)
		if int(relics.get(&"direct_hit", 0)) > 0:
			multiplier *= 1.60 if engagement_count <= 1.5 else (1.30 if engagement_count <= 2.5 else (1.15 if engagement_count <= 3.5 else 1.0))
		if (
			int(relics.get(&"thermite_bombs", 0)) > 0
			and float(entry["armor"]) > 0.0
		):
			# Approximate reduced damage while Thermite strips Armor.
			multiplier *= 0.75
	if damage_tags.has(&"electric") and int(relics.get(&"conductive", 0)) > 0:
		if float(entry["armor"]) > 0.0:
			var armor_reduction := GameStats.get_armor_damage_reduction(
				float(entry["armor"]),
				&"electric"
			)
			var conductive_bonus := minf(
				float(entry["armor"]) * GameStats.CONDUCTIVE_DAMAGE_PER_ARMOR,
				GameStats.CONDUCTIVE_MAXIMUM_DAMAGE_BONUS
			)
			multiplier *= (1.0 + conductive_bonus) / (1.0 - armor_reduction)
		else:
			multiplier *= GameStats.CONDUCTIVE_UNARMORED_DAMAGE_MULTIPLIER
	if (
		damage_tags.has(&"electric")
		and int(relics.get(&"static_discharge", 0)) > 0
	):
		var nearby_static_targets := clampf(engagement_count - 1.0, 0.0, 4.0)
		multiplier *= maxf(
			1.0
			- (1.0 - GameStats.STATIC_DISCHARGE_PRIMARY_DAMAGE_RATIO)
				* GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION
			+ nearby_static_targets
				* GameStats.STATIC_DISCHARGE_DAMAGE_RATIO
				* GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION,
			0.1
		)
	var base_critical_chance := float(stats.get(
		"critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE
	))
	var base_critical_multiplier := float(stats.get(
		"critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER
	))
	var has_critical_items := (
		int(relics.get(&"lucky_shot", 0)) > 0
		or int(relics.get(&"glass_cannon", 0)) > 0
		or int(relics.get(&"deadeye", 0)) > 0
		or int(relics.get(&"pressure_point", 0)) > 0
	)
	if base_critical_chance > 0.0 or has_critical_items:
		var chance := clampf(base_critical_chance + GameStats.LUCKY_SHOT_CHANCE_PER_STACK * float(relics.get(&"lucky_shot", 0)), 0.0, 1.0)
		var crit_multiplier := base_critical_multiplier
		crit_multiplier += GameStats.GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS * float(relics.get(&"glass_cannon", 0)) + GameStats.DEADEYE_CRITICAL_MULTIPLIER_BONUS * float(relics.get(&"deadeye", 0))
		var noncrit := pow(
			GameStats.GLASS_CANNON_NONCRITICAL_MULTIPLIER,
			float(relics.get(&"glass_cannon", 0))
		)
		var modified_critical_average := chance * crit_multiplier + (1.0 - chance) * noncrit
		var baseline_critical_average := (
			base_critical_chance * base_critical_multiplier
			+ (1.0 - base_critical_chance)
		)
		multiplier *= modified_critical_average / baseline_critical_average
		if int(relics.get(&"deadeye", 0)) > 0:
			multiplier *= 1.0 - GameStats.DEADEYE_MISS_CHANCE
		if int(relics.get(&"pressure_point", 0)) > 0 and float(entry["armor"]) > 0.0:
			var raw_damage := maxf(float(stats.get("damage", 1.0)), 1.0)
			var armored_damage := raw_damage * GameStats.get_armor_damage_multiplier(
				float(entry["armor"]),
				primary_type
			)
			var without_pressure := modified_critical_average * armored_damage
			var with_pressure := (
				chance * crit_multiplier * raw_damage
				+ (1.0 - chance) * noncrit * armored_damage
			)
			multiplier *= with_pressure / maxf(without_pressure, 1.0)
	if bonus_tags.has(&"pierce"):
		multiplier *= 1.0 + 0.12 * float(relics.get(&"deep_penetration", 0))
		if int(relics.get(&"follow_through", 0)) > 0:
			multiplier *= 1.12
	if (
		TRADE_TOWERS.has(candidate["tower_id"])
		and int(relics.get(&"trade_agreement", 0)) > 0
	):
		multiplier *= (
			float(GameStats.TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER)
			* GameStats.TRADE_AGREEMENT_UNIT_DAMAGE_MULTIPLIER
			* GameStats.TRADE_AGREEMENT_UNIT_BUDGET_MULTIPLIER
		)
	return maxf(multiplier, 0.0)


func resolve_round(
	state: Dictionary,
	mix: Array[Dictionary],
	profile_data: Dictionary,
	_mode: Dictionary,
	round_number: int,
	policy: Dictionary
) -> Dictionary:
	if use_map_geometry:
		return resolve_segmented_round(
			state, mix, profile_data, round_number, policy
		)
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
		mixed_dps += get_positioned_candidate_power(
			candidates[instance["candidate_key"]],
			state,
			mix,
			int(instance.get("placement_index", -1))
		)
	if not use_map_geometry:
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


func resolve_segmented_round(
	state: Dictionary,
	mix: Array[Dictionary],
	profile_data: Dictionary,
	round_number: int,
	policy: Dictionary
) -> Dictionary:
	if mix.is_empty() or map_combat_samples.size() < 2:
		return {
			"leak_damage": 0.0,
			"kill_income": 0.0,
			"kill_income_credited": true,
			"power_ratio": 0.0,
		}
	var segment_count := map_combat_samples.size()
	var counts_by_enemy: Array[PackedFloat32Array] = []
	var health_by_enemy: Array[PackedFloat32Array] = []
	var total_spawn_health := 0.0
	var slowest_speed := INF
	var spawn_duration := 1.0
	for entry in mix:
		var counts := PackedFloat32Array()
		var health := PackedFloat32Array()
		counts.resize(segment_count)
		health.resize(segment_count)
		counts_by_enemy.append(counts)
		health_by_enemy.append(health)
		total_spawn_health += float(entry["count"]) * float(entry["health"])
		slowest_speed = minf(slowest_speed, maxf(float(entry["speed"]), 1.0))
		spawn_duration = maxf(spawn_duration, float(entry["duration"]))
	var maximum_time := (
		spawn_duration
		+ map_path_length / maxf(slowest_speed, 1.0)
		+ MAP_COMBAT_MAX_EXTRA_TIME
	)
	var elapsed := 0.0
	var leak_damage := 0.0
	var earned_reward := 0.0
	var credited_kill_income := 0.0
	var next_purchase_time := MIDWAVE_PURCHASE_INTERVAL
	var damage_dealt := 0.0
	while elapsed < maximum_time:
		var step := minf(MAP_COMBAT_TIME_STEP, maximum_time - elapsed)
		var control_by_enemy: Array[PackedFloat32Array] = []
		for _enemy_index in mix.size():
			var control_segments := PackedFloat32Array()
			control_segments.resize(segment_count)
			control_by_enemy.append(control_segments)
		if elapsed < spawn_duration:
			var spawning_time := minf(step, spawn_duration - elapsed)
			for enemy_index in mix.size():
				var entry: Dictionary = mix[enemy_index]
				var spawned_count := (
					float(entry["count"])
					/ maxf(float(entry["duration"]), MAP_COMBAT_TIME_STEP)
					* minf(spawning_time, maxf(float(entry["duration"]) - elapsed, 0.0))
				)
				if spawned_count > 0.0:
					counts_by_enemy[enemy_index][0] += spawned_count
					health_by_enemy[enemy_index][0] += spawned_count * float(entry["health"])
		for tower_index in state["build"].size():
			var instance: Dictionary = state["build"][tower_index]
			var placement_index := int(instance.get("placement_index", -1))
			var candidate: Dictionary = candidates[instance["candidate_key"]]
			var target_powers := PackedFloat32Array()
			target_powers.resize(mix.size())
			for enemy_index in mix.size():
				target_powers[enemy_index] = get_candidate_enemy_power(
					candidate,
					state,
					mix[enemy_index],
					-1.0,
					placement_index
				)
			# Relics can change range or depend on neighboring towers, so coverage
			# must be refreshed for the current build instead of cached forever.
			var covered_segments := get_covered_combat_segments(
				candidate,
				placement_index,
				state
			)
			var target := find_segment_target(
				covered_segments,
				counts_by_enemy,
				health_by_enemy,
				target_powers
			)
			if target.x >= 0:
				var target_segment := target.x
				var enemy_index := target.y
				var local_count := maxf(
					float(counts_by_enemy[enemy_index][target_segment]),
					1.0
				)
				var dps := get_candidate_enemy_power(
					candidate,
					state,
					mix[enemy_index],
					local_count,
					placement_index
				)
				var available_health := float(health_by_enemy[enemy_index][target_segment])
				var applied_damage := minf(dps * step, available_health)
				var health_per_count := available_health / maxf(
					float(counts_by_enemy[enemy_index][target_segment]),
					MAP_COMBAT_EPSILON
				)
				var killed_count := minf(
					float(counts_by_enemy[enemy_index][target_segment]),
					applied_damage / maxf(health_per_count, 1.0)
				)
				health_by_enemy[enemy_index][target_segment] -= applied_damage
				counts_by_enemy[enemy_index][target_segment] -= killed_count
				earned_reward += killed_count * float(mix[enemy_index]["reward"])
				damage_dealt += applied_damage
				control_by_enemy[enemy_index][target_segment] += (
					get_candidate_control_power(
						candidate,
						state,
						mix[enemy_index],
						local_count
					)
				)
				if health_by_enemy[enemy_index][target_segment] <= MAP_COMBAT_EPSILON:
					health_by_enemy[enemy_index][target_segment] = 0.0
					counts_by_enemy[enemy_index][target_segment] = 0.0
		for enemy_index in mix.size():
			var moved_counts := PackedFloat32Array()
			var moved_health := PackedFloat32Array()
			moved_counts.resize(segment_count)
			moved_health.resize(segment_count)
			for source_segment in segment_count:
				var source_count := float(counts_by_enemy[enemy_index][source_segment])
				if source_count <= MAP_COMBAT_EPSILON:
					continue
				var source_health := float(health_by_enemy[enemy_index][source_segment])
				var controlled_fraction := clampf(
					float(control_by_enemy[enemy_index][source_segment])
						/ maxf(source_count, MAP_COMBAT_EPSILON),
					0.0,
					0.85
				)
				var aura_multiplier := get_segment_speed_aura_multiplier(
					enemy_index,
					source_segment,
					mix,
					counts_by_enemy
				)
				var movement := (
					float(mix[enemy_index]["speed"])
					* aura_multiplier
					* step
					/ maxf(map_combat_segment_length, 1.0)
					* (1.0 - controlled_fraction)
				)
				var destination := float(source_segment) + movement
				var lower_segment := floori(destination)
				var upper_fraction := destination - float(lower_segment)
				var lower_fraction := 1.0 - upper_fraction
				if lower_segment < segment_count:
					moved_counts[lower_segment] += source_count * lower_fraction
					moved_health[lower_segment] += source_health * lower_fraction
				else:
					leak_damage += source_count * lower_fraction * float(mix[enemy_index]["leak"])
				if upper_fraction > MAP_COMBAT_EPSILON:
					if lower_segment + 1 < segment_count:
						moved_counts[lower_segment + 1] += source_count * upper_fraction
						moved_health[lower_segment + 1] += source_health * upper_fraction
					else:
						leak_damage += source_count * upper_fraction * float(mix[enemy_index]["leak"])
			counts_by_enemy[enemy_index] = moved_counts
			health_by_enemy[enemy_index] = moved_health
		elapsed += step
		if elapsed + MAP_COMBAT_EPSILON >= next_purchase_time:
			var available_kill_income := floorf(
				earned_reward * float(profile_data["kill_income"])
			)
			var newly_credited := maxf(
				available_kill_income - credited_kill_income,
				0.0
			)
			if newly_credited > 0.0:
				state["money"] = float(state["money"]) + newly_credited
				credited_kill_income += newly_credited
				if live_build_benchmark:
					purchase_live_build_for_round(
						state, policy, profile_data, round_number
					)
				else:
					purchase_for_round(
						state, policy, mix, profile_data, round_number
					)
			next_purchase_time += MIDWAVE_PURCHASE_INTERVAL
		if elapsed >= spawn_duration and not has_segment_enemies(counts_by_enemy):
			break
	var total_kill_income := earned_reward * float(profile_data["kill_income"])
	# Preserve fractional expected income in aggregate reports and future rounds,
	# while only allowing whole earned dollars to fund mid-wave purchases.
	state["money"] = (
		float(state["money"])
		+ maxf(total_kill_income - credited_kill_income, 0.0)
	)
	return {
		"leak_damage": leak_damage,
		"kill_income": total_kill_income,
		"kill_income_credited": true,
		"power_ratio": damage_dealt / maxf(total_spawn_health, 1.0),
	}


func get_segment_speed_aura_multiplier(
	enemy_index: int,
	segment_index: int,
	mix: Array[Dictionary],
	counts_by_enemy: Array[PackedFloat32Array]
) -> float:
	var result := 1.0
	for aura_index in mix.size():
		var aura_enemy: Dictionary = mix[aura_index]["enemy"]
		if not aura_enemy.get("traits", []).has(&"speed_aura"):
			continue
		var aura_count := 0.0
		var aura_radius := float(aura_enemy.get("speed_aura_radius", 0.0))
		for aura_segment in map_combat_samples.size():
			if (
				map_combat_samples[segment_index].distance_to(
					map_combat_samples[aura_segment]
				) <= aura_radius
			):
				aura_count += float(
					counts_by_enemy[aura_index][aura_segment]
				)
		if aura_count <= MAP_COMBAT_EPSILON:
			continue
		# A buffer does not buff itself, but two or more buffers can buff one
		# another just as separate Mob instances do in gameplay.
		if aura_index == enemy_index and aura_count <= 1.0:
			continue
		result = maxf(
			result,
			float(aura_enemy.get("speed_aura_multiplier", 1.0))
		)
	return result


func get_candidate_control_power(
	candidate: Dictionary,
	state: Dictionary,
	entry: Dictionary,
	engagement_count: float
) -> float:
	var enemy_id: StringName = entry["enemy_id"]
	var base_scenario: Dictionary = enemy_scenarios[enemy_id]
	var base_count := maxf(float(base_scenario.get("enemies", 1)), 1.0)
	var control := float(candidate["control"].get(enemy_id, 0.0))
	control *= clampf(engagement_count / base_count, 0.0, 1.0)
	var traits: Dictionary = candidate["traits"]
	var stats: Dictionary = candidate["stats"]
	if (
		traits["damage_tags"].has(&"ballistic")
		and relic_count(state, &"suppressive_fire") > 0
	):
		var interval := maxf(float(stats.get("firerate", 1.0)), 0.01)
		var targets := minf(
			float(combat.get_expected_targets_per_attack(
				stats,
				traits,
				base_scenario
			)),
			engagement_count
		)
		control += (
			minf(GameStats.SUPPRESSIVE_FIRE_DURATION / interval, 1.0)
			* targets
			* (1.0 - GameStats.SLOW_SPEED_MULTIPLIER)
		)
	var psionic_stacks := int(state["relics"].get(&"lingering_thoughts", 0))
	if psionic_stacks > 0 and candidate_has_category(candidate, &"psionic"):
		control *= pow(1.0 + 0.25, float(psionic_stacks))
	var enemy: Dictionary = entry["enemy"]
	var stun_stacks := int(state["relics"].get(&"big_game_control", 0))
	if stun_stacks > 0 and candidate_has_category(candidate, &"stun"):
		var special_enemy := (
			bool(enemy.get("boss", false))
			or StringName(entry.get("variant", &"normal")) == &"elite"
		)
		control *= pow(
			1.25 if special_enemy else 0.75,
			float(stun_stacks)
		)
	var brake_stacks := int(state["relics"].get(&"emergency_brake", 0))
	if (
		brake_stacks > 0
		and candidate_has_category(candidate, &"stun")
		and traits.has(&"fast")
	):
		control *= pow(1.35, float(brake_stacks))
	if (
		bool(enemy.get("boss", false))
		and candidate_has_category(candidate, &"stun")
		and relic_count(state, &"youre_not_special") > 0
		and control <= MAP_COMBAT_EPSILON
	):
		var boss_scenario := base_scenario.duplicate(true)
		boss_scenario["boss"] = false
		control = (
			combat.get_control_value(stats, traits, boss_scenario)
			* GameStats.BOSS_STUN_DURATION_MULTIPLIER
			* clampf(engagement_count / base_count, 0.0, 1.0)
		)
	return maxf(control, 0.0)


func find_segment_target(
	covered_segments: PackedInt32Array,
	counts_by_enemy: Array[PackedFloat32Array],
	health_by_enemy: Array[PackedFloat32Array],
	tower_power: PackedFloat32Array
) -> Vector2i:
	for coverage_offset in range(covered_segments.size() - 1, -1, -1):
		var segment_index := int(covered_segments[coverage_offset])
		var best_enemy := -1
		var best_health := 0.0
		for enemy_index in counts_by_enemy.size():
			if float(tower_power[enemy_index]) <= MAP_COMBAT_EPSILON:
				continue
			var count := float(counts_by_enemy[enemy_index][segment_index])
			var health := float(health_by_enemy[enemy_index][segment_index])
			if count > MAP_COMBAT_EPSILON and health > best_health:
				best_enemy = enemy_index
				best_health = health
		if best_enemy >= 0:
			return Vector2i(segment_index, best_enemy)
	return Vector2i(-1, -1)


func has_segment_enemies(counts_by_enemy: Array[PackedFloat32Array]) -> bool:
	for counts in counts_by_enemy:
		for count in counts:
			if count > MAP_COMBAT_EPSILON:
				return true
	return false


func resolve_tower_draft(state: Dictionary, policy: Dictionary, run_rng: RandomNumberGenerator) -> void:
	var available: Array[StringName] = []
	var draft_pool := STARTER_CALIBRATION_TOWERS if starter_calibration else get_test_tower_ids()
	for tower_id in draft_pool:
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
	var offers := roll_relic_offer_set(state, round_number, run_rng)
	if offers.is_empty():
		return
	var choice_quantities: Dictionary = DraftManagerScript.new(run_rng).get_relic_choice_quantities(
		round_number,
		offers
	)
	var best := offers[0]
	var best_quantity := int(choice_quantities.get(best, 1))
	var best_score := -INF
	for relic_id in offers:
		var quantity := int(choice_quantities.get(relic_id, 1))
		var score := get_relic_choice_score(state, policy, relic_id, quantity, round_number)
		if score > best_score:
			best_score = score
			best = relic_id
			best_quantity = quantity
	state["relics"][best] = int(state["relics"].get(best, 0)) + best_quantity
	if best == &"contraband_blueprint":
		var outside: Array[StringName] = []
		for tower_id in get_test_tower_ids():
			if not state["roster"].has(tower_id):
				outside.append(tower_id)
		if not outside.is_empty():
			state["contraband_tower"] = outside[run_rng.randi_range(0, outside.size() - 1)]


func roll_relic_offer_set(
	state: Dictionary,
	round_number: int,
	run_rng: RandomNumberGenerator
) -> Array[StringName]:
	var manager = DraftManagerScript.new(run_rng)
	var recent_offers: Array[StringName] = []
	recent_offers.assign(state.get("recent_relic_offers", []))
	manager.recent_relic_offers = recent_offers
	var path_relic_eligibility := {
		&"singularity_core": has_eligible_dual_path_tower(
			state,
			&"singularity_core"
		),
		&"perfect_mutation": has_eligible_dual_path_tower(
			state,
			&"perfect_mutation"
		),
	}
	var contraband_tower := StringName(state.get("contraband_tower", &""))
	var has_dedicated_spawner := (
		roster_has_any(state["roster"], TRADE_TOWERS)
		or contraband_tower in TRADE_TOWERS
	)
	var offers: Array[StringName] = manager.roll_relic_offers(
		round_number,
		state["relics"],
		get_state_draft_tags(state),
		path_relic_eligibility,
		has_dedicated_spawner,
		EXCLUDED_RELICS
	)
	state["recent_relic_offers"] = manager.recent_relic_offers.duplicate()
	return offers


func get_state_draft_tags(state: Dictionary) -> Array[StringName]:
	var tags: Array[StringName] = []
	for tower_id in state["roster"]:
		append_tower_base_tags(tags, StringName(tower_id))
	var contraband_tower := StringName(state.get("contraband_tower", &""))
	if not contraband_tower.is_empty():
		append_tower_base_tags(tags, contraband_tower)
	for instance in state["build"]:
		var candidate: Dictionary = candidates[instance["candidate_key"]]
		for tag in candidate["tower"].get("type_tags", []):
			append_unique_draft_tag(tags, StringName(tag))
		for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
			for tag in candidate["traits"].get(tag_group, []):
				append_unique_draft_tag(tags, StringName(tag))
	return tags


func append_tower_base_tags(
	tags: Array[StringName],
	tower_id: StringName
) -> void:
	var tower := GameStats.get_tower(tower_id)
	for tag_group in ["type_tags", "damage_tags", "bonus_tags"]:
		for tag in tower.get(tag_group, []):
			append_unique_draft_tag(tags, StringName(tag))


func append_unique_draft_tag(
	tags: Array[StringName],
	tag: StringName
) -> void:
	if not tags.has(tag):
		tags.append(tag)


func get_relic_choice_score(
	state: Dictionary,
	policy: Dictionary,
	relic_id: StringName,
	quantity: int,
	round_number: int
) -> float:
	var relic := GameStats.get_legacy_item_template(relic_id)
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
		score *= float(policy["economy_weight"]) if relic_id in [&"dividends", &"holiday_sale", &"contraband_blueprint"] else 1.0
	if relic_id == &"dividends":
		score *= 1.0 + float(20 - round_number) * 0.08
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
	if bool(state["dual_path_used"].get(category, false)):
		return false
	for instance in state["build"]:
		var candidate: Dictionary = candidates[instance["candidate_key"]]
		var paths: Dictionary = candidate["tower"].get("paths", {})
		if (
			candidate["tower"].get("type_tags", []).has(category)
			and paths.has("a")
			and paths.has("b")
		):
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


func placement_has_nearby_other_tower(
	state: Dictionary,
	placement_index: int,
	radius: float
) -> bool:
	if placement_index < 0 or placement_index >= map_placements.size():
		return state["build"].size() > 1
	var origin: Vector2 = map_placements[placement_index]["position"]
	for instance in state["build"]:
		var other_index := int(instance.get("placement_index", -1))
		if (
			other_index < 0
			or other_index >= map_placements.size()
			or other_index == placement_index
		):
			continue
		if origin.distance_to(map_placements[other_index]["position"]) <= radius:
			return true
	return false


func count_nearby_towers(
	state: Dictionary,
	placement_index: int,
	radius: float,
	required_category: StringName
) -> int:
	if placement_index < 0 or placement_index >= map_placements.size():
		var fallback := 0
		for instance in state["build"]:
			if candidate_has_category(
				candidates[instance["candidate_key"]],
				required_category
			):
				fallback += 1
		return maxi(fallback - 1, 0)
	var origin: Vector2 = map_placements[placement_index]["position"]
	var count := 0
	for instance in state["build"]:
		var other_index := int(instance.get("placement_index", -1))
		if (
			other_index < 0
			or other_index >= map_placements.size()
			or other_index == placement_index
		):
			continue
		if not candidate_has_category(
			candidates[instance["candidate_key"]],
			required_category
		):
			continue
		if origin.distance_to(map_placements[other_index]["position"]) <= radius:
			count += 1
	return count


func count_towers_within_footprint_gap(
	state: Dictionary,
	placement_index: int,
	required_category: StringName
) -> int:
	if placement_index < 0 or placement_index >= map_placements.size():
		return 0
	var origin: Vector2 = map_placements[placement_index]["position"]
	var footprint_cells: Vector2i = GameStats.get_tower(
		get_test_tower_ids()[0]
	).get("footprint_cells", Vector2i.ONE)
	var combined_half_extents := (
		Vector2(footprint_cells) * GameStats.BUILD_CELL_SIZE
	)
	var count := 0
	for instance in state["build"]:
		var other_index := int(instance.get("placement_index", -1))
		if (
			other_index < 0
			or other_index >= map_placements.size()
			or other_index == placement_index
		):
			continue
		if not candidate_has_category(
			candidates[instance["candidate_key"]],
			required_category
		):
			continue
		var center_offset: Vector2 = (
			map_placements[other_index]["position"] - origin
		).abs()
		var footprint_gap := Vector2(
			maxf(center_offset.x - combined_half_extents.x, 0.0),
			maxf(center_offset.y - combined_half_extents.y, 0.0)
		)
		if footprint_gap.length() <= GameStats.BUILD_CELL_SIZE + 1.0:
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


func build_has_reveal(build: Array) -> bool:
	for instance in build:
		var traits: Dictionary = candidates[instance["candidate_key"]]["traits"]
		if traits["bonus_tags"].has(&"reveal"):
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
		var label := String(instance["tower_id"])
		counts[label] = int(counts.get(label, 0)) + 1
	var labels: Array[String] = []
	for label in counts:
		labels.append(String(label))
	labels.sort()
	var parts: Array[String] = []
	for label in labels:
		parts.append("%sx%s" % [label, counts[label]])
	return "+".join(parts)


func get_build_path_coverage(build: Array) -> float:
	if build.is_empty():
		return 0.0
	if not use_map_geometry or map_combat_samples.is_empty():
		return TOWER_ENGAGEMENT_COVERAGE
	var covered := {}
	for instance in build:
		for segment_index in instance.get("covered_segments", []):
			covered[int(segment_index)] = true
	return float(covered.size()) / maxf(float(map_combat_samples.size()), 1.0)


func get_relic_signature(relics: Dictionary) -> String:
	var labels: Array[String] = []
	for relic_id in relics:
		labels.append(String(relic_id))
	labels.sort()
	var parts: Array[String] = []
	for label in labels:
		parts.append("%sx%s" % [label, relics[StringName(label)]])
	return "+".join(parts)


func evaluate_finalists(
	finalists: Array[Dictionary],
	start_index: int,
	ranked: Array[Dictionary]
) -> void:
	var effective_runs_per_profile := maxi(
		final_runs_per_profile,
		starting_rosters.size()
	)
	var total := (
		finalists.size()
		* sensitivity_profiles.size()
		* effective_runs_per_profile
	)
	if start_index <= 0:
		final_results.clear()
	else:
		start_index = mini(start_index, final_results.size())
		if final_results.size() > start_index:
			final_results.resize(start_index)
	var checkpoint_interval := maxi(floori(float(total) / 20.0), 25)
	var progress_interval := maxi(floori(float(total) / 10.0), 1)
	var batch_size := maxi(worker_count * 32, 32)
	var next_progress := (
		(floori(float(start_index) / float(progress_interval)) + 1)
		* progress_interval
	)
	var next_checkpoint := (
		(floori(float(start_index) / float(checkpoint_interval)) + 1)
		* checkpoint_interval
	)
	print("Final evaluation: %d runs (%d per profile, %d starter pairs)" % [
		total, effective_runs_per_profile, starting_rosters.size(),
	])
	var batch_start := start_index
	while batch_start < total:
		var batch_count := mini(batch_size, total - batch_start)
		var batch_results: Array = []
		batch_results.resize(batch_count)
		var task_id := WorkerThreadPool.add_group_task(
			_evaluate_finalist_task.bind(
				batch_start,
				finalists,
				effective_runs_per_profile,
				batch_results
			),
			batch_count,
			mini(worker_count, batch_count)
		)
		WorkerThreadPool.wait_for_group_task_completion(task_id)
		for result in batch_results:
			final_results.append(result)
		var completed := batch_start + batch_count
		if completed >= next_progress or completed == total:
			print("Final evaluation: %d/%d" % [completed, total])
			while next_progress <= completed:
				next_progress += progress_interval
		if completed >= next_checkpoint or completed == total:
			save_checkpoint(
				"finalists",
				[],
				ranked,
				finalists,
				generations,
				completed
			)
			while next_checkpoint <= completed:
				next_checkpoint += checkpoint_interval
		batch_start = completed


func _evaluate_finalist_task(
	job_index: int,
	batch_start: int,
	finalists: Array[Dictionary],
	effective_runs_per_profile: int,
	batch_results: Array
) -> void:
	var flat_index := batch_start + job_index
	var runs_per_policy := (
		sensitivity_profiles.size() * effective_runs_per_profile
	)
	var policy_index := floori(float(flat_index) / float(runs_per_policy))
	var within_policy := flat_index % runs_per_policy
	var profile_index := floori(
		float(within_policy) / float(effective_runs_per_profile)
	)
	var run_index := within_policy % effective_runs_per_profile
	var roster_index := run_index % starting_rosters.size()
	var roster_repeat := floori(
		float(run_index) / float(starting_rosters.size())
	)
	var policy: Dictionary = finalists[policy_index]
	var profile_data: Dictionary = sensitivity_profiles[profile_index]
	var run_seed := (
		seed_value
		+ 900000001
		+ int(policy["id"]) * 100003
		+ String(profile_data["id"]).hash()
		+ roster_index * 3571
		+ roster_repeat * 97
	)
	batch_results[job_index] = simulate_run(
		policy,
		profile_data,
		run_seed,
		starting_rosters[roster_index]
	)


func get_checkpoint_configuration() -> Dictionary:
	return {
		"version": CHECKPOINT_VERSION,
		"preset": preset,
		"seed": seed_value,
		"population": population_size,
		"generations": generations,
		"runs_per_policy": runs_per_policy,
		"effective_runs_per_policy": maxi(
			runs_per_policy,
			starting_rosters.size()
		),
		"final_runs_per_profile": final_runs_per_profile,
		"effective_final_runs_per_profile": maxi(
			final_runs_per_profile,
			starting_rosters.size()
		),
		"finalists": finalist_count,
		"combat_samples": combat_samples,
		"simulation_round_limit": simulation_round_limit,
		"use_map_geometry": use_map_geometry,
		"map_id": selected_map_id,
		"focused_early_test": focused_early_test,
		"starter_calibration": starter_calibration,
		"disable_relics": disable_relics,
		"evolve_focused_test": evolve_focused_test,
		"purchase_lookahead_steps": PURCHASE_LOOKAHEAD_STEPS,
		"combat_health_multipliers": COMBAT_HEALTH_MULTIPLIERS,
		"map_combat_segment_stride": MAP_COMBAT_SEGMENT_STRIDE,
		"map_combat_time_step": MAP_COMBAT_TIME_STEP,
		"midwave_purchase_interval": MIDWAVE_PURCHASE_INTERVAL,
		"starting_rosters": get_starting_roster_signatures(),
		"included_towers": get_test_tower_ids(),
		"excluded_towers": EXCLUDED_TOWERS,
		"excluded_relics": EXCLUDED_RELICS,
		"gameplay_data_fingerprint": get_gameplay_data_fingerprint(),
		"balance_values": get_balance_values(),
		"sensitivity_profiles": sensitivity_profiles,
	}


func get_balance_values() -> Dictionary:
	return {
		"kill_reward_multiplier": GameStats.KILL_REWARD_MULTIPLIER,
		"round_cash_rewards": GameStats.ROUND_CASH_REWARDS,
		"round_profiles": GameStats.ROUND_PROFILES,
		"enemy_debut_groups": GameStats.ENEMY_DEBUT_GROUPS,
		"fixed_enemy_debut_rounds": GameStats.FIXED_ENEMY_DEBUT_ROUNDS,
		"wave_style_rules": GameStats.WAVE_STYLE_RULES,
		"tower_draft_rounds": TOWER_DRAFT_ROUNDS,
		"relic_draft_rounds": RELIC_DRAFT_ROUNDS,
		"item_shop_modeled": false,
		"relic_rarity_weights": {},
		"relic_minimum_rare_plus": {},
		"standard_enemy_speed_multiplier": GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER,
		"horde_enemy_health_multiplier": GameStats.HORDE_ENEMY_HEALTH_MULTIPLIER,
		"elite_enemy_health_multiplier": GameStats.ELITE_ENEMY_HEALTH_MULTIPLIER,
		"elite_enemy_speed_multiplier": GameStats.ELITE_ENEMY_SPEED_MULTIPLIER,
		"early_elite_enemy_health_multiplier": GameStats.EARLY_ELITE_ENEMY_HEALTH_MULTIPLIER,
		"early_elite_enemy_speed_multiplier": GameStats.EARLY_ELITE_ENEMY_SPEED_MULTIPLIER,
		"payday_enemy_health_multiplier": GameStats.PAYDAY_ENEMY_HEALTH_MULTIPLIER,
		"explosive_armor_multiplier": GameStats.EXPLOSIVE_ARMOR_MULTIPLIER,
	}


func get_gameplay_data_fingerprint() -> int:
	return hash([
		GameStats.TOWERS,
		GameStats.ENEMIES,
		GameStats.LEGACY_ITEM_TEMPLATES,
		GameStats.MODES,
		GameStats.ROUND_PROFILES,
		GameStats.ENEMY_DEBUT_GROUPS,
		GameStats.FIXED_ENEMY_DEBUT_ROUNDS,
		GameStats.WAVE_STYLE_RULES,
		GameStats.WAVE_ROLE_WEIGHTS,
		GameStats.FORMATION_ROLE_WEIGHTS,
		get_balance_values(),
	])


func get_checkpoint_paths() -> Array[String]:
	return [
		output_dir.path_join(CHECKPOINT_FILE_A),
		output_dir.path_join(CHECKPOINT_FILE_B),
	]


func save_checkpoint(
	stage: String,
	population: Array[Dictionary],
	ranked: Array[Dictionary],
	finalists: Array[Dictionary],
	next_generation: int,
	next_final_index: int
) -> void:
	checkpoint_sequence += 1
	var payload := {
		"configuration": get_checkpoint_configuration(),
		"sequence": checkpoint_sequence,
		"stage": stage,
		"next_generation": next_generation,
		"next_final_index": next_final_index,
		"next_policy_id": next_policy_id,
		"search_rng_state": search_rng.state,
		"population": population,
		"ranked": ranked,
		"finalists": finalists,
		"final_results": final_results,
	}
	var paths := get_checkpoint_paths()
	var path := paths[checkpoint_sequence % paths.size()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write optimizer checkpoint: %s" % path)
		return
	file.store_var(payload)
	file.close()
	print("Checkpoint saved: %s (%d)" % [stage, checkpoint_sequence])


func load_checkpoint() -> Dictionary:
	var best: Dictionary = {}
	for path in get_checkpoint_paths():
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var value: Variant = file.get_var()
		file.close()
		if not value is Dictionary:
			continue
		var candidate: Dictionary = value
		if candidate.get("configuration", {}) != get_checkpoint_configuration():
			continue
		if int(candidate.get("sequence", -1)) > int(best.get("sequence", -1)):
			best = candidate
	if not best.is_empty():
		checkpoint_sequence = int(best["sequence"])
		next_policy_id = int(best.get("next_policy_id", next_policy_id))
		search_rng.state = int(best.get("search_rng_state", search_rng.state))
	return best


func clear_checkpoints() -> void:
	for path in get_checkpoint_paths():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func write_all_reports(ranked: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	write_strategy_report(ranked)
	write_policy_json(ranked)
	write_manifest()
	write_run_report()
	if record_round_history:
		write_early_round_trace_report()
	write_dominance_report()
	write_starter_roster_report()
	write_starter_tower_report()
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
	var starter_signatures: Array[String] = []
	for roster in starting_rosters:
		starter_signatures.append(get_starting_roster_signature(roster))
	var manifest := {
		"preset": preset,
		"seed": seed_value,
		"population": population_size,
		"generations": generations,
		"runs_per_policy": runs_per_policy,
		"final_runs_per_profile": final_runs_per_profile,
		"effective_runs_per_policy": maxi(
			runs_per_policy,
			starting_rosters.size()
		),
		"effective_final_runs_per_profile": maxi(
			final_runs_per_profile,
			starting_rosters.size()
		),
		"finalists": finalist_count,
		"combat_samples": combat_samples,
		"workers": worker_count,
		"starter_roster_size": "1_or_2" if starter_calibration else STARTER_ROSTER_SIZE,
		"starter_roster_count": starting_rosters.size(),
		"starter_rosters": starter_signatures,
		"forced_starter": focused_starter_tower,
		"starter_calibration": starter_calibration,
		"relics_disabled": disable_relics,
		"included_towers": get_test_tower_ids(),
		"excluded_towers": EXCLUDED_TOWERS,
		"excluded_relics": EXCLUDED_RELICS,
		"gameplay_data_fingerprint": get_gameplay_data_fingerprint(),
		"balance_values": get_balance_values(),
		"sensitivity_profiles": sensitivity_profiles,
		"model": {
			"rounds": simulation_round_limit,
			"starting_rosters": starter_signatures,
			"maximum_towers": MAX_TOWERS,
			"engagement_coverage": TOWER_ENGAGEMENT_COVERAGE,
			"map_geometry": use_map_geometry,
			"map_id": selected_map_id,
			"map_path_samples": map_path_samples.size(),
			"map_combat_segments": map_combat_samples.size(),
			"map_combat_time_step": MAP_COMBAT_TIME_STEP,
			"midwave_purchase_interval": (
				MIDWAVE_PURCHASE_INTERVAL if use_map_geometry else 0.0
			),
			"map_legal_placements": map_placements.size(),
			"purchase_lookahead_steps": PURCHASE_LOOKAHEAD_STEPS,
			"future_power_discount": FUTURE_POWER_DISCOUNT,
			"future_funding_discount": FUTURE_FUNDING_DISCOUNT,
			"notes": [
				"Combat coefficients come from health-scaled tower Monte Carlo curves.",
				"Purchases are staged as builds, upgrades, and paths.",
				"Relic drafts and major combat/economy effects are modeled.",
				"Round role mixes use the same shared wave and formation weights as gameplay.",
				"Horde, elite, gauntlet, and payday variants and special elite packs are modeled.",
				"Saucer pursuit, abduction, split prevention, rockets, and specimen uptime are approximated.",
				"Map combat advances enemy health and count through physical path segments, applies localized control, and limits each tower to covered segments.",
				"Map combat credits earned kill income and reevaluates affordable purchases once per simulated second.",
				"Beam and melee range relics and placement-based adjacency relics use the current simulated layout.",
				"Manual aim skill, individual projectile timing, exact formation spacing, child spawn timing, selling, and some triggered relic effects remain approximations.",
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
	var file := open_report("finalist_runs.csv", "policy_id,policy_name,profile,special_round_one_type,starting_roster,first_tower,won,round_reached,lives,money,leak_damage,total_spent,path_coverage,upgrade_purchases,tower_count,build,relics,towers")
	for row in final_results:
		file.store_line(",".join(PackedStringArray([
			str(row["policy_id"]), csv(row.get("policy_name", "")), str(row["profile"]), csv(row.get("special_round_one_type", "")), csv(row["starting_roster"]), csv(row.get("first_tower", "")), str(int(row["won"])), str(row["round_reached"]), "%.3f" % row["lives"], "%.2f" % row["money"], "%.2f" % row["leak_damage"], "%.2f" % row.get("total_spent", 0.0), "%.4f" % row.get("path_coverage", 0.0), str(row.get("upgrade_purchases", 0)), str(row.get("tower_count", 0)), csv(row["build_signature"]), csv(row["relic_signature"]), csv(row["tower_signature"]),
		])))
	file.close()


func write_early_round_trace_report() -> void:
	var file := open_report(
		"early_round_trace.csv",
		"policy_id,policy_name,run_seed,special_round_one_type,forced_starter,starting_roster,first_tower,round,survived,starting_money,spent,post_purchase_money,midwave_spent,kill_income,round_reward,ending_money,round_leak_damage,lives,build,towers"
	)
	for result in final_results:
		for trace in result.get("round_history", []):
			file.store_line(",".join(PackedStringArray([
				str(result["policy_id"]),
				csv(result.get("policy_name", "")),
				str(result.get("run_seed", 0)),
				csv(result.get("special_round_one_type", "")),
				csv(result.get("forced_starter", "")),
				csv(result["starting_roster"]),
				csv(result.get("first_tower", "")),
				str(trace["round"]),
				str(int(bool(trace["survived"]))),
				"%.2f" % trace["starting_money"],
				"%.2f" % trace["spent"],
				"%.2f" % trace["post_purchase_money"],
				"%.2f" % trace.get("midwave_spent", 0.0),
				"%.2f" % trace["kill_income"],
				"%.2f" % trace["round_reward"],
				"%.2f" % trace["ending_money"],
				"%.3f" % trace["round_leak_damage"],
				"%.3f" % trace["lives"],
				csv(trace["build_signature"]),
				csv(trace["tower_signature"]),
			])))
	file.close()


func write_starter_calibration_report() -> void:
	var groups := {}
	for row in final_results:
		var key := "%s|%s|%s" % [
			row.get("policy_name", ""), row.get("special_round_one_type", ""), row["starting_roster"],
		]
		if not groups.has(key):
			groups[key] = {
				"strategy": row.get("policy_name", ""),
				"challenge": row.get("special_round_one_type", ""),
				"roster": row["starting_roster"],
				"runs": 0, "wins": 0, "round": 0.0, "lives": 0.0,
				"money": 0.0, "leaks": 0.0, "spent": 0.0,
				"coverage": 0.0, "upgrades": 0.0, "towers": 0.0,
				"first_towers": {}, "builds": {},
			}
		var group: Dictionary = groups[key]
		group["runs"] += 1
		group["wins"] += int(row["won"])
		group["round"] += float(row["round_reached"])
		group["lives"] += float(row["lives"])
		group["money"] += float(row["money"])
		group["leaks"] += float(row["leak_damage"])
		group["spent"] += float(row.get("total_spent", 0.0))
		group["coverage"] += float(row.get("path_coverage", 0.0))
		group["upgrades"] += float(row.get("upgrade_purchases", 0))
		group["towers"] += float(row.get("tower_count", 0))
		var first := String(row.get("first_tower", "none"))
		group["first_towers"][first] = int(group["first_towers"].get(first, 0)) + 1
		group["builds"][row["build_signature"]] = int(group["builds"].get(row["build_signature"], 0)) + 1
	var rows: Array = groups.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "%s|%s|%s" % [a["strategy"], a["challenge"], a["roster"]]
		var right := "%s|%s|%s" % [b["strategy"], b["challenge"], b["roster"]]
		return left < right
	)
	var file := open_report(
		"starter_calibration.csv",
		"strategy,round_6_variant,starting_roster,runs,win_rate,average_round,average_lives,average_leaks,average_money,average_spent,average_path_coverage,average_upgrade_purchases,average_tower_count,first_tower_counts,most_common_final_build"
	)
	for row in rows:
		var count := maxf(float(row["runs"]), 1.0)
		var most_common_build := ""
		var most_common_count := -1
		for build in row["builds"]:
			if int(row["builds"][build]) > most_common_count:
				most_common_count = int(row["builds"][build])
				most_common_build = String(build)
		file.store_line(",".join(PackedStringArray([
			csv(row["strategy"]), csv(row["challenge"]), csv(row["roster"]), str(row["runs"]),
			"%.4f" % (float(row["wins"]) / count), "%.3f" % (float(row["round"]) / count),
			"%.3f" % (float(row["lives"]) / count), "%.3f" % (float(row["leaks"]) / count),
			"%.2f" % (float(row["money"]) / count), "%.2f" % (float(row["spent"]) / count),
			"%.4f" % (float(row["coverage"]) / count), "%.3f" % (float(row["upgrades"]) / count),
			"%.3f" % (float(row["towers"]) / count), csv(JSON.stringify(row["first_towers"])),
			csv(most_common_build),
		])))
	file.close()


func get_starter_roster_rows() -> Array[Dictionary]:
	var totals := {}
	var all_wins := 0
	for row in final_results:
		var signature: String = row["starting_roster"]
		if not totals.has(signature):
			totals[signature] = {
				"signature": signature,
				"runs": 0,
				"wins": 0,
				"round": 0.0,
				"lives": 0.0,
				"profiles": {},
				"winning_builds": {},
			}
		var entry: Dictionary = totals[signature]
		entry["runs"] += 1
		entry["wins"] += int(row["won"])
		entry["round"] += float(row["round_reached"])
		entry["lives"] += float(row["lives"])
		entry["profiles"][row["profile"]] = true
		if bool(row["won"]):
			entry["winning_builds"][row["build_signature"]] = true
		all_wins += int(row["won"])
	var global_win_rate := (
		float(all_wins) / maxf(float(final_results.size()), 1.0)
	)
	var result: Array[Dictionary] = []
	for entry in totals.values():
		var runs := maxf(float(entry["runs"]), 1.0)
		entry["win_rate"] = float(entry["wins"]) / runs
		entry["win_rate_delta"] = float(entry["win_rate"]) - global_win_rate
		entry["average_round"] = float(entry["round"]) / runs
		entry["average_lives"] = float(entry["lives"]) / runs
		entry["profile_count"] = entry["profiles"].size()
		entry["winning_build_count"] = entry["winning_builds"].size()
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["win_rate"]) > float(b["win_rate"])
	)
	return result


func write_starter_roster_report() -> void:
	var file := open_report(
		"starter_roster_value.csv",
		"rank,starting_roster,runs,wins,win_rate,win_rate_delta,average_round,average_lives,profiles_seen,unique_winning_builds,clear_choice_flag"
	)
	var rows := get_starter_roster_rows()
	for index in rows.size():
		var row: Dictionary = rows[index]
		var flag := (
			"CLEAR_START"
			if float(row["win_rate_delta"]) >= 0.08
				and int(row["profile_count"]) == sensitivity_profiles.size()
			else ""
		)
		file.store_line(",".join(PackedStringArray([
			str(index + 1), csv(row["signature"]), str(row["runs"]),
			str(row["wins"]), "%.4f" % row["win_rate"],
			"%.4f" % row["win_rate_delta"], "%.3f" % row["average_round"],
			"%.3f" % row["average_lives"], str(row["profile_count"]),
			str(row["winning_build_count"]), flag,
		])))
	file.close()


func write_starter_tower_report() -> void:
	var file := open_report(
		"starter_tower_value.csv",
		"tower,present_runs,present_win_rate,absent_win_rate,win_rate_delta,clear_choice_flag"
	)
	for tower_id in get_test_tower_ids():
		var present_runs := 0
		var present_wins := 0
		var absent_runs := 0
		var absent_wins := 0
		for row in final_results:
			var starter_ids := String(row["starting_roster"]).split("+", false)
			if starter_ids.has(String(tower_id)):
				present_runs += 1
				present_wins += int(row["won"])
			else:
				absent_runs += 1
				absent_wins += int(row["won"])
		var present_rate := (
			float(present_wins) / maxf(float(present_runs), 1.0)
		)
		var absent_rate := (
			float(absent_wins) / maxf(float(absent_runs), 1.0)
		)
		var delta := present_rate - absent_rate
		var flag := "CLEAR_START_PICK" if delta >= 0.08 else ""
		file.store_line(",".join(PackedStringArray([
			str(tower_id), str(present_runs), "%.4f" % present_rate,
			"%.4f" % absent_rate, "%.4f" % delta, flag,
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
	for relic_key in GameStats.LEGACY_ITEM_TEMPLATES:
		var relic_id := StringName(relic_key)
		if EXCLUDED_RELICS.has(relic_id):
			continue
		if not bool(GameStats.get_legacy_item_template(relic_id).get("enabled", true)):
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
	for tower_id in get_test_tower_ids():
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
		"enemy_health": 1.0,
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
	file.store_line("Top starting tower pairs:")
	var starter_rows := get_starter_roster_rows()
	for index in mini(10, starter_rows.size()):
		var starter: Dictionary = starter_rows[index]
		file.store_line(
			"%d. %s | win %.1f%% | delta %.1f%% | runs %d" % [
				index + 1,
				starter["signature"],
				float(starter["win_rate"]) * 100.0,
				float(starter["win_rate_delta"]) * 100.0,
				starter["runs"],
			]
		)
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
