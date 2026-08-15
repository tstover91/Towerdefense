extends Node

const MAIN_SCENE = preload("res://main.tscn")
const GameStats = preload("res://stat_database.gd")
const DEFAULT_RUNS := 512

var audit_reward_multiplier := GameStats.KILL_REWARD_MULTIPLIER


func _init() -> void:
	call_deferred("run_audit")


func run_audit() -> void:
	var run_count := get_run_count()
	audit_reward_multiplier = get_reward_multiplier()
	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)
	var totals: Array[float] = []
	var round_totals: Array[float] = []
	var maximum_rounds := int(GameStats.get_mode(&"easy")["max_rounds"])
	round_totals.resize(maximum_rounds)
	round_totals.fill(0.0)
	for run_index in run_count:
		var run_seed := 92821 + run_index * 104729
		director.enemy_rng.seed = run_seed
		director.generate_run_director_plan()
		director.roll_challenge_round_order()
		var run_total := 0.0
		for round_number in range(1, maximum_rounds + 1):
			var round_type: StringName = director.get_round_type(round_number)
			var counts: Dictionary = director.simulate_director_spawn_counts(
				round_number,
				round_type,
				run_seed + round_number * 7919,
				false
			)
			append_special_event_counts(
				director, counts, round_number, round_type,
				run_seed + round_number * 15485863
			)
			var income := get_counts_income(counts)
			round_totals[round_number - 1] += income
			run_total += income
		totals.append(run_total)
	totals.sort()
	var sum := 0.0
	for value in totals:
		sum += value
	print("ENEMY INCOME AUDIT (%d completed runs, multiplier %.4f)" % [
		run_count, audit_reward_multiplier,
	])
	print("mean=%.2f median=%.2f p10=%.2f p90=%.2f min=%.2f max=%.2f" % [
		sum / float(run_count), percentile(totals, 0.50),
		percentile(totals, 0.10), percentile(totals, 0.90),
		totals.front(), totals.back(),
	])
	for round_index in maximum_rounds:
		print("round_%02d=%.2f" % [
			round_index + 1,
			round_totals[round_index] / float(run_count),
		])
	director.queue_free()
	get_tree().quit(0)


func get_run_count() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			return maxi(int(argument.trim_prefix("--runs=")), 1)
	return DEFAULT_RUNS


func get_reward_multiplier() -> float:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--reward-multiplier="):
			return maxf(float(argument.trim_prefix("--reward-multiplier=")), 0.0)
	return GameStats.KILL_REWARD_MULTIPLIER


func append_special_event_counts(
	director: Node,
	counts: Dictionary,
	round_number: int,
	round_type: StringName,
	seed: int
) -> void:
	if round_type not in [&"elite", &"gauntlet"]:
		return
	director.round_number = round_number
	director.current_round_type = round_type
	director.enemy_rng.seed = seed
	var duration := GameStats.get_round_duration(round_number)
	var is_gauntlet := round_type == &"gauntlet"
	var next_event_time: float = director.enemy_rng.randf_range(
		10.0 if is_gauntlet else 15.0,
		18.0 if is_gauntlet else 25.0
	)
	var final_event_time := duration * 0.80
	while next_event_time < final_event_time:
		var elite_count: int = (
			director.enemy_rng.randi_range(1, 3)
			if is_gauntlet
			else (
				2
				if round_number == 6 and director.enemy_rng.randf() < 0.25
				else (1 if round_number == 6 else director.enemy_rng.randi_range(1, 2))
			)
		)
		var escort_count: int = director.enemy_rng.randi_range(
			4 if is_gauntlet else 3,
			8 if is_gauntlet else 6
		)
		add_schedule_counts(counts, director.build_elite_event_schedule(
			elite_count, escort_count,
			&"horde" if is_gauntlet else &"normal"
		))
		next_event_time += director.enemy_rng.randf_range(
			10.0 if is_gauntlet else 15.0,
			18.0 if is_gauntlet else 25.0
		)
	add_schedule_counts(counts, director.build_elite_event_schedule(
		3 if round_number >= 11 else 2,
		(
			director.enemy_rng.randi_range(6, 10)
			if is_gauntlet
			else director.enemy_rng.randi_range(4, 7)
		),
		&"horde" if is_gauntlet else &"normal"
	))


func add_schedule_counts(counts: Dictionary, schedule: Array[Dictionary]) -> void:
	for event in schedule:
		var key := "%s|%s" % [
			StringName(event["enemy_id"]),
			StringName(event.get("variant", &"normal")),
		]
		counts[key] = float(counts.get(key, 0.0)) + 1.0


func get_counts_income(counts: Dictionary) -> float:
	var result := 0.0
	for count_key in counts:
		var parts := String(count_key).split("|", false, 1)
		var enemy_id := StringName(parts[0])
		var variant := StringName(parts[1]) if parts.size() > 1 else &"normal"
		result += float(counts[count_key]) * get_composite_reward(enemy_id, variant)
	return result


func get_composite_reward(enemy_id: StringName, variant: StringName) -> float:
	var enemy := GameStats.get_enemy(enemy_id)
	var reward := get_unit_reward(enemy, variant)
	var child_variant := variant if variant in [&"horde", &"payday"] else &"normal"
	if int(enemy.get("split_count", 0)) > 0:
		reward += (
			float(enemy["split_count"])
			* get_unit_reward(
				GameStats.get_enemy(StringName(enemy["split_enemy_id"])),
				child_variant
			)
		)
	if int(enemy.get("summon_limit", 0)) > 0:
		reward += (
			float(enemy["summon_limit"])
			* get_unit_reward(
				GameStats.get_enemy(StringName(enemy["summon_enemy_id"])),
				child_variant
			)
		)
	return reward


func get_unit_reward(enemy: Dictionary, variant: StringName) -> float:
	var variant_multiplier := 1.0
	match variant:
		&"horde": variant_multiplier = 0.55
		&"elite": variant_multiplier = 3.0
	return float(maxi(roundi(
		float(enemy.get("cash_reward", 0.0))
		* variant_multiplier
		* audit_reward_multiplier
	), 1))


func percentile(sorted_values: Array[float], ratio: float) -> float:
	var index := clampi(
		roundi(ratio * float(sorted_values.size() - 1)),
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]
