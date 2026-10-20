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
	var expected_budgets := [[15, 20], [10, 15], [20, 22], [28, 40], [44, 52], [67, 85], [80, 88]]
	for town_hall in range(1, 8):
		for battle in range(2):
			var wave: Array[Dictionary] = TierCatalogScript.build_wave(town_hall, battle)
			_assert(TierCatalogScript.get_wave_housing(wave) == expected_budgets[town_hall - 1][battle], "TH%d-%s fills its intended housing budget" % [town_hall, "A" if battle == 0 else "B"])
	_assert(TierCatalogScript.get_count_cap(1, &"wall") == 0, "TH1 has no walls")
	_assert(TierCatalogScript.get_count_cap(2, &"wall") == 25, "TH2 supplies Clash's twenty-five Walls")
	_assert(TierCatalogScript.get_count_cap(3, &"wall") == 50, "TH3 supplies Clash's fifty Walls")
	_assert(TierCatalogScript.get_count_cap(4, &"wall") == 75, "TH4 supplies Clash's seventy-five Walls")
	_assert(TierCatalogScript.get_count_cap(5, &"wall") == 100, "TH5 supplies Clash's one hundred Walls")
	_assert(TierCatalogScript.get_count_cap(6, &"wall") == 125, "TH6 supplies Clash's one hundred twenty-five Walls")
	_assert(TierCatalogScript.get_count_cap(7, &"wall") == 175, "TH7 supplies Clash's one hundred seventy-five Walls")
	_assert(TierCatalogScript.get_count_cap(4, &"air_defense") == 1, "TH4 unlocks its first Air Defense")
	_assert(TierCatalogScript.get_count_cap(5, &"wizard_tower") == 1, "TH5 unlocks its first Wizard Tower")
	_assert(TierCatalogScript.get_count_cap(6, &"mortar") == 2 and TierCatalogScript.get_count_cap(6, &"air_defense") == 2, "TH6 unlocks its second Mortar and Air Defense")
	_assert(TierCatalogScript.get_count_cap(7, &"cannon") == 5 and TierCatalogScript.get_count_cap(7, &"archer_tower") == 4, "TH7 uses the Clash defense counts without Tesla")
	_assert(TierCatalogScript.get_count_cap(7, &"air_sweeper") == 0, "Air Sweepers remain excluded")
	_assert(TierCatalogScript.get_count_cap(7, &"hidden_tesla") == 0 and TierCatalogScript.get_count_cap(7, &"barbarian_king") == 0, "Tesla and heroes remain excluded")
	var opening_wave: Array[Dictionary] = TierCatalogScript.build_wave(2, 0)
	_assert(opening_wave.size() == 10, "TH2-A opens with ten attackers")
	for attacker in opening_wave:
		_assert(StringName(attacker.get("kind", &"")) == &"raider" and int(attacker.get("level", 0)) == 1, "every TH2-A attacker is a level-one Barbarian reference")
	_assert(StructureCatalogScript.get_build_cost(&"wall") == 0, "new level-one Walls are free to place like current Clash")
	_assert(TierCatalogScript.get_level_cap(3, &"cannon") == 4, "TH3 Cannons cap at Clash level four")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 1), 400.0), "TH1 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 2), 800.0), "TH2 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 3), 1600.0), "TH3 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 4), 2000.0), "TH4 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 5), 2400.0), "TH5 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 6), 2800.0), "TH6 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 7), 3300.0), "TH7 uses current exact Town Hall HP")
	var armed_core := StructureCatalogScript.get_definition(&"command_core", 2)
	_assert(bool(armed_core.get("can_attack", false)) and not bool(armed_core.get("is_defense", false)), "the Core fires without becoming a Giant-preferred defense")
	_assert(is_equal_approx(float(armed_core.get("attack_damage", 0.0)), 5.6), "the Core gun uses an exact level-one Cannon shot")
	_assert(is_equal_approx(float(armed_core.get("reference_dps", 0.0)), 7.0), "the Core gun uses exact level-one Cannon DPS")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"cannon", 4)["reference_dps"]), 17.0), "level-four Cannon uses exact current DPS")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute", 1)["max_health"]), 400.0), "level-one Brute uses exact current Giant HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"ranger", 2)["attack_range_cells"]), 3.5), "Ranger preserves Archer range")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"bomber", 2)["max_health"]), 180.0), "level-two Bomber uses exact current Balloon HP")
	_assert(StringName(AttackerCatalogScript.get_definition(&"bomber", 2)["movement_type"]) == &"air", "Bombers use air movement")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"mage", 2)["damage"]), 105.0), "level-two Mage uses exact current Wizard damage per hit")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"air_defense", 2)["reference_dps"]), 110.0), "level-two Air Defense uses exact current DPS")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"wizard_tower", 2)["max_health"]), 650.0), "level-two Wizard Tower uses exact current HP")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"cannon", 8)["reference_dps"]), 48.0), "TH7 Cannons use exact level-eight DPS")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"mortar", 5)["attack_damage"]), 45.0), "TH7 Mortars use exact level-five shell damage")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"wall", 7)["max_health"]), 2400.0), "TH7 Walls use current exact level-seven HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"healer", 1)["heal_per_second"]), 36.0), "TH6 Healers use exact level-one healing")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"dragon", 2)["max_health"]), 2100.0), "TH7 Dragons use exact level-two HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"minion", 2)["reference_dps"]), 41.0), "TH7 Minions use exact level-two DPS")
	_assert(bool(AttackerCatalogScript.get_definition(&"hog", 2)["ignores_walls"]), "Hog Riders jump Walls")

	var state: RefCounted = RunStateScript.new()
	var blueprint: Array[Dictionary] = ArenaLayoutScript.new().get_run_initial_blueprint()
	state.blueprint = blueprint.duplicate(true)
	state.begin_combat(blueprint)
	var starting_currency: int = state.currency
	var defeat_blueprint: Array[Dictionary] = state.record_defeat()
	_assert(state.currency == starting_currency and defeat_blueprint == blueprint, "defeat safely restores the precombat base without currency loss")
	_assert(state.town_hall == 2 and state.get_round_number() == 1, "the run skips TH1 and opens at TH2-A")
	_assert(state.get_total_rounds() == 12, "the TH2-TH7 run contains twelve rounds")
	for round_index in state.get_total_rounds():
		state.begin_combat(blueprint)
		state.record_victory(TierCatalogScript.get_reward(state.town_hall, state.battle_index), blueprint)
		if round_index < state.get_total_rounds() - 1:
			_assert(state.get_round_number() == round_index + 2, "victory advances exactly one round")
	_assert(state.completed and state.town_hall == 7 and state.battle_index == 1, "twelve victories complete the TH2-TH7 run")

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
	_assert(main.has_node("HUD/BuildTray/Margin/Stack/Cards/AirDefenseCard") and main.has_node("HUD/BuildTray/Margin/Stack/Cards/WizardTowerCard"), "the build tray exposes the TH4 and TH5 defense unlocks")
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
	await process_frame
	var selection_panel: Control = main.get_node("HUD/SelectionPanel")
	var selection_center_x := selection_panel.get_global_rect().get_center().x
	var viewport_center_x := get_root().get_visible_rect().size.x * 0.5
	_assert(absf(selection_center_x - viewport_center_x) < 1.0, "the selected-building action menu is centered along the bottom")
	_assert(selection_panel.get_global_rect().end.y <= get_root().get_visible_rect().size.y - 60.0, "the centered action menu stays above the persistent bottom controls")
	var selected_label: Control = main.get_node("HUD/SelectionPanel/Margin/Stack/SelectedLabel")
	var upgrade_button: Control = main.get_node("HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton")
	_assert(selected_label.get_global_rect().end.y <= upgrade_button.get_global_rect().position.y, "the structure name sits above the centered action button like Clash")
	var built_cannon: Node2D = main_board.get_structure_at_cell(Vector2i(20, 20), true)
	var cannon_drag_start: Vector2 = main_board.cell_rect(built_cannon.grid_cell).get_center()
	_assert(main_board._begin_structure_drag_candidate_at(cannon_drag_start), "pressing an existing defense starts a direct-drag candidate")
	main_board._update_structure_drag(cannon_drag_start + Vector2(0.0, main_board.cell_size * 5.0))
	main_board._finish_structure_drag(cannon_drag_start + Vector2(0.0, main_board.cell_size * 5.0))
	_assert(built_cannon.grid_cell == Vector2i(20, 25), "an existing defense follows a drag instead of using tap-to-move")
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.get_selected_structure() == null and not main.get_node("HUD/SelectionPanel").visible, "tapping empty ground clears the current selection")
	var core: Node2D = main_board.get_structure(&"command_core")
	var core_drag_start: Vector2 = main_board.cell_rect(core.grid_cell).get_center()
	_assert(not main_board._begin_structure_drag_candidate_at(core_drag_start), "an unselected Town Hall leaves the first drag available for camera panning")
	main_board._handle_edit_tap(core_drag_start)
	_assert(main_board._begin_structure_drag_candidate_at(core_drag_start), "the Town Hall uses the same direct-drag control as other buildings")
	main_board._update_structure_drag(core_drag_start + Vector2(0.0, main_board.cell_size * 6.0))
	main_board._finish_structure_drag(core_drag_start + Vector2(0.0, main_board.cell_size * 6.0))
	_assert(core.grid_cell == Vector2i(36, 26), "the Town Hall can be rearranged by dragging")
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.get_selected_structure() == null, "empty ground also unselects the Town Hall")
	main._select_build_kind(&"wall")
	_assert(main_board.preview_build_at_cell(Vector2i(24, 20)), "the first Wall accepts normal placement")
	_assert(main_board.confirm_pending_build(), "the first Wall uses the standard confirmation action")
	await process_frame
	_assert(main_board.is_wall_chain_active(), "placing the first Wall activates the row-extension arrows")
	var extensions: Array[Vector2i] = main_board.get_wall_extension_cells()
	_assert(extensions.size() >= 3 and main_board.try_select_wall_extension(extensions[1]), "tapping any open arrow previews the next Wall")
	main._confirm_build()
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
	_assert(main_board.try_select_wall_extension(perpendicular_choice), "a wall chain can preview a turn after its first direction")
	main._confirm_build()
	await process_frame
	_assert(main_board.get_structure_count(&"wall") == 3, "wall-row placement keeps building consecutive segments")
	_assert(main.run_state.currency == 7, "free Wall-row segments do not spend Gold")
	main._cancel_pending_purchase()
	var placed_wall: Node = main_board.get_structure_at_cell(Vector2i(24, 20), true)
	main_board.select_structure(placed_wall)
	await process_frame
	_assert(not main_board.is_wall_chain_active(), "selecting a placed Wall does not silently enter purchase mode")
	var selected_directions: Array[Vector2i] = main_board.get_wall_extension_cells()
	_assert(not selected_directions.is_empty(), "selecting an existing Wall exposes every open adjacent direction")
	var wall_drag_start: Vector2 = main_board.cell_rect(placed_wall.grid_cell).get_center()
	_assert(main_board._begin_structure_drag_candidate_at(wall_drag_start), "grabbing a selected Wall exits extension mode and starts dragging")
	main_board._update_structure_drag(wall_drag_start + Vector2.LEFT * main_board.cell_size)
	main_board._finish_structure_drag(wall_drag_start + Vector2.LEFT * main_board.cell_size)
	_assert(placed_wall.grid_cell == Vector2i(23, 20), "an existing Wall can be rearranged by dragging")
	await process_frame
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.get_selected_structure() == null and not main_board.is_wall_chain_active(), "tapping away from Wall arrows exits extension mode and unselects the Wall")
	main._select_build_kind(&"archer_tower")
	_assert(is_instance_valid(main_board.build_preview_structure), "another building can enter draggable preview mode")
	main._cancel_pending_purchase()
	_assert(main_board.get_structure_count(&"archer_tower") == 0 and main.run_state.currency == 7, "cancel removes the ghost without building or spending Gold")
	var capped_blueprint: Array[Dictionary] = []
	for entry in main_board.capture_current_blueprint():
		if StringName(entry.get("kind", &"")) != &"wall":
			capped_blueprint.append(entry)
	for wall_index in 25:
		capped_blueprint.append({
			"id": StringName("cap_wall_%d" % wall_index),
			"kind": &"wall",
			"level": 1,
			"cell": Vector2i(3 + wall_index, 5),
			"footprint": Vector2i.ONE,
		})
	main_board.load_blueprint(capped_blueprint)
	main.run_state.blueprint = capped_blueprint.duplicate(true)
	main.pending_purchase_kind = &"wall"
	main.pending_purchase_cost = 0
	var final_wall: Node2D = main_board.get_structure(&"cap_wall_24")
	main_board.selected_structure_id = final_wall.structure_id
	main._on_structure_added(final_wall)
	_assert(main_board.get_selected_structure() == null and not main_board.is_wall_chain_active(), "building the final available Wall leaves no stale selection or extension mode")
	_assert(not main.get_node("HUD/SelectionPanel").visible, "the final Wall does not fall back to the old tap-to-move panel state")
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
