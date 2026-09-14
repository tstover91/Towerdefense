extends Node

const ReinforcementControllerScript = preload("res://reinforcement_controller.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var controller = ReinforcementControllerScript.new(
		self,
		func(position: Vector2) -> bool: return position.x >= 0.0
	)
	assert(controller.selected_reinforcement_id == &"grunt_squad")
	assert(not controller.get_selected_option().is_empty())
	assert(controller.can_begin_targeting(false, true, false, false))
	assert(not controller.can_begin_targeting(false, false, false, false))
	assert(not controller.can_begin_targeting(false, true, true, false))

	assert(controller.begin_targeting())
	assert(controller.targeting)
	assert(is_instance_valid(controller.preview))
	controller.update_preview(Vector2(-10.0, 20.0))
	assert(not controller.preview.placement_valid)
	assert(not controller.deploy(Vector2(-10.0, 20.0), 1))
	assert(controller.targeting)

	assert(controller.deploy(Vector2(100.0, 120.0), 5))
	assert(not controller.targeting)
	assert(controller.preview == null)
	assert(is_equal_approx(controller.cooldown_remaining, 25.0))
	var drops := get_tree().get_nodes_in_group("reinforcement_drops")
	assert(drops.size() == 1)
	assert(drops[0].global_position == Vector2(100.0, 120.0))

	assert(not controller.process_cooldown(1.0, false))
	assert(is_equal_approx(controller.cooldown_remaining, 25.0))
	assert(controller.process_cooldown(1.0, true))
	assert(is_equal_approx(controller.cooldown_remaining, 24.0))
	assert(controller.reset_cooldown())
	assert(is_equal_approx(controller.cooldown_remaining, 0.0))
	assert(not controller.reset_cooldown())
	controller.clear_drops()
	assert(drops[0].is_queued_for_deletion())

	print("Reinforcement controller smoke test passed: readiness, targeting, validation, deployment, round reset, and cleanup.")
	get_tree().quit(0)
