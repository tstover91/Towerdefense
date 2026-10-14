class_name TowerFlowGridTest
extends Node2D

const GRID_SIZE := Vector2i(18, 9)
const GRID_MARGIN := 20.0
const TOP_UI_HEIGHT := 82.0
const BOTTOM_UI_HEIGHT := 44.0
const MIN_CELL_SIZE := 28.0
const MAX_CELL_SIZE := 64.0
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
]

const COLOR_BACKGROUND := Color("17131b")
const COLOR_BOARD := Color("28202d")
const COLOR_CELL := Color("393143")
const COLOR_GRID := Color("5b5065")
const COLOR_PATH_SHADOW := Color(0.05, 0.03, 0.07, 0.72)
const COLOR_PATH := Color("f2cf62")
const COLOR_TOWER := Color("62d6b1")
const COLOR_TOWER_BORDER := Color("d7fff2")
const COLOR_PREVIEW_VALID := Color(0.38, 0.84, 0.69, 0.48)
const COLOR_PREVIEW_INVALID := Color(0.95, 0.28, 0.33, 0.55)
const COLOR_MARKERS: Array[Color] = [
	Color("65d9ff"),
	Color("ff8e62"),
	Color("c98cff"),
	Color("70dd83"),
	Color("f4e6b1"),
]

var entrance := Vector2i(0, 4)
var waypoints: Array[Vector2i] = [
	Vector2i(5, 1),
	Vector2i(9, 7),
	Vector2i(13, 2),
]
var exit_cell := Vector2i(17, 4)
var placed_towers: Dictionary = {}
var displayed_path: Array[Vector2i] = []
var hovered_cell := Vector2i(-1, -1)
var preview_is_valid := false
var preview_changes_path := false
var board_origin := Vector2.ZERO
var cell_size := 48.0
var title_font: Font


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	title_font = ThemeDB.fallback_font
	_recalculate_layout()
	displayed_path = _calculate_complete_path(placed_towers)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(_screen_to_cell(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_cell_press(_screen_to_cell(event.position))
	elif event is InputEventScreenTouch and event.pressed:
		var touched_cell := _screen_to_cell(event.position)
		_update_hover(touched_cell)
		_handle_cell_press(touched_cell)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_R, KEY_C, KEY_BACKSPACE]:
			placed_towers.clear()
			displayed_path = _calculate_complete_path(placed_towers)
			_update_hover(hovered_cell)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BACKGROUND)
	_draw_header()
	_draw_board()
	_draw_path(displayed_path)
	_draw_markers()
	_draw_towers()
	_draw_hover_preview()
	_draw_footer()


