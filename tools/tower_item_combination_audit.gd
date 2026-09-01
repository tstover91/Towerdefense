extends "res://tools/tower_balance_monte_carlo.gd"

const DEFAULT_ITEM_REPORT := "res://balance_reports/tower_item_combinations.csv"
const DEFAULT_OUTLIER_REPORT := "res://balance_reports/tower_item_combination_outliers.csv"
const DEFAULT_ITEM_LEVELS: Array[int] = [20]
const ITEM_AUDIT_ENEMY_COUNTS: Array[int] = [1, 3, 6, 12]

var maximum_items := GameStats.TOWER_ITEM_SLOT_COUNT
var item_filter: Array[StringName] = []
var shard_index := 0
var shard_count := 1
var loadout_limit := 0
var item_report_path := DEFAULT_ITEM_REPORT
var outlier_report_path := DEFAULT_OUTLIER_REPORT
var raw_item_iterations := 1
var evaluated_loadouts := 0
var simulated_loadouts := 0
var flagged_loadouts := 0
var list_only := false
var generated_loadout_count := 0
var outliers_only := false
var maximum_report_bytes := 0
var report_was_truncated := false


func _ready() -> void:
	call_deferred("run_item_combination_audit")


func run_item_combination_audit() -> void:
	read_item_arguments()
	rng.seed = seed_value
	enemy_counts = ITEM_AUDIT_ENEMY_COUNTS.duplicate()
	build_enemy_scenarios()
	validate_tower_progression()
	var item_ids := get_audited_item_ids()
	var catalog_loadout_count := count_loadouts(item_ids)
	if list_only:
		print("Item combination audit catalog: %d active items, %d loadouts of 1-%d total copies." % [
			item_ids.size(), catalog_loadout_count, maximum_items,
		])
		get_tree().quit(0)
		return
	var loadouts := generate_loadouts(item_ids)
	var report := FileAccess.open(item_report_path, FileAccess.WRITE)
	var outliers := FileAccess.open(outlier_report_path, FileAccess.WRITE)
	assert(report != null, "Could not create %s" % item_report_path)
	assert(outliers != null, "Could not create %s" % outlier_report_path)
	var header := "tower_id,tower_name,level,variant,item_count,loadout,item_cost,mean_power_ratio,worst_ratio,best_ratio,solo_ratio,small_pack_ratio,medium_pack_ratio,swarm_ratio,power_per_1000,performance_load,flags,model_notes"
	report.store_line(header)
	outliers.store_line(header)
	print("Item combination audit: %d items, %d total loadouts (%d in this shard), %d scenarios, shard %d/%d" % [
		item_ids.size(), catalog_loadout_count, loadouts.size(), scenarios.size(),
		shard_index + 1, shard_count,
	])
	for tower_id in GameStats.PLAYABLE_TOWER_FAMILY_IDS:
		if not tower_filter.is_empty() and not tower_filter.has(tower_id):
			continue
		for xp_level in balance_levels:
			audit_variant(report, outliers, tower_id, xp_level, &"", "base", loadouts)
			if xp_level < GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL:
				continue
			for evolution_key in GameStats.get_tower_evolutions(tower_id):
				var evolution_id := StringName(evolution_key)
				audit_variant(
					report, outliers, tower_id, xp_level, evolution_id,
					String(evolution_id), loadouts
				)
	report.close()
	outliers.close()
	print("Item combination audit complete: %d examined, %d simulated, %d flagged." % [
		evaluated_loadouts, simulated_loadouts, flagged_loadouts,
	])
	if report_was_truncated:
		print("Detailed report reached its size limit; outlier recording continued.")
	print("Reports: %s and %s" % [item_report_path, outlier_report_path])
	get_tree().quit(0)


