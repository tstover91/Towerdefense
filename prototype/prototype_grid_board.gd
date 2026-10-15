class_name PrototypeGridBoard
extends Node2D

const GridRouterScript = preload("res://prototype/grid_route_service.gd")
const EnemyScript = preload("res://prototype/prototype_enemy.gd")
const TowerScript = preload("res://prototype/prototype_tower.gd")

signal start_wave_requested
signal enemy_resolved(leaked: bool, leak_damage: int)

const GRID_SIZE := Vector2i(18, 9)
const GRID_MARGIN := 18.0
const TOP_UI_HEIGHT := 68.0
const BOTTOM_UI_HEIGHT := 62.0
const COMPACT_TOP_UI_HEIGHT := 52.0
const COMPACT_BOTTOM_UI_HEIGHT := 50.0
const WAVE_REWARD_MESSAGE_DURATION_MSEC := 3500

const ENTRANCE := Vector2i(0, 4)
const WAYPOINTS: Array[Vector2i] = [
	Vector2i(5, 1),
	Vector2i(9, 7),
	Vector2i(13, 2),
]
const EXIT_CELL := Vector2i(17, 4)
const STATIC_OBJECTS: Array[Vector2i] = [
	Vector2i(2, 2),
	Vector2i(3, 2),
	Vector2i(7, 4),
	Vector2i(11, 5),
	Vector2i(12, 5),
	Vector2i(15, 6),
]

const COLOR_BACKGROUND := Color("131313")
const COLOR_BOARD := Color("202020")
const COLOR_CELL_A := Color("ddddcf")
const COLOR_CELL_B := Color("d2d2c4")
const COLOR_GRID := Color("5b5b55")
const COLOR_PATH_SHADOW := Color(0.05, 0.05, 0.05, 0.72)
const COLOR_PATH := Color("efb83d")
const COLOR_TOWER := Color("e84f3d")
const COLOR_TOWER_BORDER := Color("171717")
const COLOR_OBJECT := Color("4b4b48")
const COLOR_OBJECT_DETAIL := Color("999990")
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
var displayed_route: Array[Vector2i] = []
var preview_route: Array[Vector2i] = []
var hovered_cell := Vector2i(-1, -1)
var preview_is_valid := false
var board_origin := Vector2.ZERO
var cell_size := 48.0
var title_font: Font
var start_button_rect := Rect2()
var upgrade_button_rect := Rect2()
var sell_button_rect := Rect2()
var safe_view_rect := Rect2()
var portrait_view := false
var compact_layout := false
var status_message := "Tap an empty cell to build a tower."
var status_override := ""
var status_override_expires_msec := 0
var active_followers: Array[Node2D] = []
var towers_by_cell: Dictionary = {}
var selected_tower: Node2D
var last_touch_press_msec := -1000
var economy = null
var economy_state: Dictionary = {
	"credits": 500,
	"used_capacity": 0,
	"maximum_capacity": 5,
	"interest": 25,
	"interest_locked": false,
}
var combat_state: Dictionary = {
	"phase": &"build",
	"displayed_wave": 1,
	"max_waves": 10,
	"lives": 20,
	"active_enemies": 0,
	"remaining_spawns": 0,
}


func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	router = GridRouterScript.new()
	router.configure(GRID_SIZE, ENTRANCE, WAYPOINTS, EXIT_CELL, STATIC_OBJECTS)
	title_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_recalculate_layout()
	displayed_route = router.find_complete_route(ENTRANCE)
	queue_redraw()


