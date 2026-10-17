class_name PrototypeGridBoard
extends Node2D

const GridRouterScript = preload("res://prototype/grid_route_service.gd")
const MapLayoutGeneratorScript = preload("res://prototype/prototype_map_layout_generator.gd")
const EnemyScript = preload("res://prototype/prototype_enemy.gd")
const TowerScript = preload("res://prototype/prototype_tower.gd")
const UIOverlayScript = preload("res://prototype/prototype_ui_overlay.gd")

signal start_wave_requested
signal enemy_resolved(leaked: bool, leak_damage: int)
signal enemies_added(count: int)
signal enemy_spawned_for_stats(enemy_type: StringName, max_health: int, director_threat: int)
signal enemy_resolved_for_stats(leaked: bool, leak_damage: int, progress_ratio: float)
signal tower_damage_recorded(tower_type: StringName, tower_level: int, amount: int)
signal structure_action_recorded(action: StringName, tower_type: StringName, tower_level: int, amount: int)
signal export_stats_requested
signal new_map_requested

const GRID_SIZE := Vector2i(19, 10)
const GRID_MARGIN := 18.0
const WAVE_REWARD_MESSAGE_DURATION_MSEC := 3500
const PLACEMENT_DRAG_THRESHOLD := 18.0
const PLACEMENT_FINGER_OFFSET_CELLS := Vector2(-0.55, -1.25)
const MAP_SEED_OVERRIDE_SETTING := "prototype/map_seed_override"

enum PlacementMode {
	NONE,
	PRECISION,
	DRAGGING,
}

const BUILD_GUNSLINGER: StringName = &"gunslinger"
const BUILD_ANTI_MATERIEL: StringName = &"anti_materiel"
const BUILD_FLAMESPITTER: StringName = &"flamespitter"
const BUILD_BOMBARDMENT: StringName = &"bombardment"
const BUILD_ATOMIC_STRIKE: StringName = &"atomic_strike"
const BUILD_WALL: StringName = &"wall"

const FALLBACK_ENTRANCE := Vector2i(0, 5)
const FALLBACK_WAYPOINTS: Array[Vector2i] = [
	Vector2i(5, 1),
	Vector2i(10, 8),
	Vector2i(14, 2),
]
const FALLBACK_EXIT_CELL := Vector2i(18, 5)
const STATIC_OBJECTS: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(7, 4),
	Vector2i(11, 5),
	Vector2i(12, 5),
	Vector2i(15, 7),
	Vector2i(4, 7),
	Vector2i(17, 8),
]

const COLOR_BACKGROUND := Color("131313")
const COLOR_BOARD := Color("202020")
const COLOR_CELL_A := Color("ddddcf")
const COLOR_CELL_B := Color("d2d2c4")
const COLOR_GRID := Color("5b5b55")
const COLOR_PATH_SHADOW := Color(0.05, 0.05, 0.05, 0.72)
const COLOR_PATH := Color("efb83d")
const COLOR_PATH_CANDIDATE_PREVIEW := Color(0.20, 0.72, 0.42, 0.72)
const COLOR_TOWER := Color("e84f3d")
const COLOR_TOWER_BORDER := Color("171717")
const COLOR_OBJECT := Color("4b4b48")
const COLOR_OBJECT_DETAIL := Color("999990")
const COLOR_WALL := Color("565653")
const COLOR_WALL_LIGHT := Color("8e8e87")
const COLOR_VALID := Color(0.20, 0.72, 0.42, 0.55)
const COLOR_INVALID := Color(0.92, 0.18, 0.16, 0.60)
const COLOR_TEXT := Color("f2efe4")
const COLOR_MUTED_TEXT := Color("b9b6ac")
const MARKER_COLORS: Array[Color] = [
	Color("51d0d9"),
	Color("e66c44"),
	Color("9d70d7"),
	Color("6fbf64"),
	Color("f2d35d"),
]

var router = null
var map_seed := 0
var entrance := FALLBACK_ENTRANCE
var waypoints: Array[Vector2i] = FALLBACK_WAYPOINTS.duplicate()
var exit_cell := FALLBACK_EXIT_CELL
var initial_route_steps := 0
var displayed_route: Array[Vector2i] = []
var preview_route: Array[Vector2i] = []
var hovered_cell := Vector2i(-1, -1)
var preview_is_valid := false
var board_origin := Vector2.ZERO
var cell_size := 48.0
var title_font: Font
var ui_overlay: Node2D
var gunslinger_button_rect := Rect2()
var anti_materiel_button_rect := Rect2()
var flamespitter_button_rect := Rect2()
var bombardment_button_rect := Rect2()
var atomic_strike_button_rect := Rect2()
var wall_button_rect := Rect2()
var start_button_rect := Rect2()
var upgrade_button_rect := Rect2()
var sell_button_rect := Rect2()
var export_button_rect := Rect2()
var new_map_button_rect := Rect2()
var cancel_button_rect := Rect2()
var selection_info_rect := Rect2()
var header_cancel_button_rect := Rect2()
var tools_button_rect := Rect2()
var wave_progress_rect := Rect2()
var selection_panel_rect := Rect2()
var safe_view_rect := Rect2()
var portrait_view := false
var compact_layout := false
var status_message := "Tap an empty cell to build a tower."
var status_override := ""
var status_override_expires_msec := 0
var active_followers: Array[Node2D] = []
var towers_by_cell: Dictionary = {}
var walls_by_cell: Dictionary = {}
var selected_tower: Node2D
var selected_wall_cell := Vector2i(-1, -1)
var tools_menu_open := false
var last_touch_press_msec := -1000
var placement_mode := PlacementMode.NONE
var placement_kind: StringName = &""
var precision_cell := Vector2i(-1, -1)
var placement_pointer_index := -2
var placement_press_position := Vector2.ZERO
var placement_drag_armed := false
var placement_drag_over_cancel := false
var placement_rejection_reasons: Dictionary = {}
var placement_pause_active := false
var economy = null
var economy_state: Dictionary = {
	"credits": 500,
	"used_power": 0,
	"power_limit": 4,
	"used_walls": 0,
	"wall_limit": 5,
	"interest": 15,
	"interest_locked": false,
}
var combat_state: Dictionary = {
	"phase": &"build",
	"displayed_wave": 1,
	"max_waves": 20,
	"lives": 20,
	"active_enemies": 0,
	"remaining_spawns": 0,
	"wave_progress": 0.0,
}


