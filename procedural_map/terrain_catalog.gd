class_name TerrainCatalog
extends RefCounted

enum TerrainType {
	FIELD,
	FOREST,
	MUD,
}

const TILE_SIZE := 32
const TERRAIN_DATA := {
	TerrainType.FIELD: {
		"display_name": "Field",
		"route_cost": 1.0,
		"speed_multiplier": 1.0,
		"buildable": true,
		"texture_path": "res://assets/terrain/field_basic.png",
	},
	TerrainType.FOREST: {
		"display_name": "Forest",
		"route_cost": 1.15,
		"speed_multiplier": 0.85,
		"buildable": true,
		"texture_path": "res://assets/terrain/forest_basic.png",
	},
	TerrainType.MUD: {
		"display_name": "Mud",
		"route_cost": 1.35,
		"speed_multiplier": 0.70,
		"buildable": false,
		"texture_path": "res://assets/terrain/mud_basic.png",
	},
}


static func get_data(terrain_type: int) -> Dictionary:
	return TERRAIN_DATA.get(terrain_type, TERRAIN_DATA[TerrainType.FIELD])


static func get_texture_path(terrain_type: int) -> String:
	return String(get_data(terrain_type)["texture_path"])
