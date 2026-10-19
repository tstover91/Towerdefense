class_name SiegeStructureCatalog
extends RefCounted

# Phase 4 deliberately uses an exact TH6 Clash stat snapshot. Geometry and the
# integrity objective remain prototype-specific, but combat values are copied.
const DEFINITIONS := {
	&"command_core": {
		"display_name": "Command Core",
		"max_health": 2800.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"reference_level": 6,
		"reference_health": 2800.0,
	},
	&"cannon": {
		"display_name": "Cannon",
		"max_health": 730.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 32.0,
		"attack_interval": 0.8,
		"attack_range_cells": 9.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 0.0,
		"reference_level": 7,
		"reference_health": 730.0,
		"reference_dps": 40.0,
		"is_defense": true,
		"target_type": &"ground",
	},
	&"archer_tower": {
		"display_name": "Archer Tower",
		"max_health": 630.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 21.0,
		"attack_interval": 0.5,
		"attack_range_cells": 10.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 0.0,
		"reference_level": 7,
		"reference_health": 630.0,
		"reference_dps": 42.0,
		"is_defense": true,
		"target_type": &"ground_air",
	},
	&"mortar": {
		"display_name": "Mortar",
		"max_health": 550.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 35.0,
		"attack_interval": 5.0,
		"attack_range_cells": 11.0,
		"minimum_range_cells": 4.0,
		"splash_radius_cells": 1.5,
		"reference_level": 4,
		"reference_health": 550.0,
		"reference_damage_per_hit": 35.0,
		"reference_attack_interval": 5.0,
		"is_defense": true,
		"target_type": &"ground",
	},
	&"air_defense": {
		"display_name": "Air Defense",
		"max_health": 950.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 160.0,
		"attack_interval": 1.0,
		"attack_range_cells": 10.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 0.0,
		"reference_level": 4,
		"reference_health": 950.0,
		"reference_dps": 160.0,
		"is_defense": true,
		"target_type": &"air",
	},
	&"wizard_tower": {
		"display_name": "Wizard Tower",
		"max_health": 680.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 20.8,
		"attack_interval": 1.3,
		"attack_range_cells": 7.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 1.0,
		"reference_level": 3,
		"reference_health": 680.0,
		"reference_dps": 16.0,
		"is_defense": true,
		"target_type": &"ground_air",
	},
	&"air_sweeper": {
		"display_name": "Air Sweeper",
		"max_health": 800.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 0.0,
		"attack_interval": 5.0,
		"attack_range_cells": 15.0,
		"minimum_range_cells": 1.0,
		"push_distance_cells": 2.0,
		"reference_level": 2,
		"reference_health": 800.0,
		"is_defense": true,
		"target_type": &"air",
	},
	&"wall": {
		"display_name": "Wall",
		"max_health": 1800.0,
		"integrity_value": 0,
		"blocks_movement": true,
		"counts_for_objective": false,
		"reference_level": 6,
		"reference_health": 1800.0,
	},
}


static func has_kind(kind: StringName) -> bool:
	return DEFINITIONS.has(kind)


static func get_definition(kind: StringName) -> Dictionary:
	return Dictionary(DEFINITIONS.get(kind, {})).duplicate(true)


static func get_max_health(kind: StringName) -> float:
	return float(DEFINITIONS.get(kind, {}).get("max_health", 0.0))