func _ready() -> void:
	# Placement must remain interactive while the rest of the combat tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	router = GridRouterScript.new()
	map_seed = _create_map_seed()
	var layout: Dictionary = MapLayoutGeneratorScript.new().generate(
		map_seed,
		GRID_SIZE,
		STATIC_OBJECTS
	)
	if not layout.is_empty():
		entrance = Vector2i(layout["entrance"])
		waypoints.assign(layout["waypoints"])
		exit_cell = Vector2i(layout["exit_cell"])
	router.configure(GRID_SIZE, entrance, waypoints, exit_cell, STATIC_OBJECTS)
	title_font = ThemeDB.fallback_font
	ui_overlay = UIOverlayScript.new()
	add_child(ui_overlay)
	ui_overlay.configure(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_recalculate_layout()
	displayed_route = router.find_complete_route(entrance)
	initial_route_steps = maxi(displayed_route.size() - 1, 0)
	queue_redraw()


func _exit_tree() -> void:
	_set_placement_pause(false)


func _process(_delta: float) -> void:
	if (
		not status_override.is_empty()
		and Time.get_ticks_msec() >= status_override_expires_msec
	):
		status_override = ""
		queue_redraw()


func _input(event: InputEvent) -> void:
	if portrait_view:
		return
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_motion(event.position, event.index)
	elif event is InputEventMouseMotion:
		if placement_drag_armed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_handle_drag_motion(event.position, -1)
		elif placement_mode == PlacementMode.PRECISION:
			_update_preview(_screen_to_cell(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if OS.has_feature("mobile") and Time.get_ticks_msec() - last_touch_press_msec <= 250:
			return
		_handle_mouse_button(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_request_start_wave()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BACKGROUND)
	if portrait_view:
		_draw_landscape_required()
		return
	_draw_board()
	if placement_mode != PlacementMode.NONE and preview_is_valid:
		# Previewing is visual only. Keep the committed route prominent so active
		# enemies never appear to leave the path they are actually following.
		_draw_route(displayed_route, COLOR_PATH)
		_draw_route_preview(preview_route, COLOR_PATH_CANDIDATE_PREVIEW)
	else:
		_draw_route(displayed_route, COLOR_PATH)
	_draw_static_objects()
	_draw_walls()
	_draw_route_markers()
	_draw_placement_preview()


func draw_ui_overlay() -> void:
	if portrait_view:
		return
	_draw_header()
	_draw_footer_controls()


func _draw_header() -> void:
	var inset := 10.0
	var lives_width := 64.0 if compact_layout else 78.0
	var resource_width := 140.0 if compact_layout else 176.0
	var lives_rect := Rect2(safe_view_rect.position + Vector2(inset, inset), Vector2(lives_width, 54.0))
	var resource_rect := Rect2(Vector2(lives_rect.end.x + 6.0, lives_rect.position.y), Vector2(resource_width, 54.0))
	for card in [lives_rect, resource_rect]:
		ui_overlay.draw_rect(card, Color(0.055, 0.055, 0.055, 0.94), true)
		ui_overlay.draw_rect(card, COLOR_TEXT, false, 2.0)
	ui_overlay.draw_string(title_font, lives_rect.position + Vector2(10.0, 18.0), "LIVES", HORIZONTAL_ALIGNMENT_LEFT, lives_rect.size.x - 20.0, 10, COLOR_MUTED_TEXT)
	ui_overlay.draw_string(title_font, lives_rect.position + Vector2(10.0, 43.0), str(int(combat_state.get("lives", 20))), HORIZONTAL_ALIGNMENT_LEFT, lives_rect.size.x - 20.0, 24, COLOR_TEXT)
	var economy_heading := "$%d  ·  +$%d%s" % [
		int(economy_state.get("credits", 0)),
		int(economy_state.get("interest", 0)),
		" LOCKED" if bool(economy_state.get("interest_locked", false)) else "",
	]
	var capacity_text := "POWER %d/%d  ·  WALLS %d/%d" % [
		int(economy_state.get("used_power", 0)),
		int(economy_state.get("power_limit", 0)),
		int(economy_state.get("used_walls", 0)),
		int(economy_state.get("wall_limit", 0)),
	]
	ui_overlay.draw_string(title_font, resource_rect.position + Vector2(10.0, 21.0), economy_heading, HORIZONTAL_ALIGNMENT_LEFT, resource_rect.size.x - 20.0, 15, COLOR_TEXT)
	ui_overlay.draw_string(title_font, resource_rect.position + Vector2(8.0, 42.0), capacity_text, HORIZONTAL_ALIGNMENT_LEFT, resource_rect.size.x - 16.0, 9 if compact_layout else 10, COLOR_MUTED_TEXT)

	var wave_card := Rect2(Vector2(wave_progress_rect.position.x - 10.0, safe_view_rect.position.y + inset), Vector2(wave_progress_rect.size.x + 20.0, 54.0))
	ui_overlay.draw_rect(wave_card, Color(0.055, 0.055, 0.055, 0.92), true)
	ui_overlay.draw_rect(wave_card, COLOR_TOWER_BORDER, false, 2.0)
	var wave_text := "WAVE %d / %d" % [int(combat_state.get("displayed_wave", 1)), int(combat_state.get("max_waves", 10))]
	var phase_text := ("PLACING · PAUSED" if placement_pause_active else "PLACING") if placement_mode != PlacementMode.NONE else String(combat_state.get("phase", &"build")).to_upper()
	ui_overlay.draw_string(title_font, wave_card.position + Vector2(10.0, 21.0), wave_text, HORIZONTAL_ALIGNMENT_CENTER, wave_card.size.x - 20.0, 15, COLOR_TEXT)
	ui_overlay.draw_string(title_font, wave_card.position + Vector2(10.0, 40.0), phase_text, HORIZONTAL_ALIGNMENT_CENTER, wave_card.size.x - 20.0, 10, COLOR_MUTED_TEXT)
	ui_overlay.draw_rect(wave_progress_rect, Color("454540"), true)
	var wave_progress := float(combat_state.get("wave_progress", 0.0))
	ui_overlay.draw_rect(Rect2(wave_progress_rect.position, Vector2(wave_progress_rect.size.x * clampf(wave_progress, 0.0, 1.0), wave_progress_rect.size.y)), COLOR_PATH, true)

	var phase := StringName(combat_state.get("phase", &"build"))
	_draw_button(start_button_rect, "START", phase == &"build")
	_draw_header_action(tools_button_rect, "TOOLS")
	if placement_mode != PlacementMode.NONE:
		var placement_card := Rect2(resource_rect.position.x, resource_rect.end.y + 5.0, resource_rect.size.x, 30.0)
		ui_overlay.draw_rect(placement_card, Color(0.055, 0.055, 0.055, 0.94), true)
		ui_overlay.draw_rect(placement_card, COLOR_PATH, false, 2.0)
		ui_overlay.draw_string(title_font, placement_card.position + Vector2(8.0, 20.0), _get_active_build_label(), HORIZONTAL_ALIGNMENT_LEFT, header_cancel_button_rect.position.x - placement_card.position.x - 12.0, 10, COLOR_PATH)
		_draw_header_action(header_cancel_button_rect, "X")
	if tools_menu_open:
		_draw_floating_panel(Rect2(export_button_rect.position - Vector2(6.0, 6.0), Vector2(export_button_rect.size.x + 12.0, new_map_button_rect.end.y - export_button_rect.position.y + 12.0)))
		_draw_button(export_button_rect, "STATS", true)
		_draw_button(new_map_button_rect, "NEW MAP", true)


func _draw_header_action(rect: Rect2, label: String) -> void:
	ui_overlay.draw_rect(rect, Color("efeade"), true)
	ui_overlay.draw_rect(rect, COLOR_TOWER_BORDER, false, 2.0)
	var text_size := title_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10)
	ui_overlay.draw_string(title_font, rect.get_center() - Vector2(text_size.x * 0.5, -text_size.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, COLOR_TOWER_BORDER)


func _get_active_build_label() -> String:
	if placement_kind == BUILD_WALL:
		return "WALL ACTIVE"
	return "%s ACTIVE" % TowerScript.get_type_name(_tower_type_for_build_kind(placement_kind))


func _draw_landscape_required() -> void:
	var viewport_size := get_viewport_rect().size
	var heading := "ROTATE TO LANDSCAPE"
	var detail := "The gameplay grid always uses 19 × 10 tiles."
	var heading_size := title_font.get_string_size(
		heading, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26
	)
	var detail_size := title_font.get_string_size(
		detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15
	)
	draw_string(
		title_font,
		Vector2((viewport_size.x - heading_size.x) * 0.5, viewport_size.y * 0.47),
		heading,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		26,
		COLOR_TEXT
	)
	draw_string(
		title_font,
		Vector2((viewport_size.x - detail_size.x) * 0.5, viewport_size.y * 0.54),
		detail,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		COLOR_MUTED_TEXT
	)


func _draw_board() -> void:
	var board_size := Vector2(GRID_SIZE) * cell_size
	draw_rect(
		Rect2(board_origin - Vector2.ONE * 5.0, board_size + Vector2.ONE * 10.0),
		COLOR_BOARD,
		true
	)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell := Vector2i(x, y)
			var color := COLOR_CELL_A if (x + y) % 2 == 0 else COLOR_CELL_B
			draw_rect(_cell_rect(cell).grow(-1.0), color, true)
	for x in range(GRID_SIZE.x + 1):
		var line_x := board_origin.x + float(x) * cell_size
		draw_line(
			Vector2(line_x, board_origin.y),
			Vector2(line_x, board_origin.y + board_size.y),
			COLOR_GRID,
			1.0
		)
	for y in range(GRID_SIZE.y + 1):
		var line_y := board_origin.y + float(y) * cell_size
		draw_line(
			Vector2(board_origin.x, line_y),
			Vector2(board_origin.x + board_size.x, line_y),
			COLOR_GRID,
			1.0
		)


func _draw_route(route: Array[Vector2i], path_color: Color) -> void:
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in route:
		points.append(_cell_center(cell))
	var shadow_color := COLOR_PATH_SHADOW
	shadow_color.a *= clampf(path_color.a * 1.5, 0.25, 1.0)
	draw_polyline(points, shadow_color, maxf(cell_size * 0.24, 7.0), true)
	draw_polyline(points, path_color, maxf(cell_size * 0.10, 3.0), true)


func _draw_route_preview(route: Array[Vector2i], path_color: Color) -> void:
	if route.size() < 2:
		return
	var line_width := maxf(cell_size * 0.055, 2.0)
	for index in range(1, route.size()):
		var start := _cell_center(route[index - 1])
		var finish := _cell_center(route[index])
		var segment := finish - start
		var segment_length := segment.length()
		if segment_length <= 0.01:
			continue
		var direction := segment / segment_length
		var dash_length := cell_size * 0.28
		var gap_length := cell_size * 0.16
		var cursor := 0.0
		while cursor < segment_length:
			var dash_end := minf(cursor + dash_length, segment_length)
			draw_line(start + direction * cursor, start + direction * dash_end, path_color, line_width, true)
			cursor += dash_length + gap_length


func _draw_static_objects() -> void:
	for cell in router.static_blocks:
		var rect := _cell_rect(cell).grow(-cell_size * 0.12)
		draw_rect(rect, COLOR_OBJECT, true)
		draw_rect(rect, COLOR_TOWER_BORDER, false, 2.0)
		draw_line(rect.position, rect.end, COLOR_OBJECT_DETAIL, 2.0, true)
		draw_line(
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y),
			COLOR_OBJECT_DETAIL,
			2.0,
			true
		)


func _draw_walls() -> void:
	for cell in walls_by_cell:
		var rect := _cell_rect(cell).grow(-cell_size * 0.10)
		draw_rect(rect, COLOR_WALL, true)
		draw_rect(rect, COLOR_TOWER_BORDER, false, maxf(cell_size * 0.05, 2.0))
		var inset := rect.grow(-cell_size * 0.14)
		draw_rect(inset, COLOR_WALL_LIGHT, false, maxf(cell_size * 0.04, 2.0))
		if cell == selected_wall_cell:
			draw_rect(rect.grow(3.0), COLOR_PATH, false, 3.0)


func _draw_route_markers() -> void:
	var markers: Array[Vector2i] = router.get_route_markers()
	var labels := ["IN", "1", "2", "3", "OUT"]
	for index in markers.size():
		var center := _cell_center(markers[index])
		var radius := cell_size * 0.29
		draw_circle(center, radius, COLOR_BOARD)
		draw_arc(center, radius, 0.0, TAU, 28, MARKER_COLORS[index], 3.0, true)
		var text_size := title_font.get_string_size(
			labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12
		)
		draw_string(
			title_font,
			center - Vector2(text_size.x * 0.5, -text_size.y * 0.32),
			labels[index],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			MARKER_COLORS[index]
		)


func _draw_placement_preview() -> void:
	if placement_mode == PlacementMode.NONE or not _is_gameplay_phase():
		return
	if not router.is_inside_grid(hovered_cell):
		return
	if router.dynamic_blocks.has(hovered_cell):
		return
	var center := _cell_center(hovered_cell)
	if _is_tower_kind(placement_kind):
		var range_cells := TowerScript.get_base_range(_tower_type_for_build_kind(placement_kind))
		draw_circle(
			center,
			range_cells * cell_size,
			Color(0.20, 0.72, 0.42, 0.10) if preview_is_valid else Color(0.92, 0.18, 0.16, 0.10)
		)
	var cell_rect := _cell_rect(hovered_cell).grow(-cell_size * 0.06)
	draw_rect(cell_rect, COLOR_VALID if preview_is_valid else COLOR_INVALID, false, 3.0)
	var tower_rect := _cell_rect(hovered_cell).grow(-cell_size * 0.14)
	var ghost_color := (
		COLOR_WALL
		if placement_kind == BUILD_WALL
		else Color(TowerScript.TYPE_DATA[_tower_type_for_build_kind(placement_kind)]["color"])
	)
	if not preview_is_valid:
		ghost_color = Color("d52f2f")
	ghost_color.a = 0.78
	draw_rect(tower_rect, ghost_color, true)
	draw_rect(tower_rect, COLOR_TOWER_BORDER, false, 2.0)
	if _is_tower_kind(placement_kind):
		draw_circle(center, cell_size * 0.15, Color(0.95, 0.92, 0.84, 0.86))
	else:
		draw_rect(tower_rect.grow(-cell_size * 0.14), COLOR_WALL_LIGHT, false, 2.0)


func _draw_footer_controls() -> void:
	if placement_mode == PlacementMode.NONE:
		var deck_rect := Rect2(
			Vector2(flamespitter_button_rect.position.x - 8.0, gunslinger_button_rect.position.y - 8.0),
			Vector2(atomic_strike_button_rect.end.x - flamespitter_button_rect.position.x + 16.0, atomic_strike_button_rect.end.y - gunslinger_button_rect.position.y + 16.0)
		)
		_draw_floating_panel(deck_rect)
		_draw_floating_panel(wall_button_rect.grow(8.0))
		_draw_build_button(gunslinger_button_rect, BUILD_GUNSLINGER, "GUN")
		_draw_build_button(anti_materiel_button_rect, BUILD_ANTI_MATERIEL, "ANTI")
		_draw_build_button(flamespitter_button_rect, BUILD_FLAMESPITTER, "FLAME")
		_draw_build_button(bombardment_button_rect, BUILD_BOMBARDMENT, "BOMB")
		_draw_build_button(atomic_strike_button_rect, BUILD_ATOMIC_STRIKE, "ATOMIC")
		_draw_build_button(wall_button_rect, BUILD_WALL, "WALL")
	if is_instance_valid(selected_tower) or selected_wall_cell.x >= 0:
		_update_selection_panel_layout()
		_draw_floating_panel(selection_panel_rect)
		_draw_selection_info()
		if is_instance_valid(selected_tower):
			_draw_button(upgrade_button_rect, _get_upgrade_button_label(), _can_afford_selected_upgrade())
			_draw_button(sell_button_rect, _get_sell_button_label(), _is_gameplay_phase())
		else:
			_draw_button(upgrade_button_rect, _get_sell_button_label(), _is_gameplay_phase())
	if placement_mode == PlacementMode.DRAGGING:
		_draw_floating_panel(cancel_button_rect.grow(8.0))
		_draw_button(cancel_button_rect, "X", true)
	var displayed_status := status_override
	if displayed_status.is_empty():
		displayed_status = (
			_get_selected_detail_text()
			if is_instance_valid(selected_tower) or selected_wall_cell.x >= 0
			else status_message
		)
	if not displayed_status.is_empty() and (placement_mode != PlacementMode.NONE or not status_override.is_empty()):
		_draw_status_toast(displayed_status)


func _draw_floating_panel(rect: Rect2) -> void:
	ui_overlay.draw_rect(rect, Color(0.055, 0.055, 0.055, 0.95), true)
	ui_overlay.draw_rect(rect, COLOR_TOWER_BORDER, false, 3.0)


func _draw_status_toast(message: String) -> void:
	var max_width := safe_view_rect.size.x - GRID_MARGIN * 2.0
	var text_width := title_font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
	var toast_width := minf(text_width + 28.0, max_width)
	var toast_height := 32.0
	var toast_rect := Rect2(
		Vector2(safe_view_rect.get_center().x - toast_width * 0.5, gunslinger_button_rect.position.y - toast_height - 12.0),
		Vector2(toast_width, toast_height)
	)
	ui_overlay.draw_rect(toast_rect, Color(0.055, 0.055, 0.055, 0.92), true)
	ui_overlay.draw_rect(toast_rect, COLOR_TOWER_BORDER, false, 2.0)
	ui_overlay.draw_string(title_font, toast_rect.position + Vector2(14.0, 21.0), message, HORIZONTAL_ALIGNMENT_LEFT, toast_rect.size.x - 28.0, 13, COLOR_TEXT)


func _draw_build_button(rect: Rect2, kind: StringName, label: String) -> void:
	var enabled := placement_kind == kind or _can_begin_placement(kind)
	var price_text := "%d/%d" % [
		int(economy_state.get("used_walls", 0)),
		int(economy_state.get("wall_limit", 0)),
	] if kind == BUILD_WALL else "$%d" % TowerScript.get_build_cost(_tower_type_for_build_kind(kind))
	var fill_color := COLOR_PATH if placement_kind == kind else (COLOR_TEXT if enabled else Color("6c6b65"))
	var label_color := COLOR_TOWER_BORDER if enabled else Color("333330")
	ui_overlay.draw_rect(rect, fill_color, true)
	ui_overlay.draw_rect(rect, COLOR_TEXT if placement_kind == kind else COLOR_TOWER_BORDER, false, 3.0)
	var accent := COLOR_WALL_LIGHT if kind == BUILD_WALL else Color(TowerScript.TYPE_DATA[_tower_type_for_build_kind(kind)]["color"])
	var icon_rect := Rect2(rect.position + Vector2(10.0, 9.0), Vector2(rect.size.x - 20.0, 27.0))
	ui_overlay.draw_rect(icon_rect, accent, true)
	ui_overlay.draw_rect(icon_rect, COLOR_TOWER_BORDER, false, 2.0)
	ui_overlay.draw_string(title_font, rect.position + Vector2(5.0, rect.size.y - 25.0), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10.0, 10, label_color)
	ui_overlay.draw_string(title_font, rect.position + Vector2(5.0, rect.size.y - 9.0), price_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10.0, 10, label_color)


func _draw_selection_info() -> void:
	var accent := COLOR_WALL_LIGHT
	var heading := "WALL"
	if is_instance_valid(selected_tower):
		accent = Color(TowerScript.TYPE_DATA[selected_tower.tower_type]["color"])
		heading = "%s · L%d" % [TowerScript.get_type_name(selected_tower.tower_type), selected_tower.level]
	ui_overlay.draw_rect(selection_info_rect, Color("282825"), true)
	ui_overlay.draw_rect(selection_info_rect, COLOR_TOWER_BORDER, false, 3.0)
	ui_overlay.draw_rect(Rect2(selection_info_rect.position, Vector2(6.0, selection_info_rect.size.y)), accent, true)
	ui_overlay.draw_string(title_font, selection_info_rect.position + Vector2(16.0, 20.0), heading, HORIZONTAL_ALIGNMENT_LEFT, selection_info_rect.size.x - 24.0, 14, COLOR_TEXT)
	var detail := _get_selected_detail_text()
	var detail_segments := detail.split(" · ")
	var detail_line_1 := ""
	var detail_line_2 := ""
	for segment_index in detail_segments.size():
		var candidate := String(detail_segments[segment_index])
		if detail_line_1.length() + candidate.length() < 24:
			detail_line_1 += (" · " if not detail_line_1.is_empty() else "") + candidate
		else:
			detail_line_2 += (" · " if not detail_line_2.is_empty() else "") + candidate
	ui_overlay.draw_string(title_font, selection_info_rect.position + Vector2(16.0, 39.0), detail_line_1, HORIZONTAL_ALIGNMENT_LEFT, selection_info_rect.size.x - 24.0, 9, COLOR_MUTED_TEXT)
	if not detail_line_2.is_empty():
		ui_overlay.draw_string(title_font, selection_info_rect.position + Vector2(16.0, 54.0), detail_line_2, HORIZONTAL_ALIGNMENT_LEFT, selection_info_rect.size.x - 24.0, 9, COLOR_MUTED_TEXT)


func _update_selection_panel_layout() -> void:
	var anchor := safe_view_rect.get_center()
	if is_instance_valid(selected_tower):
		anchor = selected_tower.position
	elif selected_wall_cell.x >= 0:
		anchor = _cell_center(selected_wall_cell)
	var gap := 6.0
	var panel_width := 214.0 if not compact_layout else 194.0
	var info_height := 64.0
	var action_height := 48.0
	var panel_height := (188.0 if is_instance_valid(selected_tower) else 134.0)
	var panel_x := anchor.x + cell_size * 0.72
	if panel_x + panel_width + 8.0 > safe_view_rect.end.x:
		panel_x = anchor.x - cell_size * 0.72 - panel_width
	panel_x = clampf(panel_x, safe_view_rect.position.x + 8.0, safe_view_rect.end.x - panel_width - 8.0)
	var min_y := safe_view_rect.position.y + 74.0
	var panel_y := clampf(anchor.y - panel_height * 0.5, min_y, safe_view_rect.end.y - panel_height - 8.0)
	selection_panel_rect = Rect2(Vector2(panel_x, panel_y), Vector2(panel_width, panel_height))
	selection_info_rect = Rect2(selection_panel_rect.position + Vector2(8.0, 8.0), Vector2(panel_width - 16.0, info_height))
	var action_y := selection_info_rect.end.y + gap
	if is_instance_valid(selected_tower):
		upgrade_button_rect = Rect2(selection_info_rect.position.x, action_y, selection_info_rect.size.x, action_height)
		sell_button_rect = Rect2(selection_info_rect.position.x, upgrade_button_rect.end.y + gap, selection_info_rect.size.x, action_height)
	else:
		upgrade_button_rect = Rect2(selection_info_rect.position.x, action_y, selection_info_rect.size.x, action_height)
		sell_button_rect = Rect2()


func _get_selected_detail_text() -> String:
	if selected_wall_cell.x >= 0:
		return "REMOVE TO RECOVER ONE WALL"
	if not is_instance_valid(selected_tower):
		return status_message
	return selected_tower.get_next_upgrade_summary()


func _draw_button(rect: Rect2, label: String, enabled := true, selected := false) -> void:
	var fill_color := COLOR_PATH if selected else (COLOR_TEXT if enabled else Color("6c6b65"))
	var label_color := COLOR_TOWER_BORDER if enabled else Color("333330")
	ui_overlay.draw_rect(rect, fill_color, true)
	ui_overlay.draw_rect(rect, COLOR_TEXT if selected else COLOR_TOWER_BORDER, false, 3.0)
	var text_size := title_font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13
	)
	ui_overlay.draw_string(
		title_font,
		rect.get_center() - Vector2(text_size.x * 0.5, -text_size.y * 0.32),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		label_color
	)


func _handle_screen_press(screen_position: Vector2) -> void:
	if not status_override.is_empty():
		status_override = ""
	if is_instance_valid(selected_tower) or selected_wall_cell.x >= 0:
		_update_selection_panel_layout()
		if selection_panel_rect.has_point(screen_position):
			if is_instance_valid(selected_tower):
				if upgrade_button_rect.has_point(screen_position):
					_upgrade_selected_tower()
				elif sell_button_rect.has_point(screen_position):
					_remove_selected_building()
			else:
				if upgrade_button_rect.has_point(screen_position):
					_remove_selected_building()
			return
		_clear_structure_selection()
	if tools_button_rect.has_point(screen_position):
		tools_menu_open = not tools_menu_open
		queue_redraw()
		return
	if tools_menu_open:
		if export_button_rect.has_point(screen_position):
			export_stats_requested.emit()
			return
		if new_map_button_rect.has_point(screen_position):
			tools_menu_open = false
			new_map_requested.emit()
			return
		tools_menu_open = false
		queue_redraw()
		return
	if start_button_rect.has_point(screen_position):
		if StringName(combat_state.get("phase", &"build")) == &"build":
			_cancel_placement()
			_clear_structure_selection()
			_request_start_wave()
		return
	if placement_mode != PlacementMode.NONE:
		if header_cancel_button_rect.has_point(screen_position):
			_cancel_placement("Placement canceled.")
			return
	var cell := _screen_to_cell(screen_position)
	if not router.is_inside_grid(cell):
		return
	if router.dynamic_blocks.has(cell):
		_cancel_placement()
		if towers_by_cell.has(cell):
			_select_tower(towers_by_cell.get(cell))
		elif walls_by_cell.has(cell):
			_select_wall(cell)
		return
	if placement_mode == PlacementMode.PRECISION:
		_handle_precision_cell_press(cell)
		return


func _handle_placement_button(kind: StringName) -> bool:
	if placement_mode != PlacementMode.NONE and placement_kind == kind:
		_cancel_placement("Placement canceled.")
		return false
	if placement_mode != PlacementMode.NONE:
		_cancel_placement()
	return _begin_precision_placement(kind)


func _handle_precision_cell_press(cell: Vector2i) -> void:
	_update_preview(cell, true)
	if precision_cell == cell and preview_is_valid:
		var built_kind := placement_kind
		if _try_place_building(cell):
			_continue_building(built_kind)
		return
	precision_cell = cell
	status_message = (
		"Tap again to build."
		if preview_is_valid
		else String(placement_rejection_reasons.get(
			cell,
			"That cell cannot hold this tower."
		))
	)
	queue_redraw()


func _try_place_building(cell: Vector2i) -> bool:
	if not _is_gameplay_phase():
		status_message = "This run is finished."
		queue_redraw()
		return false
	if economy == null:
		status_message = "Economy is not configured."
		queue_redraw()
		return false
	if placement_kind == BUILD_WALL and not economy.can_build_wall():
		status_message = "Wall limit reached. Clear another wave or remove a wall."
		queue_redraw()
		return false
	var tower_type := _tower_type_for_build_kind(placement_kind)
	var tower_cost := TowerScript.get_build_cost(tower_type)
	if _is_tower_kind(placement_kind) and not economy.can_build(tower_cost):
		if not economy.can_afford(tower_cost):
			status_message = "Need $%d to build this tower." % tower_cost
		else:
			status_message = "Tower capacity is full. Sell a tower to free one slot."
		queue_redraw()
		return false
	var rejection_reason := _get_placement_rejection_reason(cell)
	if not rejection_reason.is_empty():
		status_message = rejection_reason
		_update_preview(cell, true)
		return false
	# Rebuild the complete plan at confirmation time. Placement is paused during
	# active waves, so this plan and every enemy anchor remain stable through commit.
	var candidate_blocks: Dictionary = router.dynamic_blocks.duplicate()
	candidate_blocks[cell] = true
	var route_plan := _build_route_plan(candidate_blocks)
	if route_plan.is_empty():
		status_message = "Blocked: an active enemy cannot rejoin the new path."
		_update_preview(cell, true)
		return false
	if placement_kind == BUILD_WALL:
		if not economy.try_build_wall():
			return false
		router.add_dynamic_block(cell)
		walls_by_cell[cell] = true
		structure_action_recorded.emit(&"wall_built", &"wall", 0, 0)
		status_message = "Wall placed. Every required route remains open."
		_after_blocks_changed(route_plan)
		_refresh_local_economy_state()
		return true
	if not economy.try_build(tower_cost):
		status_message = "The tower could not be purchased."
		_refresh_local_economy_state()
		queue_redraw()
		return false
	router.add_dynamic_block(cell)
	var tower: Node2D = TowerScript.new()
	add_child(tower)
	tower.z_index = 10
	tower.position = _cell_center(cell)
	tower.configure(cell, Callable(self, "get_cell_size"), tower_type)
	tower.damage_dealt.connect(_on_tower_damage_dealt)
	if StringName(combat_state.get("phase", &"build")) == &"active":
		tower.mark_participated()
	towers_by_cell[cell] = tower
	structure_action_recorded.emit(&"tower_built", tower.tower_type, tower.level, tower_cost)
	status_message = "Tower placed. All entrance and active-unit routes remain open."
	_after_blocks_changed(route_plan)
	_refresh_local_economy_state()
	return true


func _can_begin_placement(kind: StringName) -> bool:
	if not _is_gameplay_phase() or economy == null:
		return false
	if kind == BUILD_WALL:
		return economy.can_build_wall()
	return economy.can_build(TowerScript.get_build_cost(_tower_type_for_build_kind(kind)))


func _begin_precision_placement(kind: StringName = BUILD_GUNSLINGER) -> bool:
	if not _can_begin_placement(kind):
		status_message = (
			"Wall limit reached."
			if kind == BUILD_WALL
			else "Need $%d or one free tower slot." % TowerScript.get_build_cost(_tower_type_for_build_kind(kind))
		)
		queue_redraw()
		return false
	placement_mode = PlacementMode.PRECISION
	placement_kind = kind
	placement_rejection_reasons.clear()
	precision_cell = Vector2i(-1, -1)
	_select_tower(null)
	_set_placement_pause(true)
	status_message = "%sTap a cell, then tap it again to build %s." % [
		"COMBAT PAUSED · " if placement_pause_active else "",
		"a wall" if kind == BUILD_WALL else TowerScript.get_type_name(_tower_type_for_build_kind(kind)).to_lower()
	]
	_clear_placement_preview()
	return true


func _continue_building(kind: StringName) -> void:
	placement_drag_armed = false
	placement_drag_over_cancel = false
	placement_pointer_index = -2
	precision_cell = Vector2i(-1, -1)
	placement_rejection_reasons.clear()
	_clear_placement_preview()
	_clear_structure_selection()
	placement_mode = PlacementMode.NONE
	placement_kind = &""
	_set_placement_pause(false)
	status_message = "%s placed · choose another build option." % (
		"Wall" if kind == BUILD_WALL else TowerScript.get_type_name(_tower_type_for_build_kind(kind)).capitalize()
	)
	queue_redraw()


func _clear_structure_selection() -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = null
	selected_wall_cell = Vector2i(-1, -1)
	queue_redraw()


func _cancel_placement(message := "") -> void:
	placement_mode = PlacementMode.NONE
	placement_kind = &""
	precision_cell = Vector2i(-1, -1)
	placement_drag_armed = false
	placement_drag_over_cancel = false
	placement_pointer_index = -2
	placement_rejection_reasons.clear()
	_clear_placement_preview()
	_set_placement_pause(false)
	if not message.is_empty():
		status_message = message
		queue_redraw()


func _set_placement_pause(should_pause: bool) -> void:
	var tree := get_tree()
	if tree == null:
		placement_pause_active = false
		return
	if should_pause:
		if placement_pause_active or StringName(combat_state.get("phase", &"build")) != &"active":
			return
		placement_pause_active = true
		tree.paused = true
		queue_redraw()
		return
	if not placement_pause_active:
		return
	placement_pause_active = false
	tree.paused = false
	queue_redraw()


func _handle_touch_event(event: InputEventScreenTouch) -> void:
	last_touch_press_msec = Time.get_ticks_msec()
	if event.pressed:
		var pressed_kind := _get_build_kind_at(event.position)
		if not pressed_kind.is_empty():
			_clear_structure_selection()
			if _handle_placement_button(pressed_kind):
				_arm_placement_drag(event.position, event.index)
			return
		_handle_screen_press(event.position)
		return
	if event.canceled:
		# Android can cancel a pointer when its gesture ownership changes. Keep a
		# precision selection active; the build button remains the explicit cancel.
		placement_drag_armed = false
		placement_pointer_index = -2
		return
	if placement_drag_armed and event.index == placement_pointer_index:
		_finish_placement_drag(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		var pressed_kind := _get_build_kind_at(event.position)
		if not pressed_kind.is_empty():
			_clear_structure_selection()
			if _handle_placement_button(pressed_kind):
				_arm_placement_drag(event.position, -1)
			return
		_handle_screen_press(event.position)
		return
	if placement_drag_armed and placement_pointer_index == -1:
		_finish_placement_drag(event.position)


func _get_build_kind_at(screen_position: Vector2) -> StringName:
	if placement_mode != PlacementMode.NONE:
		return &""
	if gunslinger_button_rect.has_point(screen_position):
		return BUILD_GUNSLINGER
	if anti_materiel_button_rect.has_point(screen_position):
		return BUILD_ANTI_MATERIEL
	if flamespitter_button_rect.has_point(screen_position):
		return BUILD_FLAMESPITTER
	if bombardment_button_rect.has_point(screen_position):
		return BUILD_BOMBARDMENT
	if atomic_strike_button_rect.has_point(screen_position):
		return BUILD_ATOMIC_STRIKE
	if wall_button_rect.has_point(screen_position):
		return BUILD_WALL
	return &""


func _arm_placement_drag(screen_position: Vector2, pointer_index: int) -> void:
	placement_drag_armed = true
	placement_pointer_index = pointer_index
	placement_press_position = screen_position


func _handle_drag_motion(screen_position: Vector2, pointer_index: int) -> void:
	if not placement_drag_armed or pointer_index != placement_pointer_index:
		return
	if placement_mode != PlacementMode.DRAGGING:
		var source_button := _get_active_placement_button_rect()
		if source_button.grow(8.0).has_point(screen_position):
			return
		if _get_build_panel_rect().has_point(screen_position):
			return
		if screen_position.distance_to(placement_press_position) < PLACEMENT_DRAG_THRESHOLD:
			return
		# A placement drag only begins after the pointer actually enters the board.
		# This prevents Android navigation/editor gesture jitter in the footer from
		# converting an ordinary button tap into an invalid drag-and-cancel.
		var candidate_position := screen_position + PLACEMENT_FINGER_OFFSET_CELLS * cell_size
		if not router.is_inside_grid(_screen_to_cell(candidate_position)):
			return
	placement_mode = PlacementMode.DRAGGING
	precision_cell = Vector2i(-1, -1)
	placement_drag_over_cancel = cancel_button_rect.has_point(screen_position)
	if placement_drag_over_cancel:
		_clear_placement_preview()
		return
	var preview_position := screen_position + PLACEMENT_FINGER_OFFSET_CELLS * cell_size
	_update_preview(_screen_to_cell(preview_position))


func _get_active_placement_button_rect() -> Rect2:
	match placement_kind:
		BUILD_WALL:
			return wall_button_rect
		BUILD_ANTI_MATERIEL:
			return anti_materiel_button_rect
		BUILD_FLAMESPITTER:
			return flamespitter_button_rect
		BUILD_BOMBARDMENT:
			return bombardment_button_rect
		BUILD_ATOMIC_STRIKE:
			return atomic_strike_button_rect
		_:
			return gunslinger_button_rect


func _get_build_panel_rect() -> Rect2:
	var panel_left := minf(flamespitter_button_rect.position.x, wall_button_rect.position.x) - 8.0
	var panel_top := minf(gunslinger_button_rect.position.y, wall_button_rect.position.y) - 8.0
	var panel_right := maxf(atomic_strike_button_rect.end.x, maxf(wall_button_rect.end.x, cancel_button_rect.end.x)) + 8.0
	var panel_bottom := maxf(atomic_strike_button_rect.end.y, wall_button_rect.end.y) + 8.0
	return Rect2(Vector2(panel_left, panel_top), Vector2(panel_right - panel_left, panel_bottom - panel_top))


func _is_tower_kind(kind: StringName) -> bool:
	return kind in [BUILD_GUNSLINGER, BUILD_ANTI_MATERIEL, BUILD_FLAMESPITTER, BUILD_BOMBARDMENT, BUILD_ATOMIC_STRIKE]


func _tower_type_for_build_kind(kind: StringName) -> StringName:
	match kind:
		BUILD_ANTI_MATERIEL:
			return TowerScript.TYPE_ANTI_MATERIEL
		BUILD_FLAMESPITTER:
			return TowerScript.TYPE_FLAMESPITTER
		BUILD_BOMBARDMENT:
			return TowerScript.TYPE_BOMBARDMENT
		BUILD_ATOMIC_STRIKE:
			return TowerScript.TYPE_ATOMIC_STRIKE
		_:
			return TowerScript.TYPE_GUNSLINGER


func _finish_placement_drag(screen_position: Vector2) -> void:
	if placement_mode != PlacementMode.DRAGGING:
		if placement_drag_armed and cancel_button_rect.has_point(screen_position):
			_cancel_placement("Placement canceled.")
			return
		var should_cancel := (
			placement_drag_armed
			and screen_position.distance_to(placement_press_position) >= PLACEMENT_DRAG_THRESHOLD
			and not _get_build_panel_rect().has_point(screen_position)
		)
		placement_drag_armed = false
		placement_pointer_index = -2
		if should_cancel:
			_cancel_placement("Placement canceled.")
		return
	placement_drag_over_cancel = cancel_button_rect.has_point(screen_position)
	var placed := false
	var rejection_message := "Placement canceled."
	if not placement_drag_over_cancel:
		var preview_position := screen_position + PLACEMENT_FINGER_OFFSET_CELLS * cell_size
		_update_preview(_screen_to_cell(preview_position), true)
		if preview_is_valid:
			placed = _try_place_building(hovered_cell)
		elif placement_rejection_reasons.has(hovered_cell):
			rejection_message = String(placement_rejection_reasons[hovered_cell])
	if placement_drag_over_cancel:
		_cancel_placement("Placement canceled.")
	elif placed:
		_continue_building(placement_kind)
	else:
		_cancel_placement(rejection_message)


func _update_preview(cell: Vector2i, force := false) -> void:
	if not force and cell == hovered_cell:
		return
	hovered_cell = cell
	preview_is_valid = false
	preview_route.clear()
	if (
		placement_mode != PlacementMode.NONE
		and
		_is_gameplay_phase()
		and router.is_inside_grid(cell)
		and not router.dynamic_blocks.has(cell)
	):
		preview_is_valid = (
			_can_begin_placement(placement_kind)
			and _get_placement_rejection_reason(cell).is_empty()
		)
		if preview_is_valid:
			var candidate_blocks: Dictionary = router.dynamic_blocks.duplicate()
			candidate_blocks[cell] = true
			preview_route = router.find_complete_route(
				entrance,
				0,
				candidate_blocks
			)
	queue_redraw()


func _get_placement_rejection_reason(cell: Vector2i) -> String:
	if placement_rejection_reasons.has(cell):
		return String(placement_rejection_reasons[cell])
	if not router.can_add_dynamic_block(cell):
		var route_message := "Blocked: the complete waypoint route would retrace or close."
		placement_rejection_reasons[cell] = route_message
		return route_message
	if not router.can_add_dynamic_block(cell, _get_active_route_states()):
		var active_message := "Wait: an active enemy would have to backtrack."
		placement_rejection_reasons[cell] = active_message
		return active_message
	return ""


func _clear_placement_preview() -> void:
	hovered_cell = Vector2i(-1, -1)
	preview_is_valid = false
	preview_route.clear()
	queue_redraw()


func _after_blocks_changed(route_plan: Dictionary = {}) -> void:
	var active_plan := route_plan
	if active_plan.is_empty():
		active_plan = _build_route_plan(router.dynamic_blocks)
	if not active_plan.is_empty():
		displayed_route.assign(active_plan["main_route"])
	else:
		displayed_route = router.find_complete_route(entrance)
	for follower in active_followers.duplicate():
		if is_instance_valid(follower):
			var follower_route: Array[Vector2i] = []
			if not active_plan.is_empty():
				var routes_by_id: Dictionary = active_plan["follower_routes"]
				follower_route.assign(routes_by_id.get(follower.get_instance_id(), []))
			if follower_route.is_empty() or not follower.adopt_route_from_anchor(follower_route):
				follower.reroute()
		else:
			active_followers.erase(follower)
	queue_redraw()


func _build_route_plan(blocks: Dictionary) -> Dictionary:
	var main_route: Array[Vector2i] = router.find_complete_route(entrance, 0, blocks)
	if main_route.is_empty():
		return {}
	var follower_routes: Dictionary = {}
	for follower in active_followers.duplicate():
		if not is_instance_valid(follower):
			active_followers.erase(follower)
			continue
		if not follower.active:
			continue
		var state: Dictionary = follower.get_route_state()
		var connector_route: Array[Vector2i] = router.find_route_to_main(
			Vector2i(state["cell"]),
			int(state["next_checkpoint_index"]),
			main_route,
			blocks,
			Dictionary(state["used_edges"])
		)
		if connector_route.is_empty():
			return {}
		follower_routes[follower.get_instance_id()] = connector_route
	return {
		"main_route": main_route,
		"follower_routes": follower_routes,
	}


func _get_active_route_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for follower in active_followers.duplicate():
		if not is_instance_valid(follower):
			active_followers.erase(follower)
			continue
		if follower.active:
			states.append(follower.get_route_state())
	return states


func spawn_enemy(enemy_data: Dictionary) -> void:
	_create_enemy(enemy_data)


func _create_enemy(enemy_data: Dictionary, continuation: Dictionary = {}) -> void:
	var enemy: Node2D = EnemyScript.new()
	add_child(enemy)
	enemy.z_index = 20
	enemy.configure(
		router,
		Callable(self, "_cell_center"),
		Callable(self, "_screen_to_cell")
	)
	enemy.setup_combat(
		StringName(enemy_data.get("enemy_type", &"soldier")),
		float(enemy_data.get("health_scale", 1.0)),
		cell_size,
		int(enemy_data.get("group_index", -1)),
		int(enemy_data.get("index_in_group", 0))
	)
	if enemy_data.has("health"):
		enemy.max_health = maxi(int(enemy_data["health"]), 1)
		enemy.health = enemy.max_health
	if enemy_data.has("speed_cells_per_second"):
		enemy.base_speed_cells_per_second = float(enemy_data["speed_cells_per_second"])
		enemy.current_speed_cells_per_second = enemy.base_speed_cells_per_second
		enemy.speed_pixels_per_second = enemy.base_speed_cells_per_second * cell_size
	if enemy_data.has("leak_damage"):
		enemy.leak_damage = maxi(int(enemy_data["leak_damage"]), 1)
	if enemy_data.has("initial_route_progress"):
		enemy.route_progress = maxf(float(enemy_data["initial_route_progress"]), 0.0)
	enemy.set_meta(
		"speed_cells_per_second",
		float(enemy.base_speed_cells_per_second)
	)
	enemy.set_meta("health_scale", float(enemy_data.get("health_scale", 1.0)))
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.summon_requested.connect(_on_enemy_summon_requested)
	active_followers.append(enemy)
	var began: bool = (
		enemy.begin_from_continuation(continuation)
		if not continuation.is_empty()
		else enemy.begin()
	)
	if not began:
		active_followers.erase(enemy)
		enemy.queue_free()
		enemy_resolved.emit(false, 1)
		status_message = "Enemy spawn failed because no route exists."
	else:
		enemy_spawned_for_stats.emit(
			StringName(enemy.enemy_type),
			int(enemy.max_health),
			maxi(int(enemy_data.get("director_threat", 0)), 0)
		)
	queue_redraw()


func _on_tower_damage_dealt(tower_type: StringName, tower_level: int, amount: int) -> void:
	tower_damage_recorded.emit(tower_type, tower_level, amount)


func _get_enemy_progress_ratio(enemy: Node2D) -> float:
	var route_steps := maxf(float(displayed_route.size() - 1), 1.0)
	return clampf(float(enemy.get("route_progress")) / route_steps, 0.0, 1.0)


func _on_enemy_reached_exit(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or bool(enemy.get("finished")):
		return
	var progress_ratio := _get_enemy_progress_ratio(enemy)
	enemy.mark_leaked()
	active_followers.erase(enemy)
	enemy_resolved_for_stats.emit(true, int(enemy.get("leak_damage")), progress_ratio)
	enemy_resolved.emit(true, int(enemy.get("leak_damage")))
	enemy.queue_free()
	queue_redraw()


func _on_enemy_defeated(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var release_count := int(enemy.get_release_count())
	var release_type := StringName(enemy.get_release_type())
	var continuation: Dictionary = enemy.get_continuation_state() if release_count > 0 else {}
	var release_scale := float(enemy.get_meta("health_scale", 1.0))
	var release_group := int(enemy.get("formation_id"))
	var progress_ratio := _get_enemy_progress_ratio(enemy)
	var inherited_progress := float(enemy.get("route_progress"))
	if release_count > 0:
		enemies_added.emit(release_count)
	active_followers.erase(enemy)
	enemy_resolved_for_stats.emit(false, 0, progress_ratio)
	enemy_resolved.emit(false, 0)
	enemy.queue_free()
	for child_index in release_count:
		_create_enemy({
			"enemy_type": release_type,
			"health_scale": release_scale,
			"group_index": release_group,
			"index_in_group": 100 + child_index,
			"initial_route_progress": inherited_progress,
		}, continuation)
	queue_redraw()


func _on_enemy_summon_requested(summoner: Node2D, enemy_type: StringName, count: int) -> void:
	if not is_instance_valid(summoner) or count <= 0:
		return
	var continuation: Dictionary = summoner.get_continuation_state()
	var inherited_progress := float(summoner.get("route_progress"))
	var release_group := int(summoner.get("formation_id"))
	enemies_added.emit(count)
	for child_index in count:
		var child_count_before := active_followers.size()
		_create_enemy({
			"enemy_type": enemy_type,
			"health_scale": float(summoner.get_meta("health_scale", 1.0)),
			"group_index": release_group,
			"index_in_group": 200 + int(summoner.get("summons_created")) + child_index,
			"initial_route_progress": inherited_progress,
		}, continuation)
		if active_followers.size() > child_count_before:
			active_followers[-1].set_meta("summoner_id", summoner.get_instance_id())


func set_combat_state(new_state: Dictionary) -> void:
	combat_state = new_state.duplicate(true)
	if not _is_gameplay_phase():
		_cancel_placement()
	match StringName(combat_state.get("phase", &"build")):
		&"build":
			status_message = "Wave cleared. Build, upgrade, or start the next wave."
		&"active":
			status_override = ""
			status_message = "%d active · %d still scheduled" % [
				int(combat_state.get("active_enemies", 0)),
				int(combat_state.get("remaining_spawns", 0)),
			]
		&"victory":
			status_override = ""
			status_message = "Prototype complete: all twenty waves cleared."
		&"defeat":
			status_override = ""
			status_message = "Defeat: the route leaked too many enemies."
			_remove_active_enemies()
	queue_redraw()


func configure_economy(new_economy) -> void:
	economy = new_economy
	_refresh_local_economy_state()


func set_economy_state(new_state: Dictionary) -> void:
	economy_state = new_state.duplicate(true)
	queue_redraw()


func _refresh_local_economy_state() -> void:
	if economy == null:
		return
	var phase := StringName(combat_state.get("phase", &"build"))
	var wave := int(combat_state.get("displayed_wave", 1))
	set_economy_state(economy.get_state(wave, phase == &"active"))


func mark_all_towers_participated() -> void:
	for tower in towers_by_cell.values():
		if is_instance_valid(tower):
			tower.mark_participated()
	_refresh_local_economy_state()


func get_telemetry_snapshot() -> Dictionary:
	var levels := [0, 0, 0, 0]
	var type_counts := {"gunslinger": 0, "anti_materiel": 0, "flamespitter": 0, "bombardment": 0, "atomic_strike": 0}
	var type_investment := {"gunslinger": 0, "anti_materiel": 0, "flamespitter": 0, "bombardment": 0, "atomic_strike": 0}
	var type_levels: Dictionary = {}
	for tower_type in ["gunslinger", "anti_materiel", "flamespitter", "bombardment", "atomic_strike"]:
		for tower_level in range(1, 5):
			type_levels["%s_l%d" % [tower_type, tower_level]] = 0
	for tower in towers_by_cell.values():
		if not is_instance_valid(tower):
			continue
		var level_index: int = clampi(int(tower.level) - 1, 0, levels.size() - 1)
		levels[level_index] += 1
		var type_key := String(tower.tower_type)
		type_counts[type_key] = int(type_counts.get(type_key, 0)) + 1
		type_investment[type_key] = int(type_investment.get(type_key, 0)) + int(tower.total_investment)
		var type_level_key := "%s_l%d" % [type_key, int(tower.level)]
		type_levels[type_level_key] = int(type_levels.get(type_level_key, 0)) + 1
	return {
		"map_seed": map_seed,
		"initial_route_steps": initial_route_steps,
		"tower_count": towers_by_cell.size(),
		"tower_levels": levels,
		"tower_type_counts": type_counts,
		"tower_type_levels": type_levels,
		"tower_type_investment": type_investment,
		"wall_count": walls_by_cell.size(),
		"route_steps": maxi(displayed_route.size() - 1, 0),
	}


func _create_map_seed() -> int:
	var override_seed := int(ProjectSettings.get_setting(MAP_SEED_OVERRIDE_SETTING, 0))
	if override_seed > 0:
		return override_seed
	var mixed_seed := (
		int(Time.get_unix_time_from_system())
		^ Time.get_ticks_usec()
		^ randi()
	)
	var positive_seed := int(mixed_seed & 0x7fffffff)
	return positive_seed if positive_seed > 0 else 1


func show_wave_reward(reward: Dictionary) -> void:
	var capacity_parts: Array[String] = []
	var base_reward := int(reward.get("base_reward", 0))
	var interest_reward := int(reward.get("interest_reward", 0))
	var power_increase := int(reward.get("power_increase", 0))
	var wall_increase := int(reward.get("wall_increase", 0))
	if power_increase > 0:
		capacity_parts.append("TOWER SLOT +%d" % power_increase)
	if wall_increase > 0:
		capacity_parts.append("WALL +%d" % wall_increase)
	var capacity_suffix := (
		" · " + " · ".join(capacity_parts)
		if not capacity_parts.is_empty()
		else ""
	)
	status_override = (
		"Victory."
		if base_reward == 0 and interest_reward == 0 and capacity_parts.is_empty()
		else "Wave reward $%d + interest $%d%s" % [
			base_reward,
			interest_reward,
			capacity_suffix,
		]
	)
	status_override_expires_msec = (
		Time.get_ticks_msec() + WAVE_REWARD_MESSAGE_DURATION_MSEC
	)
	queue_redraw()


func show_stats_export_result(result: Dictionary) -> void:
	status_override = String(result.get(
		"message",
		"Stats exported." if bool(result.get("success", false)) else "No stats report was found."
	))
	status_override_expires_msec = Time.get_ticks_msec() + WAVE_REWARD_MESSAGE_DURATION_MSEC
	queue_redraw()


func _request_start_wave() -> void:
	if StringName(combat_state.get("phase", &"build")) != &"build":
		return
	start_wave_requested.emit()


func _select_tower(tower: Node2D) -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = tower
	selected_wall_cell = Vector2i(-1, -1)
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(true)
	queue_redraw()


func _select_wall(cell: Vector2i) -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = null
	selected_wall_cell = cell if walls_by_cell.has(cell) else Vector2i(-1, -1)
	queue_redraw()


func _upgrade_selected_tower() -> void:
	if (
		not _is_gameplay_phase()
		or not is_instance_valid(selected_tower)
		or economy == null
	):
		return
	var upgrade_cost: int = int(selected_tower.get_next_upgrade_cost())
	if upgrade_cost <= 0:
		status_message = "Tower is already at maximum level."
		queue_redraw()
		return
	if not economy.try_spend(upgrade_cost):
		status_message = "Need $%d for the next upgrade." % upgrade_cost
		queue_redraw()
		return
	if selected_tower.upgrade(upgrade_cost):
		structure_action_recorded.emit(
			&"tower_upgraded",
			selected_tower.tower_type,
			selected_tower.level,
			upgrade_cost
		)
		status_message = "Tower upgraded to level %d." % selected_tower.level
	else:
		economy.add_credits(upgrade_cost)
		status_message = "The upgrade could not be applied."
	_refresh_local_economy_state()
	queue_redraw()


func _sell_selected_tower() -> void:
	if (
		not _is_gameplay_phase()
		or not is_instance_valid(selected_tower)
		or economy == null
	):
		return
	var cell: Vector2i = selected_tower.grid_cell
	var refund := int(selected_tower.get_sell_refund())
	var sold_type: StringName = selected_tower.tower_type
	var sold_level: int = selected_tower.level
	towers_by_cell.erase(cell)
	router.remove_dynamic_block(cell)
	economy.release_power()
	economy.add_credits(refund)
	structure_action_recorded.emit(&"tower_sold", sold_type, sold_level, refund)
	selected_tower.queue_free()
	selected_tower = null
	status_message = "Tower sold for $%d. Active enemies retained their positions." % refund
	_after_blocks_changed()
	_refresh_local_economy_state()
	_clear_placement_preview()


func _remove_selected_building() -> void:
	if selected_wall_cell.x >= 0:
		_remove_selected_wall()
	else:
		_sell_selected_tower()


func _remove_selected_wall() -> void:
	if (
		not _is_gameplay_phase()
		or selected_wall_cell.x < 0
		or not walls_by_cell.has(selected_wall_cell)
		or economy == null
	):
		return
	var cell := selected_wall_cell
	walls_by_cell.erase(cell)
	router.remove_dynamic_block(cell)
	economy.release_wall()
	structure_action_recorded.emit(&"wall_removed", &"wall", 0, 0)
	selected_wall_cell = Vector2i(-1, -1)
	status_message = "Wall removed. One Wall is available again."
	_after_blocks_changed()
	_refresh_local_economy_state()
	_clear_placement_preview()


func _can_afford_selected_upgrade() -> bool:
	if (
		not _is_gameplay_phase()
		or not is_instance_valid(selected_tower)
		or economy == null
		or not selected_tower.can_upgrade()
	):
		return false
	return economy.can_afford(selected_tower.get_next_upgrade_cost())


func _get_upgrade_button_label() -> String:
	if not is_instance_valid(selected_tower):
		return "UPGRADE"
	if not selected_tower.can_upgrade():
		return "MAX"
	return "UP $%d" % int(selected_tower.get_next_upgrade_cost())


func _get_sell_button_label() -> String:
	if selected_wall_cell.x >= 0:
		return "REMOVE"
	if not is_instance_valid(selected_tower):
		return "SELL"
	return "SELL $%d" % int(selected_tower.get_sell_refund())


func _is_gameplay_phase() -> bool:
	return StringName(combat_state.get("phase", &"build")) in [&"build", &"active"]


func _remove_active_enemies() -> void:
	for follower in active_followers:
		if not is_instance_valid(follower):
			continue
		follower.active = false
		follower.set("finished", true)
		follower.queue_free()
	active_followers.clear()


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local_position := screen_position - board_origin
	return Vector2i(
		floori(local_position.x / cell_size),
		floori(local_position.y / cell_size)
	)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		board_origin + Vector2(cell) * cell_size,
		Vector2.ONE * cell_size
	)


func _cell_center(cell: Vector2i) -> Vector2:
	return board_origin + (Vector2(cell) + Vector2.ONE * 0.5) * cell_size


func get_cell_size() -> float:
	return cell_size


func _on_viewport_size_changed() -> void:
	var old_board_origin := board_origin
	var old_cell_size := cell_size
	_recalculate_layout()
	for follower in active_followers:
		if is_instance_valid(follower):
			follower.remap_layout(
				old_board_origin,
				old_cell_size,
				board_origin,
				cell_size
			)
			if follower.has_method("update_cell_scale"):
				follower.update_cell_scale(
					cell_size,
					float(follower.get_meta("speed_cells_per_second", 1.25))
				)
	for cell in towers_by_cell:
		var tower: Node2D = towers_by_cell[cell]
		if is_instance_valid(tower):
			tower.position = _cell_center(cell)
			tower.queue_redraw()
	queue_redraw()


func _recalculate_layout() -> void:
	var viewport_size := get_viewport_rect().size
	safe_view_rect = _get_safe_view_rect(viewport_size)
	portrait_view = safe_view_rect.size.y > safe_view_rect.size.x
	if portrait_view:
		return
	compact_layout = safe_view_rect.size.y < 500.0
	var header_inset := 10.0
	var resource_x := safe_view_rect.position.x + header_inset + (70.0 if compact_layout else 84.0)
	var resource_width := 140.0 if compact_layout else 176.0
	var header_action_y := safe_view_rect.position.y + header_inset + 59.0
	header_cancel_button_rect = Rect2(resource_x + resource_width - 36.0, header_action_y, 36.0, 24.0)
	var available_width := maxf(
		safe_view_rect.size.x - GRID_MARGIN * 2.0,
		1.0
	)
	var available_height := maxf(
		safe_view_rect.size.y - GRID_MARGIN * 2.0,
		1.0
	)
	cell_size = maxf(
		floorf(minf(
			available_width / float(GRID_SIZE.x),
			available_height / float(GRID_SIZE.y)
		)),
		1.0
	)
	var board_size := Vector2(GRID_SIZE) * cell_size
	board_origin = Vector2(
		floorf(safe_view_rect.position.x + (safe_view_rect.size.x - board_size.x) * 0.5),
		floorf(safe_view_rect.position.y + (safe_view_rect.size.y - board_size.y) * 0.5)
	)
	var start_width := 102.0 if compact_layout else 112.0
	start_button_rect = Rect2(safe_view_rect.end.x - header_inset - start_width, safe_view_rect.position.y + header_inset, start_width, 54.0)
	tools_button_rect = Rect2(start_button_rect.position.x - 56.0, start_button_rect.position.y, 50.0, 34.0)
	export_button_rect = Rect2(tools_button_rect.position.x - 42.0, tools_button_rect.end.y + 10.0, 96.0, 60.0)
	new_map_button_rect = Rect2(export_button_rect.position.x, export_button_rect.end.y + 6.0, 96.0, 60.0)
	var wave_width := 150.0 if compact_layout else 184.0
	wave_progress_rect = Rect2(Vector2(safe_view_rect.get_center().x - wave_width * 0.5, safe_view_rect.position.y + 57.0), Vector2(wave_width, 5.0))

	# Permanent compact deck: two cards above three, with the wall separate.
	var control_gap := 5.0 if compact_layout else 7.0
	var card_width := 68.0 if compact_layout else 78.0
	var card_height := 60.0 if compact_layout else 70.0
	var bottom_y := safe_view_rect.end.y - GRID_MARGIN - card_height
	var top_y := bottom_y - control_gap - card_height
	var deck_x := safe_view_rect.position.x + GRID_MARGIN
	flamespitter_button_rect = Rect2(deck_x, bottom_y, card_width, card_height)
	bombardment_button_rect = Rect2(flamespitter_button_rect.end.x + control_gap, bottom_y, card_width, card_height)
	atomic_strike_button_rect = Rect2(bombardment_button_rect.end.x + control_gap, bottom_y, card_width, card_height)
	var top_x := deck_x + (card_width + control_gap) * 0.5
	gunslinger_button_rect = Rect2(top_x, top_y, card_width, card_height)
	anti_materiel_button_rect = Rect2(gunslinger_button_rect.end.x + control_gap, top_y, card_width, card_height)
	wall_button_rect = Rect2(safe_view_rect.get_center().x - card_width * 0.5, bottom_y, card_width, card_height)
	cancel_button_rect = Rect2(wall_button_rect.end.x + control_gap, bottom_y + card_height - 52.0, 48.0, 52.0)

	_update_selection_panel_layout()


func _scaled_control_widths(base_widths: PackedFloat32Array, available_width: float, gap: float) -> PackedFloat32Array:
	var result := base_widths.duplicate()
	var base_total := 0.0
	for width in result:
		base_total += width
	var width_scale := minf((available_width - gap * float(result.size() - 1)) / base_total, 1.0)
	for index in result.size():
		result[index] *= width_scale
	return result


func _get_safe_view_rect(viewport_size: Vector2) -> Rect2:
	var full_view := Rect2(Vector2.ZERO, viewport_size)
	if not OS.has_feature("mobile"):
		return full_view
	var display_size := Vector2(DisplayServer.screen_get_size())
	var display_safe_area := Rect2(DisplayServer.get_display_safe_area())
	if (
		display_size.x <= 0.0
		or display_size.y <= 0.0
		or display_safe_area.size.x <= 0.0
		or display_safe_area.size.y <= 0.0
	):
		return full_view
	var scale_to_view := Vector2(
		viewport_size.x / display_size.x,
		viewport_size.y / display_size.y
	)
	var converted := Rect2(
		display_safe_area.position * scale_to_view,
		display_safe_area.size * scale_to_view
	)
	return converted.intersection(full_view)
