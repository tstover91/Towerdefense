class_name SiegePrototypeBoard
extends Node2D

const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")
const StructureScript = preload("res://siege_prototype/siege_structure.gd")

signal structure_topology_changed

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

const PAGE_MARGIN := 28.0
const HEADER_HEIGHT := 92.0
const FOOTER_HEIGHT := 48.0

var arena_layout: RefCounted
var board_origin := Vector2.ZERO
var board_rect := Rect2()
var safe_view_rect := Rect2()
var cell_size := 48.0
var portrait_view := false
var hovered_cell := Vector2i(-1, -1)
var title_font: Font
var structures: Array[Node2D] = []
var structures_by_id: Dictionary = {}
var blueprint_snapshot: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arena_layout = ArenaLayoutScript.new()
	title_font = ThemeDB.fallback_font
	blueprint_snapshot = arena_layout.get_initial_blueprint()
	_build_structures_from_blueprint(blueprint_snapshot)
	get_viewport().size_changed.connect(_recalculate_layout)
	_recalculate_layout()


func _input(event: InputEvent) -> void:
	if portrait_view:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventScreenDrag:
		_update_hover(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_update_hover(event.position)


func _update_hover(screen_position: Vector2) -> void:
	var next_cell := screen_to_cell(screen_position)
	if next_cell == hovered_cell:
		return
	hovered_cell = next_cell
	queue_redraw()


func _recalculate_layout() -> void:
	var viewport_rect := get_viewport_rect()
	safe_view_rect = Rect2(viewport_rect.position, viewport_rect.size)
	portrait_view = viewport_rect.size.y > viewport_rect.size.x
	if portrait_view:
		_set_structure_visibility(false)
		queue_redraw()
		return
	var available_width := maxf(viewport_rect.size.x - PAGE_MARGIN * 2.0, 1.0)
	var available_height := maxf(viewport_rect.size.y - HEADER_HEIGHT - FOOTER_HEIGHT - PAGE_MARGIN, 1.0)
	cell_size = maxf(minf(
		available_width / float(ArenaLayoutScript.GRID_SIZE.x),
		available_height / float(ArenaLayoutScript.GRID_SIZE.y)
	), 1.0)
	var size := Vector2(ArenaLayoutScript.GRID_SIZE) * cell_size
	board_origin = Vector2(
		viewport_rect.position.x + (viewport_rect.size.x - size.x) * 0.5,
		viewport_rect.position.y + HEADER_HEIGHT + (available_height - size.y) * 0.5
	)
	board_rect = Rect2(board_origin, size)
	_set_structure_visibility(true)
	_update_structure_layout()
	queue_redraw()


func _build_structures_from_blueprint(blueprint: Array[Dictionary]) -> void:
	for entry in blueprint:
		var kind := StringName(entry.get("kind", &""))
		assert(StructureCatalogScript.has_kind(kind), "Missing siege structure definition for %s" % kind)
		var structure: Node2D = StructureScript.new()
		structure.configure(entry, StructureCatalogScript.get_definition(kind))
		structure.structure_destroyed.connect(_on_structure_destroyed)
		structure.structure_restored.connect(_on_structure_restored)
		add_child(structure)
		structures.append(structure)
		structures_by_id[structure.structure_id] = structure
	_update_structure_layout()


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
	for y in [1, 3, 5, 7, 9]:
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
	draw_string(title_font, Vector2(board_rect.get_center().x - cell_size * 1.1, footer_y), "FIXED TEST ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, COLOR_MUTED_TEXT)
	draw_string(title_font, Vector2(board_rect.end.x - cell_size * 2.2, footer_y), "FORTRESS DEPTH →", HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, COLOR_CORE)


func _draw_rotate_prompt() -> void:
	var viewport_rect := get_viewport_rect()
	var font_size := clampi(roundi(viewport_rect.size.x * 0.05), 18, 30)
	draw_string(title_font, viewport_rect.get_center() + Vector2(-viewport_rect.size.x * 0.34, 0.0), "Rotate to landscape to view the siege arena.", HORIZONTAL_ALIGNMENT_CENTER, viewport_rect.size.x * 0.68, font_size, COLOR_TEXT)