func _draw_header() -> void:
	var heading := "Tower Flow Test"
	var instructions := "Tap to place/remove. Towers may touch; every route must stay open."
	draw_string(title_font, Vector2(GRID_MARGIN, 30.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f4ead3"))
	draw_string(title_font, Vector2(GRID_MARGIN, 57.0), instructions, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("bdb1c3"))


func _draw_board() -> void:
	var board_size := Vector2(GRID_SIZE) * cell_size
	draw_rect(Rect2(board_origin - Vector2.ONE * 4.0, board_size + Vector2.ONE * 8.0), COLOR_BOARD, true)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var rect := _cell_rect(Vector2i(x, y)).grow(-1.0)
			draw_rect(rect, COLOR_CELL, true)
	for x in range(GRID_SIZE.x + 1):
		var line_x := board_origin.x + float(x) * cell_size
		draw_line(Vector2(line_x, board_origin.y), Vector2(line_x, board_origin.y + board_size.y), COLOR_GRID, 1.0)
	for y in range(GRID_SIZE.y + 1):
		var line_y := board_origin.y + float(y) * cell_size
		draw_line(Vector2(board_origin.x, line_y), Vector2(board_origin.x + board_size.x, line_y), COLOR_GRID, 1.0)


func _draw_path(path: Array[Vector2i]) -> void:
	if path.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in path:
		points.append(_cell_center(cell))
	draw_polyline(points, COLOR_PATH_SHADOW, maxf(cell_size * 0.24, 8.0), true)
	draw_polyline(points, COLOR_PATH, maxf(cell_size * 0.10, 4.0), true)
	for point in points:
		draw_circle(point, maxf(cell_size * 0.07, 3.0), COLOR_PATH)


func _draw_markers() -> void:
	var markers: Array[Vector2i] = [entrance]
	markers.append_array(waypoints)
	markers.append(exit_cell)
	var labels := ["IN", "1", "2", "3", "OUT"]
	for index in markers.size():
		var center := _cell_center(markers[index])
		var radius := cell_size * 0.30
		draw_circle(center, radius, Color(0.08, 0.06, 0.10, 0.92))
		draw_arc(center, radius, 0.0, TAU, 32, COLOR_MARKERS[index], 3.0, true)
		var label_size := title_font.get_string_size(labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(title_font, center - Vector2(label_size.x * 0.5, -label_size.y * 0.32), labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_MARKERS[index])


func _draw_towers() -> void:
	for tower_cell in placed_towers:
		var rect := _cell_rect(tower_cell).grow(-cell_size * 0.12)
		draw_rect(rect, COLOR_TOWER, true)
		draw_rect(rect, COLOR_TOWER_BORDER, false, 2.0)
		draw_circle(rect.get_center(), cell_size * 0.12, COLOR_BOARD)


func _draw_hover_preview() -> void:
	if not _is_inside_grid(hovered_cell) or placed_towers.has(hovered_cell):
		return
	var preview_rect := _cell_rect(hovered_cell).grow(-cell_size * 0.08)
	draw_rect(preview_rect, COLOR_PREVIEW_VALID if preview_is_valid else COLOR_PREVIEW_INVALID, true)
	draw_rect(preview_rect, COLOR_TOWER_BORDER if preview_is_valid else Color("ff6b72"), false, 2.0)


func _draw_footer() -> void:
	var status := "Path length: %d tiles    Towers: %d" % [maxi(displayed_path.size() - 1, 0), placed_towers.size()]
	if _is_inside_grid(hovered_cell) and not placed_towers.has(hovered_cell):
		if preview_is_valid:
			status += "    Placement valid"
			if preview_changes_path:
				status += " — route changes"
		else:
			status += "    Invalid: marker or blocked route"
	status += "    R/C/Backspace: clear"
	var baseline := board_origin.y + float(GRID_SIZE.y) * cell_size + 29.0
	draw_string(title_font, Vector2(GRID_MARGIN, baseline), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9cfdd"))


func _handle_cell_press(cell: Vector2i) -> void:
	if not _is_inside_grid(cell):
		return
	if placed_towers.has(cell):
		placed_towers.erase(cell)
		displayed_path = _calculate_complete_path(placed_towers)
		_update_hover(cell)
		return
	var candidate_blocks := placed_towers.duplicate()
	candidate_blocks[cell] = true
	if not _is_legal_new_tower(cell, candidate_blocks):
		return
	placed_towers = candidate_blocks
	displayed_path = _calculate_complete_path(placed_towers)
	_update_hover(cell)


func _update_hover(cell: Vector2i) -> void:
	hovered_cell = cell
	preview_is_valid = false
	preview_changes_path = false
	if _is_inside_grid(cell) and not placed_towers.has(cell):
		var candidate_blocks := placed_towers.duplicate()
		candidate_blocks[cell] = true
		preview_is_valid = _is_legal_new_tower(cell, candidate_blocks)
		if preview_is_valid:
			var candidate_path := _calculate_complete_path(candidate_blocks)
			preview_changes_path = candidate_path != displayed_path
			displayed_path = candidate_path
		else:
			displayed_path = _calculate_complete_path(placed_towers)
	else:
		displayed_path = _calculate_complete_path(placed_towers)
	queue_redraw()


func _is_legal_new_tower(cell: Vector2i, candidate_blocks: Dictionary) -> bool:
	if _is_route_marker(cell):
		return false
	return not _calculate_complete_path(candidate_blocks).is_empty()


func _calculate_complete_path(blocked: Dictionary) -> Array[Vector2i]:
	var destinations: Array[Vector2i] = [entrance]
	destinations.append_array(waypoints)
	destinations.append(exit_cell)
	var complete: Array[Vector2i] = []
	for index in range(destinations.size() - 1):
		var segment := _find_path(destinations[index], destinations[index + 1], blocked)
		if segment.is_empty():
			return []
		if not complete.is_empty():
			segment.pop_front()
		complete.append_array(segment)
	return complete


func _find_path(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var frontier: Array[Vector2i] = [start]
	var head := 0
	var came_from: Dictionary = {start: start}
	while head < frontier.size():
		var current := frontier[head]
		head += 1
		if current == goal:
			break
		for direction in DIRECTIONS:
			var next := current + direction
			if not _is_inside_grid(next) or blocked.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			frontier.append(next)
	if not came_from.has(goal):
		return []
	var reversed_path: Array[Vector2i] = [goal]
	var cursor := goal
	while cursor != start:
		cursor = came_from[cursor]
		reversed_path.append(cursor)
	reversed_path.reverse()
	return reversed_path


func _is_route_marker(cell: Vector2i) -> bool:
	return cell == entrance or cell == exit_cell or waypoints.has(cell)


func _is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local := screen_position - board_origin
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)


func _cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size


func _on_viewport_size_changed() -> void:
	_recalculate_layout()
	queue_redraw()


func _recalculate_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var available_width := viewport_size.x - GRID_MARGIN * 2.0
	var available_height := viewport_size.y - TOP_UI_HEIGHT - BOTTOM_UI_HEIGHT
	cell_size = clampf(minf(
		available_width / float(GRID_SIZE.x),
		available_height / float(GRID_SIZE.y)
	), MIN_CELL_SIZE, MAX_CELL_SIZE)
	var board_size := Vector2(GRID_SIZE) * cell_size
	var board_y := TOP_UI_HEIGHT + maxf((available_height - board_size.y) * 0.5, 0.0)
	if viewport_size.y > viewport_size.x:
		board_y = TOP_UI_HEIGHT
	board_origin = Vector2(
		(viewport_size.x - board_size.x) * 0.5,
		board_y
	)
