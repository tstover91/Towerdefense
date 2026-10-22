extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const RunStateScript = preload("res://siege_prototype/siege_run_state.gd")
const TierCatalogScript = preload("res://siege_prototype/siege_town_hall_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const WallPlanCatalogScript = preload("res://siege_prototype/siege_wall_plan_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var expected_budgets := [10, 15, 20, 22, 28, 40, 44, 52, 67, 85, 80, 88]
	var expected_rewards := [7, 9, 10, 14, 16, 20, 30, 36, 42, 48, 60, 0]
	for round_number in range(1, 13):
		var wave: Array[Dictionary] = TierCatalogScript.build_wave(round_number)
		_assert(TierCatalogScript.get_wave_housing(wave) == expected_budgets[round_number - 1], "Round %d retains its intended housing budget" % round_number)
		_assert(TierCatalogScript.get_reward(round_number) == expected_rewards[round_number - 1], "Round %d pays its intended preparation budget" % round_number)
	_assert(expected_rewards.reduce(func(total: int, reward: int) -> int: return total + reward, 0) == 292, "reward redistribution preserves the full run's 292-Gold total")
	_assert(16 + expected_rewards.slice(0, 11).reduce(func(total: int, reward: int) -> int: return total + reward, 0) == 308, "all 308 usable Gold is available before the final attack")
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
	var expected_defense_caps := [3, 4, 6, 9, 12, 17]
	for fortress_rank in range(1, 7):
		_assert(TierCatalogScript.get_fortress_rank(fortress_rank + 1) == fortress_rank, "internal Town Hall tier maps to the correct visible Fortress Rank")
		_assert(TierCatalogScript.get_defense_capacity(fortress_rank + 1) == expected_defense_caps[fortress_rank - 1], "Fortress Rank %d has the intended shared defense capacity" % fortress_rank)
	_assert(TierCatalogScript.get_wall_allowance(2) == 25, "Walls use a separate allowance from defense capacity")
	var opening_plans: Array[Dictionary] = WallPlanCatalogScript.get_opening_plans()
	_assert(opening_plans.size() == 3, "the opening draft offers three Wall plans")
	for plan in opening_plans:
		_assert_closed_wall_plan(plan)
	var expected_wall_plans := {
		&"sidecar_pocket": [11, 0],
		&"u_funnel": [18, 0],
		&"dogleg_channel": [18, 0],
		&"twin_compartments": [22, 0],
		&"dead_zone_pair": [32, 0],
		&"island_cluster": [48, 0],
		&"ring": [48, 0],
		&"grid": [45, 0],
	}
	for plan_id in expected_wall_plans:
		var plan: Dictionary = WallPlanCatalogScript.get_plan(plan_id)
		var counts: Array = expected_wall_plans[plan_id]
		_assert(not plan.is_empty(), "%s is present in the Wall Plan catalog" % plan_id)
		_assert(Array(plan.get("cells", [])).size() == counts[0], "%s uses the intended number of new Walls" % plan_id)
		_assert(Array(plan.get("required_wall_cells", [])).size() == counts[1], "%s declares the intended shared-wall anchors" % plan_id)
	_assert(WallPlanCatalogScript.get_plan(&"divider").is_empty(), "the excluded Divider is not added")
	var rank_two_plans: Array[Dictionary] = WallPlanCatalogScript.get_plan_choices(2, 30)
	_assert(_plan_ids(rank_two_plans) == [&"sidecar_pocket", &"u_funnel", &"dogleg_channel"], "Rank 2 offers Sidecar, U-Funnel, and Dogleg")
	var rank_six_plans: Array[Dictionary] = WallPlanCatalogScript.get_plan_choices(6, 100)
	_assert(_plan_ids(rank_six_plans) == [&"ring", &"grid", &"island_cluster"], "Rank 6 offers Ring, Grid, and Island structures")
	_assert(TierCatalogScript.get_unlock_rank(&"mortar") == 2 and TierCatalogScript.get_unlock_rank(&"wizard_tower") == 4, "locked defenses expose Fortress Rank unlocks")
	var opening_wave: Array[Dictionary] = TierCatalogScript.build_wave(1)
	_assert(opening_wave.size() == 10, "Round 1 opens with ten attackers")
	for attacker in opening_wave:
		_assert(StringName(attacker.get("kind", &"")) == &"raider" and int(attacker.get("level", 0)) == 1, "every opening attacker is a level-one Barbarian reference")
	_assert(TierCatalogScript.get_town_hall_upgrade_cost(3) == 18 and TierCatalogScript.get_town_hall_upgrade_cost(7) == 80, "Town Hall upgrades expose their independent large-investment costs")
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
	_assert(state.town_hall == 2 and state.get_round_number() == 1, "the run skips TH1 and opens at TH2")
	_assert(state.get_fortress_rank() == 1 and state.get_total_ranks() == 6, "the player-facing run opens at Fortress Rank 1 of 6")
	_assert(state.get_total_rounds() == 12, "the TH2-TH7 run contains twelve rounds")
	for round_index in state.get_total_rounds():
		state.begin_combat(blueprint)
		state.record_victory(TierCatalogScript.get_reward(state.get_round_number()), blueprint)
		if round_index < state.get_total_rounds() - 1:
			_assert(state.get_round_number() == round_index + 2, "victory advances exactly one round")
	_assert(state.completed and state.town_hall == 2, "twelve victories complete the run without purchasing Town Hall levels")
	var upgrade_state: RefCounted = RunStateScript.new()
	_assert(upgrade_state.upgrade_town_hall() and upgrade_state.town_hall == 3 and upgrade_state.get_round_number() == 1, "purchasing Town Hall progress does not advance the enemy round")

	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	board.load_blueprint(blueprint)
	var cannon: Node2D = board.get_structure(&"cannon_1")
	_assert(cannon.level == 2 and is_equal_approx(cannon.max_health, 360.0), "TH2 begins with the carried-over level-two Cannon")
	board.apply_structure_levels({&"command_core": 2, &"cannon": 3})
	_assert(cannon.level == 3 and is_equal_approx(cannon.max_health, 420.0), "Town Hall synchronization applies the exact level-three Cannon stat line")
	_assert(int(board.get_blueprint_snapshot()[1]["level"]) == 3, "globally synchronized levels persist in the base blueprint")
	var sidecar_plan: Dictionary = WallPlanCatalogScript.get_plan(&"sidecar_pocket")
	var empty_blueprint: Array[Dictionary] = []
	board.load_blueprint(empty_blueprint)
	board.set_edit_mode(true)
	board.begin_wall_plan(sidecar_plan.get("cells", []), Vector2i(10, 10))
	_assert(board.is_wall_plan_active() and board.get_pending_wall_plan_count() == 11, "the Sidecar previews only its eleven new Walls")
	_assert(board.pending_wall_plan_valid, "the open-sided Sidecar can be placed without attaching it to existing Walls")
	_assert(board.preview_wall_plan_at_cell(Vector2i(20, 10)), "the player can move the open-sided Sidecar anywhere with clear buildable space")
	board.queue_free()
	await process_frame

	var main_scene: PackedScene = load("res://siege_prototype/siege_main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	var main_board: Node2D = main.get_node("SiegeBoard")
	_assert(main.get_node("HUD/TopBar/PhaseBadge").text.begins_with("TOWN HALL 2"), "the HUD shows independently purchased Town Hall progression")
	_assert(main.get_node("HUD/WallDraftPanel").visible and not main.get_node("HUD/ScoutPanel").visible, "a new run opens with the three-choice Wall Plan draft")
	_assert(main.get_node("HUD/WallDraftPanel/Margin/Stack/Cards/Plan1/Margin/Stack/Name").text.contains("24 WALLS"), "the wide compartment reports its actual Wall use")
	_assert(main.get_node("HUD/WallDraftPanel/Margin/Stack/Cards/Plan2/Margin/Stack/Name").text.contains("20 WALLS"), "the Core box preserves leftover Walls")
	_assert(main.get_node("HUD/WallDraftPanel/Margin/Stack/Cards/Plan3/Margin/Stack/Name").text.contains("16 WALLS"), "the defense pocket preserves the most leftover Walls")
	_assert(not main.get_node("HUD/WallDraftPanel/Margin/Stack").has_node("Subtitle"), "the Wall draft has no explanatory subtitle")
	for card_name in ["Plan1", "Plan2", "Plan3"]:
		_assert(not main.get_node("HUD/WallDraftPanel/Margin/Stack/Cards/%s/Margin/Stack" % card_name).has_node("Description"), "Wall choices do not include description copy")
	main._select_wall_plan(1)
	_assert(main_board.is_wall_plan_active() and main_board.get_pending_wall_plan_count() == 20, "choosing a plan creates one draggable multi-Wall ghost")
	_assert(main.get_node("HUD/WallPlanPlacementPanel").visible and not main.get_node("HUD/WallDraftPanel").visible, "a chosen plan receives rotate, mirror, cancel, and confirm controls")
	var original_plan_size: Vector2i = main_board._wall_plan_size(main_board.pending_wall_plan_cells)
	_assert(main_board.rotate_pending_wall_plan(), "the complete Wall Plan rotates as one preview")
	_assert(main_board._wall_plan_size(main_board.pending_wall_plan_cells) == Vector2i(original_plan_size.y, original_plan_size.x), "rotation turns the full plan footprint")
	_assert(main_board.mirror_pending_wall_plan(), "the complete Wall Plan can be mirrored")
	main._select_wall_plan(1)
	var drafted_wall_cell: Vector2i = main_board.get_pending_wall_plan_cells()[0]
	main._confirm_wall_plan()
	_assert(main.run_state.has_claimed_wall_plan_for_current_rank() and main_board.get_structure_count(&"wall") == 20, "confirming builds the selected plan once and consumes only its actual Walls")
	_assert(not main_board.is_wall_plan_active() and main.get_node("HUD/ScoutPanel").visible, "confirmation closes placement and reveals the next-attack scout")
	var drafted_wall: Node2D = main_board.get_structure_at_cell(drafted_wall_cell, true)
	main_board.select_structure(drafted_wall)
	_assert(drafted_wall.wall_formation_id != &"" and main_board.get_wall_formation_size(drafted_wall.wall_formation_id) == 20, "every drafted Wall remembers its complete original formation")
	var drafted_wall_id: StringName = drafted_wall.structure_id
	var drafted_formation_id: StringName = drafted_wall.wall_formation_id
	_assert(not main.has_node("HUD/SelectionPanel/Margin/Stack/Actions/SelectRowButton") and not main.has_node("HUD/SelectionPanel/Margin/Stack/Actions/RotateRowButton"), "obsolete Wall row controls are removed")
	var formation_origins: Dictionary = {}
	for structure_id in main_board._wall_formation_ids(drafted_wall.wall_formation_id):
		formation_origins[structure_id] = main_board.get_structure(structure_id).grid_cell
	var formation_drag_start: Vector2 = main_board.cell_rect(drafted_wall.grid_cell).get_center()
	_assert(main_board._begin_structure_drag_candidate_at(formation_drag_start), "pressing a selected drafted Wall starts its formation drag")
	main_board._update_structure_drag(formation_drag_start + Vector2.DOWN * main_board.cell_size * 8.0)
	_assert(main_board.structure_drag_drop_valid, "the complete Wall formation previews a clear destination as valid")
	main_board._finish_structure_drag(formation_drag_start + Vector2.DOWN * main_board.cell_size * 8.0)
	for structure_id in formation_origins:
		_assert(main_board.get_structure(structure_id).grid_cell == Vector2i(formation_origins[structure_id]) + Vector2i.DOWN * 8, "dragging one drafted Wall moves every member by the same offset")
	var moved_formation_blueprint: Array[Dictionary] = main_board.capture_current_blueprint()
	main_board.load_blueprint(moved_formation_blueprint)
	_assert(main_board.get_structure(drafted_wall_id).wall_formation_id == drafted_formation_id, "formation identity survives blueprint rebuilds between rounds")
	main_board.clear_selection()
	_assert(main.get_node("HUD/ScoutPanel/Margin/Stack/Roster").text.contains("10× Raider · L1 · GROUND"), "the scout reports enemy count, type, level, and movement trait")
	_assert(main_board.get_defense_count() == 1 and TierCatalogScript.get_defense_capacity(2) == 3, "the opening Cannon uses one of three shared defense slots while the Core is excluded")
	_assert(main_board.get_structure(&"cannon_1").level == 3, "the opening Cannon automatically uses the TH2 stat level")
	main_board.selected_structure_id = &"cannon_1"
	var currency_before_tower_upgrade_attempt: int = main.run_state.currency
	main._upgrade_selected()
	_assert(main.run_state.currency == currency_before_tower_upgrade_attempt, "individual defenses no longer spend Gold on statistical levels")
	_assert(main_board.get_structure(&"cannon_1").level == 3, "an individual upgrade attempt leaves the TH-scaled Cannon unchanged")
	main._toggle_shop()
	_assert(main.get_node("HUD/BuildTray").visible, "the Shop button opens the Clash-style building tray")
	_assert(main.has_node("HUD/BuildTray/Margin/Stack/Cards/AirDefenseCard") and main.has_node("HUD/BuildTray/Margin/Stack/Cards/WizardTowerCard"), "the build tray exposes the TH4 and TH5 defense unlocks")
	_assert(not main.get_node("HUD/BuildTray/Margin/Stack/Cards/MortarCard").visible, "future defense unlocks are not previewed before their Fortress Rank")
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
	_assert(main.run_state.currency == 11, "placing the Cannon deducts its five-Gold prototype price once")
	_assert(main_board.get_structure_at_cell(Vector2i(20, 20), true).level == 3, "a newly built Cannon immediately receives the current Town Hall stat level")
	_assert(main_board.get_structure_count(&"cannon") == 2, "the TH2 base now contains both allowed Cannons")
	main._refresh_shop_cards()
	_assert(not main.get_node("HUD/BuildTray/Margin/Stack/Cards/CannonCard").disabled, "the old per-type Cannon limit no longer blocks a free shared defense slot")
	_assert(main.get_node("HUD/BuildTray/Margin/Stack/Cards/CannonCard").text.contains("DEFENSES 2 / 3"), "tower cards show the shared defense capacity")
	_assert(not main.get_node("HUD/BuildTray/Margin/Stack/Cards/WallCard").visible, "individual new-Wall construction is removed from the normal Shop")
	_assert(main.get_node("HUD/SelectionPanel").visible, "a built defense receives its contextual panel")
	await process_frame
	var selection_panel: Control = main.get_node("HUD/SelectionPanel")
	var selection_center_x := selection_panel.get_global_rect().get_center().x
	var viewport_center_x := get_root().get_visible_rect().size.x * 0.5
	_assert(absf(selection_center_x - viewport_center_x) < 1.0, "the selected-building action menu is centered along the bottom")
	_assert(selection_panel.get_global_rect().end.y <= get_root().get_visible_rect().size.y - 60.0, "the centered action menu stays above the persistent bottom controls")
	var selected_label: Control = main.get_node("HUD/SelectionPanel/Margin/Stack/SelectedLabel")
	var upgrade_button: Control = main.get_node("HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton")
	_assert(selected_label.text.contains("TH2 POWER") and not upgrade_button.visible, "ordinary defenses show Town Hall-derived power without an individual stat-upgrade action")
	var built_cannon: Node2D = main_board.get_structure_at_cell(Vector2i(20, 20), true)
	var cannon_drag_start: Vector2 = main_board.board_origin + (Vector2(built_cannon.grid_cell) + Vector2(built_cannon.footprint) * 0.5) * main_board.cell_size
	_assert(main_board._begin_structure_drag_candidate_at(cannon_drag_start), "pressing an existing defense starts a direct-drag candidate")
	main_board._update_structure_drag(cannon_drag_start + Vector2(0.0, main_board.cell_size * 5.0))
	main_board._finish_structure_drag(cannon_drag_start + Vector2(0.0, main_board.cell_size * 5.0))
	_assert(built_cannon.grid_cell == Vector2i(20, 25), "an existing defense follows a drag instead of using tap-to-move")
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.get_selected_structure() == null and not main.get_node("HUD/SelectionPanel").visible, "tapping empty ground clears the current selection")
	var core: Node2D = main_board.get_structure(&"command_core")
	var core_drag_start: Vector2 = main_board.board_origin + (Vector2(core.grid_cell) + Vector2(core.footprint) * 0.5) * main_board.cell_size
	_assert(not main_board._begin_structure_drag_candidate_at(core_drag_start), "an unselected Town Hall leaves the first drag available for camera panning")
	main_board._handle_edit_tap(core_drag_start)
	_assert(main_board._begin_structure_drag_candidate_at(core_drag_start), "the Town Hall uses the same direct-drag control as other buildings")
	main_board._update_structure_drag(core_drag_start + Vector2(0.0, main_board.cell_size * 6.0))
	main_board._finish_structure_drag(core_drag_start + Vector2(0.0, main_board.cell_size * 6.0))
	_assert(core.grid_cell == Vector2i(36, 26), "the Town Hall can be rearranged by dragging")
	main_board._handle_edit_tap(main_board.cell_rect(Vector2i(12, 12)).get_center())
	_assert(main_board.get_selected_structure() == null, "empty ground also unselects the Town Hall")
	main._select_build_kind(&"archer_tower")
	_assert(is_instance_valid(main_board.build_preview_structure), "another building can enter draggable preview mode")
	main._cancel_pending_purchase()
	_assert(main_board.get_structure_count(&"archer_tower") == 0 and main.run_state.currency == 11, "cancel removes the ghost without building or spending Gold")
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
	main_board.selected_structure_id = &"command_core"
	main.run_state.currency = 18
	main._on_selection_changed(main_board.get_structure(&"command_core"))
	_assert(main.get_node("HUD/SelectionPanel/Margin/Stack/Actions/UpgradeButton").text.contains("UPGRADE TO TH3"), "selecting the Town Hall offers its purchased next level")
	main._upgrade_selected()
	await process_frame
	_assert(main.run_state.town_hall == 3 and main.run_state.currency == 0 and main.run_state.get_round_number() == 1, "buying TH3 spends Gold without advancing the round")
	_assert(main_board.get_structure(&"command_core").level == 3 and main_board.get_structure(&"cannon_1").level == 4, "the Town Hall purchase refreshes the Core and every existing defense")
	_assert(main_board.get_structure(&"cap_wall_0").level == 3, "the Town Hall purchase also refreshes existing Wall health")
	_assert(main.get_node("HUD/BuildTray/Margin/Stack/Cards/MortarCard").visible, "purchasing TH3 immediately unlocks the Mortar")
	_assert(main.get_node("HUD/WallDraftPanel").visible, "purchasing a Town Hall level offers that level's Wall Plan")
	main._close_wall_draft()
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	_assert(main.get_node("HUD/ResultPanel").visible, "a victory opens a clear reward summary")
	_assert(main.get_node("HUD/ResultPanel/Margin/Stack/Details").text.contains("+7 GOLD"), "the reward summary reports earned Gold")
	_assert(main.run_state.get_round_number() == 2 and main.run_state.town_hall == 3, "winning advances the enemy round without changing the purchased Town Hall")
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	_assert(main.run_state.town_hall == 3 and main.run_state.get_round_number() == 3, "multiple victories continue to leave Town Hall progression under player control")
	_assert(main.get_node("HUD/ResultPanel/Margin/Stack/Title").text == "DEFENSE HELD", "victories no longer present automatic Town Hall rank-ups")
	main._close_result_panel()
	_assert(main.get_node("HUD/ScoutPanel").visible and not main.get_node("HUD/WallDraftPanel").visible, "ordinary victories return directly to the next-round scout")
	main.queue_free()
	_finish("SIEGE_RUN_PROGRESSION_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege run progression smoke failed: %s" % description)
	failure_count += 1


func _assert_closed_wall_plan(plan: Dictionary) -> void:
	var cells: Array = plan.get("cells", [])
	var occupied := {}
	var maximum := Vector2i.ZERO
	for value in cells:
		var cell := Vector2i(value)
		occupied[cell] = true
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	var closed := true
	for x in range(maximum.x + 1):
		closed = closed and occupied.has(Vector2i(x, 0)) and occupied.has(Vector2i(x, maximum.y))
	for y in range(maximum.y + 1):
		closed = closed and occupied.has(Vector2i(0, y)) and occupied.has(Vector2i(maximum.x, y))
	_assert(closed, "%s has a continuous perimeter with no open corners" % String(plan.get("name", "Wall plan")))


func _plan_ids(plans: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	for plan in plans:
		result.append(StringName(plan.get("id", &"")))
	return result


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
