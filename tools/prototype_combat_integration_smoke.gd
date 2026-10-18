extends SceneTree

const PrototypeScene = preload("res://prototype/prototype_main.tscn")
const TowerScript = preload("res://prototype/prototype_tower.gd")

var resolved_enemy_count := 0
var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	ProjectSettings.set_setting("prototype/map_seed_override", 1)
	get_root().size = Vector2i(1152, 648)
	var game: Node = PrototypeScene.instantiate()
	get_root().add_child(game)
	current_scene = game
	await process_frame
	var board: Node2D = game.get_node("GridBoard")
	board.enemy_resolved.connect(_on_enemy_resolved)
	var button_center: Vector2 = board.gunslinger_button_rect.get_center()
	var android_touch := InputEventScreenTouch.new()
	android_touch.index = 0
	android_touch.position = button_center
	android_touch.pressed = true
	board._input(android_touch)
	android_touch = InputEventScreenTouch.new()
	android_touch.index = 0
	android_touch.position = button_center
	android_touch.pressed = false
	board._input(android_touch)
	_assert(
		int(board.placement_mode) == 1,
		"the permanent tower card begins precision placement"
	)
	_assert(board._get_build_kind_at(button_center).is_empty(), "tower cards are unavailable while placement is armed")
	board._handle_screen_press(board.header_cancel_button_rect.get_center())
	_assert(
		int(board.placement_mode) == 0,
		"the placement cancel restores the tower cards"
	)
	_assert(board._get_build_kind_at(button_center) == &"gunslinger", "tower cards return after canceling placement")
	board._begin_precision_placement()
	board._arm_placement_drag(button_center, 0)
	board._handle_drag_motion(button_center + Vector2(80.0, 0.0), 0)
	_assert(
		int(board.placement_mode) == 1,
		"movement across the floating build drawer does not turn a tap into a drag"
	)
	board._cancel_placement()
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
	board._handle_placement_button(&"gunslinger")
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
	_assert(board._get_build_kind_at(button_center) == &"gunslinger", "tower cards return immediately after precision building")
	_assert(not is_instance_valid(board.selected_tower), "repeat building does not open the tower selection rail")
	_assert(board.displayed_route != original_route, "blocking a route cell changes the displayed path")
	_assert(game.economy.credits == 350, "gun placement costs $150")
	_assert(game.economy.used_power == 1, "tower placement consumes Power")
	var tower: Node2D = board.towers_by_cell[tower_cell]
	_assert(tower.level == 1, "new tower starts at level one")
	board._cancel_placement()
	board._select_tower(tower)
	board._update_selection_panel_layout()
	_assert(is_equal_approx(board.sell_button_rect.size.x, board.upgrade_button_rect.size.x), "the tower popup uses full-width actions without a close button")
	board._handle_screen_press(board.safe_view_rect.end - Vector2(4.0, 4.0))
	_assert(not is_instance_valid(board.selected_tower), "tapping outside the popup deselects the tower")
	board._select_tower(tower)
	board._upgrade_selected_tower()
	_assert(tower.level == 2, "selected tower upgrades")
	_assert(game.economy.credits == 300, "the gun's modest level-two upgrade costs $50")

	board.spawn_enemy({
		"health": 8,
		"speed_cells_per_second": 0.55,
		"leak_damage": 1,
	})
	var preview_test_enemy: Node2D = board.active_followers[0]
	var route_before_preview: Array[Vector2i] = preview_test_enemy.route.duplicate()
	var blocks_before_preview: Dictionary = board.router.dynamic_blocks.duplicate()
	board._begin_precision_placement()
	board._update_preview(Vector2i(1, 5), true)
	_assert(preview_test_enemy.route == route_before_preview, "live placement preview cannot reroute an active enemy")
	_assert(board.router.dynamic_blocks == blocks_before_preview, "live placement preview cannot commit a temporary blocker")
	board._cancel_placement()
	board._select_tower(tower)
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
	var drag_start: Vector2 = board.gunslinger_button_rect.get_center()
	var drag_release: Vector2 = (
		board._cell_center(unused_cell)
		+ Vector2(0.55, 1.25) * board.get_cell_size()
	)
	board._begin_precision_placement()
	board._arm_placement_drag(drag_start, 0)
	board._handle_drag_motion(drag_release, 0)
	_assert(board.preview_is_valid, "dragging shows a valid live route preview")
	_assert(board.hovered_cell == unused_cell, "drag preview offsets above and left of the finger onto the intended cell")
	_assert(not board.towers_by_cell.has(unused_cell), "drag preview does not commit early")
	board._finish_placement_drag(drag_release)
	_assert(board.towers_by_cell.has(unused_cell), "releasing a valid drag builds immediately")
	_assert(int(board.placement_mode) == 0, "drag placement ends after a confirmed build")
	_assert(board._get_build_kind_at(drag_start) == &"gunslinger", "tower cards remain available after drag placement")
	_assert(game.economy.credits == 290, "a second gun costs $150")
	board.show_wave_reward({
		"base_reward": 180,
		"interest_reward": 20,
		"limits_increased": false,
	})
	_assert(
		board.status_override == "Wave reward $180 + interest $20",
		"wave rewards remain visible while a tower is selected"
	)
	board._cancel_placement()
	board._select_tower(board.towers_by_cell[unused_cell])
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
	_assert(int(board.placement_mode) == 0, "wall placement ends after the wall is confirmed")
	_assert(board._get_build_kind_at(board.wall_button_rect.get_center()) == &"wall", "the wall card returns immediately after wall placement")
	board._cancel_placement()
	board._select_wall(wall_cell)
	board._remove_selected_building()
	_assert(not board.walls_by_cell.has(wall_cell), "removing a wall reopens its cell")
	_assert(game.economy.used_walls == 0, "removing a wall restores its limit")
	_assert(board.displayed_route == original_route, "removing a wall restores the route")

	game._on_start_wave_requested()
	_assert(game.economy.locked_interest == 13, "wave start locks 3% interest through the game coordinator")
	board.spawn_enemy({
		"health": 2,
		"speed_cells_per_second": 0.1,
		"leak_damage": 1,
	})
	var tracked_enemy: Node2D = board.active_followers[-1]
	var tracked_gunslinger: Node2D = TowerScript.new()
	board.add_child(tracked_gunslinger)
	tracked_gunslinger.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_GUNSLINGER)
	tracked_gunslinger.position = tracked_enemy.position
	tracked_gunslinger.damage_dealt.connect(board._on_tower_damage_dealt)
	tracked_gunslinger._fire_at(tracked_enemy)
	await process_frame
	_assert(not is_instance_valid(tracked_enemy), "a lethal beam hit resolves its enemy immediately")
	tracked_gunslinger.queue_free()
	board.spawn_enemy({
		"health": 9999,
		"speed_cells_per_second": 1.0,
		"leak_damage": 1,
	})
	var pause_test_enemy: Node2D = board.active_followers[-1]
	await process_frame
	var paused_position := pause_test_enemy.position
	var paused_wave_elapsed: float = game.round_controller.wave_elapsed
	_assert(board._begin_precision_placement(), "placement can begin during an active wave")
	_assert(paused, "active-wave placement pauses the SceneTree")
	for paused_frame in 5:
		await process_frame
	_assert(pause_test_enemy.position.is_equal_approx(paused_position), "enemy movement freezes during placement")
	_assert(is_equal_approx(game.round_controller.wave_elapsed, paused_wave_elapsed), "spawn timing freezes during placement")
	board._cancel_placement()
	_assert(not paused, "canceling placement resumes combat")
	for resumed_frame in 3:
		await process_frame
	_assert(not pause_test_enemy.position.is_equal_approx(paused_position), "enemy movement resumes after placement")
	pause_test_enemy.active = false
	pause_test_enemy.finished = true
	board.active_followers.erase(pause_test_enemy)
	pause_test_enemy.queue_free()
	game.round_controller.schedule_index = game.round_controller.schedule.size()
	game.round_controller.active_enemy_count = 0
	_assert(game.round_controller._try_complete_wave(), "forced integration wave completes")
	await process_frame
	_assert(game.economy.credits == 603, "wave clear pays $150 plus the locked $13 interest")
	_assert(
		board.status_override == "Wave reward $150 + interest $13",
		"the coordinated wave reward is the final visible notification"
	)

	board._handle_placement_button(&"gunslinger")
	board._handle_screen_press(board._cell_center(unused_cell))
	board._handle_screen_press(board._cell_center(unused_cell))
	_assert(game.economy.credits == 453, "building remains available between waves")
	_assert(game.run_stats.get_rows().size() == 1, "wave completion records one telemetry row")
	var stats_row: Dictionary = game.run_stats.get_rows()[0]
	_assert(int(stats_row["planned_threat"]) == 8, "telemetry records the director's wave budget")
	_assert(int(stats_row["spent_threat"]) == 8, "telemetry records the threat committed to formations")
	_assert(not String(stats_row["wave_style"]).is_empty(), "telemetry records the wave formation style")
	_assert(not String(stats_row["run_enemy_roster"]).is_empty(), "telemetry records the run's limited enemy roster")
	_assert(int(stats_row["planned_parent_count"]) == 8, "telemetry records planned parent enemies")
	_assert(int(stats_row["expected_child_count"]) == 0, "opening telemetry expects no spawned children")
	_assert(int(stats_row["planned_total_count"]) == 8, "telemetry records expected total population")
	_assert(
		int(stats_row["spawned_director_threat"]) <= int(stats_row["spent_threat"]),
		"spawn telemetry cannot exceed the planned wave threat"
	)
	_assert(int(stats_row["spawned_health"]) == 10001, "telemetry records effective spawned health")
	_assert(int(stats_row["defeated_enemies"]) == 1, "telemetry includes an enemy killed on the final hit")
	_assert(int(stats_row["gunslinger_damage"]) == 2, "telemetry includes the killing Gunslinger damage")
	_assert(int(stats_row["gunslinger_l1_damage"]) == 2, "telemetry attributes damage to tower level")
	_assert(int(stats_row["tower_count"]) == 0, "telemetry snapshots the end-of-wave tower count")
	var export_result: Dictionary = game.run_stats.export_reports_to_project()
	game.board.show_stats_export_result(export_result)
	if not bool(export_result.get("success", false)):
		push_error("Stats export failed: %s" % String(export_result.get("message", "unknown error")))
	_assert(
		FileAccess.file_exists(ProjectSettings.globalize_path("res://balance_reports/prototype_run_stats.csv"))
		and FileAccess.file_exists(ProjectSettings.globalize_path("res://balance_reports/prototype_run_stats.json"))
		and FileAccess.file_exists(ProjectSettings.globalize_path("res://balance_reports/.gdignore")),
		"the stats control exports both reports into the project folder"
	)
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
	_assert(game.economy.credits == 453, "terminal input cannot change the balance")
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
