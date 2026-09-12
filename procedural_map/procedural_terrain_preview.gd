extends Node2D

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")
const FlowField = preload("res://procedural_map/terrain_flow_field.gd")

@export var map_seed := 481516

@onready var seed_label: Label = $Interface/TopBar/SeedLabel
@onready var tower_label: Label = $Interface/TopBar/TowerLabel

var generator := Generator.new()
var flow_field := FlowField.new()
var terrain_textures: Dictionary = {}
var tower_origins: Array[Vector2i] = []


func _ready() -> void:
	_load_terrain_textures()
	get_viewport().size_changed.connect(_fit_map_to_viewport)
	_generate_current_seed()
	_fit_map_to_viewport()


func _draw() -> void:
	var tile_size := Vector2(Terrain.TILE_SIZE, Terrain.TILE_SIZE)
	for y in generator.grid_size.y:
		for x in generator.grid_size.x:
			var cell := Vector2i(x, y)
			var terrain_type := generator.get_terrain(cell)
			var texture := terrain_textures[terrain_type] as Texture2D
			draw_texture_rect(
				texture,
				Rect2(Vector2(cell * Terrain.TILE_SIZE), tile_size),
				false
			)
	_draw_grid()
	_draw_routes()
	_draw_towers()


func _load_terrain_textures() -> void:
	for terrain_type in Terrain.TERRAIN_DATA:
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(Terrain.get_texture_path(terrain_type))
		)
		assert(not image.is_empty(), "Unable to load procedural terrain texture")
		terrain_textures[terrain_type] = ImageTexture.create_from_image(image)


func _draw_grid() -> void:
	var map_size := Vector2(generator.grid_size * Terrain.TILE_SIZE)
	var grid_color := Color("24182124")
	for x in range(generator.grid_size.x + 1):
		var line_x := float(x * Terrain.TILE_SIZE)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, map_size.y), grid_color)
	for y in range(generator.grid_size.y + 1):
		var line_y := float(y * Terrain.TILE_SIZE)
		draw_line(Vector2(0.0, line_y), Vector2(map_size.x, line_y), grid_color)


func _draw_routes() -> void:
	var route_color := Color("F0E6C8B8")
	for start_y in [3, 7, 10, 14, 17]:
		var route := flow_field.trace_route(Vector2i(0, start_y))
		if route.size() < 2:
			continue
		var points := PackedVector2Array()
		for cell in route:
			points.append(
				Vector2(cell * Terrain.TILE_SIZE)
				+ Vector2.ONE * Terrain.TILE_SIZE * 0.5
			)
		draw_polyline(points, route_color, 2.0, true)


func _draw_towers() -> void:
	var footprint_size := Vector2(
		FlowField.TOWER_FOOTPRINT_CELLS * Terrain.TILE_SIZE
	)
	for origin in tower_origins:
		var footprint := Rect2(
			Vector2(origin * Terrain.TILE_SIZE),
			footprint_size
		)
		draw_rect(footprint, Color("241821D8"), true)
		draw_rect(footprint.grow(-4.0), Color("75C9A3"), false, 3.0)
		draw_circle(footprint.get_center(), 10.0, Color("75C9A3"))


func _generate_current_seed() -> void:
	generator.generate(map_seed)
	tower_origins.clear()
	_rebuild_routes()
	seed_label.text = "SEED %d" % map_seed
	_update_tower_label()


func _fit_map_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var map_size := Vector2(generator.grid_size * Terrain.TILE_SIZE)
	var available_size := viewport_size - Vector2(32.0, 88.0)
	var fitted_scale := minf(
		available_size.x / map_size.x,
		available_size.y / map_size.y
	)
	fitted_scale = minf(fitted_scale, 1.0)
	scale = Vector2.ONE * maxf(fitted_scale, 0.1)
	position = Vector2(
		(viewport_size.x - map_size.x * scale.x) * 0.5,
		64.0 + (available_size.y - map_size.y * scale.y) * 0.5
	)


