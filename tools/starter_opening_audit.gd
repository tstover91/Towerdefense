extends Node

const GameStats = preload("res://stat_database.gd")
const CombatSimulator = preload("res://tools/tower_balance_monte_carlo.gd")
const STARTERS: Array[StringName] = [
	&"gunslinger", &"energy_core", &"orb_barrage", &"assassin", &"reactor",
]
const OPENING_COUNTS := [6, 8, 10, 13, 16]
const SAMPLE_COUNT := 200


func _ready() -> void:
	var combat = CombatSimulator.new()
	combat.duration = 10.0
	combat.rng.seed = 741852
	print("STARTER OPENING AUDIT (10 seconds of representative engagement)")
	for tower_id in STARTERS:
		var tower := GameStats.get_tower(tower_id)
		var stats := build_level_stats(tower_id, 0)
		var traits := build_level_traits(tower_id, 0)
		var source_id := GameStats.get_tower_combat_source_id(tower_id)
		var round_ratios := PackedFloat32Array()
		for round_number in range(1, 6):
			var enemy := GameStats.get_enemy(&"normal")
			var scenario := combat.build_enemy_scenario(
				&"normal", enemy, OPENING_COUNTS[round_number - 1]
			)
			scenario["health"] = (
				float(enemy["health"])
				* GameStats.get_enemy_health_multiplier(round_number, &"normal")
			)
			var dps_sum := 0.0
			for _sample in SAMPLE_COUNT:
				dps_sum += combat.simulate_trial(source_id, stats, traits, scenario)
			var mean_dps := dps_sum / float(SAMPLE_COUNT)
			var total_health := float(scenario["health"]) * float(scenario["enemies"])
			round_ratios.append(mean_dps * combat.duration / maxf(total_health, 1.0))
		print("%s cost=%d clear_ratios=%s" % [
			tower_id,
			int(tower["placement_cost"]),
			format_ratios(round_ratios),
		])
	combat.free()
	get_tree().quit(0)


func build_level_stats(tower_id: StringName, level_index: int) -> Dictionary:
	var tower := GameStats.get_tower(tower_id)
	var stats: Dictionary = tower["levels"][level_index].duplicate(true)
	for inherent_path in GameStats.get_tower_inherent_paths(tower_id):
		apply_numeric(stats, inherent_path.get("stat_multipliers", {}), true)
		apply_numeric(stats, inherent_path.get("stat_additions", {}), false)
		for key in inherent_path.get("stat_overrides", {}):
			stats[key] = inherent_path["stat_overrides"][key]
		if inherent_path.has("pierce_count_add"):
			stats["pierce_count"] = (
				int(stats.get("pierce_count", 0))
				+ int(inherent_path["pierce_count_add"])
			)
	return stats


func build_level_traits(tower_id: StringName, level_index: int) -> Dictionary:
	var tower := GameStats.get_tower(tower_id)
	var damage_tags: Array = tower.get("damage_tags", []).duplicate()
	var bonus_tags: Array = tower.get("bonus_tags", []).duplicate()
	var flags := {}
	var values := {}
	var primary_type := StringName(tower.get(
		"primary_damage_type", damage_tags[0] if not damage_tags.is_empty() else &""
	))
	for definition in GameStats.get_tower_inherent_paths(tower_id):
		apply_trait_definition(
			definition, damage_tags, bonus_tags, flags, values
		)
		primary_type = StringName(definition.get("primary_damage_type", primary_type))
	var level: Dictionary = tower["levels"][level_index]
	apply_trait_definition(level, damage_tags, bonus_tags, flags, values)
	return {
		"damage_tags": damage_tags,
		"bonus_tags": bonus_tags,
		"primary_type": primary_type,
		"delivery": StringName(tower.get("delivery_type", GameStats.DELIVERY_HITSCAN)),
		"impact": StringName(tower.get("impact_mode", GameStats.IMPACT_PRIMARY)),
		"flags": flags,
		"values": values,
	}


func apply_trait_definition(
	definition: Dictionary,
	damage_tags: Array,
	bonus_tags: Array,
	flags: Dictionary,
	values: Dictionary
) -> void:
	for tag in definition.get("add_damage_tags", []):
		if tag not in damage_tags:
			damage_tags.append(tag)
	for tag in definition.get("remove_damage_tags", []):
		damage_tags.erase(tag)
	for tag in definition.get("add_bonus_tags", []):
		if tag not in bonus_tags:
			bonus_tags.append(tag)
	for tag in definition.get("remove_bonus_tags", []):
		bonus_tags.erase(tag)
	flags.merge(definition.get("behavior_flags", {}), true)
	values.merge(definition.get("behavior_values", {}), true)


func apply_numeric(stats: Dictionary, modifiers: Dictionary, multiply: bool) -> void:
	for key in modifiers:
		if not stats.has(key):
			continue
		if stats[key] is int:
			stats[key] = (
				roundi(float(stats[key]) * float(modifiers[key]))
				if multiply
				else int(stats[key]) + roundi(float(modifiers[key]))
			)
		elif stats[key] is float:
			stats[key] = (
				float(stats[key]) * float(modifiers[key])
				if multiply
				else float(stats[key]) + float(modifiers[key])
			)


func format_ratios(ratios: PackedFloat32Array) -> String:
	var labels := PackedStringArray()
	for ratio in ratios:
		labels.append("%.2f" % ratio)
	return "[" + ", ".join(labels) + "]"
