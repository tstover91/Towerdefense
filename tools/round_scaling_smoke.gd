extends SceneTree

const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	assert(GameStats.ROUND_PROFILES.size() == 20)
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
		var legacy_round_health := 1.15 + float(round_number - 1) * 0.025

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
			legacy_round_health * 1.10 * 1.80
		))
		assert(is_equal_approx(
			GameStats.get_round_health_multiplier(round_number, true),
			legacy_round_health * 1.10
		))
		total_duration += expected_duration

	assert(is_equal_approx(total_duration, 1050.0))
	for enemy_id in GameStats.ENEMIES:
		var enemy: Dictionary = GameStats.ENEMIES[enemy_id]
		assert(enemy.has("director_cost"))
		assert(enemy.has("formation_strength"))
		assert(not enemy.has("spawn_cost"))
		assert(not enemy.has("threat_cost"))

	print("Round scaling smoke checks passed.")
	quit(0)
