extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const CombatScript = preload("res://siege_prototype/siege_combat_controller.gd")
const RouterScript = preload("res://siege_prototype/siege_grid_router.gd")
const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"raider")["move_speed_cells"]), 2.2), "Raiders use exact Barbarian movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute")["move_speed_cells"]), 1.5), "Brutes use exact Giant movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"sapper")["move_speed_cells"]), 3.0), "Sappers use exact Wall Breaker movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"raider")["max_health"]), 65.0), "Raiders use exact level-3 Barbarian HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute")["max_health"]), 600.0), "Brutes use exact level-3 Giant HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"sapper")["wall_damage"]), 1000.0), "Sappers use exact level-3 Wall Breaker contact damage")
	var route: Array[Vector2i] = RouterScript.find_path(
		Vector2i(0, 1),
		[Vector2i(3, 1)],
		[Vector2i(1, 1)],
		Vector2i(4, 3)
	)
	_assert(not route.is_empty(), "the grid router finds a deterministic route around an obstacle")
	_assert(not route.has(Vector2i(1, 1)), "the route never enters blocked cells")

	var harness := Node.new()
	get_root().add_child(harness)
	var board: Node2D = BoardScript.new()
	board.name = "SiegeBoard"
	harness.add_child(board)
	var combat: Node2D = CombatScript.new()
	combat.name = "SiegeCombat"
	harness.add_child(combat)
	await process_frame
	combat.set_physics_process(false)

	combat.start_demo_wave()
	combat.simulate_step(0.05)
	_assert(combat.attackers.size() == 1, "the deterministic wave begins with one Brute tank")
	var first_attacker: Node2D = combat.attackers[0]
	_assert(first_attacker.intended_target_id != &"", "the Brute first chooses a non-wall objective")
	var first_active_target: Node2D = board.get_structure(first_attacker.active_target_id)
	_assert(first_active_target != null and first_active_target.kind == &"wall", "a sealed route redirects the Brute to a blocking wall")
	var first_intended_target: Node2D = board.get_structure(first_attacker.intended_target_id)
	_assert(first_intended_target != null and first_intended_target.kind == &"cannon", "Brutes use Clash's defense preference")

	var sapper: Node2D = combat._spawn_attacker(&"sapper", 7)
	sapper.simulate(0.01)
	var sapper_target: Node2D = board.get_structure(sapper.active_target_id)
	_assert(sapper_target != null and sapper_target.kind == &"wall", "Sappers route to the wall protecting their intended building")
	combat._on_attacker_died(sapper)

	var initial_wall_count := _living_kind_count(board, &"wall")
	var saw_attacker_damage := false
	for _step in 600:
		for attacker in combat.attackers:
			if attacker.health < attacker.max_health:
				saw_attacker_damage = true
		combat.simulate_step(0.1)
		if not combat.active:
			break
	_assert(saw_attacker_damage, "Cannons damage attackers during the live simulation")
	_assert(_living_kind_count(board, &"wall") < initial_wall_count, "the wave breaches at least one wall segment")
	var core: Node2D = board.get_structure(&"command_core")
	_assert(board.get_remaining_integrity() < 6 or core.health < core.max_health, "surviving attackers reach and damage a real objective")
	_assert(combat.result == &"attackers" or combat.result == &"defenders", "the deterministic wave reaches a declared result")
	_assert(combat.elapsed_time <= 45.1, "the test round respects the 45-second hard limit")

	combat.reset_fortress()
	_assert(board.get_remaining_integrity() == 6, "rebuild restores the fortress after combat")
	_assert(_living_kind_count(board, &"wall") == 12, "rebuild restores every wall segment")

	harness.queue_free()
	_finish("SIEGE_COMBAT_PHASE4_SMOKE_OK")


func _living_kind_count(board: Node2D, kind: StringName) -> int:
	var count := 0
	for structure in board.structures:
		if structure.kind == kind and not structure.destroyed:
			count += 1
	return count


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege combat Phase 4 smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
