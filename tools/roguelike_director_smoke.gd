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
		var progression := GameStats.build_normal_enemy_progression(rng)
		var debut_plan: Dictionary = progression["debut_plan"]
		validate_debut_plan(debut_plan, progression)
		var style_plan := GameStats.build_round_style_plan(rng, debut_plan)
		validate_style_plan(debut_plan, style_plan)
		observed_round_eight_styles[style_plan[8]] = true
		observed_round_eighteen_styles[style_plan[18]] = true
		for enemy_id in debut_plan:
			observed_debut_rounds[enemy_id][debut_plan[enemy_id]] = true

	for enemy_id in observed_debut_rounds:
		if GameStats.get_enemy_family(enemy_id) != &"general":
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


func validate_debut_plan(plan: Dictionary, progression: Dictionary) -> void:
	assert(plan.size() == GameStats.ENEMIES.size())
	assert(int(plan[&"normal"]) == 1)
	assert(int(plan[&"striker"]) == 17)
	assert(int(plan[&"heavy_enforcer"]) == 17)
	assert(int(plan[&"bulwark"]) == 22)
	assert(int(plan[&"brute"]) == 24)
	var selected_families: Array = progression["selected_families"]
	var selected_tier_one: Array = progression["selected_tier_one"]
	var selected_tier_two: Array = progression["selected_tier_two"]
	assert(selected_families.size() == 3)
	assert(selected_tier_one.size() == 3)
	assert(selected_tier_two.size() == 2)
	for index in selected_tier_one.size():
		assert(GameStats.get_enemy_family(selected_tier_one[index]) == selected_families[index])
		assert(int(plan[selected_tier_one[index]]) == [4, 6, 10][index])
	for index in selected_tier_two.size():
		assert(GameStats.get_enemy_family_tier(selected_tier_two[index]) == 2)
		assert(int(plan[selected_tier_two[index]]) == [14, 18][index])
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		if (
			GameStats.get_enemy_family(enemy_id) != &"general"
			and not selected_tier_one.has(enemy_id)
			and not selected_tier_two.has(enemy_id)
		):
			assert(int(plan[enemy_id]) == 999)


func validate_style_plan(
	debut_plan: Dictionary,
	style_plan: Dictionary
) -> void:
	assert(style_plan.size() == 24)
	assert(style_plan[1] == &"standard")
	assert(style_plan[12] == &"mixed_roster")
	assert(style_plan[13] == &"mixed_roster")
	for round_number in [19, 21, 22, 23]:
		assert(style_plan[round_number] == &"layered_assault")
	assert(style_plan[24] == &"final_escort")
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
