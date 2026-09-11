extends Node2D

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")

@export var map_seed := 481516

@onready var seed_label: Label = $Interface/TopBar/SeedLabel

var generator := Generator.new()
var terrain_textures: Dictionary = {}


func _ready() -> void:
	_load_terrain_textures()
	get_viewport().size_changed.connect(_fit_map_to_viewport)
	_generate_current_seed()
	_fit_map_to_viewport()


func _draw() -> void:
	var tile_size := Vector2(Terrain.TILE_SIZE, Terrain.TILE_SIZE)
	for y in Generator.GRID_SIZE.y:
		for x in Generator.GRID_SIZE.x:
			var cell := Vector2i(x, y)
			var terrain_type := generator.get_terrain(cell)
			var texture := terrain_textures[terrain_type] as Texture2D
			draw_texture_rect(
				texture,
				Rect2(Vector2(cell * Terrain.TILE_SIZE), tile_size),
				false
			)
	_draw_grid()


func _load_terrain_textures() -> void:
	for terrain_type in Terrain.TERRAIN_DATA:
		var image := Image.load_from_file(
			ProjectSettings.globalize_path(Terrain.get_texture_path(terrain_type))
		)
		assert(not image.is_empty(), "Unable to load procedural terrain texture")
		terrain_textures[terrain_type] = ImageTexture.create_from_image(image)


func _draw_grid() -> void:
	var map_size := Vector2(Generator.GRID_SIZE * Terrain.TILE_SIZE)
	var grid_color := Color("24182124")
	for x in range(Generator.GRID_SIZE.x + 1):
		var line_x := float(x * Terrain.TILE_SIZE)
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, map_size.y), grid_color)
	for y in range(Generator.GRID_SIZE.y + 1):
		var line_y := float(y * Terrain.TILE_SIZE)
		draw_line(Vector2(0.0, line_y), Vector2(map_size.x, line_y), grid_color)


func _generate_current_seed() -> void:
	generator.generate(map_seed)
	seed_label.text = "SEED %d" % map_seed
	queue_redraw()


func _fit_map_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var map_size := Vector2(Generator.GRID_SIZE * Terrain.TILE_SIZE)
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