func _process(_delta: float) -> void:
	if (
		not status_override.is_empty()
		and Time.get_ticks_msec() >= status_override_expires_msec
	):
		status_override = ""
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if portrait_view:
		return
	if event is InputEventMouseMotion:
		_update_preview(_screen_to_cell(event.position))
	elif event is InputEventScreenDrag:
		_update_preview(_screen_to_cell(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if (
			event.pressed
			and (
				not OS.has_feature("mobile")
				or Time.get_ticks_msec() - last_touch_press_msec > 250
			)
		):
			_handle_screen_press(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		last_touch_press_msec = Time.get_ticks_msec()
		_handle_screen_press(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_request_start_wave()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BACKGROUND)
	if portrait_view:
		_draw_landscape_required()
		return
	_draw_header()
	_draw_board()
	_draw_route(preview_route if preview_is_valid else displayed_route)
	_draw_static_objects()
	_draw_route_markers()
	_draw_placement_preview()
	_draw_footer_controls()


func _draw_header() -> void:
	var heading_size := 18 if compact_layout else 22
	var detail_size := 12 if compact_layout else 14
	var heading_y := safe_view_rect.position.y + (22.0 if compact_layout else 29.0)
	var detail_y := safe_view_rect.position.y + (41.0 if compact_layout else 52.0)
	draw_string(
		title_font,
		Vector2(safe_view_rect.position.x + GRID_MARGIN, heading_y),
		"GRID MAZE PROTOTYPE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		heading_size,
		COLOR_TEXT
	)
	var economy_text := "$%d   ·   INT +$%d%s   ·   CAP %d/%d" % [
		int(economy_state.get("credits", 0)),
		int(economy_state.get("interest", 0)),
		" LOCKED" if bool(economy_state.get("interest_locked", false)) else "",
		int(economy_state.get("used_capacity", 0)),
		int(economy_state.get("maximum_capacity", 0)),
	]
	draw_string(
		title_font,
		Vector2(safe_view_rect.position.x + GRID_MARGIN, detail_y),
		economy_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		detail_size,
		COLOR_MUTED_TEXT
	)
	var wave_text := "WAVE %d/%d" % [
		int(combat_state.get("displayed_wave", 1)),
		int(combat_state.get("max_waves", 10)),
	]
	var lives_text := "LIVES %d" % int(combat_state.get("lives", 20))
	var phase_text := String(combat_state.get("phase", &"build")).to_upper()
	var summary := "%s   ·   %s   ·   %s" % [wave_text, lives_text, phase_text]
	var summary_size := title_font.get_string_size(
		summary, HORIZONTAL_ALIGNMENT_LEFT, -1.0, detail_size
	)
	draw_string(
		title_font,
		Vector2(
			safe_view_rect.end.x - GRID_MARGIN - summary_size.x,
			detail_y
		),
		summary,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		detail_size,
		COLOR_TEXT
	)


func _draw_landscape_required() -> void:
	var viewport_size := get_viewport_rect().size
	var heading := "ROTATE TO LANDSCAPE"
	var detail := "The gameplay grid always uses 18 × 9 tiles."
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


func _draw_route(route: Array[Vector2i]) -> void:
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in route:
		points.append(_cell_center(cell))
	draw_polyline(points, COLOR_PATH_SHADOW, maxf(cell_size * 0.24, 7.0), true)
	draw_polyline(points, COLOR_PATH, maxf(cell_size * 0.10, 3.0), true)


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
	if not _is_gameplay_phase():
		return
	if not router.is_inside_grid(hovered_cell):
		return
	if router.dynamic_blocks.has(hovered_cell):
		return
	var rect := _cell_rect(hovered_cell).grow(-cell_size * 0.06)
	draw_rect(rect, COLOR_VALID if preview_is_valid else COLOR_INVALID, true)
	draw_rect(rect, COLOR_TOWER_BORDER, false, 2.0)


func _draw_footer_controls() -> void:
	var phase := StringName(combat_state.get("phase", &"build"))
	var start_label := (
		"START WAVE"
		if phase == &"build"
		else ("RUNNING" if phase == &"active" else String(phase).to_upper())
	)
	_draw_button(start_button_rect, start_label, phase == &"build")
	_draw_button(
		upgrade_button_rect,
		_get_upgrade_button_label(),
		_can_afford_selected_upgrade()
	)
	_draw_button(
		sell_button_rect,
		_get_sell_button_label(),
		is_instance_valid(selected_tower) and _is_gameplay_phase()
	)
	var info_x := sell_button_rect.end.x + 16.0
	var info_width := maxf(safe_view_rect.end.x - info_x - GRID_MARGIN, 0.0)
	var displayed_status := status_override
	if displayed_status.is_empty():
		displayed_status = (
			selected_tower.get_summary()
			if is_instance_valid(selected_tower)
			else status_message
		)
	draw_string(
		title_font,
		Vector2(info_x, start_button_rect.position.y + 25.0),
		displayed_status,
		HORIZONTAL_ALIGNMENT_LEFT,
		info_width,
		13,
		COLOR_MUTED_TEXT
	)


func _draw_button(rect: Rect2, label: String, enabled := true) -> void:
	var fill_color := COLOR_TEXT if enabled else Color("6c6b65")
	var label_color := COLOR_TOWER_BORDER if enabled else Color("333330")
	draw_rect(rect, fill_color, true)
	draw_rect(rect, COLOR_TOWER_BORDER, false, 3.0)
	var text_size := title_font.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13
	)
	draw_string(
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
	if start_button_rect.has_point(screen_position):
		_request_start_wave()
		return
	if upgrade_button_rect.has_point(screen_position):
		_upgrade_selected_tower()
		return
	if sell_button_rect.has_point(screen_position):
		_sell_selected_tower()
		return
	var cell := _screen_to_cell(screen_position)
	if not router.is_inside_grid(cell):
		return
	if router.dynamic_blocks.has(cell):
		_select_tower(towers_by_cell.get(cell))
		return
	if not _is_gameplay_phase():
		status_message = "This run is finished."
		queue_redraw()
		return
	if economy == null:
		status_message = "Economy is not configured."
		queue_redraw()
		return
	if not economy.can_build(TowerScript.BUILD_COST):
		if not economy.can_afford(TowerScript.BUILD_COST):
			status_message = "Need $%d to build this tower." % TowerScript.BUILD_COST
		else:
			status_message = "Tower capacity is full. Sell a tower to free one slot."
		queue_redraw()
		return
	var route_states := _get_active_route_states()
	if not router.can_add_dynamic_block(cell, route_states):
		status_message = "Blocked: that placement would trap a route or an active unit."
		_update_preview(cell)
		return
	if not economy.try_build(TowerScript.BUILD_COST):
		status_message = "The tower could not be purchased."
		_refresh_local_economy_state()
		queue_redraw()
		return
	router.add_dynamic_block(cell)
	var tower: Node2D = TowerScript.new()
	add_child(tower)
	tower.z_index = 10
	tower.position = _cell_center(cell)
	tower.configure(cell, Callable(self, "get_cell_size"))
	if StringName(combat_state.get("phase", &"build")) == &"active":
		tower.mark_participated()
	towers_by_cell[cell] = tower
	_select_tower(tower)
	status_message = "Tower placed. All entrance and active-unit routes remain open."
	_after_blocks_changed()
	_refresh_local_economy_state()
	_update_preview(cell)


func _update_preview(cell: Vector2i) -> void:
	hovered_cell = cell
	preview_is_valid = false
	preview_route.clear()
	if (
		_is_gameplay_phase()
		and router.is_inside_grid(cell)
		and not router.dynamic_blocks.has(cell)
	):
		preview_is_valid = (
			economy != null
			and economy.can_build(TowerScript.BUILD_COST)
			and router.can_add_dynamic_block(
			cell,
			_get_active_route_states()
			)
		)
		if preview_is_valid:
			var candidate_blocks: Dictionary = router.dynamic_blocks.duplicate()
			candidate_blocks[cell] = true
			preview_route = router.find_complete_route(
				ENTRANCE,
				0,
				candidate_blocks
			)
	queue_redraw()


func _after_blocks_changed() -> void:
	displayed_route = router.find_complete_route(ENTRANCE)
	for follower in active_followers.duplicate():
		if is_instance_valid(follower):
			follower.reroute()
		else:
			active_followers.erase(follower)
	queue_redraw()


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
	var enemy: Node2D = EnemyScript.new()
	add_child(enemy)
	enemy.z_index = 20
	enemy.configure(
		router,
		Callable(self, "_cell_center"),
		Callable(self, "_screen_to_cell")
	)
	enemy.setup_combat(
		int(enemy_data.get("health", 18)),
		float(enemy_data.get("speed_cells_per_second", 1.25)),
		cell_size,
		int(enemy_data.get("leak_damage", 1))
	)
	enemy.set_meta(
		"speed_cells_per_second",
		float(enemy_data.get("speed_cells_per_second", 1.25))
	)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	enemy.defeated.connect(_on_enemy_defeated)
	active_followers.append(enemy)
	if not enemy.begin():
		active_followers.erase(enemy)
		enemy.queue_free()
		enemy_resolved.emit(false, 1)
		status_message = "Enemy spawn failed because no route exists."
	queue_redraw()


func _on_enemy_reached_exit(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or bool(enemy.get("finished")):
		return
	enemy.mark_leaked()
	active_followers.erase(enemy)
	enemy_resolved.emit(true, int(enemy.get("leak_damage")))
	enemy.queue_free()
	queue_redraw()


func _on_enemy_defeated(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	active_followers.erase(enemy)
	enemy_resolved.emit(false, 0)
	enemy.queue_free()
	queue_redraw()


func set_combat_state(new_state: Dictionary) -> void:
	combat_state = new_state.duplicate(true)
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
			status_message = "Prototype complete: all ten waves cleared."
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


func show_wave_reward(reward: Dictionary) -> void:
	status_override = "Wave reward $%d + interest $%d%s" % [
		int(reward.get("base_reward", 0)),
		int(reward.get("interest_reward", 0)),
		" · CAPACITY +1" if bool(reward.get("capacity_increased", false)) else "",
	]
	status_override_expires_msec = (
		Time.get_ticks_msec() + WAVE_REWARD_MESSAGE_DURATION_MSEC
	)
	queue_redraw()


func _request_start_wave() -> void:
	if StringName(combat_state.get("phase", &"build")) != &"build":
		return
	start_wave_requested.emit()


func _select_tower(tower: Node2D) -> void:
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(false)
	selected_tower = tower
	if is_instance_valid(selected_tower):
		selected_tower.set_selected(true)
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
	towers_by_cell.erase(cell)
	router.remove_dynamic_block(cell)
	economy.release_capacity()
	economy.add_credits(refund)
	selected_tower.queue_free()
	selected_tower = null
	status_message = "Tower sold for $%d. Active enemies retained their positions." % refund
	_after_blocks_changed()
	_refresh_local_economy_state()
	_update_preview(cell)


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
	var top_ui_height := (
		COMPACT_TOP_UI_HEIGHT if compact_layout else TOP_UI_HEIGHT
	)
	var bottom_ui_height := (
		COMPACT_BOTTOM_UI_HEIGHT if compact_layout else BOTTOM_UI_HEIGHT
	)
	var available_width := maxf(
		safe_view_rect.size.x - GRID_MARGIN * 2.0,
		1.0
	)
	var available_height := maxf(
		safe_view_rect.size.y - top_ui_height - bottom_ui_height,
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
		floorf(
			safe_view_rect.position.x
			+ (safe_view_rect.size.x - board_size.x) * 0.5
		),
		floorf(
			safe_view_rect.position.y
			+ top_ui_height
			+ maxf((available_height - board_size.y) * 0.5, 0.0)
		)
	)
	var footer_y := board_origin.y + board_size.y + 12.0
	var button_height := 32.0 if compact_layout else 38.0
	start_button_rect = Rect2(
		safe_view_rect.position.x + GRID_MARGIN,
		footer_y,
		132.0,
		button_height
	)
	upgrade_button_rect = Rect2(
		start_button_rect.end.x + 10.0,
		footer_y,
		110.0,
		button_height
	)
	sell_button_rect = Rect2(
		upgrade_button_rect.end.x + 10.0,
		footer_y,
		110.0,
		button_height
	)


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
