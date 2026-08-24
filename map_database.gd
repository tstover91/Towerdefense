class_name MapDatabase
extends RefCounted

const DEFAULT_MAP_ID: StringName = &"farm"
const MAPS := {
	&"farm": {
		"display_name": "Farm",
		"scene": preload("res://maps/farm_map.tscn"),
		"preview": preload("res://assets/maps/farm.png"),
	},
	&"farm_gauntlet": {
		"display_name": "Farm Gauntlet",
		"scene": preload("res://maps/farm_gauntlet_map.tscn"),
		"preview": preload("res://assets/maps/farm_gauntlet.png"),
	},
}


static func has_map(map_id: StringName) -> bool:
	return MAPS.has(map_id)


static func get_map(map_id: StringName) -> Dictionary:
	var resolved_id := map_id if MAPS.has(map_id) else DEFAULT_MAP_ID
	var definition: Dictionary = MAPS[resolved_id].duplicate(true)
	definition["id"] = resolved_id
	return definition


static func get_map_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for map_key in MAPS:
		ids.append(StringName(map_key))
	return ids


static func instantiate_map(map_id: StringName) -> TowerDefenseMap:
	var definition := get_map(map_id)
	return (definition["scene"] as PackedScene).instantiate() as TowerDefenseMap
