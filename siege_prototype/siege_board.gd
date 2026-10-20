class_name SiegePrototypeBoard
extends Node2D

const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const StructureScript = preload("res://siege_prototype/siege_structure.gd")

signal structure_topology_changed
signal view_transform_changed
signal edit_status_changed(text: String)
signal selected_structure_changed(structure: Node)
signal structure_added(structure: Node)
signal build_preview_changed(kind: StringName, cell: Vector2i, can_confirm: bool)
signal wall_extension_requested
signal wall_extension_start_requested(cell: Vector2i)
signal placement_cancel_requested

const COLOR_BACKGROUND := Color("131313")
const COLOR_BOARD_SHADOW := Color(0.0, 0.0, 0.0, 0.42)
const COLOR_CELL_A := Color("deded1")
const COLOR_CELL_B := Color("d4d4c7")
const COLOR_DEPLOYMENT_A := Color("7d3434")
const COLOR_DEPLOYMENT_B := Color("6b2b2b")
const COLOR_BUFFER_A := Color("b2aa92")
const COLOR_BUFFER_B := Color("a69e87")
const COLOR_GRID := Color("5b5b55")
const COLOR_CORE := Color("e9b949")
const COLOR_TERRAIN := Color("42423f")
const COLOR_TEXT := Color("f2efe4")
const COLOR_MUTED_TEXT := Color("b9b6ac")
const COLOR_HOVER := Color(0.20, 0.72, 0.42, 0.42)
const COLOR_SELECTED := Color(0.95, 0.72, 0.24, 0.72)
const COLOR_INVALID_BUILD := Color(0.86, 0.22, 0.20, 0.48)
const COLOR_RANGE_FILL := Color(0.82, 0.93, 1.0, 0.10)
const COLOR_RANGE_OUTLINE := Color(0.91, 0.97, 1.0, 0.88)
const COLOR_MIN_RANGE_FILL := Color(0.92, 0.32, 0.24, 0.10)
const COLOR_MIN_RANGE_OUTLINE := Color(1.0, 0.48, 0.34, 0.84)
const BASE_TAP_DRAG_THRESHOLD := 12.0

const PAGE_MARGIN := 0.0
const HEADER_HEIGHT := 0.0
const FOOTER_HEIGHT := 0.0
const MIN_VIEW_ZOOM := 0.82
const MAX_VIEW_ZOOM := 5.0
const INITIAL_VIEW_ZOOM := 2.05
const WHEEL_ZOOM_STEP := 1.12

var arena_layout: RefCounted
var board_origin := Vector2.ZERO
var board_rect := Rect2()
var safe_view_rect := Rect2()
var cell_size := 48.0
var fit_cell_size := 48.0
var view_zoom := INITIAL_VIEW_ZOOM
var portrait_view := false
var hovered_cell := Vector2i(-1, -1)
var title_font: Font
var structures: Array[Node2D] = []
var structures_by_id: Dictionary = {}
var blueprint_snapshot: Array[Dictionary] = []
var mouse_dragging := false
var build_mouse_dragging := false
var build_drag_last_position := Vector2.ZERO
var mouse_press_position := Vector2.ZERO
var mouse_moved := false
var touch_points: Dictionary = {}
var touch_start_positions: Dictionary = {}
var touch_moved: Dictionary = {}
var build_drag_touch_index := -1
var wall_draw_mouse_dragging := false
var wall_draw_touch_index := -1
var wall_draw_last_position := Vector2.ZERO
var wall_draw_invalid_cell := Vector2i(-1, -1)
var structure_drag_candidate_id: StringName
var structure_dragging := false
var structure_drag_press_position := Vector2.ZERO
var structure_drag_last_position := Vector2.ZERO
var structure_drag_pointer_offset := Vector2.ZERO
var structure_drag_touch_index := -1
var structure_drag_origin_cell := Vector2i(-1, -1)
var structure_drag_preview_cell := Vector2i(-1, -1)
var structure_drag_drop_valid := true
var wall_row_drag_origin_cells: Dictionary = {}
var wall_row_drag_preview_delta := Vector2i.ZERO
var edit_mode := true
var selected_structure_id: StringName
var selected_wall_row_ids: Array[StringName] = []
var pending_build_kind: StringName
var pending_build_cell := Vector2i(-1, -1)
var pending_build_valid := false
var wall_chain_cells: Array[Vector2i] = []
var wall_chain_max_new_walls := 0
var build_preview_structure: Node2D
var next_structure_serial := 100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_layout = ArenaLayoutScript.new()
	title_font = ThemeDB.fallback_font
	blueprint_snapshot = arena_layout.get_initial_blueprint()
	_build_structures_from_blueprint(blueprint_snapshot)
	get_viewport().size_changed.connect(_recalculate_layout)
	_recalculate_layout()


