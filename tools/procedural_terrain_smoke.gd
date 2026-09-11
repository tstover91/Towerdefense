extends Node

const Terrain = preload("res://procedural_map/terrain_catalog.gd")
const Generator = preload("res://procedural_map/terrain_generator.gd")


func _ready() -> void:
	var first := Generator.new()
	var second := Generator.new()
	var first_cells: Array[int] = first.generate(12345)
	var second_cells: Array[int] = second.generate(12345)
	assert(first_cells == second_cells)
	assert(first_cells.size() == Generator.GRID_SIZE.x * Generator.GRID_SIZE.y)
	assert(first.count_terrain(Terrain.TerrainType.FIELD) > 0)
	assert(first.count_terrain(Terrain.TerrainType.FOREST) > 0)
	assert(first.count_terrain(Terrain.TerrainType.MUD) > 0)
	for y in Generator.GRID_SIZE.y:
		for x in Generator.EDGE_CLEARANCE_COLUMNS:
			assert(first.get_terrain(Vector2i(x, y)) == Terrain.TerrainType.FIELD)
			assert(first.get_terrain(Vector2i(Generator.GRID_SIZE.x - 1 - x, y)) == Terrain.TerrainType.FIELD)
	print("Procedural terrain smoke test passed: deterministic 28x16 field, forest, and mud generation.")
	get_tree().quit(0)

