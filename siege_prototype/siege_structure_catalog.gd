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
		"display_name": "Thermal Projector",
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

# Specializations change one tower's combat role without owning a separate stat
# ladder. Their base damage and health continue to come from the purchased Town
# Hall level, then these behavior modifiers are applied.
const SPECIALIZATIONS := {
	&"wizard_tower": {
		&"plasma_caster": {
			"display_name": "Plasma Caster",
			"cost": 12,
			"attack_mode": &"splash",
			"attack_damage_multiplier": 1.25,
			"attack_range_cells": 8.0,
			"splash_radius_cells": 1.4,
		},
		&"inferno_beam": {
			"display_name": "Inferno Beam",
			"cost": 12,
			"attack_mode": &"ramping_beam",
			"attack_interval": 0.2,
			"attack_range_cells": 8.0,
			"splash_radius_cells": 0.0,
			"target_type": &"ground_air",
			"beam_ramp_start_multiplier": 0.75,
			"beam_ramp_step_multiplier": 0.25,
			"beam_ramp_step_interval": 0.5,
			"beam_ramp_max_multiplier": 2.5,
		},
	},
}

# Current Clash combat values for the TH1-TH7 vertical slice. Economy values
# intentionally live outside this table because the run uses a condensed TD
# currency instead of Clash build prices and timers.
const LEVEL_STATS := {
	&"command_core": {
		1: {"max_health": 400.0},
		2: {"max_health": 800.0},
		3: {"max_health": 1600.0},
		4: {"max_health": 2000.0},
		5: {"max_health": 2400.0},
		6: {"max_health": 2800.0},
		7: {"max_health": 3300.0},
	},
	&"cannon": {
		1: {"max_health": 300.0, "attack_damage": 5.6, "reference_dps": 7.0},
		2: {"max_health": 360.0, "attack_damage": 8.0, "reference_dps": 10.0},
		3: {"max_health": 420.0, "attack_damage": 10.4, "reference_dps": 13.0},
		4: {"max_health": 500.0, "attack_damage": 13.6, "reference_dps": 17.0},
		5: {"max_health": 600.0, "attack_damage": 18.4, "reference_dps": 23.0},
		6: {"max_health": 660.0, "attack_damage": 24.0, "reference_dps": 30.0},
		7: {"max_health": 730.0, "attack_damage": 32.0, "reference_dps": 40.0},
		8: {"max_health": 800.0, "attack_damage": 38.4, "reference_dps": 48.0},
	},
	&"archer_tower": {
		1: {"max_health": 380.0, "attack_damage": 5.5, "reference_dps": 11.0},
		2: {"max_health": 420.0, "attack_damage": 7.5, "reference_dps": 15.0},
		3: {"max_health": 460.0, "attack_damage": 9.5, "reference_dps": 19.0},
		4: {"max_health": 500.0, "attack_damage": 12.5, "reference_dps": 25.0},
		5: {"max_health": 540.0, "attack_damage": 15.0, "reference_dps": 30.0},
		6: {"max_health": 580.0, "attack_damage": 17.5, "reference_dps": 35.0},
		7: {"max_health": 630.0, "attack_damage": 21.0, "reference_dps": 42.0},
		8: {"max_health": 690.0, "attack_damage": 24.0, "reference_dps": 48.0},
	},
	&"mortar": {
		1: {"max_health": 400.0, "attack_damage": 20.0, "reference_damage_per_hit": 20.0},
		2: {"max_health": 450.0, "attack_damage": 25.0, "reference_damage_per_hit": 25.0},
		3: {"max_health": 500.0, "attack_damage": 30.0, "reference_damage_per_hit": 30.0},
		4: {"max_health": 550.0, "attack_damage": 35.0, "reference_damage_per_hit": 35.0},
		5: {"max_health": 600.0, "attack_damage": 45.0, "reference_damage_per_hit": 45.0},
	},
	&"air_defense": {
		1: {"max_health": 800.0, "attack_damage": 80.0, "reference_dps": 80.0},
		2: {"max_health": 850.0, "attack_damage": 110.0, "reference_dps": 110.0},
		3: {"max_health": 900.0, "attack_damage": 140.0, "reference_dps": 140.0},
		4: {"max_health": 950.0, "attack_damage": 160.0, "reference_dps": 160.0},
		5: {"max_health": 1000.0, "attack_damage": 190.0, "reference_dps": 190.0},
	},
	&"wizard_tower": {
		1: {"max_health": 620.0, "attack_damage": 14.3, "reference_dps": 11.0},
		2: {"max_health": 650.0, "attack_damage": 16.9, "reference_dps": 13.0},
		3: {"max_health": 680.0, "attack_damage": 20.8, "reference_dps": 16.0},
		4: {"max_health": 730.0, "attack_damage": 26.0, "reference_dps": 20.0},
	},
	&"wall": {
		1: {"max_health": 100.0},
		2: {"max_health": 200.0},
		3: {"max_health": 400.0},
		4: {"max_health": 800.0},
		5: {"max_health": 1200.0},
		6: {"max_health": 1800.0},
		7: {"max_health": 2400.0},
	},
}

