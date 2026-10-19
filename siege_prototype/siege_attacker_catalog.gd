class_name SiegeAttackerCatalog
extends RefCounted

# Exact TH6-era Home Village combat values. Display names differ so this remains
# an original prototype, but HP, damage, cadence, range, and speed are copied.
const DEFINITIONS := {
	&"raider": {
		"display_name": "Raider",
		"max_health": 65.0,
		"damage": 15.0,
		"wall_damage": 15.0,
		"attack_interval": 1.0,
		"move_speed_cells": 2.25,
		"reference_move_speed_tiles": 2.25,
		"attack_range_cells": 0.4,
		"preferred_target": &"any",
		"self_destructs": false,
		"reference_unit": "Barbarian",
		"reference_level": 3,
		"reference_health": 65.0,
		"reference_dps": 14.0,
	},
	&"brute": {
		"display_name": "Brute",
		"max_health": 600.0,
		"damage": 40.0,
		"wall_damage": 40.0,
		"attack_interval": 2.0,
		"move_speed_cells": 1.5,
		"reference_move_speed_tiles": 1.5,
		"attack_range_cells": 1.0,
		"preferred_target": &"defenses",
		"self_destructs": false,
		"reference_unit": "Giant",
		"reference_level": 3,
		"reference_health": 600.0,
		"reference_dps": 20.0,
	},
	&"sapper": {
		"display_name": "Sapper",
		"max_health": 29.0,
		"damage": 25.0,
		"wall_damage": 1000.0,
		"death_damage": 13.0,
		"death_wall_damage": 520.0,
		"death_damage_radius_cells": 2.0,
		"attack_interval": 1.0,
		"move_speed_cells": 3.0,
		"reference_move_speed_tiles": 3.0,
		"attack_range_cells": 1.0,
		"preferred_target": &"any",
		"self_destructs": true,
		"reference_unit": "Wall Breaker",
		"reference_level": 3,
		"reference_health": 29.0,
		"reference_wall_damage": 1000.0,
	},
	&"ranger": {
		"display_name": "Ranger",
		"max_health": 29.0,
		"damage": 13.0,
		"wall_damage": 13.0,
		"attack_interval": 1.0,
		"move_speed_cells": 3.0,
		"reference_move_speed_tiles": 3.0,
		"attack_range_cells": 3.5,
		"preferred_target": &"any",
		"self_destructs": false,
		"reference_unit": "Archer",
		"reference_level": 3,
		"reference_health": 29.0,
		"reference_dps": 13.0,
	},
}

const LEVEL_STATS := {
	&"raider": {
		1: {"max_health": 45.0, "damage": 9.0, "wall_damage": 9.0, "reference_dps": 9.0},
		2: {"max_health": 54.0, "damage": 12.0, "wall_damage": 12.0, "reference_dps": 12.0},
		3: {"max_health": 65.0, "damage": 15.0, "wall_damage": 15.0, "reference_dps": 15.0},
	},
	&"ranger": {
		1: {"max_health": 22.0, "damage": 8.0, "wall_damage": 8.0, "reference_dps": 8.0},
		2: {"max_health": 26.0, "damage": 10.0, "wall_damage": 10.0, "reference_dps": 10.0},
		3: {"max_health": 29.0, "damage": 13.0, "wall_damage": 13.0, "reference_dps": 13.0},
	},
	&"brute": {
		1: {"max_health": 400.0, "damage": 24.0, "wall_damage": 24.0, "reference_dps": 12.0},
		2: {"max_health": 500.0, "damage": 30.0, "wall_damage": 30.0, "reference_dps": 15.0},
		3: {"max_health": 600.0, "damage": 40.0, "wall_damage": 40.0, "reference_dps": 20.0},
	},
	&"sapper": {
		1: {"max_health": 20.0, "damage": 10.0, "wall_damage": 400.0, "death_damage": 6.0, "death_wall_damage": 240.0},
		2: {"max_health": 24.0, "damage": 20.0, "wall_damage": 800.0, "death_damage": 10.0, "death_wall_damage": 400.0},
		3: {"max_health": 29.0, "damage": 25.0, "wall_damage": 1000.0, "death_damage": 13.0, "death_wall_damage": 520.0},
	},
}


static func has_kind(kind: StringName) -> bool:
	return DEFINITIONS.has(kind)


static func get_definition(kind: StringName, level := -1) -> Dictionary:
	var result := Dictionary(DEFINITIONS.get(kind, {})).duplicate(true)
	if result.is_empty():
		return result
	var resolved_level := level
	if resolved_level < 0:
		resolved_level = int(result.get("reference_level", 1))
	var levels: Dictionary = LEVEL_STATS.get(kind, {})
	if levels.has(resolved_level):
		result.merge(Dictionary(levels[resolved_level]), true)
	result["reference_level"] = resolved_level
	return result
