extends SceneTree

const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	assert(GameStats.ROUND_PROFILES.size() == 20)
	assert(is_equal_approx(GameStats.KILL_REWARD_MULTIPLIER, 0.25))
	var expected_health_multipliers := [
		2.30, 3.40, 4.80, 6.00, 7.00,
		8.00, 9.00, 10.00, 11.00, 11.80,
		12.50, 13.20, 13.80, 14.40, 14.90,
		15.50, 16.10, 17.20, 17.80, 18.40,
	]
	var total_duration := 0.0
	for round_number in range(1, 21):
		var expected_duration := (
			90.0
			if round_number == 20
			else minf(20.0 + float(round_number - 1) * 5.0, 60.0)
		)
		var early_multiplier := 1.0
		match round_number:
			1: early_multiplier = 0.75
			2: early_multiplier = 0.80
			3: early_multiplier = 0.85
			4: early_multiplier = 0.90
			5: early_multiplier = 0.95
		var legacy_threat_rate := (
			1.0
			+ float(round_number) * 0.12
			+ float(round_number * round_number) * 0.009
		) * 1.40 * early_multiplier
		var legacy_boss_health := (
			1.15 + float(round_number - 1) * 0.025
		) * 1.10

		assert(is_equal_approx(
			GameStats.get_round_duration(round_number),
			expected_duration
		))
		assert(is_equal_approx(
			GameStats.get_round_threat_budget(round_number),
			legacy_threat_rate * expected_duration
		))
		assert(is_equal_approx(
			GameStats.get_round_health_multiplier(round_number, false),
			expected_health_multipliers[round_number - 1]
		))
		assert(is_equal_approx(
			GameStats.get_round_health_multiplier(round_number, true),
			legacy_boss_health
		))
		total_duration += expected_duration

	assert(is_equal_approx(total_duration, 1050.0))
	for enemy_id in GameStats.ENEMIES:
		var enemy: Dictionary = GameStats.ENEMIES[enemy_id]
		assert(enemy.has("director_cost"))
		assert(enemy.has("formation_strength"))
		assert(enemy.has("earliest_debut_round"))
		assert(is_zero_approx(float(enemy.get("health_per_wave", 0.0))))
		assert(not enemy.has("spawn_cost"))
		assert(not enemy.has("threat_cost"))
		assert(not enemy.has("first_wave"))

	assert(roundi(
		float(GameStats.ENEMIES[&"normal"]["health"])
		* GameStats.get_enemy_health_multiplier(1, &"normal")
	) == 115)
	assert(roundi(
		float(GameStats.ENEMIES[&"normal"]["health"])
		* GameStats.get_enemy_health_multiplier(20, &"normal")
	) == 598)
	assert(roundi(
		float(GameStats.ENEMIES[&"bruiser"]["health"])
		* GameStats.get_enemy_health_multiplier(20, &"bruiser")
	) == 4858)
	assert(roundi(
		float(GameStats.ENEMIES[&"brute"]["health"])
		* GameStats.get_enemy_health_multiplier(20, &"brute")
	) == 160875)
	assert(is_equal_approx(
		GameStats.get_armor_damage_reduction(20.0, &"ballistic"),
		20.0 / 70.0
	))
	assert(is_equal_approx(
		GameStats.get_armor_damage_reduction(20.0, &"explosive"),
		25.0 / 75.0
	))
	assert(is_equal_approx(
		GameStats.get_armor_damage_reduction(10000.0),
		GameStats.MAXIMUM_ARMOR_DAMAGE_REDUCTION
	))

	print("Round scaling smoke checks passed.")
	quit(0)
