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
		"move_speed_cells": 2.2,
		"reference_move_speed_tiles": 2.2,
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
}


static func has_kind(kind: StringName) -> bool:
	return DEFINITIONS.has(kind)


static func get_definition(kind: StringName) -> Dictionary:
	return Dictionary(DEFINITIONS.get(kind, {})).duplicate(true)