const RUN_UPGRADE_COSTS := {
	&"cannon": {2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9},
	&"archer_tower": {2: 4, 3: 5, 4: 6, 5: 7, 6: 8, 7: 9, 8: 10},
	&"mortar": {2: 7, 3: 8, 4: 9, 5: 10},
	&"air_defense": {2: 7, 3: 9, 4: 10, 5: 11},
	&"wizard_tower": {2: 9, 3: 10, 4: 11},
	&"wall": {2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6},
}

const RUN_BUILD_COSTS := {
	&"cannon": 5,
	&"archer_tower": 6,
	&"mortar": 8,
	&"air_defense": 7,
	&"wizard_tower": 9,
	&"wall": 0,
}


static func has_kind(kind: StringName) -> bool:
	return DEFINITIONS.has(kind)


static func get_definition(kind: StringName, level := -1, specialization: StringName = &"") -> Dictionary:
	var result := Dictionary(DEFINITIONS.get(kind, {})).duplicate(true)
	if result.is_empty():
		return result
	var resolved_level := level
	if resolved_level < 0:
		resolved_level = int(result.get("reference_level", 1))
	var levels: Dictionary = LEVEL_STATS.get(kind, {})
	if levels.has(resolved_level):
		result.merge(Dictionary(levels[resolved_level]), true)
	if specialization != &"":
		_apply_specialization(result, kind, specialization)
	result["level"] = resolved_level
	result["specialization"] = specialization
	result["reference_level"] = resolved_level
	result["reference_health"] = float(result.get("max_health", 0.0))
	return result


static func _apply_specialization(result: Dictionary, kind: StringName, specialization: StringName) -> void:
	var specialization_definition := get_specialization_definition(kind, specialization)
	if specialization_definition.is_empty():
		return
	var base_reference_dps := float(result.get("reference_dps", 0.0))
	if base_reference_dps <= 0.0:
		var base_interval := maxf(float(result.get("attack_interval", 1.0)), 0.01)
		base_reference_dps = float(result.get("attack_damage", 0.0)) / base_interval
	var damage_multiplier := float(specialization_definition.get("attack_damage_multiplier", 1.0))
	for key in specialization_definition:
		if key in ["cost", "attack_damage_multiplier"]:
			continue
		result[key] = specialization_definition[key]
	var attack_mode := StringName(result.get("attack_mode", &"single"))
	if attack_mode == &"ramping_beam":
		result["attack_damage"] = base_reference_dps * float(result.get("attack_interval", 0.2))
		result["reference_dps"] = base_reference_dps
		result["maximum_reference_dps"] = base_reference_dps * float(result.get("beam_ramp_max_multiplier", 1.0))
	else:
		result["attack_damage"] = float(result.get("attack_damage", 0.0)) * damage_multiplier
		result["reference_dps"] = float(result.get("attack_damage", 0.0)) / maxf(float(result.get("attack_interval", 1.0)), 0.01)


static func get_specialization_ids(kind: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for specialization in Dictionary(SPECIALIZATIONS.get(kind, {})).keys():
		result.append(StringName(specialization))
	return result


static func has_specialization(kind: StringName, specialization: StringName) -> bool:
	return Dictionary(SPECIALIZATIONS.get(kind, {})).has(specialization)


static func get_specialization_definition(kind: StringName, specialization: StringName) -> Dictionary:
	return Dictionary(Dictionary(SPECIALIZATIONS.get(kind, {})).get(specialization, {})).duplicate(true)


static func get_specialization_cost(kind: StringName, specialization: StringName) -> int:
	return int(get_specialization_definition(kind, specialization).get("cost", -1))


static func get_specialization_display_name(kind: StringName, specialization: StringName) -> String:
	return String(get_specialization_definition(kind, specialization).get("display_name", specialization))


static func get_max_health(kind: StringName, level := -1) -> float:
	return float(get_definition(kind, level).get("max_health", 0.0))


static func get_build_cost(kind: StringName) -> int:
	return int(RUN_BUILD_COSTS.get(kind, -1))


static func get_upgrade_cost(kind: StringName, next_level: int) -> int:
	return int(Dictionary(RUN_UPGRADE_COSTS.get(kind, {})).get(next_level, -1))
