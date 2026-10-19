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
const TAP_DRAG_THRESHOLD := 12.0

const PAGE_MARGIN := 28.0
const HEADER_HEIGHT := 92.0
const FOOTER_HEIGHT := 78.0
const MIN_VIEW_ZOOM := 0.82
const MAX_VIEW_ZOOM := 2.5
const INITIAL_VIEW_ZOOM := 1.35
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
var mouse_press_position := Vector2.ZERO
var mouse_moved := false
var touch_points: Dictionary = {}
var touch_start_positions: Dictionary = {}
var touch_moved: Dictionary = {}
var edit_mode := true
var selected_structure_id: StringName
var pending_build_kind: StringName
var pending_build_cell := Vector2i(-1, -1)
var pending_build_valid := false
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
				mouse_dragging = true
				mouse_press_position = event.position
				mouse_moved = false
			else:
				mouse_dragging = false
				if not mouse_moved:
					_handle_edit_tap(event.position)
			_update_hover(event.position)
	elif event is InputEventMouseMotion:
		if mouse_dragging:
			if event.position.distance_to(mouse_press_position) > TAP_DRAG_THRESHOLD:
				mouse_moved = true
			pan_view(event.relative)
			get_viewport().set_input_as_handled()
		else:
			_update_hover(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			touch_start_positions[event.index] = event.position
			touch_moved[event.index] = false
		else:
			var was_tap := not bool(touch_moved.get(event.index, true)) and touch_points.size() == 1
			touch_points.erase(event.index)
			touch_start_positions.erase(event.index)
			touch_moved.erase(event.index)
			if was_tap:
				_handle_edit_tap(event.position)
		_update_hover(event.position)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)
		get_viewport().set_input_as_handled()


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	var old_points := touch_points.duplicate()
	touch_points[event.index] = event.position
	if event.position.distance_to(Vector2(touch_start_positions.get(event.index, event.position))) > TAP_DRAG_THRESHOLD:
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
		selected_structure_id = &""
		pending_build_kind = &""
		pending_build_cell = Vector2i(-1, -1)
		pending_build_valid = false
		selected_structure_changed.emit(null)
	queue_redraw()


func is_edit_mode() -> bool:
	return edit_mode


func _handle_edit_tap(screen_position: Vector2) -> void:
	if not edit_mode:
		return
	var cell := screen_to_cell(screen_position)
	if not arena_layout.is_inside_grid(cell):
		return
	if pending_build_kind != &"":
		if preview_build_at_cell(cell):
			edit_status_changed.emit("Position ready · tap the green check to build")
		else:
			edit_status_changed.emit("That position is blocked or outside the build area")
		return
	var tapped_structure := get_structure_at_cell(cell, true)
	if tapped_structure != null:
		selected_structure_id = tapped_structure.structure_id
		selected_structure_changed.emit(tapped_structure)
		edit_status_changed.emit("%s selected · tap an empty cell to move it" % String(tapped_structure.definition.get("display_name", tapped_structure.kind)))
		queue_redraw()
		return
	if selected_structure_id == &"":
		edit_status_changed.emit("Tap a building or wall, then tap its new position")
		return
	if try_move_structure(selected_structure_id, cell):
		var moved := get_structure(selected_structure_id)
		edit_status_changed.emit("%s moved · layout saved" % String(moved.definition.get("display_name", moved.kind)))
	else:
		edit_status_changed.emit("That position is blocked or outside the build area")


func begin_build(kind: StringName) -> void:
	pending_build_kind = kind
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	selected_structure_id = &""
	selected_structure_changed.emit(null)
	build_preview_changed.emit(kind, pending_build_cell, false)
	edit_status_changed.emit("Place %s on an empty build tile" % String(StructureCatalogScript.get_definition(kind, 1).get("display_name", kind)))
	queue_redraw()


func cancel_build() -> void:
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	build_preview_changed.emit(&"", pending_build_cell, false)
	queue_redraw()


func confirm_pending_build() -> bool:
	if pending_build_kind == &"" or pending_build_cell.x < 0 or not pending_build_valid:
		return false
	var kind := pending_build_kind
	var cell := pending_build_cell
	if not try_add_structure(kind, cell, 1):
		return false
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	build_preview_changed.emit(&"", pending_build_cell, false)
	queue_redraw()
	return true


func preview_build_at_cell(cell: Vector2i) -> bool:
	if pending_build_kind == &"" or not arena_layout.is_inside_grid(cell):
		return false
	pending_build_cell = cell
	pending_build_valid = can_place_structure(pending_build_kind, cell)
	build_preview_changed.emit(pending_build_kind, cell, pending_build_valid)
	queue_redraw()
	return pending_build_valid


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
	selected_structure_id = structure.structure_id
	capture_current_blueprint()
	structure_topology_changed.emit()
	selected_structure_changed.emit(structure)
	structure_added.emit(structure)
	edit_status_changed.emit("%s built · select it to upgrade" % String(structure.definition.get("display_name", kind)))
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
	selected_structure_id = &""
	pending_build_kind = &""
	pending_build_cell = Vector2i(-1, -1)
	pending_build_valid = false
	_build_structures_from_blueprint(blueprint)
	if capture:
		blueprint_snapshot = blueprint.duplicate(true)
	structure_topology_changed.emit()
	selected_structure_changed.emit(null)
	queue_redraw()


func try_move_structure(structure_id: StringName, destination: Vector2i) -> bool:
	if not edit_mode:
		return false
	var structure := get_structure(structure_id)
	if structure == null or structure.destroyed:
		return false
	for x in structure.footprint.x:
		for y in structure.footprint.y:
			var cell := destination + Vector2i(x, y)
			if not arena_layout.is_buildable_cell(cell):
				return false
			var occupant := get_structure_at_cell(cell, true)
			if occupant != null and occupant != structure:
				return false
	structure.grid_cell = destination
	structure.set_layout_metrics(board_origin, cell_size)
	capture_current_blueprint()
	structure_topology_changed.emit()
	queue_redraw()
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
			draw_rect(Rect2(board_origin + Vector2(selected.grid_cell) * cell_size, Vector2(selected.footprint) * cell_size).grow(-1.5), COLOR_SELECTED, false, maxf(cell_size * 0.10, 2.0))
	if edit_mode and pending_build_kind != &"" and pending_build_cell.x >= 0:
		var preview_footprint := _default_footprint(pending_build_kind)
		var preview_rect := Rect2(board_origin + Vector2(pending_build_cell) * cell_size, Vector2(preview_footprint) * cell_size)
		var preview_color := COLOR_HOVER if pending_build_valid else COLOR_INVALID_BUILD
		var outline_color := Color("65d66f") if pending_build_valid else Color("e34b47")
		draw_rect(preview_rect.grow(-1.5), preview_color, true)
		draw_rect(preview_rect.grow(-1.5), outline_color, false, maxf(cell_size * 0.10, 2.0))
	if arena_layout.is_inside_grid(hovered_cell):
		draw_rect(cell_rect(hovered_cell).grow(-1.5), COLOR_HOVER, true)


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
