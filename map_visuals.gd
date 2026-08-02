extends Node2D

const SOURCE_ID := 0
const MAP_SIZE := Vector2i(15, 11)
const GRASS_TILES := [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(3, 0), Vector2i(4, 0),
]
const WATER_TILES := [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
const STONE_TILES := [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]
const ROCKY_TILES := [
	Vector2i(6, 3), Vector2i(7, 3), Vector2i(0, 4), Vector2i(4, 4),
]

@onready var ground: TileMapLayer = $Ground
@onready var path_visuals: TileMapLayer = $PathVisuals
@onready var details: TileMapLayer = $Details


func _ready() -> void:
	_paint_map()


func _paint_map() -> void:
	ground.clear()
	path_visuals.clear()
	details.clear()
	_paint_ground()
	_paint_terrain_features()
	_paint_road()
	_paint_details()


func _paint_ground() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var variant_index := posmod(x * 7 + y * 11, GRASS_TILES.size())
			var atlas_coordinates: Vector2i = GRASS_TILES[variant_index]
			ground.set_cell(Vector2i(x, y), SOURCE_ID, atlas_coordinates)


func _paint_terrain_features() -> void:
	for y in range(7, 11):
		for x in range(0, 3):
			var water_index := mini(x, WATER_TILES.size() - 1)
			var water_tile: Vector2i = WATER_TILES[water_index]
			ground.set_cell(Vector2i(x, y), SOURCE_ID, water_tile)

	for y in range(5, 7):
		for x in range(7, 10):
			var stone_index := posmod(x + y, STONE_TILES.size())
			var stone_tile: Vector2i = STONE_TILES[stone_index]
			ground.set_cell(Vector2i(x, y), SOURCE_ID, stone_tile)

	for y in range(5, 8):
		for x in range(13, 15):
			var rocky_index := posmod(x * 3 + y, ROCKY_TILES.size())
			var rocky_tile: Vector2i = ROCKY_TILES[rocky_index]
			ground.set_cell(Vector2i(x, y), SOURCE_ID, rocky_tile)

	ground.set_cell(Vector2i(7, 0), SOURCE_ID, Vector2i(5, 4))
	ground.set_cell(Vector2i(8, 0), SOURCE_ID, Vector2i(6, 4))
	ground.set_cell(Vector2i(9, 0), SOURCE_ID, Vector2i(7, 4))


func _paint_road() -> void:
	var vertical := Vector2i(0, 1)
	var horizontal := Vector2i(1, 1)
	var corner_right_bottom := Vector2i(4, 1)
	var corner_left_bottom := Vector2i(5, 1)
	var corner_right_top := Vector2i(6, 1)
	var corner_left_top := Vector2i(7, 1)

	for y in range(0, 3):
		path_visuals.set_cell(Vector2i(2, y), SOURCE_ID, vertical)
	path_visuals.set_cell(Vector2i(2, 3), SOURCE_ID, corner_right_top)
	for x in range(3, 12):
		path_visuals.set_cell(Vector2i(x, 3), SOURCE_ID, horizontal)
	path_visuals.set_cell(Vector2i(12, 3), SOURCE_ID, corner_left_bottom)
	for y in range(4, 8):
		path_visuals.set_cell(Vector2i(12, y), SOURCE_ID, vertical)
	path_visuals.set_cell(Vector2i(12, 8), SOURCE_ID, corner_left_top)
	for x in range(5, 12):
		path_visuals.set_cell(Vector2i(x, 8), SOURCE_ID, horizontal)
	path_visuals.set_cell(Vector2i(4, 8), SOURCE_ID, corner_right_bottom)
	for y in range(9, 11):
		path_visuals.set_cell(Vector2i(4, y), SOURCE_ID, vertical)


func _paint_details() -> void:
	var detail_tiles := {
		Vector2i(0, 1): Vector2i(0, 6),
		Vector2i(1, 4): Vector2i(1, 6),
		Vector2i(5, 1): Vector2i(5, 0),
		Vector2i(10, 1): Vector2i(6, 0),
		Vector2i(13, 1): Vector2i(7, 0),
		Vector2i(5, 5): Vector2i(6, 6),
		Vector2i(11, 6): Vector2i(7, 6),
		Vector2i(5, 10): Vector2i(4, 7),
		Vector2i(10, 10): Vector2i(5, 7),
		Vector2i(14, 9): Vector2i(6, 7),
	}
	for map_coordinates: Vector2i in detail_tiles:
		var atlas_coordinates: Vector2i = detail_tiles[map_coordinates]
		details.set_cell(map_coordinates, SOURCE_ID, atlas_coordinates)
