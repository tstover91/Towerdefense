extends SceneTree

const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const BoardScript = preload("res://siege_prototype/siege_board.gd")

const TEST_VIEWPORTS: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(2400, 1080),
	Vector2i(960, 540),
	Vector2i(640, 320),
]

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var layout: RefCounted = ArenaLayoutScript.new()
	_assert(ArenaLayoutScript.BUILD_AREA_SIZE == Vector2i(44, 44), "the fortress uses Clash's 44x44 build area")
	_assert(ArenaLayoutScript.GRID_SIZE == Vector2i(47, 44), "the simulation adds a three-column left approach")
	_assert(layout.get_deployment_cells().size() == 44, "the entire left edge is a deployment front")
	for cell in layout.get_deployment_cells():
		_assert(cell.x == 0, "deployment cells stay in the leftmost column")
		_assert(not layout.is_buildable_cell(cell), "deployment cells cannot hold structures")
	_assert(layout.get_validation_errors().is_empty(), "the initial blueprint is valid and non-overlapping")

	var kind_counts := {
		&"command_core": 0,
		&"cannon": 0,
		&"archer_tower": 0,
		&"mortar": 0,
		&"air_defense": 0,
		&"wizard_tower": 0,
		&"air_sweeper": 0,
		&"wall": 0,
	}
	var first_blueprint: Array[Dictionary] = layout.get_initial_blueprint()
	for structure in first_blueprint:
		var kind := StringName(structure.get("kind", &""))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		var footprint := Vector2i(structure.get("footprint", Vector2i.ZERO))
		if kind == &"command_core":
			_assert(footprint == Vector2i(4, 4), "the Town Hall uses its Clash 4x4 footprint")
		elif kind == &"air_sweeper":
			_assert(footprint == Vector2i(2, 2), "the Air Sweeper uses its Clash 2x2 footprint")
		elif kind == &"wall":
			_assert(footprint == Vector2i.ONE, "walls retain their Clash 1x1 footprint")
		else:
			_assert(footprint == Vector2i(3, 3), "%s uses a Clash 3x3 defense footprint" % kind)
	_assert(int(kind_counts[&"command_core"]) == 1, "the arena begins with one Command Core")
	_assert(int(kind_counts[&"cannon"]) == 3, "the arena includes all three TH6 Cannons")
	_assert(int(kind_counts[&"archer_tower"]) == 3, "the arena includes all three TH6 Archer Towers")
	_assert(int(kind_counts[&"mortar"]) == 2, "the arena includes both TH6 Mortars")
	_assert(int(kind_counts[&"air_defense"]) == 2, "the arena includes both TH6 Air Defenses")
	_assert(int(kind_counts[&"wizard_tower"]) == 2, "the arena includes both TH6 Wizard Towers")
	_assert(int(kind_counts[&"air_sweeper"]) == 1, "the arena includes the TH6 Air Sweeper")
	_assert(int(kind_counts[&"wall"]) == 68, "the scaled TH6 fortress uses sixty-eight wall segments")

	var second_blueprint: Array[Dictionary] = layout.get_initial_blueprint()
	first_blueprint[0]["cell"] = Vector2i.ZERO
	_assert(Vector2i(second_blueprint[0]["cell"]) == Vector2i(36, 19), "blueprint callers receive independent deterministic copies")

	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	for viewport_size in TEST_VIEWPORTS:
		get_root().size = viewport_size
		board._recalculate_layout()
		_assert(not board.portrait_view, "%s remains landscape" % viewport_size)
		_assert(board.cell_size > 0.0, "%s produces a usable square cell" % viewport_size)
		_assert(board.safe_view_rect.intersects(board.board_rect), "%s keeps the pannable arena visible" % viewport_size)
		var core_cell_center: Vector2 = board.cell_rect(Vector2i(36, 19)).get_center()
		_assert(board.screen_to_cell(core_cell_center) == Vector2i(36, 19), "%s maps screen coordinates back to arena cells" % viewport_size)

	get_root().size = Vector2i(1152, 648)
	board._recalculate_layout()
	var original_cell_size: float = board.cell_size
	var anchor: Vector2 = board.cell_rect(Vector2i(23, 22)).get_center()
	board.zoom_at_screen_position(anchor, board.view_zoom * 1.2)
	_assert(board.cell_size > original_cell_size, "zooming increases the rendered cell size")
	_assert(board.screen_to_cell(anchor) == Vector2i(23, 22), "zoom preserves the map cell under the gesture anchor")
	var origin_before_pan: Vector2 = board.board_origin
	board.pan_view(Vector2(-80.0, -40.0))
	_assert(board.board_origin != origin_before_pan, "a zoomed board can be panned")
	board.reset_view()
	_assert(is_equal_approx(board.view_zoom, board.INITIAL_VIEW_ZOOM), "reset view restores the opening zoom")

	get_root().size = Vector2i(540, 960)
	board._recalculate_layout()
	_assert(board.portrait_view, "portrait view asks for landscape instead of changing the arena")
	board.queue_free()
	_finish("SIEGE_ARENA_LAYOUT_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege arena layout smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
