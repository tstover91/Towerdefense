extends SceneTree

const BoardScript = preload("res://prototype/prototype_grid_board.gd")

const TEST_VIEWPORTS: Array[Vector2i] = [
	Vector2i(1152, 648),
	Vector2i(2400, 1080),
	Vector2i(960, 540),
	Vector2i(800, 360),
	Vector2i(640, 320),
]

var failure_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var board: Node2D = BoardScript.new()
	get_root().add_child(board)
	await process_frame
	_assert(not board.displayed_route.is_empty(), "prototype map has a valid waypoint route")
	for viewport_size in TEST_VIEWPORTS:
		get_root().size = viewport_size
		board._recalculate_layout()
		_assert(not board.portrait_view, "%s remains landscape" % viewport_size)
		_assert(board.router.grid_size == Vector2i(19, 10), "%s keeps the 19x10 gameplay grid" % viewport_size)
		_assert(board.cell_size > 0.0, "%s produces a usable square cell" % viewport_size)
		var board_rect := Rect2(
			board.board_origin,
			Vector2(board.router.grid_size) * board.cell_size
		)
		_assert(
			board.safe_view_rect.encloses(board_rect),
			"%s keeps the entire board inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.build_button_rect),
			"%s keeps the tower control inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.mortar_button_rect)
			and board.safe_view_rect.encloses(board.beam_button_rect),
			"%s keeps every tower control inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.wall_button_rect),
			"%s keeps the wall control inside the safe viewport" % viewport_size
		)
		_assert(
			board.build_button_rect.size.y >= 60.0
			and board.mortar_button_rect.size.y >= 60.0
			and board.beam_button_rect.size.y >= 60.0
			and board.wall_button_rect.size.y >= 60.0,
			"%s gives build controls mobile-sized touch targets" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.start_button_rect),
			"%s keeps the start control inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.upgrade_button_rect),
			"%s keeps the upgrade control inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.sell_button_rect),
			"%s keeps the sell control inside the safe viewport" % viewport_size
		)
		_assert(
			board.safe_view_rect.encloses(board.export_button_rect)
			and board.export_button_rect.size.y >= 60.0,
			"%s keeps the stats export control mobile-sized and inside the safe viewport" % viewport_size
		)
	get_root().size = Vector2i(540, 960)
	board._recalculate_layout()
	_assert(board.portrait_view, "portrait view is rejected instead of changing the grid")
	_finish("PROTOTYPE_LAYOUT_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype layout smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
