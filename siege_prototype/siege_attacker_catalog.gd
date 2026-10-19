class_name SiegeAttackerCatalog
extends RefCounted

# Combat values are compressed for a short prototype round. Reference fields
# record the TH6-era Clash unit that inspired each role.
const DEFINITIONS := {
	&"raider": {
		"display_name": "Raider",
		"max_health": 70.0,
		"damage": 22.0,
		"wall_damage": 22.0,
		"attack_interval": 1.0,
		"move_speed_cells": 2.2,
		"attack_range_cells": 1.05,
		"preferred_target": &"any",
		"self_destructs": false,
		"reference_unit": "Barbarian",
		"reference_level": 3,
		"reference_health": 65.0,
		"reference_dps": 14.0,
	},
	&"brute": {
		"display_name": "Brute",
		"max_health": 280.0,
		"damage": 36.0,
		"wall_damage": 36.0,
		"attack_interval": 2.0,
		"move_speed_cells": 1.5,
		"attack_range_cells": 1.05,
		"preferred_target": &"defenses",
		"self_destructs": false,
		"reference_unit": "Giant",
		"reference_level": 3,
		"reference_health": 600.0,
		"reference_dps": 20.0,
	},
	&"sapper": {
		"display_name": "Sapper",
		"max_health": 42.0,
		"damage": 20.0,
		"wall_damage": 600.0,
		"attack_interval": 1.0,
		"move_speed_cells": 3.0,
		"attack_range_cells": 1.05,
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