func _unhandled_input(event: InputEvent) -> void:
	if portrait_view:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_at_screen_position(event.position, view_zoom * WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_at_screen_position(event.position, view_zoom / WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _begin_wall_draw_at(event.position):
					wall_draw_mouse_dragging = true
					get_viewport().set_input_as_handled()
					return
				if _can_drag_build_preview_at(event.position):
					build_mouse_dragging = true
					preview_build_at_screen_position(event.position)
					get_viewport().set_input_as_handled()
					return
				if _begin_structure_drag_candidate_at(event.position):
					get_viewport().set_input_as_handled()
					return
				mouse_dragging = true
				mouse_press_position = event.position
				mouse_moved = false
			else:
				if wall_draw_mouse_dragging:
					wall_draw_mouse_dragging = false
					_update_wall_draw(event.position)
					get_viewport().set_input_as_handled()
					return
				if build_mouse_dragging:
					build_mouse_dragging = false
					preview_build_at_screen_position(event.position)
					get_viewport().set_input_as_handled()
					return
				if structure_drag_candidate_id != &"":
					_finish_structure_drag(event.position)
					get_viewport().set_input_as_handled()
					return
				mouse_dragging = false
				if not mouse_moved:
					_handle_edit_tap(event.position)
			_update_hover(event.position)
	elif event is InputEventMouseMotion:
		if wall_draw_mouse_dragging:
			_update_wall_draw(event.position)
			get_viewport().set_input_as_handled()
		elif build_mouse_dragging:
			preview_build_at_screen_position(event.position)
			get_viewport().set_input_as_handled()
		elif structure_drag_candidate_id != &"":
			_update_structure_drag(event.position)
			get_viewport().set_input_as_handled()
		elif mouse_dragging:
			if event.position.distance_to(mouse_press_position) > _tap_drag_threshold():
				mouse_moved = true
			pan_view(event.relative)
			get_viewport().set_input_as_handled()
		else:
			_update_hover(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if wall_draw_touch_index >= 0:
				_promote_wall_draw_touch_to_pinch()
			if touch_points.is_empty() and _begin_wall_draw_at(event.position):
				wall_draw_touch_index = event.index
				wall_draw_last_position = event.position
				get_viewport().set_input_as_handled()
				return
			if build_drag_touch_index >= 0:
				_promote_build_touch_to_pinch()
			if touch_points.is_empty() and _can_drag_build_preview_at(event.position):
				build_drag_touch_index = event.index
				build_drag_last_position = event.position
				preview_build_at_screen_position(event.position)
				get_viewport().set_input_as_handled()
				return
			if structure_drag_touch_index >= 0:
				_promote_structure_touch_to_pinch()
			if touch_points.is_empty() and _begin_structure_drag_candidate_at(event.position):
				structure_drag_touch_index = event.index
				structure_drag_last_position = event.position
				get_viewport().set_input_as_handled()
				return
			touch_points[event.index] = event.position
			touch_start_positions[event.index] = event.position
			touch_moved[event.index] = false
		else:
			if event.index == wall_draw_touch_index:
				_update_wall_draw(event.position)
				wall_draw_touch_index = -1
				wall_draw_last_position = Vector2.ZERO
				get_viewport().set_input_as_handled()
				return
			if event.index == build_drag_touch_index:
				build_drag_touch_index = -1
				build_drag_last_position = Vector2.ZERO
				preview_build_at_screen_position(event.position)
				get_viewport().set_input_as_handled()
				return
			if event.index == structure_drag_touch_index:
				_finish_structure_drag(event.position)
				structure_drag_touch_index = -1
				get_viewport().set_input_as_handled()
				return
			var was_tap := not bool(touch_moved.get(event.index, true)) and touch_points.size() == 1
			touch_points.erase(event.index)
			touch_start_positions.erase(event.index)
			touch_moved.erase(event.index)
			if was_tap:
				_handle_edit_tap(event.position)
		_update_hover(event.position)
	elif event is InputEventScreenDrag:
		if event.index == wall_draw_touch_index:
			wall_draw_last_position = event.position
			_update_wall_draw(event.position)
		elif event.index == build_drag_touch_index:
			build_drag_last_position = event.position
			preview_build_at_screen_position(event.position)
		elif event.index == structure_drag_touch_index:
			structure_drag_last_position = event.position
			_update_structure_drag(event.position)
		else:
			_handle_touch_drag(event)
		get_viewport().set_input_as_handled()


func _begin_wall_draw_at(screen_position: Vector2) -> bool:
	if not edit_mode:
		return false
	var cell := screen_to_cell(screen_position)
	if cell.x < 0:
		return false
	if pending_build_kind == &"wall" and not wall_chain_cells.is_empty():
		if not get_wall_extension_cells().has(cell):
			return false
		return _append_wall_chain_cell(cell)
	if pending_build_kind == &"" and _selected_wall_can_extend_to(cell):
		wall_extension_start_requested.emit(cell)
		if pending_build_kind != &"wall" or wall_chain_cells.is_empty():
			return false
		if wall_chain_cells.has(cell):
			return true
		return _append_wall_chain_cell(cell)
	return false


func _update_wall_draw(screen_position: Vector2) -> void:
	if pending_build_kind != &"wall" or wall_chain_cells.is_empty():
		return
	var target := screen_to_cell(screen_position)
	if target.x < 0:
		wall_draw_invalid_cell = target
		queue_redraw()
		return
	var current := wall_chain_cells[-1]
	if wall_chain_cells.size() >= 2 and target == wall_chain_cells[-2]:
		wall_chain_cells.pop_back()
		wall_draw_invalid_cell = Vector2i(-1, -1)
		_update_wall_chain_preview()
		return
	var initial_delta := target - current
	var horizontal_first := absi(initial_delta.x) >= absi(initial_delta.y)
	while current != target:
		var delta := target - current
		var step := Vector2i.ZERO
		if horizontal_first and delta.x != 0:
			step.x = signi(delta.x)
		elif not horizontal_first and delta.y != 0:
			step.y = signi(delta.y)
		elif delta.x != 0:
			step.x = signi(delta.x)
		else:
			step.y = signi(delta.y)
		var next_cell := current + step
		if not _append_wall_chain_cell(next_cell):
			wall_draw_invalid_cell = next_cell
			queue_redraw()
			return
		current = next_cell


func _append_wall_chain_cell(cell: Vector2i) -> bool:
	if wall_chain_cells.is_empty() or wall_chain_max_new_walls <= 0:
		return false
	if wall_chain_cells.size() >= 2 and cell == wall_chain_cells[-2]:
		wall_chain_cells.pop_back()
		wall_draw_invalid_cell = Vector2i(-1, -1)
		_update_wall_chain_preview()
		return true
	if wall_chain_cells.size() - 1 >= wall_chain_max_new_walls:
		wall_draw_invalid_cell = cell
		queue_redraw()
		return false
	var focus := wall_chain_cells[-1]
	if focus.distance_to(cell) != 1.0 or wall_chain_cells.has(cell) or not can_place_structure(&"wall", cell):
		wall_draw_invalid_cell = cell
		queue_redraw()
		return false
	wall_chain_cells.append(cell)
	wall_draw_invalid_cell = Vector2i(-1, -1)
	_update_wall_chain_preview()
	wall_extension_requested.emit()
	return true


func _update_wall_chain_preview() -> void:
	pending_build_cell = wall_chain_cells[-1] if wall_chain_cells.size() > 1 else Vector2i(-1, -1)
	pending_build_valid = wall_chain_cells.size() > 1
	build_preview_changed.emit(&"wall", pending_build_cell, pending_build_valid)
	queue_redraw()


func _promote_wall_draw_touch_to_pinch() -> void:
	if wall_draw_touch_index < 0:
		return
	var first_index := wall_draw_touch_index
	var first_position := wall_draw_last_position
	wall_draw_touch_index = -1
	wall_draw_last_position = Vector2.ZERO
	touch_points[first_index] = first_position
	touch_start_positions[first_index] = first_position
	touch_moved[first_index] = true


func _begin_structure_drag_candidate_at(screen_position: Vector2) -> bool:
	if not edit_mode:
		return false
	var cell := screen_to_cell(screen_position)
	if not arena_layout.is_inside_grid(cell):
		return false
	var structure := get_structure_at_cell(cell, true)
	if structure == null or structure.destroyed:
		return false
	var moving_selected_row := selected_wall_row_ids.size() > 1 and selected_wall_row_ids.has(structure.structure_id)
	# Clash-style gesture arbitration: the first tap selects a structure. Only
	# an already-selected structure captures a drag; dragging across any other
	# structure remains a camera pan.
	if structure.structure_id != selected_structure_id and not moving_selected_row:
		return false
	if pending_build_kind != &"":
		if pending_build_kind != &"wall" or wall_chain_cells.is_empty():
			return false
		# Grabbing a structure while Wall extension is active exits that mode
		# first, so Walls use the same direct-drag behavior as every building.
		placement_cancel_requested.emit()
		if pending_build_kind != &"":
			return false
	selected_structure_id = structure.structure_id
	structure_drag_candidate_id = structure.structure_id
	structure_dragging = false
	structure_drag_press_position = screen_position
	structure_drag_last_position = screen_position
	# Clash-style building movement is anchored to the footprint center. This
	# keeps 3x3 defenses and the 4x4 Core centered under the finger instead of
	# making their top-left grid cell act like the drag handle.
	structure_drag_pointer_offset = Vector2(structure.footprint) * 0.5
	structure_drag_origin_cell = structure.grid_cell
	structure_drag_preview_cell = structure.grid_cell
	structure_drag_drop_valid = true
	wall_row_drag_origin_cells.clear()
	wall_row_drag_preview_delta = Vector2i.ZERO
	if moving_selected_row:
		for structure_id in selected_wall_row_ids:
			var row_wall := get_structure(structure_id)
			if row_wall != null:
				wall_row_drag_origin_cells[structure_id] = row_wall.grid_cell
	queue_redraw()
	return true


func _update_structure_drag(screen_position: Vector2) -> void:
	if structure_drag_candidate_id == &"":
		return
	structure_drag_last_position = screen_position
	if not structure_dragging:
		if screen_position.distance_to(structure_drag_press_position) <= _tap_drag_threshold():
			return
		structure_dragging = true
	var structure := get_structure(structure_drag_candidate_id)
	if structure == null or structure.destroyed:
		_reset_structure_drag_state()
		return
	var pointer_grid := (screen_position - board_origin) / cell_size
	var destination := Vector2i(
		roundi(pointer_grid.x - structure_drag_pointer_offset.x),
		roundi(pointer_grid.y - structure_drag_pointer_offset.y)
	)
	structure_drag_preview_cell = destination
	if not wall_row_drag_origin_cells.is_empty():
		wall_row_drag_preview_delta = destination - structure_drag_origin_cell
		structure_drag_drop_valid = _can_move_selected_wall_row_by(wall_row_drag_preview_delta)
		var free_delta := screen_position - structure_drag_press_position
		for structure_id in selected_wall_row_ids:
			var row_wall := get_structure(structure_id)
			if row_wall == null:
				continue
			var origin_cell: Vector2i = wall_row_drag_origin_cells.get(structure_id, row_wall.grid_cell)
			row_wall.position = board_origin + Vector2(origin_cell) * cell_size + free_delta
		return
	structure_drag_drop_valid = _can_move_structure_to(structure, destination)
	# Keep the object under the finger while its footprint provides the snapped
	# grid feedback. The logical layout is committed only when the drag ends.
	structure.position = screen_position - structure_drag_pointer_offset * cell_size


func _finish_structure_drag(screen_position: Vector2) -> void:
	if structure_drag_candidate_id == &"":
		return
	_update_structure_drag(screen_position)
	var structure := get_structure(structure_drag_candidate_id)
	var was_dragged := structure_dragging
	var origin_cell := structure_drag_origin_cell
	var destination := structure_drag_preview_cell
	var valid_drop := structure_drag_drop_valid
	var row_drag_origins := wall_row_drag_origin_cells.duplicate()
	var row_drag_delta := wall_row_drag_preview_delta
	var moved_row := not row_drag_origins.is_empty()
	_reset_structure_drag_state()
	if structure == null or structure.destroyed:
		clear_selection()
		return
	if was_dragged:
		if moved_row:
			for structure_id in selected_wall_row_ids:
				var row_wall := get_structure(structure_id)
				if row_wall == null:
					continue
				var row_origin_cell: Vector2i = row_drag_origins.get(structure_id, row_wall.grid_cell)
				row_wall.grid_cell = row_origin_cell + row_drag_delta if valid_drop else row_origin_cell
				row_wall.set_layout_metrics(board_origin, cell_size)
		elif valid_drop and destination.x >= 0:
			try_move_structure(structure.structure_id, destination, false)
		else:
			structure.grid_cell = origin_cell
			structure.set_layout_metrics(board_origin, cell_size)
		if valid_drop and ((moved_row and row_drag_delta != Vector2i.ZERO) or (not moved_row and destination != origin_cell)):
			capture_current_blueprint()
			structure_topology_changed.emit()
	selected_structure_id = structure.structure_id
	selected_structure_changed.emit(structure)
	queue_redraw()


func _promote_structure_touch_to_pinch() -> void:
	if structure_drag_touch_index < 0:
		return
	var first_index := structure_drag_touch_index
	var first_position := structure_drag_last_position
	if not wall_row_drag_origin_cells.is_empty():
		for structure_id in selected_wall_row_ids:
			var row_wall := get_structure(structure_id)
			if row_wall != null and wall_row_drag_origin_cells.has(structure_id):
				row_wall.grid_cell = wall_row_drag_origin_cells[structure_id]
				row_wall.set_layout_metrics(board_origin, cell_size)
	else:
		var structure := get_structure(structure_drag_candidate_id)
		if structure != null and structure_drag_origin_cell.x >= 0:
			structure.grid_cell = structure_drag_origin_cell
			structure.set_layout_metrics(board_origin, cell_size)
	_reset_structure_drag_state()
	structure_drag_touch_index = -1
	touch_points[first_index] = first_position
	touch_start_positions[first_index] = first_position
	touch_moved[first_index] = true


func _promote_build_touch_to_pinch() -> void:
	if build_drag_touch_index < 0:
		return
	var first_index := build_drag_touch_index
	var first_position := build_drag_last_position
	build_drag_touch_index = -1
	build_drag_last_position = Vector2.ZERO
	touch_points[first_index] = first_position
	touch_start_positions[first_index] = first_position
	touch_moved[first_index] = true


func _reset_structure_drag_state() -> void:
	structure_drag_candidate_id = &""
	structure_dragging = false
	structure_drag_press_position = Vector2.ZERO
	structure_drag_last_position = Vector2.ZERO
	structure_drag_pointer_offset = Vector2.ZERO
	structure_drag_origin_cell = Vector2i(-1, -1)
	structure_drag_preview_cell = Vector2i(-1, -1)
	structure_drag_drop_valid = true
	wall_row_drag_origin_cells.clear()
	wall_row_drag_preview_delta = Vector2i.ZERO


func _can_drag_build_preview() -> bool:
	return edit_mode and pending_build_kind != &"" and wall_chain_cells.is_empty()


func _can_drag_build_preview_at(screen_position: Vector2) -> bool:
	return _can_drag_build_preview() and get_build_preview_screen_rect().grow(maxf(cell_size * 0.35, 12.0)).has_point(screen_position)


func preview_build_at_screen_position(screen_position: Vector2) -> bool:
	if not _can_drag_build_preview():
		return false
	var footprint := _default_footprint(pending_build_kind)
	var pointer_cell := screen_to_cell(screen_position)
	if pointer_cell.x < 0:
		return false
	var destination := pointer_cell - Vector2i(footprint.x / 2, footprint.y / 2)
	return preview_build_at_cell(destination)


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	var old_points := touch_points.duplicate()
	touch_points[event.index] = event.position
	if event.position.distance_to(Vector2(touch_start_positions.get(event.index, event.position))) > _tap_drag_threshold():
		touch_moved[event.index] = true
	if touch_points.size() < 2:
		pan_view(event.relative)
		_update_hover(event.position)
		return
	var indices: Array = touch_points.keys()
	for index in indices:
		touch_moved[index] = true
	var first_index = indices[0]
	var second_index = indices[1]
	if not old_points.has(first_index) or not old_points.has(second_index):
		return
	var old_a := Vector2(old_points[first_index])
	var old_b := Vector2(old_points[second_index])
	var new_a := Vector2(touch_points[first_index])
	var new_b := Vector2(touch_points[second_index])
	var old_center := (old_a + old_b) * 0.5
	var new_center := (new_a + new_b) * 0.5
	var old_distance := maxf(old_a.distance_to(old_b), 1.0)
	var new_distance := maxf(new_a.distance_to(new_b), 1.0)
	pan_view(new_center - old_center)
	zoom_at_screen_position(new_center, view_zoom * new_distance / old_distance)


func _update_hover(screen_position: Vector2) -> void:
	var next_cell := screen_to_cell(screen_position)
	if next_cell == hovered_cell:
		return
	hovered_cell = next_cell
	queue_redraw()


func set_edit_mode(enabled: bool) -> void:
	edit_mode = enabled
	if not edit_mode:
		_reset_structure_drag_state()
		structure_drag_touch_index = -1
		pending_build_kind = &""
		pending_build_cell = Vector2i(-1, -1)
		pending_build_valid = false
		wall_chain_cells.clear()
		wall_chain_max_new_walls = 0
		wall_draw_invalid_cell = Vector2i(-1, -1)
		_clear_build_preview_structure()
		clear_selection()
	queue_redraw()


func is_edit_mode() -> bool:
	return edit_mode


func _handle_edit_tap(screen_position: Vector2) -> void:
	if not edit_mode:
		return
	var cell := screen_to_cell(screen_position)
	if not arena_layout.is_inside_grid(cell):
		if pending_build_kind == &"wall" and not wall_chain_cells.is_empty():
			placement_cancel_requested.emit()
		clear_selection()
		return
	if pending_build_kind != &"":
		if pending_build_kind == &"wall" and not wall_chain_cells.is_empty():
			if not try_select_wall_extension(cell):
				var replacement := get_structure_at_cell(cell, true)
				placement_cancel_requested.emit()
				if replacement != null and not replacement.destroyed:
					select_structure(replacement)
			return
		return
	if _selected_wall_can_extend_to(cell):
		wall_extension_start_requested.emit(cell)
		return
	var tapped_structure := get_structure_at_cell(cell, true)
	if tapped_structure != null:
		select_structure(tapped_structure)
		return
	clear_selection()


func select_structure(structure: Node2D) -> void:
	if structure == null or structure.destroyed:
		clear_selection()
		return
	selected_wall_row_ids.clear()
	selected_structure_id = structure.structure_id
	selected_structure_changed.emit(structure)
	queue_redraw()


func clear_selection() -> void:
	var had_selection := selected_structure_id != &""
	selected_structure_id = &""
	selected_wall_row_ids.clear()
	if had_selection:
		selected_structure_changed.emit(null)
	queue_redraw()


func get_selected_wall_row_count() -> int:
	return selected_wall_row_ids.size()


func get_selected_tower_range_cells() -> Vector2:
	var selected := get_selected_structure()
	if selected == null or selected.destroyed or not _structure_has_weapon(selected):
		return Vector2.ZERO
	return Vector2(
		maxf(float(selected.definition.get("minimum_range_cells", 0.0)), 0.0),
		maxf(float(selected.definition.get("attack_range_cells", 0.0)), 0.0)
	)


func get_selectable_wall_row_count() -> int:
	return _longest_wall_row_ids().size()


func select_wall_row() -> bool:
	var row := _longest_wall_row_ids()
	if row.size() <= 1:
		return false
	selected_wall_row_ids.assign(row)
	var selected := get_selected_structure()
	selected_structure_changed.emit(selected)
	queue_redraw()
	return true


func rotate_selected_wall_row() -> bool:
	if selected_wall_row_ids.size() <= 1:
		return false
	var pivot := get_selected_structure()
	if pivot == null or pivot.kind != &"wall":
		return false
	var destinations: Dictionary = {}
	for structure_id in selected_wall_row_ids:
		var wall := get_structure(structure_id)
		if wall == null or wall.destroyed:
			return false
		var relative: Vector2i = wall.grid_cell - pivot.grid_cell
		destinations[structure_id] = pivot.grid_cell + Vector2i(-relative.y, relative.x)
	if not _wall_row_destinations_valid(destinations):
		edit_status_changed.emit("Not enough room to rotate this Wall row")
		return false
	for structure_id in selected_wall_row_ids:
		var wall := get_structure(structure_id)
		wall.grid_cell = destinations[structure_id]
		wall.set_layout_metrics(board_origin, cell_size)
	capture_current_blueprint()
	structure_topology_changed.emit()
	selected_structure_changed.emit(pivot)
	queue_redraw()
	return true


func _longest_wall_row_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var selected := get_selected_structure()
	if selected == null or selected.kind != &"wall" or selected.destroyed:
		return result
	var horizontal := _wall_run_through(selected.grid_cell, Vector2i.RIGHT)
	var vertical := _wall_run_through(selected.grid_cell, Vector2i.DOWN)
	return horizontal if horizontal.size() >= vertical.size() else vertical


func _wall_run_through(origin: Vector2i, axis: Vector2i) -> Array[StringName]:
	var cells: Array[Vector2i] = [origin]
	var cursor := origin - axis
	while _wall_at_cell(cursor) != null:
		cells.push_front(cursor)
		cursor -= axis
	cursor = origin + axis
	while _wall_at_cell(cursor) != null:
		cells.append(cursor)
		cursor += axis
	var result: Array[StringName] = []
	for cell in cells:
		var wall := _wall_at_cell(cell)
		if wall != null:
			result.append(wall.structure_id)
	return result


func _wall_at_cell(cell: Vector2i) -> Node2D:
	var structure := get_structure_at_cell(cell, true)
	if structure == null or structure.destroyed or structure.kind != &"wall":
		return null
	return structure


func begin_build(kind: StringName) -> void:
	pending_build_kind = kind
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	wall_chain_cells.clear()
	wall_chain_max_new_walls = 0
	wall_draw_invalid_cell = Vector2i(-1, -1)
	_create_build_preview_structure(kind)
	selected_structure_id = &""
	selected_wall_row_ids.clear()
	selected_structure_changed.emit(null)
	var opening_cell := _find_nearest_build_cell(screen_to_cell(get_viewport_rect().get_center()), kind)
	if opening_cell.x >= 0:
		preview_build_at_cell(opening_cell)
	else:
		build_preview_changed.emit(kind, pending_build_cell, false)
	queue_redraw()


func cancel_build() -> void:
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	wall_chain_cells.clear()
	wall_chain_max_new_walls = 0
	wall_draw_invalid_cell = Vector2i(-1, -1)
	_clear_build_preview_structure()
	build_preview_changed.emit(&"", pending_build_cell, false)
	queue_redraw()


func confirm_pending_build() -> bool:
	if pending_build_kind == &"" or pending_build_cell.x < 0 or not pending_build_valid:
		return false
	if pending_build_kind == &"wall" and wall_chain_cells.size() > 1:
		return not confirm_pending_wall_chain().is_empty()
	var kind := pending_build_kind
	var cell := pending_build_cell
	if not try_add_structure(kind, cell, 1):
		return false
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	_clear_build_preview_structure()
	build_preview_changed.emit(&"", pending_build_cell, false)
	queue_redraw()
	return true


func begin_wall_chain(anchor: Vector2i, preserve_selection := false, max_new_walls := 1) -> void:
	_clear_build_preview_structure()
	pending_build_kind = &"wall"
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	wall_chain_cells.assign([anchor])
	wall_chain_max_new_walls = maxi(max_new_walls, 0)
	wall_draw_invalid_cell = Vector2i(-1, -1)
	if not preserve_selection:
		selected_structure_id = &""
		selected_wall_row_ids.clear()
		selected_structure_changed.emit(null)
	build_preview_changed.emit(&"wall", pending_build_cell, false)
	queue_redraw()


func begin_wall_chain_from_existing(anchor: Vector2i, max_new_walls := 1) -> void:
	begin_wall_chain(anchor, true, max_new_walls)


func advance_wall_chain(cell: Vector2i) -> void:
	begin_wall_chain(cell, false, wall_chain_max_new_walls)


func is_wall_chain_active() -> bool:
	return not wall_chain_cells.is_empty()


func get_wall_extension_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if wall_chain_cells.is_empty() and selected_wall_row_ids.size() > 1:
		return result
	var focus := Vector2i(-1, -1)
	if not wall_chain_cells.is_empty():
		focus = wall_chain_cells[-1]
	else:
		var selected := get_selected_structure()
		if selected != null and selected.kind == &"wall" and not selected.destroyed:
			focus = selected.grid_cell
	if focus.x < 0:
		return result
	if not wall_chain_cells.is_empty() and wall_chain_cells.size() - 1 >= wall_chain_max_new_walls:
		return result
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var candidate: Vector2i = focus + Vector2i(direction)
		if arena_layout.is_inside_grid(candidate) and not wall_chain_cells.has(candidate) and can_place_structure(&"wall", candidate):
			result.append(candidate)
	return result


func _selected_wall_can_extend_to(cell: Vector2i) -> bool:
	if pending_build_kind != &"" or not get_wall_extension_cells().has(cell):
		return false
	var selected := get_selected_structure()
	return selected != null and selected.kind == &"wall" and not selected.destroyed


func try_select_wall_extension(cell: Vector2i) -> bool:
	if not is_wall_chain_active() or not get_wall_extension_cells().has(cell):
		return false
	return _append_wall_chain_cell(cell)


func get_pending_wall_count() -> int:
	return maxi(wall_chain_cells.size() - 1, 0)


func confirm_pending_wall_chain() -> Array[Node2D]:
	var added: Array[Node2D] = []
	if pending_build_kind != &"wall" or get_pending_wall_count() <= 0 or not pending_build_valid:
		return added
	for index in range(1, wall_chain_cells.size()):
		if not can_place_structure(&"wall", wall_chain_cells[index]):
			return []
	for index in range(1, wall_chain_cells.size()):
		var cell := wall_chain_cells[index]
		var structure_id := StringName("wall_%d" % next_structure_serial)
		next_structure_serial += 1
		var entry := {"id": structure_id, "kind": &"wall", "level": 1, "cell": cell, "footprint": Vector2i.ONE}
		var structure: Node2D = _create_structure(entry)
		structures.append(structure)
		structures_by_id[structure.structure_id] = structure
		structure.set_layout_metrics(board_origin, cell_size)
		added.append(structure)
	var last_wall: Node2D = added[-1]
	selected_wall_row_ids.clear()
	selected_structure_id = last_wall.structure_id
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	wall_chain_cells.clear()
	wall_chain_max_new_walls = 0
	wall_draw_invalid_cell = Vector2i(-1, -1)
	capture_current_blueprint()
	structure_topology_changed.emit()
	selected_structure_changed.emit(last_wall)
	queue_redraw()
	return added


func preview_build_at_cell(cell: Vector2i) -> bool:
	if pending_build_kind == &"" or not arena_layout.is_inside_grid(cell):
		return false
	pending_build_cell = cell
	pending_build_valid = can_place_structure(pending_build_kind, cell)
	_update_build_preview_structure()
	build_preview_changed.emit(pending_build_kind, cell, pending_build_valid)
	queue_redraw()
	return pending_build_valid


func get_build_preview_screen_rect() -> Rect2:
	if pending_build_kind == &"" or pending_build_cell.x < 0:
		return Rect2()
	return Rect2(
		board_origin + Vector2(pending_build_cell) * cell_size,
		Vector2(_default_footprint(pending_build_kind)) * cell_size
	)


func get_wall_chain_focus_cell() -> Vector2i:
	return wall_chain_cells[-1] if not wall_chain_cells.is_empty() else Vector2i(-1, -1)


func _find_nearest_build_cell(center: Vector2i, kind: StringName) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 1000000
	for x in ArenaLayoutScript.GRID_SIZE.x:
		for y in ArenaLayoutScript.GRID_SIZE.y:
			var candidate := Vector2i(x, y)
			if not can_place_structure(kind, candidate):
				continue
			var distance := candidate.distance_squared_to(center)
			if distance < best_distance:
				best = candidate
				best_distance = distance
	return best


func _create_build_preview_structure(kind: StringName) -> void:
	_clear_build_preview_structure()
	var entry := {
		"id": &"build_preview",
		"kind": kind,
		"level": 1,
		"cell": Vector2i.ZERO,
		"footprint": _default_footprint(kind),
	}
	build_preview_structure = StructureScript.new()
	build_preview_structure.configure(entry, StructureCatalogScript.get_definition(kind, 1))
	build_preview_structure.z_index = 40
	add_child(build_preview_structure)
	_update_build_preview_structure()


func _update_build_preview_structure() -> void:
	if not is_instance_valid(build_preview_structure):
		return
	build_preview_structure.grid_cell = pending_build_cell
	build_preview_structure.visible = pending_build_cell.x >= 0 and not portrait_view
	build_preview_structure.modulate = Color(0.78, 1.0, 0.78, 0.86) if pending_build_valid else Color(1.0, 0.55, 0.52, 0.78)
	build_preview_structure.set_layout_metrics(board_origin, cell_size)


func _clear_build_preview_structure() -> void:
	if not is_instance_valid(build_preview_structure):
		build_preview_structure = null
		return
	remove_child(build_preview_structure)
	build_preview_structure.queue_free()
	build_preview_structure = null


func can_place_structure(kind: StringName, destination: Vector2i) -> bool:
	if not edit_mode or not StructureCatalogScript.has_kind(kind):
		return false
	var footprint: Vector2i = _default_footprint(kind)
	for x in footprint.x:
		for y in footprint.y:
			var cell := destination + Vector2i(x, y)
			if not arena_layout.is_buildable_cell(cell) or get_structure_at_cell(cell, true) != null:
				return false
	return true


func try_add_structure(kind: StringName, destination: Vector2i, level := 1) -> bool:
	if not can_place_structure(kind, destination):
		return false
	var footprint: Vector2i = _default_footprint(kind)
	var structure_id := StringName("%s_%d" % [kind, next_structure_serial])
	next_structure_serial += 1
	var entry := {"id": structure_id, "kind": kind, "level": level, "cell": destination, "footprint": footprint}
	var structure: Node2D = _create_structure(entry)
	structures.append(structure)
	structures_by_id[structure.structure_id] = structure
	structure.set_layout_metrics(board_origin, cell_size)
	selected_wall_row_ids.clear()
	selected_structure_id = structure.structure_id
	capture_current_blueprint()
	structure_topology_changed.emit()
	selected_structure_changed.emit(structure)
	structure_added.emit(structure)
	queue_redraw()
	return true


func upgrade_structure(structure_id: StringName, next_level: int) -> bool:
	var structure := get_structure(structure_id)
	if structure == null or structure.destroyed or next_level <= structure.level:
		return false
	structure.upgrade_to(next_level, StructureCatalogScript.get_definition(structure.kind, next_level))
	capture_current_blueprint()
	structure_topology_changed.emit()
	selected_structure_changed.emit(structure)
	return true


func get_selected_structure() -> Node2D:
	return get_structure(selected_structure_id) if selected_structure_id != &"" else null


func get_structure_count(kind: StringName) -> int:
	var result := 0
	for structure in structures:
		if structure.kind == kind:
			result += 1
	return result


func load_blueprint(blueprint: Array[Dictionary], capture := true) -> void:
	_clear_structures()
	_reset_structure_drag_state()
	structure_drag_touch_index = -1
	selected_structure_id = &""
	selected_wall_row_ids.clear()
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	wall_chain_cells.clear()
	wall_chain_max_new_walls = 0
	wall_draw_invalid_cell = Vector2i(-1, -1)
	_clear_build_preview_structure()
	_build_structures_from_blueprint(blueprint)
	if capture:
		blueprint_snapshot = blueprint.duplicate(true)
	structure_topology_changed.emit()
	selected_structure_changed.emit(null)
	queue_redraw()


func try_move_structure(structure_id: StringName, destination: Vector2i, save_immediately := true) -> bool:
	if not edit_mode:
		return false
	var structure := get_structure(structure_id)
	if structure == null or structure.destroyed:
		return false
	if not _can_move_structure_to(structure, destination):
		return false
	structure.grid_cell = destination
	structure.set_layout_metrics(board_origin, cell_size)
	if save_immediately:
		capture_current_blueprint()
		structure_topology_changed.emit()
	queue_redraw()
	return true


func _can_move_structure_to(structure: Node2D, destination: Vector2i) -> bool:
	for x in structure.footprint.x:
		for y in structure.footprint.y:
			var cell := destination + Vector2i(x, y)
			if not arena_layout.is_buildable_cell(cell):
				return false
			var occupant := get_structure_at_cell(cell, true)
			if occupant != null and occupant != structure:
				return false
	return true


func _can_move_selected_wall_row_by(delta: Vector2i) -> bool:
	if selected_wall_row_ids.size() <= 1:
		return false
	var destinations: Dictionary = {}
	for structure_id in selected_wall_row_ids:
		if not wall_row_drag_origin_cells.has(structure_id):
			return false
		destinations[structure_id] = Vector2i(wall_row_drag_origin_cells[structure_id]) + delta
	return _wall_row_destinations_valid(destinations)


func _wall_row_destinations_valid(destinations: Dictionary) -> bool:
	var destination_cells: Dictionary = {}
	for structure_id in destinations:
		var cell: Vector2i = destinations[structure_id]
		if not arena_layout.is_buildable_cell(cell) or destination_cells.has(cell):
			return false
		destination_cells[cell] = true
		var occupant := get_structure_at_cell(cell, true)
		if occupant != null and not selected_wall_row_ids.has(occupant.structure_id):
			return false
	return true


func _recalculate_layout() -> void:
	var viewport_rect := get_viewport_rect()
	safe_view_rect = Rect2(viewport_rect.position, viewport_rect.size)
	portrait_view = viewport_rect.size.y > viewport_rect.size.x
	if portrait_view:
		_set_structure_visibility(false)
		queue_redraw()
		return
	var available_width := maxf(viewport_rect.size.x - PAGE_MARGIN * 2.0, 1.0)
	var available_height := maxf(viewport_rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT, 1.0)
	fit_cell_size = maxf(minf(
		available_width / float(ArenaLayoutScript.GRID_SIZE.x),
		available_height / float(ArenaLayoutScript.GRID_SIZE.y)
	), 1.0)
	view_zoom = clampf(view_zoom, MIN_VIEW_ZOOM, MAX_VIEW_ZOOM)
	cell_size = fit_cell_size * view_zoom
	var size := Vector2(ArenaLayoutScript.GRID_SIZE) * cell_size
	var usable_rect := _get_usable_view_rect()
	board_origin = Vector2(
		usable_rect.position.x + (usable_rect.size.x - size.x) * 0.5,
		usable_rect.position.y + (usable_rect.size.y - size.y) * 0.5
	)
	_update_board_transform()
	_set_structure_visibility(true)


func reset_view() -> void:
	view_zoom = INITIAL_VIEW_ZOOM
	_recalculate_layout()


func zoom_at_screen_position(screen_position: Vector2, requested_zoom: float) -> void:
	if portrait_view or fit_cell_size <= 0.0:
		return
	var next_zoom := clampf(requested_zoom, MIN_VIEW_ZOOM, MAX_VIEW_ZOOM)
	if is_equal_approx(next_zoom, view_zoom):
		return
	var world_anchor := (screen_position - board_origin) / cell_size
	view_zoom = next_zoom
	cell_size = fit_cell_size * view_zoom
	board_origin = screen_position - world_anchor * cell_size
	_update_board_transform()


func pan_view(screen_delta: Vector2) -> void:
	if portrait_view:
		return
	board_origin += screen_delta
	_update_board_transform()


func _update_board_transform() -> void:
	var size := Vector2(ArenaLayoutScript.GRID_SIZE) * cell_size
	board_origin = _clamp_board_origin(board_origin, size)
	board_rect = Rect2(board_origin, size)
	_update_structure_layout()
	view_transform_changed.emit()
	queue_redraw()


func _get_usable_view_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	return Rect2(
		Vector2(viewport_rect.position.x + PAGE_MARGIN, viewport_rect.position.y + HEADER_HEIGHT),
		Vector2(
			maxf(viewport_rect.size.x - PAGE_MARGIN * 2.0, 1.0),
			maxf(viewport_rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT, 1.0)
		)
	)


func _clamp_board_origin(requested_origin: Vector2, board_size: Vector2) -> Vector2:
	var usable := _get_usable_view_rect()
	var result := requested_origin
	if board_size.x <= usable.size.x:
		result.x = usable.position.x + (usable.size.x - board_size.x) * 0.5
	else:
		result.x = clampf(result.x, usable.end.x - board_size.x, usable.position.x)
	if board_size.y <= usable.size.y:
		result.y = usable.position.y + (usable.size.y - board_size.y) * 0.5
	else:
		result.y = clampf(result.y, usable.end.y - board_size.y, usable.position.y)
	return result


func _build_structures_from_blueprint(blueprint: Array[Dictionary]) -> void:
	for entry in blueprint:
		var structure: Node2D = _create_structure(entry)
		structures.append(structure)
		structures_by_id[structure.structure_id] = structure
	_update_structure_layout()


func _create_structure(entry: Dictionary) -> Node2D:
	var kind := StringName(entry.get("kind", &""))
	assert(StructureCatalogScript.has_kind(kind), "Missing siege structure definition for %s" % kind)
	var level := int(entry.get("level", -1))
	var structure: Node2D = StructureScript.new()
	structure.configure(entry, StructureCatalogScript.get_definition(kind, level))
	structure.structure_destroyed.connect(_on_structure_destroyed)
	structure.structure_restored.connect(_on_structure_restored)
	add_child(structure)
	return structure


func _default_footprint(kind: StringName) -> Vector2i:
	match kind:
		&"command_core": return Vector2i(4, 4)
		&"wall": return Vector2i.ONE
		_: return Vector2i(3, 3)


func _clear_structures() -> void:
	for structure in structures:
		if is_instance_valid(structure):
			remove_child(structure)
			structure.queue_free()
	structures.clear()
	structures_by_id.clear()


func _set_structure_visibility(value: bool) -> void:
	for structure in structures:
		structure.visible = value


func _update_structure_layout() -> void:
	for structure in structures:
		structure.set_layout_metrics(board_origin, cell_size)
	_update_build_preview_structure()


func _on_structure_destroyed(_structure: Node) -> void:
	structure_topology_changed.emit()


func _on_structure_restored(_structure: Node) -> void:
	structure_topology_changed.emit()


func get_structure(structure_id: StringName) -> Node2D:
	return structures_by_id.get(structure_id)


func get_structure_at_cell(cell: Vector2i, include_destroyed := false) -> Node2D:
	for structure in structures:
		if structure.occupies_cell(cell) and (include_destroyed or not structure.destroyed):
			return structure
	return null


func get_structure_blocked_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for structure in structures:
		if structure.destroyed or not structure.blocks_movement:
			continue
		result.append_array(structure.get_occupied_cells())
	return result


func get_navigation_blocked_cells() -> Array[Vector2i]:
	var result := get_structure_blocked_cells()
	for cell in ArenaLayoutScript.STATIC_TERRAIN:
		if not result.has(cell):
			result.append(cell)
	return result


func get_remaining_integrity() -> int:
	var total := 0
	for structure in structures:
		if structure.counts_for_objective and not structure.destroyed:
			total += structure.integrity_value
	return total


func damage_structure(structure_id: StringName, amount: float) -> float:
	var structure := get_structure(structure_id)
	return structure.apply_damage(amount) if structure != null else 0.0


func capture_current_blueprint() -> Array[Dictionary]:
	var captured: Array[Dictionary] = []
	for structure in structures:
		captured.append(structure.get_blueprint_entry())
	blueprint_snapshot = captured.duplicate(true)
	return blueprint_snapshot.duplicate(true)


func get_blueprint_snapshot() -> Array[Dictionary]:
	return blueprint_snapshot.duplicate(true)


func reconstruct_blueprint() -> void:
	_clear_structures()
	_build_structures_from_blueprint(blueprint_snapshot)
	structure_topology_changed.emit()


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	if portrait_view or not board_rect.has_point(screen_position):
		return Vector2i(-1, -1)
	var local_position := screen_position - board_origin
	var cell := Vector2i(floori(local_position.x / cell_size), floori(local_position.y / cell_size))
	return cell if arena_layout.is_inside_grid(cell) else Vector2i(-1, -1)


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size)


func structure_rect(structure: Dictionary) -> Rect2:
	var cell := Vector2i(structure.get("cell", Vector2i.ZERO))
	var footprint := Vector2i(structure.get("footprint", Vector2i.ONE))
	return Rect2(board_origin + Vector2(cell) * cell_size, Vector2(footprint) * cell_size)


func _draw() -> void:
	draw_rect(get_viewport_rect(), COLOR_BACKGROUND, true)
	if portrait_view:
		_draw_rotate_prompt()
		return
	draw_rect(board_rect.grow(6.0), COLOR_BOARD_SHADOW, true)
	_draw_cells()
	_draw_static_terrain()
	_draw_deployment_arrows()
	_draw_labels()
	if edit_mode and selected_structure_id != &"":
		var selected := get_structure(selected_structure_id)
		if selected != null:
			var range_cell: Vector2i = structure_drag_preview_cell if structure_dragging else selected.grid_cell
			_draw_selected_tower_range(selected, range_cell)
			if selected_wall_row_ids.size() > 1:
				for structure_id in selected_wall_row_ids:
					var row_wall := get_structure(structure_id)
					if row_wall == null:
						continue
					var selected_cell: Vector2i = row_wall.grid_cell
					if structure_dragging and wall_row_drag_origin_cells.has(structure_id):
						selected_cell = Vector2i(wall_row_drag_origin_cells[structure_id]) + wall_row_drag_preview_delta
					var selection_rect := cell_rect(selected_cell)
					if structure_dragging:
						var fill := COLOR_HOVER if structure_drag_drop_valid else COLOR_INVALID_BUILD
						var outline := Color("65d66f") if structure_drag_drop_valid else Color("e34b47")
						draw_rect(selection_rect.grow(-1.5), fill, true)
						draw_rect(selection_rect.grow(-1.5), outline, false, maxf(cell_size * 0.10, 2.0))
					else:
						draw_rect(selection_rect.grow(-1.5), COLOR_SELECTED, false, maxf(cell_size * 0.10, 2.0))
			else:
				var selected_cell: Vector2i = structure_drag_preview_cell if structure_dragging else selected.grid_cell
				var selection_rect := Rect2(board_origin + Vector2(selected_cell) * cell_size, Vector2(selected.footprint) * cell_size)
				if structure_dragging:
					var fill := COLOR_HOVER if structure_drag_drop_valid else COLOR_INVALID_BUILD
					var outline := Color("65d66f") if structure_drag_drop_valid else Color("e34b47")
					draw_rect(selection_rect.grow(-1.5), fill, true)
					draw_rect(selection_rect.grow(-1.5), outline, false, maxf(cell_size * 0.10, 2.0))
				else:
					draw_rect(selection_rect.grow(-1.5), COLOR_SELECTED, false, maxf(cell_size * 0.10, 2.0))
	if edit_mode and pending_build_kind != &"" and pending_build_cell.x >= 0 and not is_wall_chain_active():
		var preview_footprint := _default_footprint(pending_build_kind)
		var preview_rect := Rect2(board_origin + Vector2(pending_build_cell) * cell_size, Vector2(preview_footprint) * cell_size)
		var preview_color := COLOR_HOVER if pending_build_valid else COLOR_INVALID_BUILD
		var outline_color := Color("65d66f") if pending_build_valid else Color("e34b47")
		draw_rect(preview_rect.grow(-1.5), preview_color, true)
		draw_rect(preview_rect.grow(-1.5), outline_color, false, maxf(cell_size * 0.10, 2.0))
	if edit_mode and is_wall_chain_active():
		for index in range(1, wall_chain_cells.size()):
			var chain_rect := cell_rect(wall_chain_cells[index]).grow(-1.5)
			draw_rect(chain_rect, COLOR_HOVER, true)
			draw_rect(chain_rect, Color("65d66f"), false, maxf(cell_size * 0.10, 2.0))
		if arena_layout.is_inside_grid(wall_draw_invalid_cell):
			var invalid_rect := cell_rect(wall_draw_invalid_cell).grow(-1.5)
			draw_rect(invalid_rect, COLOR_INVALID_BUILD, true)
			draw_rect(invalid_rect, Color("e34b47"), false, maxf(cell_size * 0.10, 2.0))
	if edit_mode and (is_wall_chain_active() or _selected_structure_is_wall()):
		_draw_wall_extension_arrows()
	if arena_layout.is_inside_grid(hovered_cell):
		draw_rect(cell_rect(hovered_cell).grow(-1.5), COLOR_HOVER, true)


func _draw_selected_tower_range(structure: Node2D, display_cell: Vector2i) -> void:
	if structure.destroyed or not _structure_has_weapon(structure):
		return
	var attack_range := maxf(float(structure.definition.get("attack_range_cells", 0.0)), 0.0)
	if attack_range <= 0.0:
		return
	var center := board_origin + (Vector2(display_cell) + Vector2(structure.footprint) * 0.5) * cell_size
	var outer_radius := attack_range * cell_size
	draw_circle(center, outer_radius, COLOR_RANGE_FILL)
	draw_arc(center, outer_radius, 0.0, TAU, 128, COLOR_RANGE_OUTLINE, maxf(cell_size * 0.065, 1.5), true)
	var minimum_range := maxf(float(structure.definition.get("minimum_range_cells", 0.0)), 0.0)
	if minimum_range <= 0.0:
		return
	var inner_radius := minimum_range * cell_size
	draw_circle(center, inner_radius, COLOR_MIN_RANGE_FILL)
	draw_arc(center, inner_radius, 0.0, TAU, 96, COLOR_MIN_RANGE_OUTLINE, maxf(cell_size * 0.055, 1.25), true)


func _structure_has_weapon(structure: Node2D) -> bool:
	return bool(structure.definition.get("can_attack", false)) or bool(structure.definition.get("is_defense", false))


func _draw_wall_extension_arrows() -> void:
	for cell in get_wall_extension_cells():
		var center := cell_rect(cell).get_center()
		var selected := get_selected_structure()
		var reference_cells: Array[Vector2i] = wall_chain_cells.duplicate()
		if reference_cells.is_empty() and selected != null and selected.kind == &"wall":
			reference_cells.append(selected.grid_cell)
		if reference_cells.is_empty():
			return
		var nearest := reference_cells[0]
		var nearest_distance := 1000000
		for chain_cell in reference_cells:
			var distance := chain_cell.distance_squared_to(cell)
			if distance < nearest_distance:
				nearest = chain_cell
				nearest_distance = distance
		var direction := Vector2(cell - nearest).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var tip := center + direction * cell_size * 0.34
		var back := center - direction * cell_size * 0.22
		var points := PackedVector2Array([
			tip,
			back + perpendicular * cell_size * 0.25,
			back - perpendicular * cell_size * 0.25,
		])
		draw_colored_polygon(points, Color("65d66f"))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("f2efe4"), maxf(cell_size * 0.06, 1.5), true)


func _selected_structure_is_wall() -> bool:
	var selected := get_selected_structure()
	return selected != null and selected.kind == &"wall" and not selected.destroyed


func _tap_drag_threshold() -> float:
	var viewport_size := get_viewport_rect().size
	return maxf(BASE_TAP_DRAG_THRESHOLD, minf(viewport_size.x, viewport_size.y) * 0.018)


func _draw_cells() -> void:
	for x in ArenaLayoutScript.GRID_SIZE.x:
		for y in ArenaLayoutScript.GRID_SIZE.y:
			var cell := Vector2i(x, y)
			var alternating := (x + y) % 2 == 0
			var color := COLOR_CELL_A if alternating else COLOR_CELL_B
			if arena_layout.is_deployment_cell(cell):
				color = COLOR_DEPLOYMENT_A if alternating else COLOR_DEPLOYMENT_B
			elif x < ArenaLayoutScript.DEPLOYMENT_COLUMNS + ArenaLayoutScript.BUILD_BUFFER_COLUMNS:
				color = COLOR_BUFFER_A if alternating else COLOR_BUFFER_B
			draw_rect(cell_rect(cell), color, true)
			draw_rect(cell_rect(cell), COLOR_GRID, false, maxf(cell_size * 0.025, 1.0))


func _draw_static_terrain() -> void:
	for cell in ArenaLayoutScript.STATIC_TERRAIN:
		var rect := cell_rect(cell).grow(-cell_size * 0.13)
		var points := PackedVector2Array([
			Vector2(rect.position.x + rect.size.x * 0.16, rect.position.y + rect.size.y * 0.72),
			Vector2(rect.position.x + rect.size.x * 0.30, rect.position.y + rect.size.y * 0.25),
			Vector2(rect.position.x + rect.size.x * 0.68, rect.position.y + rect.size.y * 0.12),
			Vector2(rect.position.x + rect.size.x * 0.90, rect.position.y + rect.size.y * 0.58),
			Vector2(rect.position.x + rect.size.x * 0.70, rect.position.y + rect.size.y * 0.88),
		])
		draw_colored_polygon(points, COLOR_TERRAIN)
		draw_polyline(points, COLOR_GRID, maxf(cell_size * 0.045, 1.0), true)


func _draw_deployment_arrows() -> void:
	var arrow_color := Color("ef624d")
	for y in [3, 12, 21, 30, 39]:
		var center := cell_rect(Vector2i(0, y)).get_center()
		var start := Vector2(maxf(board_origin.x - cell_size * 0.55, 4.0), center.y)
		var end := Vector2(board_origin.x + cell_size * 0.70, center.y)
		draw_line(start, end, arrow_color, maxf(cell_size * 0.075, 2.0), true)
		draw_line(end, end + Vector2(-cell_size * 0.20, -cell_size * 0.14), arrow_color, maxf(cell_size * 0.075, 2.0), true)
		draw_line(end, end + Vector2(-cell_size * 0.20, cell_size * 0.14), arrow_color, maxf(cell_size * 0.075, 2.0), true)


func _draw_labels() -> void:
	var small_size := clampi(roundi(cell_size * 0.27), 10, 16)
	var footer_y := board_rect.end.y + minf(FOOTER_HEIGHT * 0.62, 28.0)
	draw_string(title_font, Vector2(board_rect.position.x, footer_y), "ENEMY FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, Color("ef624d"))
	draw_string(title_font, Vector2(board_rect.get_center().x - cell_size * 3.0, footer_y), "44×44 CLASH BUILD AREA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, COLOR_MUTED_TEXT)
	draw_string(title_font, Vector2(board_rect.end.x - cell_size * 2.2, footer_y), "FORTRESS DEPTH →", HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, COLOR_CORE)


func _draw_rotate_prompt() -> void:
	var viewport_rect := get_viewport_rect()
	var font_size := clampi(roundi(viewport_rect.size.x * 0.05), 18, 30)
	draw_string(title_font, viewport_rect.get_center() + Vector2(-viewport_rect.size.x * 0.34, 0.0), "Rotate to landscape to view the siege arena.", HORIZONTAL_ALIGNMENT_CENTER, viewport_rect.size.x * 0.68, font_size, COLOR_TEXT)
