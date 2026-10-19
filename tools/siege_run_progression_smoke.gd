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
	var expected_budgets := [[15, 20], [22, 30], [52, 70]]
	for town_hall in range(1, 4):
		for battle in range(2):
			var wave: Array[Dictionary] = TierCatalogScript.build_wave(town_hall, battle)
			_assert(TierCatalogScript.get_wave_housing(wave) == expected_budgets[town_hall - 1][battle], "TH%d-%s fills its intended housing budget" % [town_hall, "A" if battle == 0 else "B"])
	_assert(TierCatalogScript.get_count_cap(1, &"wall") == 0, "TH1 has no walls")
	_assert(TierCatalogScript.get_count_cap(2, &"wall") == 12, "the TH2 run condenses walls to twelve")
	_assert(TierCatalogScript.get_count_cap(3, &"wall") == 20, "the TH3 run condenses walls to twenty")
	_assert(TierCatalogScript.get_level_cap(3, &"cannon") == 4, "TH3 Cannons cap at Clash level four")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 1), 400.0), "TH1 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 2), 800.0), "TH2 uses current exact Town Hall HP")
	_assert(is_equal_approx(StructureCatalogScript.get_max_health(&"command_core", 3), 1600.0), "TH3 uses current exact Town Hall HP")
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
	for round_index in 6:
		state.begin_combat(blueprint)
		state.record_victory(TierCatalogScript.get_reward(state.town_hall, state.battle_index), blueprint)
		if round_index < 5:
			_assert(state.get_round_number() == round_index + 2, "victory advances exactly one round")
	_assert(state.completed and state.town_hall == 3 and state.battle_index == 1, "six victories complete the TH1-TH3 run")

	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	board.load_blueprint(blueprint)
	var cannon: Node2D = board.get_structure(&"cannon_1")
	_assert(cannon.level == 1 and is_equal_approx(cannon.max_health, 300.0), "run blueprint creates a level-one Cannon")
	_assert(board.upgrade_structure(&"cannon_1", 2), "board accepts an explicit structure upgrade")
	_assert(cannon.level == 2 and is_equal_approx(cannon.max_health, 360.0), "upgrading applies the exact level-two stat line")
	_assert(int(board.get_blueprint_snapshot()[1]["level"]) == 2, "upgraded level persists in the base blueprint")
	board.queue_free()
	await process_frame

	var main_scene: PackedScene = load("res://siege_prototype/siege_main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	var main_board: Node2D = main.get_node("SiegeBoard")
	main_board.selected_structure_id = &"cannon_1"
	main._upgrade_selected()
	_assert(main.run_state.currency == 1, "the HUD upgrade action spends condensed currency")
	_assert(main_board.get_structure(&"cannon_1").level == 2, "the HUD upgrade action applies the next level")
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	main.run_state.begin_combat(main_board.capture_current_blueprint())
	main._on_wave_finished(&"defenders")
	_assert(main.run_state.town_hall == 2 and main.run_state.battle_index == 0, "two HUD victories advance to TH2-A")
	main._cycle_build()
	_assert(main.pending_purchase_kind == &"cannon", "TH2 build cycling offers the newly unlocked second Cannon")
	_assert(main_board.try_add_structure(&"cannon", Vector2i(20, 20), 1), "the offered Cannon can be placed on an empty footprint")
	_assert(main.run_state.currency == 8, "placing the Cannon deducts its five-bolt build price once")
	_assert(main_board.get_structure_count(&"cannon") == 2, "the TH2 base now contains both allowed Cannons (found %d)" % main_board.get_structure_count(&"cannon"))
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
