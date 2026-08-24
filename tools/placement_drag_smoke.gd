extends Node

const MAIN_SCENE = preload("res://main.tscn")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)
	await get_tree().process_frame

	director.tower_roster.assign([&"invader"])
	director.populate_tower_list()
	director.set_build_drawer_open(true)
	var tower_press := make_touch(3, Vector2(92.0, 500.0), true)
	director._on_tower_fan_button_gui_input(tower_press, 0)
	assert(director.placement_drag_candidate_kind == &"tower")

	var tower_drag := InputEventScreenDrag.new()
	tower_drag.index = 3
	tower_drag.position = Vector2(360.0, 430.0)
	assert(director.handle_placement_drag_input(tower_drag))
	assert(director.active_placement_drag_kind == &"tower")
	assert(director.build_mode)
	assert(is_instance_valid(director.tower_to_place))
	assert(director.placement_drag_world_position.is_equal_approx(
		Vector2(360.0, 318.0)
	))

	var valid_release_screen := find_valid_tower_release_screen(director)
	assert(valid_release_screen != Vector2.INF)
	var money_before: int = director.money
	var tower_release := make_touch(3, valid_release_screen, false)
	assert(director.handle_placement_drag_input(tower_release))
	assert(director.active_placement_drag_kind.is_empty())
	assert(not director.build_mode)
	assert(director.money < money_before)
	var placed_towers := get_tree().get_nodes_in_group("towers")
	assert(placed_towers.size() == 1)
	assert(bool(placed_towers[0].get("is_placed")))
	var money_after_build: int = director.money
	director._on_tower_fan_button_gui_input(
		make_touch(4, Vector2(92.0, 500.0), true), 0
	)
	var invalid_drag := InputEventScreenDrag.new()
	invalid_drag.index = 4
	invalid_drag.position = Vector2(240.0, 360.0)
	assert(director.handle_placement_drag_input(invalid_drag))
	assert(director.handle_placement_drag_input(
		make_touch(4, Vector2.ZERO, false)
	))
	assert(not director.build_mode)
	assert(not is_instance_valid(director.tower_to_place))
	assert(director.money == money_after_build)

	director.round_number = 1
	director.round_active = true
	var reinforcement_press := make_touch(5, Vector2(1060.0, 580.0), true)
	director._on_reinforcement_button_gui_input(reinforcement_press)
	assert(director.placement_drag_candidate_kind == &"reinforcement")
	var reinforcement_drag := InputEventScreenDrag.new()
	reinforcement_drag.index = 5
	reinforcement_drag.position = Vector2(520.0, 450.0)
	assert(director.handle_placement_drag_input(reinforcement_drag))
	assert(director.active_placement_drag_kind == &"reinforcement")
	assert(director.reinforcement_targeting)
	assert(director.reinforcement_preview.global_position.is_equal_approx(
		Vector2(520.0, 338.0)
	))
	var reinforcement_release := make_touch(
		5, Vector2(520.0, 450.0), false
	)
	assert(director.handle_placement_drag_input(reinforcement_release))
	assert(not director.reinforcement_targeting)
	assert(director.reinforcement_cooldown_remaining > 0.0)
	assert(get_tree().get_nodes_in_group("reinforcement_drops").size() == 1)

	print("Placement drag smoke test passed: offset previews and release-to-build/deploy.")
	director.queue_free()
	get_tree().quit(0)


func make_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = position
	touch.pressed = pressed
	return touch


func find_valid_tower_release_screen(director: Node) -> Vector2:
	for screen_y in range(190, 620, 32):
		for screen_x in range(80, 900, 32):
			var screen_position := Vector2(screen_x, screen_y)
			var world_position: Vector2 = (
				director.screen_to_placement_world_position(screen_position)
			)
			var snapped_position: Vector2 = director.get_tower_build_position(
				world_position,
				director.pending_tower_type
			)
			if director.can_place_tower(snapped_position):
				return screen_position
	return Vector2.INF
