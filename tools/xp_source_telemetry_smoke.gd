extends Node

const TOWER_INSTANCE_PROGRESSION = preload(
	"res://tower_progression/tower_instance_progression.gd"
)
const TOWER_XP_CREDIT_SERVICE = preload(
	"res://tower_progression/tower_xp_credit_service.gd"
)


class FakeEnemy:
	extends Node
	var enemy_id: StringName = &"normal"
	var traits: Array = []
	var max_health := 100
	var xp_budget_multiplier := 1.0


func _ready() -> void:
	var enemy := FakeEnemy.new()
	add_child(enemy)
	var damage_budget := TOWER_XP_CREDIT_SERVICE.get_enemy_damage_xp_budget(enemy)
	assert(is_equal_approx(
		TOWER_XP_CREDIT_SERVICE.get_kill_xp(enemy),
		damage_budget * 0.05
	))

	var progression = TOWER_INSTANCE_PROGRESSION.new(&"invader")
	progression.record_damage(10, 2.0)
	progression.record_kill(0.5)
	progression.record_control_credit(0.25)
	progression.record_round_completion_xp(3.0)
	var breakdown: Dictionary = progression.consume_round_xp_breakdown()
	assert(is_equal_approx(float(breakdown["damage"]), 2.0))
	assert(is_equal_approx(float(breakdown["kills"]), 0.5))
	assert(is_equal_approx(float(breakdown["support"]), 0.25))
	assert(is_equal_approx(float(breakdown["completion"]), 3.0))
	assert(is_equal_approx(float(breakdown["total"]), 5.75))
	var reset_breakdown: Dictionary = progression.consume_round_xp_breakdown()
	assert(is_equal_approx(float(reset_breakdown["total"]), 0.0))

	print("XP source telemetry smoke test passed: final-hit ratio and per-wave source accounting are correct.")
	get_tree().quit(0)
