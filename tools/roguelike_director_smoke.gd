extends SceneTree

const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	var observed_debut_rounds := {}
	var observed_round_eight_styles := {}
	var observed_round_eighteen_styles := {}
	for enemy_key in GameStats.ENEMIES:
		observed_debut_rounds[StringName(enemy_key)] = {}

	for seed_value in range(1, 129):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var debut_plan := GameStats.build_enemy_debut_plan(rng)
		validate_debut_plan(debut_plan)
		var style_plan := GameStats.build_round_style_plan(rng, debut_plan)
		validate_style_plan(debut_plan, style_plan)
		observed_round_eight_styles[style_plan[8]] = true
		observed_round_eighteen_styles[style_plan[18]] = true
		for enemy_id in debut_plan:
			observed_debut_rounds[enemy_id][debut_plan[enemy_id]] = true

	for group in GameStats.ENEMY_DEBUT_GROUPS:
		for enemy_id in group["enemies"]:
			assert(observed_debut_rounds[enemy_id].size() > 1)
	assert(observed_round_eight_styles.size() > 1)
	assert(observed_round_eighteen_styles.size() > 1)

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 90210
	var first_debuts := GameStats.build_enemy_debut_plan(first_rng)
	var first_styles := GameStats.build_round_style_plan(first_rng, first_debuts)
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 90210
	var second_debuts := GameStats.build_enemy_debut_plan(second_rng)
	var second_styles := GameStats.build_round_style_plan(second_rng, second_debuts)
	assert(first_debuts == second_debuts)
	assert(first_styles == second_styles)

	for enemy_key in GameStats.ENEMIES:
		var enemy: Dictionary = GameStats.ENEMIES[enemy_key]
		assert(enemy.has("earliest_debut_round"))
		assert(not enemy.has("first_wave"))
	assert(not GameStats.FORMATION_ROLE_WEIGHTS.has(&"sandwich"))
	assert(not GameStats.FORMATION_ROLE_WEIGHTS.has(&"escorted_elite"))

	print("Roguelike director smoke checks passed.")
	quit(0)


func validate_debut_plan(plan: Dictionary) -> void:
	assert(plan.size() == GameStats.ENEMIES.size())
	assert(int(plan[&"normal"]) == 1)
	assert(int(plan[&"runner"]) == 2)
	assert(int(plan[&"swarmling"]) == 2)
	assert(int(plan[&"bruiser"]) == 5)
	assert(int(plan[&"armored"]) == 5)
	assert(int(plan[&"splitter"]) == 8)
	assert(int(plan[&"buffer"]) == 8)
	assert(int(plan[&"hidden"]) == 11)
	assert(int(plan[&"swat_enforcer"]) == 14)
	assert(int(plan[&"shielded"]) == 17)
	assert(int(plan[&"heavy_enforcer"]) == 17)
	assert(int(plan[&"shield_projector"]) == 20)
	assert(int(plan[&"juggernaut"]) == 20)
	assert(int(plan[&"bulwark"]) == 22)
	assert(int(plan[&"brute"]) == 24)
	for group in GameStats.ENEMY_DEBUT_GROUPS:
		var assigned_rounds: Array[int] = []
		for enemy_id in group["enemies"]:
			assigned_rounds.append(int(plan[enemy_id]))
		assigned_rounds.sort()
		var expected_rounds: Array[int] = []
		for round_number in group["rounds"]:
			expected_rounds.append(int(round_number))
		expected_rounds.sort()
		assert(assigned_rounds == expected_rounds)


func validate_style_plan(
	debut_plan: Dictionary,
	style_plan: Dictionary
) -> void:
	assert(style_plan.size() == 24)
	assert(style_plan[24] == &"final_escort")
	var previous_style: StringName = &""
	for round_number in range(1, 24):
		var style_name := StringName(style_plan[round_number])
		var available := GameStats.get_available_enemy_ids(
			round_number,
			debut_plan
		)
		assert(style_name in GameStats.get_eligible_wave_styles(
			round_number,
			available
		))
		if round_number > 1:
			assert(style_name != previous_style)
		previous_style = style_name
