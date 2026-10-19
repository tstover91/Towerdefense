extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const CatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame

	_assert(board.structures.size() == 82, "the TH6 defense blueprint creates 82 real structure nodes")
	_assert(board.get_structure_blocked_cells().size() == 196, "Clash-sized living footprints block 196 grid cells")
	_assert(board.get_navigation_blocked_cells().size() == 196, "the clear Clash-sized field uses the structure blockers")
	_assert(board.get_remaining_integrity() == 14, "every non-wall building counts toward the objective")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"command_core"), 2800.0), "the core uses exact TH6 Town Hall HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"wall"), 1800.0), "the wall uses exact level-6 HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"archer_tower"), 630.0), "Archer Towers use exact level-7 HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"air_defense"), 950.0), "Air Defenses use exact level-4 HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"wizard_tower"), 680.0), "Wizard Towers use exact level-3 HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"air_sweeper"), 800.0), "the Air Sweeper uses exact level-2 HP")

	var wall: Node2D = board.get_structure(&"wall_1")
	var wall_cell: Vector2i = wall.grid_cell
	_assert(is_equal_approx(board.damage_structure(&"wall_1", 125.0), 125.0), "damage reports the amount actually applied")
	_assert(is_equal_approx(wall.health, 1675.0), "nonlethal damage persists on the structure")
	_assert(is_equal_approx(board.damage_structure(&"wall_1", -10.0), 0.0), "negative damage is ignored")
	board.damage_structure(&"wall_1", 2000.0)
	_assert(wall.destroyed, "lethal damage marks a wall destroyed")
	_assert(not board.get_structure_blocked_cells().has(wall_cell), "destroyed walls stop blocking movement")
	_assert(board.get_remaining_integrity() == 14, "walls never contribute to the destruction objective")

	board.damage_structure(&"cannon_1", 1000.0)
	_assert(board.get_remaining_integrity() == 13, "destroyed objective buildings reduce remaining integrity")

	var snapshot: Array[Dictionary] = board.get_blueprint_snapshot()
	snapshot[0]["cell"] = Vector2i.ZERO
	_assert(Vector2i(board.get_blueprint_snapshot()[0]["cell"]) == Vector2i(36, 19), "callers cannot mutate the saved blueprint")

	var old_wall_instance_id := wall.get_instance_id()
	board.reconstruct_blueprint()
	await process_frame
	var rebuilt_wall: Node2D = board.get_structure(&"wall_1")
	_assert(rebuilt_wall.get_instance_id() != old_wall_instance_id, "reconstruction replaces battle-damaged instances")
	_assert(not rebuilt_wall.destroyed and is_equal_approx(rebuilt_wall.health, rebuilt_wall.max_health), "reconstruction restores full health")
	_assert(board.get_structure_blocked_cells().has(wall_cell), "reconstructed walls block their blueprint cells again")
	_assert(board.get_remaining_integrity() == 14, "reconstruction restores objective integrity")

	board.set_edit_mode(true)
	_assert(board.try_move_structure(&"cannon_1", Vector2i(10, 10)), "a selected defense can move to a valid empty build cell")
	_assert(board.get_structure(&"cannon_1").grid_cell == Vector2i(10, 10), "editing updates the defense grid position")
	_assert(not board.try_move_structure(&"cannon_1", Vector2i(0, 5)), "editing rejects the enemy deployment front")
	_assert(not board.try_move_structure(&"cannon_1", Vector2i(36, 19)), "editing rejects occupied cells")

	board.queue_free()
	_finish("SIEGE_STRUCTURE_LIFECYCLE_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege structure lifecycle smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
