extends SceneTree

const PrototypeScene = preload("res://prototype/prototype_main.tscn")

var resolved_enemy_count := 0
var failure_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1152, 648)
	var game: Node = PrototypeScene.instantiate()
	get_root().add_child(game)
	current_scene = game
	await process_frame
	var board: Node2D = game.get_node("GridBoard")
	board.enemy_resolved.connect(_on_enemy_resolved)
	var button_center: Vector2 = board.build_button_rect.get_center()
	board._begin_precision_placement()
	board._arm_placement_drag(button_center, 0)
	var touch_jitter := button_center + Vector2(14.0, 0.0)
	board._handle_drag_motion(touch_jitter, 0)
	_assert(int(board.placement_mode) == 1, "touch jitter on the button remains a precision tap")
	board._finish_placement_drag(touch_jitter)
	_assert(int(board.placement_mode) == 1, "releasing a jittered tap does not cancel placement")
	board._cancel_placement()
	var original_route: Array[Vector2i] = board.displayed_route.duplicate()
	var tower_cell: Vector2i = original_route[1]
	board._handle_screen_press(board.build_button_rect.get_center())
	_assert(
		int(board.placement_mode) == 1,
		"tapping the tower button begins precision placement"
	)
	board._handle_screen_press(board._cell_center(tower_cell))
	_assert(not board.towers_by_cell.has(tower_cell), "the first precision tap only positions the preview")
	_assert(board.preview_is_valid, "a legal precision preview validates its candidate route")
	_assert(board.preview_route != original_route, "the live preview shows the proposed reroute")
	board._handle_screen_press(board._cell_center(tower_cell))
	_assert(board.towers_by_cell.has(tower_cell), "the second precision tap creates a combat tower")
	_assert(int(board.placement_mode) == 0, "precision placement ends after building")
	_assert(board.displayed_route != original_route, "blocking a route cell changes the displayed path")
	_assert(game.economy.credits == 400, "tower placement costs $100")
	_assert(game.economy.used_power == 1, "tower placement consumes Power")
	var tower: Node2D = board.towers_by_cell[tower_cell]
	_assert(tower.level == 1, "new tower starts at level one")
	board._upgrade_selected_tower()
	_assert(tower.level == 2, "selected tower upgrades")
	_assert(game.economy.credits == 300, "level two costs $100")

	board.spawn_enemy({
		"health": 8,
		"speed_cells_per_second": 0.55,
		"leak_damage": 1,
	})
	var frame_guard := 0
	while resolved_enemy_count <= 0 and frame_guard < 360:
		await process_frame
		frame_guard += 1
	_assert(resolved_enemy_count == 1, "tower projectile defeats the routed enemy")
	_assert(board.active_followers.is_empty(), "defeated enemy leaves active routing")
	board._sell_selected_tower()
	await process_frame
	_assert(not board.towers_by_cell.has(tower_cell), "selling removes the selected tower")
	_assert(not board.router.dynamic_blocks.has(tower_cell), "selling reopens its route cell")
	_assert(board.displayed_route == original_route, "selling restores the original shortest path")
	_assert(board.preview_route.is_empty(), "selling clears the obsolete candidate path")
	_assert(not board.preview_is_valid, "selling stops drawing a placement preview")
	_assert(game.economy.used_power == 0, "selling releases Power")
	_assert(game.economy.credits == 440, "participating tower sells for 70% of total investment")

	var unused_cell := Vector2i(1, 5)
	var drag_start: Vector2 = board.build_button_rect.get_center()
	var drag_release: Vector2 = (
		board._cell_center(unused_cell)
		+ Vector2.DOWN * board.get_cell_size() * 0.85
	)
	board._begin_precision_placement()
	board._arm_placement_drag(drag_start, 0)
	board._handle_drag_motion(drag_release, 0)
	_assert(board.preview_is_valid, "dragging shows a valid live route preview")
	_assert(not board.towers_by_cell.has(unused_cell), "drag preview does not commit early")
	board._finish_placement_drag(drag_release)
	_assert(board.towers_by_cell.has(unused_cell), "releasing a valid drag builds immediately")
	_assert(game.economy.credits == 340, "a second tower costs $100")
	board.show_wave_reward({
		"base_reward": 120,
		"interest_reward": 20,
		"limits_increased": false,
	})
	_assert(
		board.status_override == "Wave reward $120 + interest $20",
		"wave rewards remain visible while a tower is selected"
	)
	board._sell_selected_tower()
	await process_frame
	_assert(game.economy.credits == 440, "unused tower returns its full investment")
	board._begin_precision_placement()
	board._arm_placement_drag(drag_start, 0)
	var invalid_release := Vector2(-100.0, -100.0)
	board._handle_drag_motion(invalid_release, 0)
	board._finish_placement_drag(invalid_release)
	_assert(int(board.placement_mode) == 0, "an invalid drag release cancels placement")
	_assert(game.economy.credits == 440, "canceling a drag spends no credits")
	_assert(game.economy.used_power == 0, "canceling a drag consumes no Power")
	var wall_cell: Vector2i = original_route[1]
	board._begin_precision_placement(&"wall")
	board._handle_screen_press(board._cell_center(wall_cell))
	board._handle_screen_press(board._cell_center(wall_cell))
	_assert(board.walls_by_cell.has(wall_cell), "a wall occupies one grid cell")
	_assert(game.economy.used_walls == 1, "placing a wall consumes one Wall")
	_assert(game.economy.used_power == 0, "walls do not consume tower Power")
	_assert(game.economy.credits == 440, "walls do not spend tower money")
	board._remove_selected_building()
	_assert(not board.walls_by_cell.has(wall_cell), "removing a wall reopens its cell")
	_assert(game.economy.used_walls == 0, "removing a wall restores its limit")
	_assert(board.displayed_route == original_route, "removing a wall restores the route")

	game._on_start_wave_requested()
	_assert(game.economy.locked_interest == 22, "wave start locks interest through the game coordinator")
	game.round_controller.schedule_index = game.round_controller.schedule.size()
	game.round_controller.active_enemy_count = 0
	_assert(game.round_controller._try_complete_wave(), "forced integration wave completes")
	_assert(game.economy.credits == 582, "wave clear pays $120 plus the locked $22 interest")
	_assert(
		board.status_override == "Wave reward $120 + interest $22 · POWER +1 · WALL +1",
		"the coordinated wave reward is the final visible notification"
	)

	board._handle_screen_press(board.build_button_rect.get_center())
	board._handle_screen_press(board._cell_center(unused_cell))
	board._handle_screen_press(board._cell_center(unused_cell))
	_assert(game.economy.credits == 482, "building remains available between waves")
	var terminal_tower_count: int = board.towers_by_cell.size()
	board.spawn_enemy({
		"health": 9999,
		"speed_cells_per_second": 0.1,
		"leak_damage": 1,
	})
	_assert(board.active_followers.size() == 1, "terminal cleanup test has an active enemy")
	game.round_controller.phase = &"defeat"
	game._on_combat_state_changed(game.round_controller.get_state())
	_assert(int(board.economy_state["interest"]) == 0, "terminal HUD does not project another interest payment")
	_assert(board.active_followers.is_empty(), "defeat removes remaining active enemies")
	board._sell_selected_tower()
	board._upgrade_selected_tower()
	_assert(not board._begin_precision_placement(), "terminal state refuses new placement")
	_assert(
		board.towers_by_cell.size() == terminal_tower_count,
		"build, upgrade, and sell transactions stop after the run"
	)
	_assert(game.economy.credits == 482, "terminal input cannot change the balance")
	_finish("PROTOTYPE_COMBAT_INTEGRATION_SMOKE_OK")


func _on_enemy_resolved(leaked: bool, _leak_damage: int) -> void:
	_assert(not leaked, "integration enemy is defeated rather than leaked")
	resolved_enemy_count += 1


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype combat integration failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
