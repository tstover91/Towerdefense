extends Node

const GameStats = preload("res://stat_database.gd")
const WaveDirectorScript = preload("res://wave_director.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var expected_opening_counts := [6, 8, 10, 13, 16]
	for run_index in 64:
		var rng := RandomNumberGenerator.new()
		rng.seed = 71237 + run_index * 104729
		var director = WaveDirectorScript.new(rng)
		director.generate_run_plan()
		for round_number in range(1, 25):
			var round_type: StringName = &"standard"
			if round_number == 8:
				round_type = &"horde"
			elif round_number == 16:
				round_type = &"elite"
			var plan: Dictionary = director.build_round_schedule(
				round_number, round_type, &"easy", 24
			)
			var schedule: Array = plan["schedule"]
			assert(not schedule.is_empty())
			assert(float(plan["threat_spent"]) <= float(plan["threat_budget"]) + 0.001)
			var available := GameStats.get_available_enemy_ids(
				round_number, director.enemy_debut_plan
			)
			var group_ends := 0
			for spawn_event in schedule:
				var enemy_id := StringName(spawn_event["enemy_id"])
				assert(enemy_id in available or enemy_id == &"brute")
				if bool(spawn_event.get("planned_group_end", false)):
					group_ends += 1
					assert(float(spawn_event["minimum_group_gap"]) > 0.0)
			assert(group_ends == int(plan["group_count"]))
			var eligible := GameStats.get_eligible_wave_styles(
				round_number, available
			)
			if round_number < 24:
				assert(StringName(plan["style"]) in eligible)
			if round_number <= 5:
				assert(
					schedule.size() == expected_opening_counts[round_number - 1],
					"Round %d planned %d enemies, expected %d" % [
						round_number,
						schedule.size(),
						expected_opening_counts[round_number - 1],
					]
				)
	print("Planned round director smoke checks passed across 64 runs.")
	get_tree().quit(0)
