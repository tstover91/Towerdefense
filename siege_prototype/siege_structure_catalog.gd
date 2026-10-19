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
		# Low-level Clash Town Halls do not fire. For this defense game the Core
		# uses the exact level-one Cannon shot, cadence, and range as a weak gun.
		"attack_damage": 5.6,
		"attack_interval": 0.8,
		"attack_range_cells": 9.0,
		"minimum_range_cells": 0.0,
		"splash_radius_cells": 0.0,
		"reference_dps": 7.0,
		"can_attack": true,
		"target_type": &"ground",
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

# Current Clash combat values for the TH1-TH3 vertical slice. Economy values
# intentionally live outside this table because the run uses a condensed TD
# currency instead of Clash build prices and timers.
const LEVEL_STATS := {
	&"command_core": {
		1: {"max_health": 400.0},
		2: {"max_health": 800.0},
		3: {"max_health": 1600.0},
		6: {"max_health": 2800.0},
	},
	&"cannon": {
		1: {"max_health": 300.0, "attack_damage": 5.6, "reference_dps": 7.0},
		2: {"max_health": 360.0, "attack_damage": 8.0, "reference_dps": 10.0},
		3: {"max_health": 420.0, "attack_damage": 10.4, "reference_dps": 13.0},
		4: {"max_health": 500.0, "attack_damage": 13.6, "reference_dps": 17.0},
		7: {"max_health": 730.0, "attack_damage": 32.0, "reference_dps": 40.0},
	},
	&"archer_tower": {
		1: {"max_health": 380.0, "attack_damage": 5.5, "reference_dps": 11.0},
		2: {"max_health": 420.0, "attack_damage": 7.5, "reference_dps": 15.0},
		3: {"max_health": 460.0, "attack_damage": 9.5, "reference_dps": 19.0},
		7: {"max_health": 630.0, "attack_damage": 21.0, "reference_dps": 42.0},
	},
	&"mortar": {
		1: {"max_health": 400.0, "attack_damage": 20.0, "reference_damage_per_hit": 20.0},
		4: {"max_health": 550.0, "attack_damage": 35.0, "reference_damage_per_hit": 35.0},
	},
	&"wall": {
		1: {"max_health": 100.0},
		2: {"max_health": 200.0},
		3: {"max_health": 400.0},
		6: {"max_health": 1800.0},
	},
}

const RUN_UPGRADE_COSTS := {
	&"cannon": {2: 3, 3: 4, 4: 5},
	&"archer_tower": {2: 4, 3: 5},
	&"mortar": {},
	&"wall": {2: 1, 3: 2},
}

const RUN_BUILD_COSTS := {
	&"cannon": 5,
	&"archer_tower": 6,
	&"mortar": 8,
	&"wall": 0,
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
	result["level"] = resolved_level
	result["reference_level"] = resolved_level
	result["reference_health"] = float(result.get("max_health", 0.0))
	return result


static func get_max_health(kind: StringName, level := -1) -> float:
	return float(get_definition(kind, level).get("max_health", 0.0))


static func get_build_cost(kind: StringName) -> int:
	return int(RUN_BUILD_COSTS.get(kind, -1))


static func get_upgrade_cost(kind: StringName, next_level: int) -> int:
	return int(Dictionary(RUN_UPGRADE_COSTS.get(kind, {})).get(next_level, -1))
