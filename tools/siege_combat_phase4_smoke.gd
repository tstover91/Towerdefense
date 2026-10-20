extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const CombatScript = preload("res://siege_prototype/siege_combat_controller.gd")
const RouterScript = preload("res://siege_prototype/siege_grid_router.gd")
const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"raider")["move_speed_cells"]), 2.25), "Raiders use current exact Barbarian movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute")["move_speed_cells"]), 1.5), "Brutes use exact Giant movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"sapper")["move_speed_cells"]), 3.0), "Sappers use exact Wall Breaker movement speed")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"raider")["max_health"]), 65.0), "Raiders use exact level-3 Barbarian HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"brute")["max_health"]), 600.0), "Brutes use exact level-3 Giant HP")
	_assert(is_equal_approx(float(AttackerCatalogScript.get_definition(&"sapper")["wall_damage"]), 1000.0), "Sappers use exact level-3 Wall Breaker contact damage")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"archer_tower")["attack_damage"]), 21.0), "Archer Towers deal exact half-second shot damage")
	_assert(is_equal_approx(float(StructureCatalogScript.get_definition(&"wizard_tower")["attack_damage"]), 20.8), "Wizard Towers deal exact 1.3-second splash damage")
	_assert(StringName(StructureCatalogScript.get_definition(&"air_defense")["target_type"]) == &"air", "Air Defenses remain air-only")
	var route: Array[Vector2i] = RouterScript.find_path(
		Vector2i(0, 1),
		[Vector2i(3, 1)],
		[Vector2i(1, 1)],
		Vector2i(4, 3)
	)
	_assert(not route.is_empty(), "the grid router finds a deterministic route around an obstacle")
	_assert(not route.has(Vector2i(1, 1)), "the route never enters blocked cells")
	_assert(route.has(Vector2i(1, 0)), "the grid router uses diagonal movement")
	var corner_route: Array[Vector2i] = RouterScript.find_path(
		Vector2i(0, 0),
		[Vector2i(1, 1)],
		[Vector2i(1, 0), Vector2i(0, 1)],
		Vector2i(3, 3)
	)
	_assert(corner_route.is_empty(), "diagonal movement cannot cut through blocked corners")
	var expensive_wall_route: Dictionary = RouterScript.find_weighted_path(
		Vector2i(0, 1),
		[Vector2i(4, 1)],
		[],
		{Vector2i(2, 1): 20.0},
		Vector2i(5, 3)
	)
	_assert(
		Array(expensive_wall_route.get("crossed_walls", [])).is_empty(),
		"route cost makes troops walk around a wall when that is faster than breaking it"
	)
	var cheap_wall_route: Dictionary = RouterScript.find_weighted_path(
		Vector2i(0, 1),
		[Vector2i(4, 1)],
		[],
		{Vector2i(2, 1): 0.1},
		Vector2i(5, 3)
	)
	_assert(
		Array(cheap_wall_route.get("crossed_walls", [])).has(Vector2i(2, 1)),
		"route cost selects a breach when breaking the wall is faster than the detour"
	)
	var wall_goal_route: Dictionary = RouterScript.find_weighted_path(
		Vector2i(0, 1),
		[Vector2i(2, 1)],
		[],
		{Vector2i(2, 1): 0.1},
		Vector2i(3, 3)
	)
	_assert(Array(wall_goal_route.get("crossed_walls", [])).has(Vector2i(2, 1)), "a tightly enclosed melee target can route to and breach a Wall attack position")

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
	_assert(first_intended_target != null and bool(first_intended_target.definition.get("is_defense", false)), "Brutes use Clash's defense preference")
	var committed_target_id: StringName = first_attacker.intended_target_id
	first_attacker.mark_plan_dirty()
	first_attacker.simulate(0.01)
	_assert(first_attacker.intended_target_id == committed_target_id, "attackers stay committed while their intended target survives")
	_assert(first_attacker._get_protective_wall_cells().size() == 68, "connected wall groups qualify as Wall Breaker protection")

	var ranger: Node2D = combat._spawn_attacker(&"ranger", 20)
	ranger.simulate(0.01)
	_assert(ranger.intended_target_id != &"" and ranger.active_target_id == ranger.intended_target_id, "Rangers choose a clear firing position and shoot over Walls instead of breaching them")
	_assert(not ranger.path.is_empty() and ranger._distance_from_position_to_structure(Vector2(ranger.path[-1]), board.get_structure(ranger.intended_target_id)) <= ranger.attack_range_cells + 0.001, "ranged routes end at the unit's real attack perimeter")
	_assert(not combat._tower_can_target_attacker(board.get_structure(&"air_defense_1"), ranger), "Air Defenses ignore ground attackers")
	combat._on_attacker_died(ranger)

	var bomber: Node2D = combat._spawn_attacker(&"bomber", 20, 2)
	bomber.simulate(0.01)
	_assert(bomber.intended_target_id != &"" and bomber.active_target_id == bomber.intended_target_id, "flying Bombers cross Walls and commit directly to a defense")
	_assert(combat._tower_can_target_attacker(board.get_structure(&"air_defense_1"), bomber), "Air Defenses acquire flying attackers")
	_assert(combat._tower_can_target_attacker(board.get_structure(&"archer_tower_1"), bomber), "ground-and-air defenses acquire flying attackers")
	_assert(not combat._tower_can_target_attacker(board.get_structure(&"cannon_1"), bomber), "ground-only Cannons ignore flying attackers")
	combat._on_attacker_died(bomber)

	var hog: Node2D = combat._spawn_attacker(&"hog", 20, 2)
	hog.simulate(0.01)
	_assert(hog.intended_target_id != &"" and hog.active_target_id == hog.intended_target_id, "Hog Riders jump Walls and route directly to a defense")
	combat._on_attacker_died(hog)

	var wounded_raider: Node2D = combat._spawn_attacker(&"raider", 20, 3)
	var healer: Node2D = combat._spawn_attacker(&"healer", 20, 1)
	wounded_raider.grid_position = Vector2(8.0, 20.0)
	healer.grid_position = Vector2(8.0, 21.0)
	wounded_raider.apply_damage(50.0)
	var wounded_health: float = wounded_raider.health
	healer.simulate(0.7)
	_assert(wounded_raider.health > wounded_health, "Healers restore health to nearby ground troops")
	combat._on_attacker_died(healer)
	combat._on_attacker_died(wounded_raider)

	var dragon: Node2D = combat._spawn_attacker(&"dragon", 20, 2)
	var minion: Node2D = combat._spawn_attacker(&"minion", 20, 2)
	_assert(combat._tower_can_target_attacker(board.get_structure(&"air_defense_1"), dragon), "Air Defenses acquire Dragons")
	_assert(combat._tower_can_target_attacker(board.get_structure(&"wizard_tower_1"), minion), "Wizard Towers acquire Minions")
	combat._on_attacker_died(dragon)
	combat._on_attacker_died(minion)

	var sapper: Node2D = combat._spawn_attacker(&"sapper", 20)
	sapper.simulate(0.01)
	var sapper_target: Node2D = board.get_structure(sapper.active_target_id)
	_assert(sapper_target != null and sapper_target.kind == &"wall", "Sappers route to the wall protecting their intended building")
	combat._on_attacker_died(sapper)

	var overlapping_raider: Node2D = combat._spawn_attacker(&"raider", 15)
	overlapping_raider.grid_position = first_attacker.grid_position
	combat._apply_unit_separation()
	_assert(
		overlapping_raider.grid_position.distance_to(first_attacker.grid_position) > 0.0,
		"nearby ground troops separate instead of occupying one point"
	)
	combat._on_attacker_died(overlapping_raider)
	var stale_target_test: Node2D = combat._spawn_attacker(&"raider", 16)
	var stale_attacker_id: int = stale_target_test.attacker_id
	combat.tower_targets[&"cannon_1"] = stale_attacker_id
	combat._on_attacker_died(stale_target_test)
	combat._update_towers(1.0)
	_assert(int(combat.tower_targets.get(&"cannon_1", -1)) != stale_attacker_id, "dead attackers are removed from tower target caches before they are freed")

	var initial_wall_count := _living_kind_count(board, &"wall")
	var saw_attacker_damage := false
	for _step in 1800:
		for attacker in combat.attackers:
			if attacker.health < attacker.max_health:
				saw_attacker_damage = true
		combat.simulate_step(0.1)
		if not combat.active:
			break
	_assert(saw_attacker_damage, "Cannons damage attackers during the live simulation")
	_assert(_living_kind_count(board, &"wall") < initial_wall_count, "the wave breaches at least one wall segment")
	var core: Node2D = board.get_structure(&"command_core")
	_assert(board.get_remaining_integrity() < 13 or core.health < core.max_health, "surviving attackers reach and damage a real objective")
	_assert(combat.result == &"attackers" or combat.result == &"defenders", "the deterministic wave reaches a declared result")
	_assert(not combat.active, "combat ends only after one side has actually been eliminated")

	combat.reset_fortress()
	_assert(board.get_remaining_integrity() == 13, "rebuild restores the fortress after combat")
	_assert(_living_kind_count(board, &"wall") == 68, "rebuild restores every wall segment")
	combat.active = true
	combat.result = &"running"
	combat._spawn_attacker(&"healer", 20, 1)
	combat._check_wave_end()
	_assert(combat.result == &"defenders" and combat.attackers.is_empty(), "a support-only army resolves immediately without a timer")

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
