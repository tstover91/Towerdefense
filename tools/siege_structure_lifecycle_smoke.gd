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

	_assert(board.structures.size() == 11, "the fixed blueprint creates 11 real structure nodes")
	_assert(board.get_structure_blocked_cells().size() == 14, "living footprints block 14 grid cells")
	_assert(board.get_navigation_blocked_cells().size() == 18, "terrain and structures share one navigation blocker query")
	_assert(board.get_remaining_integrity() == 6, "the core and two cannons provide six integrity")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"command_core"), 900.0), "the TH6-scaled core has 900 HP")
	_assert(is_equal_approx(CatalogScript.get_max_health(&"wall"), 580.0), "the TH6-scaled wall has 580 HP")

	var wall: Node2D = board.get_structure(&"wall_1")
	var wall_cell: Vector2i = wall.grid_cell
	_assert(is_equal_approx(board.damage_structure(&"wall_1", 125.0), 125.0), "damage reports the amount actually applied")
	_assert(is_equal_approx(wall.health, 455.0), "nonlethal damage persists on the structure")
	_assert(is_equal_approx(board.damage_structure(&"wall_1", -10.0), 0.0), "negative damage is ignored")
	board.damage_structure(&"wall_1", 1000.0)
	_assert(wall.destroyed, "lethal damage marks a wall destroyed")
	_assert(not board.get_structure_blocked_cells().has(wall_cell), "destroyed walls stop blocking movement")
	_assert(board.get_remaining_integrity() == 6, "walls never contribute to the destruction objective")

	board.damage_structure(&"north_cannon", 1000.0)
	_assert(board.get_remaining_integrity() == 5, "destroyed objective buildings reduce remaining integrity")

	var snapshot: Array[Dictionary] = board.get_blueprint_snapshot()
	snapshot[0]["cell"] = Vector2i.ZERO
	_assert(Vector2i(board.get_blueprint_snapshot()[0]["cell"]) == Vector2i(11, 4), "callers cannot mutate the saved blueprint")

	var old_wall_instance_id := wall.get_instance_id()
	board.reconstruct_blueprint()
	await process_frame
	var rebuilt_wall: Node2D = board.get_structure(&"wall_1")
	_assert(rebuilt_wall.get_instance_id() != old_wall_instance_id, "reconstruction replaces battle-damaged instances")
	_assert(not rebuilt_wall.destroyed and is_equal_approx(rebuilt_wall.health, rebuilt_wall.max_health), "reconstruction restores full health")
	_assert(board.get_structure_blocked_cells().has(wall_cell), "reconstructed walls block their blueprint cells again")
	_assert(board.get_remaining_integrity() == 6, "reconstruction restores objective integrity")

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
