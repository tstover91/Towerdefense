extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const RunStateScript = preload("res://siege_prototype/siege_run_state.gd")
const TierCatalogScript = preload("res://siege_prototype/siege_town_hall_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var expected_budgets := [[15, 20], [10, 15], [20, 22]]
	for town_hall in range(1, 4):
		for battle in range(2):
			var wave: Array[Dictionary] = TierCatalogScript.build_wave(town_hall, battle)
			_assert(TierCatalogScript.get_wave_housing(wave) == expected_budgets[town_hall - 1][battle], "TH%d-%s fills its intended housing budget" % [town_hall, "A" if battle == 0 else "B"])
	_assert(TierCatalogScript.get_count_cap(1, &"wall") == 0, "TH1 has no walls")
	_assert(TierCatalogScript.get_count_cap(2, &"wall") == 25, "TH2 supplies Clash's twenty-five Walls")
	_assert(TierCatalogScript.get_count_cap(3, &"wall") == 50, "TH3 supplies Clash's fifty Walls")
	var opening_wave: Array[Dictionary] = TierCatalogScript.build_wave(2, 0)
	_assert(opening_wave.size() == 10, "TH2-A opens with ten attackers")
	for attacker in opening_wave:
		_assert(StringName(attacker.get("kind", &"")) == &"raider" and int(attacker.get("level", 0)) == 1, "every TH2-A attacker is a level-one Barbarian reference")
	_assert(StructureCatalogScript.get_build_cost(&"wall") == 0, "new level-one Walls are free to place like current Clash")
	_assert(TierCatalogScript.get_level_cap(3, &"cannon") == 4, "TH3 Cannons cap at Clash level four")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 1), 400.0), "TH1 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 2), 800.0), "TH2 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 3), 1600.0), "TH3 uses current exact Town Hall HP")
	var armed_core := StructureCatalogScript.get_definition(&"command_core", 2)
	_assert(bool(armed_core.get("can_attack", false)) and not bool(armed_core.get("is_defense", false)), "the Core fires without becoming a Giant-preferred defense")
	_assert(is_equal_approx(float(armed_core.get("attack_damage", 0.0)), 5.6), "the Core gun uses an exact level-one Cannon shot")
	_assert(is_equal_approx(float(armed_core.get("reference_dps", 0.0)), 7.0), "the Core gun uses exact level-one Cannon DPS")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"cannon", 4)["reference_dps"]), 17.0), "level-four Cannon uses exact current DPS")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute", 1)["max_health"]), 400.0), "level-one Brute uses exact current Giant HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"ranger", 2)["attack_range_cells"]), 3.5), "Ranger preserves Archer range")

	var state: RefCounted = RunStateScript.new()
	var blueprint: Array[Dictionary] = ArenaLayoutScript.new().get_run_initial_blueprint()
	state.blueprint = blueprint.duplicate(true)
	state.begin_combat(blueprint)
	var starting_currency: int = state.currency
	var defeat_blueprint: Array[Dictionary] = state.record_defeat()
	_assert(state.currency == starting_currency and defeat_blueprint == blueprint, "defeat safely restores the precombat base without currency loss")
	_assert(state.town_hall == 2 and state.get_round_number() == 1, "the run skips TH1 and opens at TH2-A")
	for round_index in 4:
		state.begin_combat(blueprint)
		state.record_victory(TierCatalogScript.get_reward(state.town_hall, state.battle_index), blueprint)
		if round_index < 3:
			_assert(state.get_round_number() == round_index + 2, "victory advances exactly one round")
	_assert(state.completed and state.town_hall == 3 and state.battle_index == 1, "four victories complete the TH2-TH3 run")

	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	board.load_blueprint(blueprint)
	var cannon: Node2D = board.get_structure(&"cannon_1")
	_assert(cannon.level == 2 and is_equal_approx(cannon.max_health, 360.0), "TH2 begins with the carried-over level-two Cannon")
	_assert(board.upgrade_structure(&"cannon_1", 3), "board accepts an explicit structure upgrade")
	_assert(cannon.level == 3 and is_equal_approx(cannon.max_health, 420.0), "upgrading applies the exact level-three stat line")
	_assert(int(board.get_blueprint_snapshot()[1]["level"]) == 3, "upgraded level persists in the base blueprint")
	board.queue_free()
	await process_frame

	var main_scene: PackedScene = load("res://siege_prototype/siege_main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	var main_board: Node2D = main.get_node("SiegeBoard")
	main_board.selected_structure_id = &"cannon_1"
	main._upgrade_selected()
	_assert(main.run_state.currency == 12, "the HUD upgrade action spends condensed Gold")
	_assert(main_board.get_structure(&"cannon_1").level == 3, "the HUD upgrade action applies the TH2 level cap")
	main._toggle_shop()
	_assert(main.get_node("HUD/BuildTray").visible, "the Shop button opens the Clash-style building tray")
	main._select_build_kind(&"cannon")
	_assert(main.pending_purchase_kind == &"cannon", "the Cannon card starts an explicit Cannon purchase")
	_assert(main.get_node("HUD/PlacementPanel").visible and not main.get_node("HUD/BuildTray").visible, "choosing a card opens confirm/cancel placement controls")
	_assert(not main.has_node("HUD/PlacementPanel/Margin/Actions/PlacementLabel"), "placement controls contain no popup instruction text")
	_assert(main.get_node("HUD/PlacementPanel/Margin/Actions/CancelButton").visible and main.get_node("HUD/PlacementPanel/Margin/Actions/ConfirmButton").visible, "normal placement shows only cancel and confirm")
	_assert(is_instance_valid(main_board.build_preview_structure), "choosing a card creates a visible draggable building ghost")
	var opening_preview_cell: Vector2i = main_board.pending_build_cell
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.pending_build_cell == opening_preview_cell, "tapping elsewhere does not relocate or place the building ghost")
	var drag_target: Vector2 = main_board.cell_rect(Vector2i(21, 21)).get_center()
	_assert(main_board.preview_build_at_screen_position(drag_target), "dragging the ghost snaps it to a valid grid footprint")
	_assert(main_board.pending_build_cell == Vector2i(20, 20) and main_board.build_preview_structure.grid_cell == Vector2i(20, 20), "the ghost follows the dragged footprint before confirmation")
	_assert(main_board.confirm_pending_build(), "the offered Cannon can be confirmed on an empty footprint")
	_assert(not is_instance_valid(main_board.build_preview_structure), "confirmation removes the temporary building ghost")
	_assert(main.run_state.currency == 7, "placing the Cannon deducts its five-Gold prototype price once")
	_assert(main_board.get_structure_count(&"cannon") == 2, "the TH2 base now contains both allowed Cannons")
	_assert(main.get_node("HUD/SelectionPanel").visible, "a built defense receives its contextual Upgrade panel")
	main._select_build_kind(&"wall")
	_assert(main_board.preview_build_at_cell(Vector2i(24, 20)), "the first Wall accepts normal placement")
	_assert(main_board.confirm_pending_build(), "the first Wall uses the standard confirmation action")
	await process_frame
	_assert(main_board.is_wall_chain_active(), "placing the first Wall activates the row-extension arrows")
	var extensions: Array[Vector2i] = main_board.get_wall_extension_cells()
	_assert(extensions.size() >= 3 and main_board.try_select_wall_extension(extensions[1]), "tapping any open arrow immediately adds the next Wall")
	await process_frame
	var chain_focus: Vector2i = main_board.get_wall_chain_focus_cell()
	var turn_choices: Array[Vector2i] = main_board.get_wall_extension_cells()
	var perpendicular_choice: Vector2i = Vector2i(-1, -1)
	var has_straight_choice := false
	for choice in turn_choices:
		if choice.y == chain_focus.y:
			has_straight_choice = true
		elif choice.x == chain_focus.x:
			perpendicular_choice = choice
	_assert(has_straight_choice and perpendicular_choice.x >= 0, "after two pieces, both straight and turning directions remain available when open")
	_assert(main_board.try_select_wall_extension(perpendicular_choice), "a wall chain can turn after its first direction")
	await process_frame
	_assert(main_board.get_structure_count(&"wall") == 3, "wall-row placement keeps building consecutive segments")
	_assert(main.run_state.currency == 7, "free Wall-row segments do not spend Gold")
	main._cancel_pending_purchase()
	var placed_wall: Node = main_board.get_structure_at_cell(Vector2i(24, 20), true)
	main._on_selection_changed(placed_wall)
	await process_frame
	_assert(main_board.is_wall_chain_active(), "selecting a placed Wall restores its extension arrows")
	var selected_directions: Array[Vector2i] = main_board.get_wall_extension_cells()
	_assert(not selected_directions.is_empty(), "reselecting an existing Wall exposes every open adjacent direction")
	main._cancel_pending_purchase()
	main._select_build_kind(&"archer_tower")
	_assert(is_instance_valid(main_board.build_preview_structure), "another building can enter draggable preview mode")
	main._cancel_pending_purchase()
	_assert(main_board.get_structure_count(&"archer_tower") == 0 and main.run_state.currency == 7, "cancel removes the ghost without building or spending Gold")
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	_assert(main.run_state.town_hall == 3 and main.run_state.battle_index == 0, "two HUD victories advance from TH2 to TH3-A")
	main.queue_free()
	_finish("SIEGE_RUN_PROGRESSION_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege run progression smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