func read_item_arguments() -> void:
	balance_levels = DEFAULT_ITEM_LEVELS.duplicate()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--towers="):
			tower_filter.clear()
			for tower_name in argument.get_slice("=", 1).split(",", false):
				tower_filter.append(StringName(tower_name.strip_edges()))
		elif argument.begins_with("--levels="):
			balance_levels.clear()
			for level_text in argument.get_slice("=", 1).split(",", false):
				balance_levels.append(clampi(
					int(level_text.strip_edges()), 1,
					GameStats.TOWER_XP_MAX_LEVEL
				))
		elif argument == "--all-levels":
			balance_levels.clear()
			for xp_level in range(1, GameStats.TOWER_XP_MAX_LEVEL + 1):
				balance_levels.append(xp_level)
		elif argument.begins_with("--items="):
			item_filter.clear()
			for item_name in argument.get_slice("=", 1).split(",", false):
				item_filter.append(StringName(item_name.strip_edges()))
		elif argument.begins_with("--max-items="):
			maximum_items = clampi(
				int(argument.get_slice("=", 1)), 1,
				GameStats.TOWER_ITEM_SLOT_COUNT
			)
		elif argument.begins_with("--iterations="):
			raw_item_iterations = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--duration="):
			duration = maxf(float(argument.get_slice("=", 1)), 5.0)
		elif argument.begins_with("--seed="):
			seed_value = int(argument.get_slice("=", 1))
		elif argument.begins_with("--shard-index="):
			shard_index = maxi(int(argument.get_slice("=", 1)), 0)
		elif argument.begins_with("--shard-count="):
			shard_count = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--limit-loadouts="):
			loadout_limit = maxi(int(argument.get_slice("=", 1)), 0)
		elif argument == "--list-only":
			list_only = true
		elif argument == "--outliers-only":
			outliers_only = true
		elif argument.begins_with("--max-report-mb="):
			maximum_report_bytes = maxi(
				int(float(argument.get_slice("=", 1)) * 1024.0 * 1024.0), 0
			)
		elif argument.begins_with("--report-path="):
			item_report_path = argument.get_slice("=", 1)
		elif argument.begins_with("--outlier-path="):
			outlier_report_path = argument.get_slice("=", 1)
	shard_index = mini(shard_index, shard_count - 1)
	balance_levels.sort()
	var unique_levels: Array[int] = []
	for xp_level in balance_levels:
		if not unique_levels.has(xp_level):
			unique_levels.append(xp_level)
	balance_levels = unique_levels


func get_audited_item_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for item_id in GameStats.get_tower_item_ids():
		if item_filter.is_empty() or item_filter.has(item_id):
			result.append(item_id)
	result.sort()
	return result


func generate_loadouts(item_ids: Array[StringName]) -> Array[int]:
	assert(item_ids.size() <= 255, "Item audit encoding supports up to 255 items")
	var result: Array[int] = []
	generated_loadout_count = 0
	append_loadouts(item_ids, 0, [], result)
	return result


func count_loadouts(item_ids: Array[StringName]) -> int:
	var counts: Array[int] = [1]
	counts.resize(maximum_items + 1)
	for item_id in item_ids:
		var next_counts := counts.duplicate()
		var maximum_copies := mini(int(GameStats.get_tower_item(item_id).get(
			"max_copies_per_tower", GameStats.TOWER_ITEM_STACK_LIMIT
		)), maximum_items)
		for used in maximum_items + 1:
			for copies in range(1, maximum_copies + 1):
				if used + copies <= maximum_items:
					next_counts[used + copies] += counts[used]
		counts = next_counts
	var total := 0
	for used in range(1, maximum_items + 1):
		total += counts[used]
	return total


func append_loadouts(
	item_ids: Array[StringName],
	start_index: int,
	current: Array[StringName],
	result: Array[int]
) -> void:
	if not current.is_empty():
		if generated_loadout_count % shard_count == shard_index:
			result.append(encode_loadout(item_ids, current))
		generated_loadout_count += 1
	if current.size() >= maximum_items:
		return
	for item_index in range(start_index, item_ids.size()):
		var item_id := item_ids[item_index]
		var maximum_copies := int(GameStats.get_tower_item(item_id).get(
			"max_copies_per_tower", GameStats.TOWER_ITEM_STACK_LIMIT
		))
		if current.count(item_id) >= maximum_copies:
			continue
		current.append(item_id)
		append_loadouts(item_ids, item_index, current, result)
		current.pop_back()


