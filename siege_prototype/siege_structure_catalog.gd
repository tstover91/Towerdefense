class_name SiegeStructureCatalog
extends RefCounted

# Clash values are reference ratios, not drop-in balance. The prototype health
# scale maps a TH6 Town Hall's 2,800 HP to a 900 HP Command Core.
const DEFINITIONS := {
	&"command_core": {
		"display_name": "Command Core",
		"max_health": 900.0,
		"integrity_value": 4,
		"blocks_movement": true,
		"counts_for_objective": true,
		"reference_level": 6,
		"reference_health": 2800.0,
	},
	&"cannon": {
		"display_name": "Cannon",
		"max_health": 235.0,
		"integrity_value": 1,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 18.0,
		"attack_interval": 0.8,
		"attack_range_cells": 5.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 0.0,
		"reference_level": 7,
		"reference_health": 730.0,
		"reference_dps": 40.0,
	},
	&"mortar": {
		"display_name": "Mortar",
		"max_health": 180.0,
		"integrity_value": 2,
		"blocks_movement": true,
		"counts_for_objective": true,
		"attack_damage": 55.0,
		"attack_interval": 3.0,
		"attack_range_cells": 6.0,
		"minimum_range_cells": 2.0,
		"splash_radius_cells": 1.25,
		"reference_level": 4,
		"reference_health": 550.0,
		"reference_damage_per_hit": 35.0,
		"reference_attack_interval": 5.0,
	},
	&"wall": {
		"display_name": "Wall",
		"max_health": 580.0,
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
