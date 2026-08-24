extends SceneTree

const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	assert(GameStats.ROUND_PROFILES.size() == 24)
	assert(is_equal_approx(GameStats.KILL_REWARD_MULTIPLIER, 0.104))
	assert(GameStats.get_round_cash_reward(1) == 200)
	assert(GameStats.get_round_cash_reward(2) == 225)
	assert(GameStats.get_round_cash_reward(3) == 275)
	assert(GameStats.get_round_cash_reward(9) == 675)
	assert(GameStats.get_round_cash_reward(10) == 750)
	assert(GameStats.get_round_cash_reward(11) == 975)
	assert(GameStats.get_round_cash_reward(12) == 1200)
	assert(GameStats.get_round_cash_reward(13) == 1425)
	assert(GameStats.get_round_cash_reward(14) == 1750)
	assert(GameStats.get_round_cash_reward(15) == 2150)
	assert(GameStats.get_round_cash_reward(16) == 2400)
	assert(GameStats.get_round_cash_reward(17) == 5000)
	assert(GameStats.get_round_cash_reward(18) == 2500)
	assert(is_equal_approx(GameStats.get_round_threat_budget(4), 56.0))
	assert(is_equal_approx(GameStats.get_round_threat_budget(5), 75.0))
	assert(is_equal_approx(GameStats.get_round_threat_budget(6), 90.0))
	assert(is_equal_approx(GameStats.get_round_threat_budget(7), 120.0))
	assert(is_equal_approx(GameStats.get_round_threat_budget(8), 160.0))
	assert(is_equal_approx(GameStats.get_round_threat_budget(9), 210.0))
	assert(is_equal_approx(GameStats.get_elite_enemy_health_multiplier(6), 1.75))
	assert(is_equal_approx(GameStats.get_elite_enemy_speed_multiplier(6), 1.15))
	assert(is_equal_approx(GameStats.get_elite_enemy_health_multiplier(11), 2.25))
	var total_round_cash := 0
	for round_number in range(1, 25):
		total_round_cash += GameStats.get_round_cash_reward(round_number)
	assert(total_round_cash == 39200)
	var expected_health_multipliers := [
		1.50, 2.00, 2.50, 3.00, 3.50, 4.00,
		4.50, 5.00, 5.50, 6.00, 6.50, 7.00,
		7.40, 7.70, 8.00, 8.30, 8.60, 9.00,
		9.40, 9.80, 10.20, 10.60, 11.00, 11.00,
	]
	assert(is_equal_approx(GameStats.get_late_difficulty_health_multiplier(10), 1.0))
	assert(is_equal_approx(GameStats.get_late_difficulty_health_multiplier(11), 1.10))
	assert(is_equal_approx(GameStats.get_late_difficulty_health_multiplier(19), 1.15))
	assert(is_equal_approx(GameStats.get_late_difficulty_health_multiplier(20), 1.20))
	assert(is_equal_approx(GameStats.get_late_difficulty_health_multiplier(24), 1.25))
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
		) * 1.10 * GameStats.get_late_difficulty_health_multiplier(round_number)
		expected_health_multipliers[round_number - 1] *= (
			GameStats.get_late_difficulty_health_multiplier(round_number)
		)

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
		assert(enemy.has("family"))
		assert(int(enemy.get("family_tier", 0)) in [1, 2])

	var expected_families := {
		&"speed": {1: [&"runner"], 2: [&"rusher"]},
		&"swarms": {1: [&"swarmling"], 2: [&"splitter"]},
		&"tank": {1: [&"bruiser"], 2: [&"juggernaut"]},
		&"armor": {1: [&"armored"], 2: [&"swat_enforcer"]},
		&"buffs": {1: [&"buffer"], 2: []},
		&"hidden": {1: [&"hidden"], 2: []},
		&"healer": {1: [&"regenerator"], 2: []},
		&"summon": {1: [&"summoner"], 2: []},
		&"shields": {1: [&"shielded"], 2: [&"shield_projector"]},
		&"general": {
			1: [&"normal"],
			2: [&"striker", &"heavy_enforcer", &"bulwark", &"brute"],
		},
	}
	for family in expected_families:
		for tier in expected_families[family]:
			var actual := GameStats.get_enemy_family_ids(family, tier)
			actual.sort()
			var expected: Array = expected_families[family][tier].duplicate()
			expected.sort()
			assert(actual == expected)
	assert(int(GameStats.ENEMIES[&"juggernaut"]["armor"]) == 0)
	assert(not GameStats.ENEMIES[&"juggernaut"]["traits"].has(&"armored"))
	var early_family_weights: Dictionary = GameStats.WAVE_ROLE_WEIGHTS[1]["weights"]
	assert(is_equal_approx(float(early_family_weights[&"fodder"]), 50.0))
	assert(is_equal_approx(float(early_family_weights[&"support"]), 10.0))

	assert(roundi(
		float(GameStats.ENEMIES[&"normal"]["health"])
		* GameStats.get_enemy_health_multiplier(1, &"normal")
	) == 75)
	assert(roundi(
		float(GameStats.ENEMIES[&"normal"]["health"])
		* GameStats.get_enemy_health_multiplier(23, &"normal")
	) == 453)
	assert(roundi(
		float(GameStats.ENEMIES[&"bruiser"]["health"])
		* GameStats.get_enemy_health_multiplier(23, &"bruiser")
	) == 3568)
	assert(roundi(
		float(GameStats.ENEMIES[&"brute"]["health"])
		* GameStats.get_enemy_health_multiplier(24, &"brute")
	) == 213469)
	assert(int(GameStats.ENEMIES[&"heavy_enforcer"]["health"]) == 1800)
	assert(GameStats.ENEMIES[&"striker"]["role"] == &"pressure")
	assert(int(GameStats.ENEMIES[&"striker"]["director_cost"]) == 8)
	assert(int(GameStats.ENEMIES[&"juggernaut"]["health"]) == 3500)
	assert(int(GameStats.ENEMIES[&"bulwark"]["health"]) == 6000)
	assert(is_equal_approx(float(GameStats.ENEMIES[&"brute"]["move_speed"]), 18.0))
	assert(int(GameStats.ENEMIES[&"hidden"]["health"]) == 75)
	assert(is_equal_approx(float(GameStats.ENEMIES[&"hidden"]["move_speed"]), 95.0))
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