func encode_loadout(item_ids: Array[StringName], loadout: Array[StringName]) -> int:
	var code := loadout.size()
	for position in loadout.size():
		code |= item_ids.find(loadout[position]) << (3 + position * 8)
	return code


func decode_loadout(
	item_ids: Array[StringName],
	code: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	for position in (code & 7):
		var item_index := (code >> (3 + position * 8)) & 255
		result.append(item_ids[item_index])
	return result


func audit_variant(
	report: FileAccess,
	outliers: FileAccess,
	tower_id: StringName,
	xp_level: int,
	evolution_id: StringName,
	variant_name: String,
	loadout_codes: Array[int]
) -> void:
	var tower := GameStats.get_tower(tower_id)
	var base_stats := get_variant_stats(tower_id, xp_level, evolution_id)
	var base_traits := get_variant_traits(tower_id, xp_level, evolution_id)
	var baseline_by_scenario := get_scenario_means(
		tower_id, base_stats, base_traits
	)
	var baseline_model := {
		"effects": {}, "triggers": {}, "unmodeled": [],
		"notes": [], "inactive_items": [],
	}
	var accepted_for_variant := 0
	var item_ids := get_audited_item_ids()
	for loadout_index in loadout_codes.size():
		if loadout_limit > 0 and accepted_for_variant >= loadout_limit:
			break
		evaluated_loadouts += 1
		var loadout := decode_loadout(item_ids, loadout_codes[loadout_index])
		var resolution := resolve_loadout(
			tower_id, evolution_id, base_stats, base_traits,
			loadout
		)
		accepted_for_variant += 1
		simulated_loadouts += 1
		var item_stats: Dictionary = base_stats.duplicate(true)
		var item_traits: Dictionary = base_traits.duplicate(true)
		item_traits["damage_tags"] = Array(base_traits["damage_tags"]).duplicate()
		item_traits["bonus_tags"] = Array(base_traits["bonus_tags"]).duplicate()
		var model := apply_loadout(
			item_stats, item_traits, Array(resolution["equip_order"])
		)
		model["inactive_items"] = Array(resolution["inactive_items"])
		if not Array(resolution["inactive_items"]).is_empty():
			model["notes"].append("Inactive here: %s" % ",".join(
				Array(resolution["inactive_items"])
			))
		var means := get_scenario_means(tower_id, item_stats, item_traits)
		var ratios: Array[float] = []
		var count_ratios := {1: [], 3: [], 6: [], 12: []}
		for scenario_index in scenarios.size():
			var baseline_multiplier := get_contextual_item_multiplier(
				baseline_model, base_stats, base_traits,
				scenarios[scenario_index]
			)
			var baseline := maxf(
				float(baseline_by_scenario[scenario_index]) * baseline_multiplier,
				0.001
			)
			var post_multiplier := get_contextual_item_multiplier(
				model, item_stats, item_traits, scenarios[scenario_index]
			)
			var ratio := float(means[scenario_index]) * post_multiplier / baseline
			if baseline_by_scenario[scenario_index] <= 0.001 and means[scenario_index] <= 0.001:
				ratio = 1.0
			ratios.append(ratio)
			var count := int(scenarios[scenario_index]["primary_count"])
			if count_ratios.has(count):
				count_ratios[count].append(ratio)
		var mean_ratio := mean_float_array(ratios)
		var item_cost := get_loadout_cost(loadout)
		var performance_load := get_performance_load(model, item_stats)
		var flags := get_loadout_flags(
			mean_ratio, ratios.min(), ratios.max(), performance_load,
			Array(model["unmodeled"]), Array(model["inactive_items"])
		)
		var row := PackedStringArray([
			String(tower_id), String(tower["display_name"]), str(xp_level),
			variant_name, str(loadout.size()),
			format_loadout(loadout), str(item_cost),
			"%.4f" % mean_ratio, "%.4f" % ratios.min(),
			"%.4f" % ratios.max(),
			"%.4f" % mean_float_array(count_ratios[1]),
			"%.4f" % mean_float_array(count_ratios[3]),
			"%.4f" % mean_float_array(count_ratios[6]),
			"%.4f" % mean_float_array(count_ratios[12]),
			"%.4f" % ((mean_ratio - 1.0) * 1000.0 / maxf(item_cost, 1.0)),
			"%.2f" % performance_load, "|".join(flags),
			"|".join(model["notes"]),
		])
		var csv_line := to_csv_line(row)
		if not outliers_only and not report_was_truncated:
			var next_line_bytes := csv_line.to_utf8_buffer().size() + 1
			if (
				maximum_report_bytes > 0
				and report.get_position() + next_line_bytes
					> maximum_report_bytes
			):
				report_was_truncated = true
			else:
				report.store_line(csv_line)
		if not flags.is_empty():
			flagged_loadouts += 1
			outliers.store_line(csv_line)
		if evaluated_loadouts % 10000 == 0:
			print("  Examined %d loadouts; %d flagged..." % [
				evaluated_loadouts, flagged_loadouts,
			])


func get_scenario_means(
	tower_id: StringName,
	stats: Dictionary,
	traits: Dictionary
) -> Array[float]:
	var result: Array[float] = []
	for scenario_index in scenarios.size():
		var total := 0.0
		for iteration in raw_item_iterations:
			# Common random numbers make a true no-effect item compare exactly to
			# baseline instead of being flagged because two trials rolled differently.
			rng.seed = seed_value + scenario_index * 104729 + iteration * 1000003
			total += simulate_trial(
				tower_id, stats, traits, scenarios[scenario_index]
			)
		result.append(total / float(raw_item_iterations))
	return result


func resolve_loadout(
	tower_id: StringName,
	evolution_id: StringName,
	stats: Dictionary,
	traits: Dictionary,
	loadout: Array
) -> Dictionary:
	var tags := get_initial_compatibility_tags(
		tower_id, evolution_id, stats, traits
	)
	var remaining: Array = loadout.duplicate()
	var equip_order: Array[StringName] = []
	var made_progress := true
	while made_progress and not remaining.is_empty():
		made_progress = false
		var equipped_index := -1
		for index in remaining.size():
			var item_id := StringName(remaining[index])
			if definition_matches_tags(
				GameStats.get_tower_item(item_id), tower_id, tags,
				loadout, item_id
			):
				equipped_index = index
				break
		if equipped_index < 0:
			break
		var equipped_id := StringName(remaining.pop_at(equipped_index))
		equip_order.append(equipped_id)
		append_granted_tags(tags, GameStats.get_tower_item(equipped_id))
		made_progress = true
	var inactive_items: Array[String] = []
	for item_id in remaining:
		inactive_items.append(String(item_id))
	return {
		"equip_order": equip_order,
		"inactive_items": inactive_items,
	}


func get_initial_compatibility_tags(
	tower_id: StringName,
	evolution_id: StringName,
	stats: Dictionary,
	traits: Dictionary
) -> Array[StringName]:
	var tags: Array[StringName] = [&"attack"]
	var tower := GameStats.get_tower(tower_id)
	for source in [tower.get("type_tags", []), traits["damage_tags"], traits["bonus_tags"]]:
		for tag in source:
			var normalized := StringName(tag)
			if not tags.has(normalized):
				tags.append(normalized)
	var projectile_eligible := bool(tower.get("projectile_item_eligible", true))
	if not evolution_id.is_empty():
		var evolution := GameStats.get_tower_evolution(tower_id, evolution_id)
		if evolution.has("projectile_item_eligible"):
			projectile_eligible = bool(evolution["projectile_item_eligible"])
	if (
		StringName(traits["delivery"]) == GameStats.DELIVERY_PROJECTILE
		and projectile_eligible
		and not Array(traits["damage_tags"]).has(&"beam")
		and not tags.has(&"projectile")
	):
		tags.append(&"projectile")
	if int(stats.get("bounce_count", 0)) > 0 and not tags.has(&"ricochet"):
		tags.append(&"ricochet")
	return tags


func definition_matches_tags(
	item: Dictionary,
	tower_id: StringName,
	tags: Array[StringName],
	loadout: Array,
	item_id: StringName
) -> bool:
	var allowed: Array = item.get("allowed_tower_ids", [])
	if not allowed.is_empty() and not allowed.has(tower_id):
		return false
	for tag in item.get("required_all_tags", []):
		if not tags.has(StringName(tag)):
			return false
	var required_any: Array = item.get("required_any_tags", [])
	if not required_any.is_empty():
		var found := false
		for tag in required_any:
			if tags.has(StringName(tag)):
				found = true
				break
		if not found:
			return false
	for tag in item.get("forbidden_tags", []):
		if tags.has(StringName(tag)):
			return false
	for conflicting_id in item.get("exclusive_with", []):
		if StringName(conflicting_id) != item_id and loadout.has(conflicting_id):
			return false
	for equipped_id in loadout:
		var normalized_id := StringName(equipped_id)
		if normalized_id == item_id:
			continue
		if Array(GameStats.get_tower_item(normalized_id).get(
			"exclusive_with", []
		)).has(item_id):
			return false
	return true


func append_granted_tags(tags: Array[StringName], item: Dictionary) -> void:
	for key in ["add_type_tags", "add_damage_tags", "add_bonus_tags"]:
		for tag in item.get(key, []):
			var normalized := StringName(tag)
			if not tags.has(normalized):
				tags.append(normalized)


func apply_loadout(
	stats: Dictionary,
	traits: Dictionary,
	equip_order: Array
) -> Dictionary:
	var counts: Dictionary = {}
	var triggers: Dictionary = {}
	var effects: Dictionary = {}
	var notes: Array[String] = []
	var unmodeled: Array[String] = []
	for item_value in equip_order:
		var item_id := StringName(item_value)
		var item := GameStats.get_tower_item(item_id)
		counts[item_id] = int(counts.get(item_id, 0)) + 1
		apply_item_definition(stats, item)
		apply_item_tags(traits, item)
		for effect_id in item.get("item_effects", {}):
			effects[effect_id] = float(effects.get(effect_id, 0.0)) + float(item["item_effects"][effect_id])
		for trigger_id in item.get("trigger_effects", {}):
			triggers[trigger_id] = float(triggers.get(trigger_id, 0.0)) + float(item["trigger_effects"][trigger_id])
	apply_legacy_item_effects(stats, traits, effects)
	apply_trigger_stats(stats, traits, triggers)
	for effect_id in effects:
		if effect_id in [
			&"perfect_intelligence", &"charred_clothes", &"big_game_control",
			&"emergency_brake", &"youre_not_special", &"pressure_point",
			&"mentor", &"probability_transmitter",
		]:
			unmodeled.append(String(effect_id))
	for trigger_id in triggers:
		if trigger_id in [
			&"temporary_armor_reduction", &"aftershock", &"patient_hunter",
			&"replication_matrix", &"xp_gain_bonus", &"mentor",
			&"experimental_blueprint",
		]:
			unmodeled.append(String(trigger_id))
	if not unmodeled.is_empty():
		notes.append("Some utility/progression effects require live play validation")
	return {
		"counts": counts, "triggers": triggers, "effects": effects,
		"notes": notes, "unmodeled": unmodeled,
	}


func apply_item_definition(stats: Dictionary, item: Dictionary) -> void:
	apply_defaults(stats, item.get("stat_defaults", {}))
	apply_numeric_modifiers(stats, item.get("stat_multipliers", {}), true)
	apply_numeric_modifiers(stats, item.get("stat_additions", {}), false)
	apply_minimums(stats, item.get("stat_minimums", {}))
	for key in item.get("stat_overrides", {}):
		stats[key] = item["stat_overrides"][key]
	if stats.has("unit_stats"):
		var unit_stats: Dictionary = stats["unit_stats"]
		apply_defaults(unit_stats, item.get("unit_stat_defaults", {}))
		apply_numeric_modifiers(unit_stats, item.get("unit_stat_multipliers", {}), true)
		apply_numeric_modifiers(unit_stats, item.get("unit_stat_additions", {}), false)
		apply_minimums(unit_stats, item.get("unit_stat_minimums", {}))
		stats["unit_stats"] = unit_stats
	if item.has("pierce_count_add"):
		stats["pierce_count"] = int(stats.get("pierce_count", 0)) + int(item["pierce_count_add"])


func apply_defaults(stats: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]


func apply_minimums(stats: Dictionary, minimums: Dictionary) -> void:
	for key in minimums:
		stats[key] = maxf(float(stats.get(key, minimums[key])), float(minimums[key]))


func apply_item_tags(traits: Dictionary, item: Dictionary) -> void:
	for tag in item.get("add_damage_tags", []):
		if not traits["damage_tags"].has(tag):
			traits["damage_tags"].append(tag)
	for tag in item.get("add_bonus_tags", []):
		if not traits["bonus_tags"].has(tag):
			traits["bonus_tags"].append(tag)


func apply_legacy_item_effects(
	stats: Dictionary,
	traits: Dictionary,
	effects: Dictionary
) -> void:
	var target_stats: Dictionary = stats["unit_stats"] if stats.has("unit_stats") else stats
	var damage_key := "damage"
	var interval_key := "attack_interval" if stats.has("unit_stats") else "firerate"
	var range_key := "aim_radius" if stats.has("unit_stats") else "range"
	var heavy := int(effects.get(&"heavy_rounds", 0))
	var lightweight := int(effects.get(&"lightweight_ammo", 0))
	target_stats[damage_key] = maxi(roundi(
		float(target_stats.get(damage_key, 0.0))
		* pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER, heavy)
		* pow(GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER, lightweight)
	), 1)
	target_stats[interval_key] = maxf(
		float(target_stats.get(interval_key, 1.0))
		* pow(GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER, heavy)
		* pow(GameStats.LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER, lightweight),
		0.01
	)
	if range_key in target_stats:
		target_stats[range_key] = maxf(float(target_stats[range_key]), 0.1)
	var lucky := int(effects.get(&"lucky_shot", 0))
	var glass := int(effects.get(&"glass_cannon", 0))
	target_stats["critical_chance"] = clampf(
		float(target_stats.get("critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE))
		+ GameStats.LUCKY_SHOT_CHANCE_PER_STACK * lucky, 0.0, 1.0
	)
	target_stats["critical_multiplier"] = maxf(
		float(target_stats.get("critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER))
		+ GameStats.GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS * glass, 1.0
	)
	if glass > 0:
		target_stats["noncritical_damage_multiplier"] = pow(
			GameStats.GLASS_CANNON_NONCRITICAL_MULTIPLIER, glass
		)
	if int(effects.get(&"suppressive_fire", 0)) > 0:
		target_stats["slow_duration"] = maxf(
			float(target_stats.get("slow_duration", 0.0)),
			GameStats.SUPPRESSIVE_FIRE_DURATION
		)
	if int(effects.get(&"follow_through", 0)) > 0:
		target_stats["pierce_loses_no_power"] = true
	if int(effects.get(&"blast_gel", 0)) > 0 and target_stats.has("splash_radius"):
		target_stats["splash_radius"] = float(target_stats["splash_radius"]) * pow(
			GameStats.BLAST_GEL_RADIUS_MULTIPLIER,
			int(effects.get(&"blast_gel", 0))
		)
	if stats.has("unit_stats"):
		stats["unit_stats"] = target_stats
		stats["damage"] = target_stats["damage"]
		stats["firerate"] = target_stats["attack_interval"]
	if int(stats.get("pierce_count", 0)) > 0 and not traits["bonus_tags"].has(&"pierce"):
		traits["bonus_tags"].append(&"pierce")


func apply_trigger_stats(
	stats: Dictionary,
	traits: Dictionary,
	triggers: Dictionary
) -> void:
	var additional_projectiles := int(triggers.get("additional_projectiles", 0))
	if additional_projectiles > 0:
		stats["projectile_count"] = int(stats.get("projectile_count", 1)) + additional_projectiles
	if float(triggers.get("bounce_damage_multiplier", 0.0)) > 0.0:
		stats["bounce_damage_multiplier"] = (
			float(stats.get("bounce_damage_multiplier", 1.0))
			* float(triggers["bounce_damage_multiplier"])
		)
	if int(stats.get("bounce_count", 0)) > 0 and not traits["bonus_tags"].has(&"ricochet"):
		traits["bonus_tags"].append(&"ricochet")


func get_contextual_item_multiplier(
	model: Dictionary,
	stats: Dictionary,
	traits: Dictionary,
	scenario: Dictionary
) -> float:
	var effects: Dictionary = model["effects"]
	var triggers: Dictionary = model["triggers"]
	var multiplier := 1.0
	var enemy_count := maxi(int(scenario.get("primary_count", 1)), 1)
	var scenario_traits: Array = scenario.get("traits", [])
	var damage_tags: Array = traits["damage_tags"]
	var bonus_tags: Array = traits["bonus_tags"]
	var hollow := int(effects.get(&"hollow_point", 0))
	multiplier *= 1.0 + 0.0625 * hollow
	var point_blank := int(effects.get(&"point_blank", 0))
	var long_barrel := int(effects.get(&"long_barrel", 0))
	multiplier *= 1.0 + 0.5 * (
		GameStats.POINT_BLANK_MAX_DAMAGE_PER_STACK * point_blank
		+ GameStats.LONG_BARREL_MAX_DAMAGE_PER_STACK * long_barrel
	)
	var duelist := int(effects.get(&"duelist", 0))
	if enemy_count == 1:
		multiplier *= 1.0 + 0.30 * duelist
	elif enemy_count == 2:
		multiplier *= 1.0 + 0.15 * duelist
	var giant_killer := int(effects.get(&"giant_killer", 0))
	if giant_killer > 0:
		multiplier *= pow(
			GameStats.GIANT_KILLER_SPECIAL_DAMAGE_MULTIPLIER
			if bool(scenario.get("boss", false)) or scenario_traits.has(&"elite")
			else GameStats.GIANT_KILLER_NORMAL_DAMAGE_MULTIPLIER,
			giant_killer
		)
	if int(effects.get(&"interference_beam", 0)) > 0 and (
		float(stats.get("slow_duration", 0.0)) > 0.0
		or float(stats.get("stun_duration", 0.0)) > 0.0
	):
		multiplier *= GameStats.INTERFERENCE_BEAM_DAMAGE_MULTIPLIER
	if int(effects.get(&"conductive", 0)) > 0 and damage_tags.has(&"electric"):
		multiplier *= 1.0 + minf(float(scenario.get("armor", 0.0)) * 0.005, 0.25)
	if float(triggers.get("primary_hit_explosion_damage_multiplier", 0.0)) > 0.0:
		multiplier *= 1.0 + float(triggers["primary_hit_explosion_damage_multiplier"]) * minf(float(enemy_count), 4.0)
	if int(triggers.get("secondary_detonation", 0)) > 0 and damage_tags.has(&"explosive"):
		multiplier *= 1.0 + GameStats.SECONDARY_DETONATOR_DAMAGE_MULTIPLIER
	if int(triggers.get("terminal_fragment_count", 0)) > 0:
		multiplier *= 1.0 + 2.0 * GameStats.FRACTURE_ROUNDS_FRAGMENT_DAMAGE_MULTIPLIER
	if int(triggers.get("afterimage_projectile_count", 0)) > 0:
		multiplier *= 1.15 if enemy_count > 1 else 1.0
	if int(triggers.get("sticky_charge", 0)) > 0:
		multiplier *= 1.0 + GameStats.STICKY_CHARGE_BASE_CHANCE * GameStats.STICKY_CHARGE_DAMAGE_MULTIPLIER
	if int(effects.get(&"radiation_conversion", 0)) > 0:
		multiplier *= 1.16
	if int(effects.get(&"crowd_pleaser", 0)) > 0 and damage_tags.has(&"explosive"):
		multiplier *= 1.0 + minf(0.12 * float(enemy_count), 1.50)
	if int(effects.get(&"direct_hit", 0)) > 0 and damage_tags.has(&"explosive"):
		match enemy_count:
			1: multiplier *= 1.60
			2: multiplier *= 1.30
			3: multiplier *= 1.15
	if int(effects.get(&"chain_lightning", 0)) > 0 and damage_tags.has(&"electric"):
		var remaining := maxi(enemy_count - 1, 0)
		var jump_power := 1.0
		var added := 0.0
		for _jump in mini(int(effects[&"chain_lightning"]), remaining):
			jump_power *= GameStats.CHAIN_LIGHTNING_DAMAGE_FALLOFF
			added += jump_power
		multiplier *= 1.0 + added
	if int(triggers.get("contributes_electric_hits", 0)) > 0 or damage_tags.has(&"electric"):
		multiplier *= 1.0 + GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION / float(GameStats.ELECTRIC_HITS_TO_PROC)
	if bonus_tags.has(&"stun") and int(effects.get(&"aftershock", 0)) > 0:
		multiplier *= 1.10
	return maxf(multiplier, 0.0)


func get_performance_load(model: Dictionary, stats: Dictionary) -> float:
	var triggers: Dictionary = model["triggers"]
	var effects: Dictionary = model["effects"]
	return (
		float(maxi(int(stats.get("projectile_count", 1)) - 1, 0))
		+ float(maxi(int(stats.get("bounce_count", 0)), 0)) * 1.5
		+ float(triggers.get("primary_hit_explosion_damage_multiplier", 0.0) > 0.0) * 2.0
		+ float(triggers.get("secondary_detonation", 0.0) > 0.0) * 2.0
		+ float(triggers.get("terminal_fragment_count", 0.0))
		+ float(triggers.get("afterimage_projectile_count", 0.0))
		+ float(effects.get(&"chain_lightning", 0.0)) * 1.5
	)


func get_loadout_flags(
	mean_ratio: float,
	worst_ratio: float,
	best_ratio: float,
	performance_load: float,
	unmodeled: Array,
	inactive_items: Array
) -> Array[String]:
	var flags: Array[String] = []
	if mean_ratio >= 2.50:
		flags.append("extreme_power")
	elif mean_ratio >= 1.75:
		flags.append("high_power")
	if best_ratio >= 4.0:
		flags.append("matchup_spike")
	if mean_ratio <= 1.01 and worst_ratio >= 0.99:
		flags.append("no_effect")
	if worst_ratio < 0.80:
		flags.append("large_penalty")
	if performance_load >= 7.0:
		flags.append("performance_risk")
	if not inactive_items.is_empty():
		flags.append("inactive_item")
	if not unmodeled.is_empty():
		flags.append("manual_review")
	return flags


func get_loadout_cost(loadout: Array) -> int:
	var result := 0
	for item_id in loadout:
		result += int(GameStats.get_tower_item(StringName(item_id)).get("price", 0))
	return result


func format_loadout(loadout: Array) -> String:
	var counts: Dictionary = {}
	for item_id in loadout:
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	var parts: Array[String] = []
	for item_id in counts:
		parts.append("%s%s" % [
			String(item_id), "x%d" % counts[item_id] if counts[item_id] > 1 else "",
		])
	parts.sort()
	return "+".join(parts)


func mean_float_array(values: Array) -> float:
	if values.is_empty():
		return 1.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())
