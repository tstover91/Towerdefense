extends SceneTree

const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	assert(GameStats.ROUND_PROFILES.size() == 24)
	assert(is_equal_approx(GameStats.KILL_REWARD_MULTIPLIER, 0.104))
	assert(GameStats.get_round_cash_reward(1) == 150)
	assert(GameStats.get_round_cash_reward(2) == 175)
	assert(GameStats.get_round_cash_reward(3) == 200)
	assert(GameStats.get_round_cash_reward(9) == 525)
	assert(GameStats.get_round_cash_reward(10) == 600)
	assert(GameStats.get_round_cash_reward(11) == 800)
	assert(GameStats.get_round_cash_reward(16) == 2400)
	assert(GameStats.get_round_cash_reward(17) == 5000)
	assert(GameStats.get_round_cash_reward(18) == 2500)
	var total_round_cash := 0
	for round_number in range(1, 25):
		total_round_cash += GameStats.get_round_cash_reward(round_number)
	assert(total_round_cash == 37100)
	var expected_health_multipliers := [
		1.50, 2.00, 2.50, 3.00, 3.50, 4.00,
		4.50, 5.00, 5.50, 6.00, 6.50, 7.00,
		7.40, 7.70, 8.00, 8.30, 8.60, 9.00,
		9.40, 9.80, 10.20, 10.60, 11.00, 11.00,
	]
	var total_duration := 0.0
	var previous_threat_budget := 0.0
	for round_number in range(1, 25):
		var expected_duration := (
			90.0
			if round_number == 24
			else minf(20.0 + float(round_number - 1) * 5.0, 60.0)
		)
		var expected_boss_health := (
			1.15 + float(round_number - 1) * 0.025
		) * 1.10

		assert(is_equal_approx(
			GameStats.get_round_duration(round_number),
			expected_duration
		))
		var threat_budget := GameStats.get_round_threat_budget(round_number)
		assert(threat_budget > previous_threat_budget)
		previous_threat_budget = threat_budget
		assert(is_equal_approx(
			GameStats.get_round_health_multiplier(round_number, false),
			expected_health_multipliers[round_number - 1]
		))
		assert(is_equal_approx(
			GameStats.get_round_health_multiplier(round_number, true),
			expected_boss_health
		))
		total_duration += expected_duration

	assert(is_equal_approx(total_duration, 1290.0))
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
	) == 75)
	assert(roundi(
		float(GameStats.ENEMIES[&"normal"]["health"])
		* GameStats.get_enemy_health_multiplier(23, &"normal")
	) == 366)
	assert(roundi(
		float(GameStats.ENEMIES[&"bruiser"]["health"])
		* GameStats.get_enemy_health_multiplier(23, &"bruiser")
	) == 2883)
	assert(roundi(
		float(GameStats.ENEMIES[&"brute"]["health"])
		* GameStats.get_enemy_health_multiplier(24, &"brute")
	) == 170775)
	assert(int(GameStats.ENEMIES[&"heavy_enforcer"]["health"]) == 1800)
	assert(int(GameStats.ENEMIES[&"juggernaut"]["health"]) == 3500)
	assert(int(GameStats.ENEMIES[&"bulwark"]["health"]) == 6000)
	assert(is_equal_approx(float(GameStats.ENEMIES[&"brute"]["move_speed"]), 18.0))
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