func _on_previous_seed_pressed() -> void:
	map_seed -= 1
	_generate_current_seed()


func _on_next_seed_pressed() -> void:
	map_seed += 1
	_generate_current_seed()


func _on_randomize_pressed() -> void:
	map_seed = randi()
	_generate_current_seed()


func _on_clear_towers_pressed() -> void:
	tower_origins.clear()
	_rebuild_routes()
	_update_tower_label()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var viewport_position := Vector2.ZERO
	if event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		viewport_position = event.position
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		viewport_position = event.position
	if not pressed:
		return

	var local_position := to_local(viewport_position)
	var cell := Vector2i(floor(local_position / float(Terrain.TILE_SIZE)))
	if not generator.contains(cell):
		return
	var occupied_index := _find_tower_at_cell(cell)
	if occupied_index >= 0:
		tower_origins.remove_at(occupied_index)
		_rebuild_routes()
		_update_tower_label()
		return
	var origin := Vector2i(
		clampi(cell.x, 0, generator.grid_size.x - FlowField.TOWER_FOOTPRINT_CELLS.x),
		clampi(cell.y, 0, generator.grid_size.y - FlowField.TOWER_FOOTPRINT_CELLS.y)
	)
	if _tower_footprint_is_free(origin) and _tower_footprint_is_buildable(origin):
		tower_origins.append(origin)
	_rebuild_routes()
	_update_tower_label()


func _tower_footprint_is_free(origin: Vector2i) -> bool:
	for existing_origin in tower_origins:
		var difference := (origin - existing_origin).abs()
		if (
			difference.x < FlowField.TOWER_FOOTPRINT_CELLS.x
			and difference.y < FlowField.TOWER_FOOTPRINT_CELLS.y
		):
			return false
	return true


func _tower_footprint_is_buildable(origin: Vector2i) -> bool:
	for y_offset in FlowField.TOWER_FOOTPRINT_CELLS.y:
		for x_offset in FlowField.TOWER_FOOTPRINT_CELLS.x:
			var cell := origin + Vector2i(x_offset, y_offset)
			var terrain_data := Terrain.get_data(generator.get_terrain(cell))
			if not bool(terrain_data["buildable"]):
				return false
	return true


func _find_tower_at_cell(cell: Vector2i) -> int:
	for index in tower_origins.size():
		var origin := tower_origins[index]
		if (
			cell.x >= origin.x
			and cell.y >= origin.y
			and cell.x < origin.x + FlowField.TOWER_FOOTPRINT_CELLS.x
			and cell.y < origin.y + FlowField.TOWER_FOOTPRINT_CELLS.y
		):
			return index
	return -1


func _rebuild_routes() -> void:
	var blocked: Array[Vector2i] = []
	for y in range(
		generator.profile.safe_top_rows,
		generator.profile.protected_right_top_rows
	):
		for x_offset in generator.profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	for y in range(
		generator.grid_size.y - generator.profile.protected_right_bottom_rows,
		generator.grid_size.y - generator.profile.safe_bottom_rows
	):
		for x_offset in generator.profile.protected_right_columns:
			blocked.append(Vector2i(generator.grid_size.x - 1 - x_offset, y))
	var exits: Array[int] = []
	for y in range(
		generator.profile.exit_top_margin_rows,
		generator.grid_size.y - generator.profile.exit_bottom_margin_rows
	):
		exits.append(y)
	flow_field.rebuild(
		generator.cells,
		generator.grid_size,
		tower_origins,
		Rect2i(
			Vector2i(0, generator.profile.safe_top_rows),
			Vector2i(
				generator.grid_size.x,
				generator.grid_size.y
					- generator.profile.safe_top_rows
					- generator.profile.safe_bottom_rows
			)
		),
		blocked,
		exits
	)
	queue_redraw()


func _update_tower_label() -> void:
	tower_label.text = "%d TEST TOWERS" % tower_origins.size()
