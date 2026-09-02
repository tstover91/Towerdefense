extends Node

const TOWER_INSTANCE_PROGRESSION = preload(
	"res://tower_progression/tower_instance_progression.gd"
)


func _ready() -> void:
	var progression = TOWER_INSTANCE_PROGRESSION.new(&"energycore")
	var expected_thresholds := {
		2: 14.0,
		5: 88.0,
		10: 415.0,
		15: 1467.0,
		20: 5000.0,
	}
	for expected_level in expected_thresholds:
		assert(
			is_equal_approx(
				progression.get_total_xp_required_for_level(expected_level),
				expected_thresholds[expected_level]
			)
		)

	progression.grant_xp(expected_thresholds[15])
	assert(progression.level == 15)
	for _award_index in 10_000:
		progression.grant_xp(1.0)
	assert(progression.level == 20)
	assert(is_equal_approx(progression.xp, expected_thresholds[15] + 10_000.0))
	assert(progression.get_level_for_total_xp(expected_thresholds[10] - 1.0) == 9)
	assert(progression.get_level_for_total_xp(expected_thresholds[10]) == 10)

	progression.set_level_for_sandbox(5)
	assert(progression.level == 5)
	assert(is_equal_approx(progression.xp, expected_thresholds[5]))
	print("Tower XP curve smoke test passed: cached thresholds, incremental leveling, and max-level accounting.")
	get_tree().quit(0)
