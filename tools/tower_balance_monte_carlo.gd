extends Node

const GameStats = preload("res://stat_database.gd")
const BEHOLDER_BEAMS = preload("res://beholder_converging_beams.gd")
const DEFAULT_ITERATIONS := 1000
const DEFAULT_DURATION := 30.0
const RANGE_PIXELS_PER_UNIT := 12.9
const TARGET_HIT_RADIUS := 12.0
const DEFAULT_REPORT_PATH := "res://balance_reports/tower_monte_carlo.csv"
const BALANCED_TOWERS: Array[StringName] = [
	&"invader", &"gauss_repeater", &"beholder", &"reaver", &"brainiac",
	&"longshot", &"slinger", &"voidcaller", &"orbitalcannon", &"energycore",
	&"saucer", &"fisherman",
]

var rng := RandomNumberGenerator.new()
var iterations := DEFAULT_ITERATIONS
var duration := DEFAULT_DURATION
var seed_value := 730241
var tower_filter: Array[StringName] = []
var report_path := DEFAULT_REPORT_PATH
var scenarios: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("run_balance_simulation")


func run_balance_simulation() -> void:
	read_arguments()
	rng.seed = seed_value
	build_enemy_scenarios()
	validate_tower_progression()
	var tower_count := tower_filter.size() if not tower_filter.is_empty() else BALANCED_TOWERS.size()
	print("Balance simulator: %d towers, %d enemy types, %d iterations, %.1f seconds" % [tower_count, scenarios.size(), iterations, duration])
	var rows := run_simulation()
	write_report(rows)
	print_summary(rows)
	get_tree().quit()


func validate_tower_progression() -> void:
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		var tower: Dictionary = GameStats.get_tower(tower_id)
		var levels: Array = tower["levels"]
		assert(levels.size() == 4, "%s must have exactly four regular levels" % tower_id)
		var sell_values: Array = GameStats.TOWER_UPGRADED_SELL_VALUES.get(tower_id, [])
		assert(sell_values.size() == levels.size(), "%s sell values must match its levels" % tower_id)
		for path_id in tower.get("paths", {}):
			var path: Dictionary = tower["paths"][path_id]
			assert(int(path.get("unlock_level", -1)) == 3, "%s path %s must unlock at the fourth regular level" % [tower_id, path_id])


func read_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--iterations="):
			iterations = maxi(int(argument.get_slice("=", 1)), 50)
		elif argument.begins_with("--duration="):
			duration = maxf(float(argument.get_slice("=", 1)), 5.0)
		elif argument.begins_with("--seed="):
			seed_value = int(argument.get_slice("=", 1))
		elif argument.begins_with("--towers="):
			tower_filter.clear()
			for tower_name in argument.get_slice("=", 1).split(",", false):
				tower_filter.append(StringName(tower_name.strip_edges()))
		elif argument.begins_with("--report-path="):
			report_path = argument.get_slice("=", 1)


func run_simulation() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
		if tower_filter.is_empty() and not BALANCED_TOWERS.has(tower_id):
			continue
		if not tower_filter.is_empty() and not tower_filter.has(tower_id):
			continue
		var tower: Dictionary = GameStats.get_tower(tower_id)
		var levels: Array = tower["levels"]
		for level in levels.size():
			rows.append_array(simulate_variant(tower_id, level, [], "base"))
		var maximum_level := levels.size() - 1
		var paths: Dictionary = tower.get("paths", {})
		if paths.has("a"):
			rows.append_array(simulate_variant(tower_id, maximum_level, [&"a"], "path_a"))
		if paths.has("b"):
			rows.append_array(simulate_variant(tower_id, maximum_level, [&"b"], "path_b"))
	return rows


func build_enemy_scenarios() -> void:
	scenarios.clear()
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		var enemy: Dictionary = GameStats.get_enemy(enemy_id)
		var enemy_traits: Array = enemy.get("traits", []).duplicate()
		var enemy_count := get_enemy_pack_size(enemy)
		var spawned_count := 0
		var spawned_health_per_primary := 0.0
		if int(enemy.get("split_count", 0)) > 0:
			var split_count := int(enemy.get("split_count", 0))
			var split_enemy := GameStats.get_enemy(
				StringName(enemy["split_enemy_id"])
			)
			spawned_count += enemy_count * split_count
			spawned_health_per_primary += float(split_count) * (
				float(split_enemy.get("health", 1.0))
				+ float(split_enemy.get("health_per_wave", 0.0))
					* float(maxi(int(enemy.get("earliest_debut_round", 1)) - 1, 0))
			)
		if int(enemy.get("summon_limit", 0)) > 0:
			var summon_count := int(enemy.get("summon_limit", 0))
			var summon_enemy := GameStats.get_enemy(
				StringName(enemy["summon_enemy_id"])
			)
			spawned_count += enemy_count * summon_count
			spawned_health_per_primary += float(summon_count) * (
				float(summon_enemy.get("health", 1.0))
				+ float(summon_enemy.get("health_per_wave", 0.0))
					* float(maxi(int(enemy.get("earliest_debut_round", 1)) - 1, 0))
			)
		var debut_round := maxi(int(enemy.get("earliest_debut_round", 1)), 1)
		var health := (
			float(enemy.get("health", 1))
			+ float(enemy.get("health_per_wave", 0.0)) * float(debut_round - 1)
		)
		var speed := float(enemy.get("move_speed", 70.0))
		if enemy_traits.has(&"rushes"):
			var rush_start := clampf(float(enemy.get("rush_start_ratio", 0.7)), 0.0, 1.0)
			var rush_multiplier := maxf(float(enemy.get("rush_speed_multiplier", 1.0)), 1.0)
			speed /= maxf(rush_start + (1.0 - rush_start) / rush_multiplier, 0.01)
		scenarios.append({
			"id": String(enemy_id),
			"enemy_name": String(enemy.get("display_name", enemy_id)),
			"enemies": enemy_count + spawned_count,
			"primary_enemies": enemy_count,
			"spawned_enemies": spawned_count,
			"spawned_health_per_primary": spawned_health_per_primary,
			"armor": float(enemy.get("armor", 0.0)),
			"health": maxf(health, 1.0),
			"speed": speed,
			"regeneration": float(enemy.get("regeneration_per_second", 0.0)),
			"ablative_shield_points": int(enemy.get("ablative_shield_points", 0)),
			"boss": bool(enemy.get("boss", false)),
			"hidden": enemy_traits.has(&"hidden"),
			"traits": enemy_traits,
			"distance_min": 0.30 if enemy_count >= 6 else 0.45,
			"distance_max": 0.90,
		})


func get_enemy_pack_size(enemy: Dictionary) -> int:
	if bool(enemy.get("boss", false)):
		return 1
	match StringName(enemy.get("spawn_style", &"steady")):
		&"stream": return 12
		&"burst": return 7
		&"spaced": return 3
		_: return 5


func simulate_variant(
	tower_id: StringName,
	level: int,
	paths: Array[StringName],
	variant_name: String
) -> Array[Dictionary]:
	var tower: Dictionary = GameStats.get_tower(tower_id)
	var stats := get_variant_stats(tower_id, level, paths)
	var traits := get_variant_traits(tower_id, level, paths)
	var cost := get_variant_cost(tower_id, level, paths)
	var result: Array[Dictionary] = []
	for scenario in scenarios:
		var samples: Array[float] = []
		for _iteration in iterations:
			samples.append(simulate_trial(tower_id, stats, traits, scenario))
		samples.sort()
		var mean := 0.0
		for sample in samples:
			mean += sample
		mean /= float(samples.size())
		result.append({
			"tower_id": tower_id,
			"tower_name": tower["display_name"],
			"level": level,
			"variant": variant_name,
			"scenario": scenario["id"],
			"enemy_name": scenario["enemy_name"],
			"enemy_count": scenario["enemies"],
			"cost": cost,
			"mean_dps": mean,
			"p10_dps": percentile(samples, 0.10),
			"p90_dps": percentile(samples, 0.90),
			"dps_per_100": mean * 100.0 / maxf(float(cost), 1.0),
			"control_value": get_control_value(stats, traits, scenario),
			"model": get_model_note(tower_id),
		})
	return result


func get_variant_stats(
	tower_id: StringName,
	level: int,
	paths: Array[StringName]
) -> Dictionary:
	var stats := GameStats.get_tower_level(tower_id, level)
	for path_id in paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		apply_numeric_modifiers(stats, path.get("stat_multipliers", {}), true)
		apply_numeric_modifiers(stats, path.get("stat_additions", {}), false)
		if path.has("pierce_count_add"):
			stats["pierce_count"] = (
				int(stats.get("pierce_count", 0))
				+ int(path.get("pierce_count_add", 0))
			)
		for conditional in path.get("conditional_stat_multipliers", []):
			if paths.has(StringName(conditional.get("unless_path", &""))):
				continue
			apply_numeric_modifiers(stats, conditional.get("values", {}), true)
		for key in path.get("stat_overrides", {}):
			stats[key] = path["stat_overrides"][key]
		for conditional in path.get("conditional_stat_overrides", []):
			if paths.has(StringName(conditional.get("unless_path", &""))):
				continue
			for key in conditional.get("values", {}):
				stats[key] = conditional["values"][key]
		if stats.has("unit_stats"):
			var unit_stats: Dictionary = stats["unit_stats"]
			apply_numeric_modifiers(unit_stats, path.get("unit_stat_multipliers", {}), true)
			apply_numeric_modifiers(unit_stats, path.get("unit_stat_additions", {}), false)
			for key in path.get("unit_stat_overrides", {}):
				unit_stats[key] = path["unit_stat_overrides"][key]
			stats["unit_stats"] = unit_stats
	return stats


func apply_numeric_modifiers(stats: Dictionary, modifiers: Dictionary, multiply: bool) -> void:
	for key in modifiers:
		if not stats.has(key):
			continue
		if stats[key] is int:
			stats[key] = roundi(float(stats[key]) * float(modifiers[key])) if multiply else int(stats[key]) + roundi(float(modifiers[key]))
		elif stats[key] is float:
			stats[key] = float(stats[key]) * float(modifiers[key]) if multiply else float(stats[key]) + float(modifiers[key])


func get_variant_traits(tower_id: StringName, level: int, paths: Array[StringName]) -> Dictionary:
	var tower := GameStats.get_tower(tower_id)
	var damage_tags: Array = tower.get("damage_tags", []).duplicate()
	var bonus_tags: Array = tower.get("bonus_tags", []).duplicate()
	var levels: Array = tower.get("levels", [])

	for level_index in range(0, mini(level + 1, levels.size())):
		var level_data: Dictionary = levels[level_index]

		for tag in level_data.get("add_damage_tags", []):
			if not damage_tags.has(tag):
				damage_tags.append(tag)

		for tag in level_data.get("add_bonus_tags", []):
			if not bonus_tags.has(tag):
				bonus_tags.append(tag)

		for tag in level_data.get("remove_damage_tags", []):
			damage_tags.erase(tag)

		for tag in level_data.get("remove_bonus_tags", []):
			bonus_tags.erase(tag)
	var primary_type := StringName(tower.get("primary_damage_type", damage_tags[0]))
	var delivery := StringName(tower.get("delivery_type", GameStats.DELIVERY_HITSCAN))
	var impact := StringName(tower.get("impact_mode", GameStats.IMPACT_PRIMARY))
	var flags := {}
	var values := {}
	for level_index in range(0, mini(level + 1, levels.size())):
		var level_data: Dictionary = levels[level_index]
		flags.merge(level_data.get("behavior_flags", {}), true)
		values.merge(level_data.get("behavior_values", {}), true)
	for path_id in paths:
		var path := GameStats.get_tower_path(tower_id, path_id)
		for tag in path.get("add_damage_tags", []):
			if not damage_tags.has(tag): damage_tags.append(tag)
		for tag in path.get("remove_damage_tags", []): damage_tags.erase(tag)
		for tag in path.get("add_bonus_tags", []):
			if not bonus_tags.has(tag): bonus_tags.append(tag)
		for tag in path.get("remove_bonus_tags", []): bonus_tags.erase(tag)
		if path.has("primary_damage_type"): primary_type = StringName(path["primary_damage_type"])
		if path.has("delivery_type"): delivery = StringName(path["delivery_type"])
		if path.has("impact_mode"): impact = StringName(path["impact_mode"])
		flags.merge(path.get("behavior_flags", {}), true)
		values.merge(path.get("behavior_values", {}), true)
	return {"damage_tags": damage_tags, "bonus_tags": bonus_tags, "primary_type": primary_type, "delivery": delivery, "impact": impact, "flags": flags, "values": values, "paths": paths}


func get_variant_cost(tower_id: StringName, level: int, paths: Array[StringName]) -> int:
	var tower := GameStats.get_tower(tower_id)
	var cost := int(tower["placement_cost"])
	var levels: Array = tower["levels"]
	for current_level in range(1, level + 1): cost += int(levels[current_level]["upgrade_cost"])
	for path_id in paths: cost += int(GameStats.get_tower_path(tower_id, path_id).get("cost", 0))
	return cost


func simulate_trial(tower_id: StringName, stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	if bool(scenario.get("hidden", false)) and not traits["bonus_tags"].has(&"reveal"):
		return 0.0
	if stats.has("unit_stats"):
		return simulate_spawner_trial(tower_id, stats, traits, scenario)
	if (
		tower_id == &"orbitalcannon"
		and (
			traits["flags"].get("orbital_solar_lance", false)
			or traits["flags"].get("orbital_bombardment", false)
		)
	):
		return simulate_orbital_path_trial(stats, traits, scenario)
	var damage := float(stats.get("damage", 0))
	var interval := maxf(float(stats.get("firerate", 1.0)), 0.01)
	if bool(stats.get("gauss_overclock_enabled", false)):
		var ramp_duration := minf(
			float(stats.get("gauss_overclock_ramp_duration", 3.0)),
			duration
		)
		var average_bonus := (
			float(stats.get("gauss_overclock_max_speed_bonus", 0.25))
			* (1.0 - ramp_duration / maxf(2.0 * duration, 0.01))
		)
		interval /= 1.0 + average_bonus
	var attacks := floori((duration + rng.randf() * interval) / interval)
	if tower_id == &"saucer":
		var active_duration := duration * get_saucer_pursuit_uptime(
			stats,
			scenario
		)
		attacks = floori((active_duration + rng.randf() * interval) / interval)
	var total := 0.0
	var shield_hits_remaining := maxi(
		int(scenario.get("ablative_shield_points", 0)),
		0
	)
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	var primary_type: StringName = traits["primary_type"]
	if flags.get("longshot_kill_chain", false):
		var critical_chance := (
			GameStats.DEFAULT_CRITICAL_CHANCE
			if traits["bonus_tags"].has(&"critical")
			else 0.0
		)
		var critical_multiplier := float(stats.get(
			"critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER
		))
		var normal_kills := apply_armor(
			damage, primary_type, float(scenario["armor"]), false
		) >= float(scenario["health"])
		var critical_kills := apply_armor(
			damage * critical_multiplier,
			primary_type,
			float(scenario["armor"]),
			false
		) >= float(scenario["health"])
		var normal_reload_factor := (
			float(values.get("kill_reload_remaining_multiplier", 0.50))
			if normal_kills else 1.0
		)
		var critical_reload_factor := (
			float(values.get(
				"critical_kill_reload_remaining_multiplier", 0.10
			))
			if critical_kills else 1.0
		)
		var expected_reload_factor := (
			(1.0 - critical_chance) * normal_reload_factor
			+ critical_chance * critical_reload_factor
		)
		attacks = floori(
			(duration + rng.randf() * interval)
			/ maxf(interval * expected_reload_factor, 0.01)
		)
	if tower_id not in [&"reaver", &"voidcaller"]:
		var projectile_total := maxi(int(stats.get("projectile_count", 1)), 1)
		if tower_id == &"energycore":
			projectile_total = mini(projectile_total, int(scenario["enemies"]))
		attacks *= projectile_total
	if flags.get("orbital_bombardment", false):
		attacks *= maxi(int(values.get("bombardment_strike_count", 5)), 1)
	for attack_index in attacks:
		var attack_damage := get_reaver_combo_damage(damage, stats, flags) if tower_id == &"reaver" else damage
		if tower_id != &"reaver" and traits["bonus_tags"].has(&"critical"):
			var guaranteed_finisher: bool = bool(flags.get("reaver_assassinate", false)) and attack_index % maxi(int(stats.get("combo_hit_count", 3)), 1) == maxi(int(stats.get("combo_hit_count", 3)), 1) - 1
			if guaranteed_finisher or rng.randf() < GameStats.DEFAULT_CRITICAL_CHANCE:
				attack_damage *= float(stats.get(
					"critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER
				))
		if flags.get("orbital_solar_lance", false):
			attack_damage *= (
				float(values.get("solar_lance_duration", 1.5))
				/ maxf(float(values.get("solar_lance_tick_interval", 0.2)), 0.01)
				* float(values.get("solar_lance_tick_damage_multiplier", 0.25))
			)
		elif flags.get("orbital_bombardment", false):
			attack_damage *= float(values.get("bombardment_damage_multiplier", 0.38))
		var distance_ratio := rng.randf_range(float(scenario["distance_min"]), float(scenario["distance_max"]))
		var hit_chance := get_hit_chance(tower_id, stats, traits, scenario, distance_ratio, attack_index, attacks)
		if rng.randf() > hit_chance and primary_type != &"explosive":
			continue
		var hit_damage := apply_armor(attack_damage, primary_type, float(scenario["armor"]), int(stats.get("pierce_count", 0)) > 0)
		if shield_hits_remaining > 0:
			if tower_id == &"brainiac":
				var blocked_ticks := mini(
					shield_hits_remaining,
					BEHOLDER_BEAMS.TICK_COUNT
				)
				shield_hits_remaining -= blocked_ticks
				hit_damage *= (
					1.0
					- float(blocked_ticks)
						/ float(BEHOLDER_BEAMS.TICK_COUNT)
				)
			else:
				shield_hits_remaining -= 1
				continue
		hit_damage = minf(hit_damage, float(scenario["health"]))
		if tower_id == &"voidcaller":
			total += get_voidcaller_volley_damage(hit_damage, stats, scenario)
		else:
			total += get_attack_total_damage(hit_damage, stats, traits, scenario)
		if flags.get("slinger_contact_explosions", false):
			total += get_slinger_contact_explosion_damage(
				attack_damage,
				stats,
				traits,
				scenario
			)
	if flags.get("beholder_ramping_beam", false):
		var base_single_dps := damage / maxf(interval, 0.01)
		var expected_lock_duration := minf(
			duration,
			float(scenario["health"]) / maxf(base_single_dps, 1.0)
		)
		total *= get_beholder_ramp_average(values, expected_lock_duration)
	if flags.get("beholder_damage_mark", false):
		var maximum_mark_bonus := (
			float(values.get("mark_damage_per_stack", 0.02))
			* float(values.get("mark_maximum_stacks", 10))
		)
		var mark_ramp_duration := 1.0
		var ramp_fraction := minf(mark_ramp_duration / maxf(duration, 0.01), 1.0)
		total *= 1.0 + maximum_mark_bonus * (1.0 - ramp_fraction * 0.5)
	if flags.get("beholder_death_explosion", false) and int(scenario["enemies"]) > 1:
		var kill_count := total / maxf(float(scenario["health"]), 1.0)
		var death_damage := apply_armor(
			damage * float(values.get("death_explosion_damage_multiplier", 1.0)),
			&"explosive",
			float(scenario["armor"]),
			false
		)
		death_damage = minf(death_damage, float(scenario["health"]))
		var death_coverage := clampf(
			0.12 + float(values.get("death_explosion_radius", 3.0)) * 0.055,
			0.12,
			0.75
		)
		total += kill_count * death_damage * float(int(scenario["enemies"]) - 1) * death_coverage * 0.625
	if flags.get("brainiac_psionic_link", false) and int(scenario["enemies"]) > 1:
		var link_uptime := minf(
			float(values.get("brainiac_link_duration", 2.0))
			/ maxf(float(values.get("brainiac_link_cooldown", 6.0)), 0.01),
			1.0
		)
		var link_coverage := clampf(
			0.12 + float(values.get("brainiac_link_radius", 3.5)) * 0.08,
			0.12,
			0.70
		)
		total += (
			total
			* link_uptime
			* float(values.get("brainiac_link_damage_share", 0.35))
			* float(int(scenario["enemies"]) - 1)
			* link_coverage
		)
	if tower_id == &"saucer":
		total += get_saucer_abduction_total(stats, scenario)
	total += simulate_periodic_specials(tower_id, damage, stats, traits, scenario)
	var regeneration := float(scenario.get("regeneration", 0.0))
	if regeneration > 0.0:
		var pressured_targets := minf(
			get_expected_targets_per_attack(stats, traits, scenario),
			float(scenario["enemies"])
		)
		total = maxf(total - regeneration * duration * pressured_targets, 0.0)
	return total / duration


func simulate_orbital_path_trial(
	stats: Dictionary,
	traits: Dictionary,
	scenario: Dictionary
) -> float:
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	var interval := maxf(float(stats.get("firerate", 1.0)), 0.01)
	var volleys := floori((duration + rng.randf() * interval) / interval)
	var enemy_count := maxi(int(scenario["enemies"]), 1)
	var enemy_positions: Array[Vector2] = [Vector2.ZERO]
	var reference_radius := maxf(float(stats.get("splash_radius", 0.0)), 0.01)
	var pack_radius := reference_radius + 0.75
	for _enemy_index in range(1, enemy_count):
		enemy_positions.append(
			Vector2.from_angle(rng.randf_range(0.0, TAU))
			* sqrt(rng.randf())
			* pack_radius
		)
	var total := 0.0
	var strike_count := (
		maxi(int(values.get("bombardment_strike_count", 5)), 1)
		if flags.get("orbital_bombardment", false)
		else 1
	)
	var spread_radius := (
		maxf(float(values.get("bombardment_spread_radius", 3.0)), 0.0)
		if flags.get("orbital_bombardment", false)
		else 0.0
	)
	var base_damage := float(stats.get("damage", 0))
	if flags.get("orbital_bombardment", false) and not flags.get("orbital_solar_lance", false):
		base_damage = float(roundi(
			base_damage * float(values.get("bombardment_damage_multiplier", 0.38))
		))
	var hit_radius := (
		GameStats.BUILD_CELL_SIZE / RANGE_PIXELS_PER_UNIT
		if flags.get("orbital_solar_lance", false)
		else float(stats.get("splash_radius", 0.0))
		* float(values.get("bombardment_radius_multiplier", 0.70))
	)
	var tick_count := 1
	if flags.get("orbital_solar_lance", false):
		var lance_duration := float(values.get("solar_lance_duration", 1.5))
		var tick_interval := maxf(
			float(values.get("solar_lance_tick_interval", 0.2)),
			0.01
		)
		tick_count = floori(lance_duration / tick_interval) + 1
		var tick_start_multiplier := (
			float(values.get("solar_lance_dual_tick_damage_multiplier", 0.10))
			if flags.get("orbital_bombardment", false)
			else float(values.get("solar_lance_tick_damage_multiplier", 0.25))
		)
		var tick_end_multiplier := (
			tick_start_multiplier
			if flags.get("orbital_bombardment", false)
			else float(values.get("solar_lance_tick_end_damage_multiplier", 0.50))
		)
		var total_tick_damage := 0.0
		for current_tick in tick_count:
			var ramp_progress := (
				float(current_tick) / float(tick_count - 1)
				if tick_count > 1
				else 1.0
			)
			total_tick_damage += float(maxi(roundi(
				base_damage * lerpf(
					tick_start_multiplier,
					tick_end_multiplier,
					ramp_progress
				)
			), 1))
		base_damage = total_tick_damage / float(tick_count)
	for _volley_index in volleys:
		for strike_index in strike_count:
			var strike_position := Vector2.ZERO
			if strike_index > 0:
				strike_position = (
					Vector2.from_angle(rng.randf_range(0.0, TAU))
					* sqrt(rng.randf())
					* spread_radius
				)
			for enemy_position in enemy_positions:
				var distance_from_strike := enemy_position.distance_to(strike_position)
				if distance_from_strike > hit_radius:
					continue
				var damage_multiplier := 1.0
				if (
					not flags.get("orbital_solar_lance", false)
					and distance_from_strike
					> hit_radius * GameStats.EXPLOSION_INNER_RADIUS_RATIO
				):
					damage_multiplier = GameStats.EXPLOSION_OUTER_DAMAGE_MULTIPLIER
				var strike_damage := apply_armor(
					base_damage * damage_multiplier,
					&"beam" if flags.get("orbital_solar_lance", false) else &"explosive",
					float(scenario["armor"]),
					false
				)
				strike_damage = minf(strike_damage, float(scenario["health"]))
				total += strike_damage * float(tick_count)
	var regeneration := float(scenario.get("regeneration", 0.0))
	if regeneration > 0.0:
		total = maxf(total - regeneration * duration * float(enemy_count), 0.0)
	return total / duration


func get_reaver_combo_damage(damage: float, stats: Dictionary, flags: Dictionary) -> float:
	if not bool(flags.get("reaver_assassinate", false)):
		return damage
	var hit_count := maxi(int(stats.get("combo_hit_count", 3)), 1)
	if hit_count == 1:
		return damage * GameStats.DEFAULT_CRITICAL_MULTIPLIER
	var light_fraction := 0.25
	var total := 0.0
	for hit_index in hit_count:
		var hit_damage := damage * light_fraction if hit_index < hit_count - 1 else damage * (1.0 - light_fraction * float(hit_count - 1))
		if hit_index == hit_count - 1 or rng.randf() < GameStats.DEFAULT_CRITICAL_CHANCE:
			hit_damage *= GameStats.DEFAULT_CRITICAL_MULTIPLIER
		total += hit_damage
	return total


func get_hit_chance(tower_id: StringName, stats: Dictionary, traits: Dictionary, scenario: Dictionary, distance_ratio: float, attack_index: int, attack_count: int) -> float:
	if tower_id == &"brainiac":
		return clampf(
			0.16
			+ 0.64 * pow(distance_ratio, 2.5)
			+ 0.035 * float(int(scenario["enemies"])),
			0.08,
			1.0
		)
	if traits["delivery"] == GameStats.DELIVERY_HITSCAN:
		if tower_id == &"beholder":
			var turn_speed := float(stats.get("beam_turn_speed_degrees", 480.0))
			var width_bonus := float(stats.get("beam_half_width", 2.5)) * 0.015
			var speed_penalty := float(scenario["speed"]) / 900.0
			return clampf(0.88 + turn_speed / 6000.0 + width_bonus - speed_penalty, 0.60, 1.0)
		return 1.0
	if traits["impact"] in [GameStats.IMPACT_FIRST_CONTACT, GameStats.IMPACT_DESTINATION]:
		if tower_id == &"gauss_repeater":
			var maximum_spread := float(stats.get("maximum_spread_degrees", 20.0))
			var minimum_spread := float(stats.get("minimum_spread_degrees", 5.0))
			var tighten_duration := float(stats.get("spread_tighten_duration", 5.0))
			var elapsed := float(attack_index) / maxf(float(attack_count), 1.0) * duration
			var spread := lerpf(maximum_spread, minimum_spread, clampf(elapsed / tighten_duration, 0.0, 1.0))
			var angular_target := rad_to_deg(atan(TARGET_HIT_RADIUS / maxf(float(stats.get("range", 1.0)) * RANGE_PIXELS_PER_UNIT * distance_ratio, 1.0)))
			return clampf(angular_target / maxf(spread, 0.1), 0.02, 1.0)
		return clampf(0.70 + 0.025 * float(int(scenario["enemies"])), 0.0, 1.0)
	var distance_pixels := float(stats.get("range", 1.0)) * RANGE_PIXELS_PER_UNIT * distance_ratio
	var travel_time := distance_pixels / maxf(float(stats.get("projectile_speed", 600.0)), 1.0)
	var displacement := float(scenario["speed"]) * travel_time
	return clampf(TARGET_HIT_RADIUS / maxf(displacement, TARGET_HIT_RADIUS), 0.0, 1.0)


func get_attack_total_damage(primary_damage: float, stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	var enemy_count := int(scenario["enemies"])
	var total := primary_damage
	var bounce_count := mini(int(stats.get("bounce_count", 0)), enemy_count - 1)
	total += primary_damage * float(bounce_count)
	var already_hit := 1 + bounce_count
	var pierce_count := int(stats.get("pierce_count", 0))
	if traits["flags"].get("infinite_pierce", false): pierce_count = enemy_count - already_hit
	for pierce_index in mini(pierce_count, enemy_count - already_hit):
		total += primary_damage * maxf(1.0 - 0.30 * float(pierce_index + 1), 0.40)
	var splash_radius := float(stats.get("splash_radius", 0.0))
	if traits["primary_type"] == &"explosive" and splash_radius > 0.0 and enemy_count > 1:
		var coverage := clampf(0.12 + splash_radius * 0.055, 0.12, 0.75)
		for _enemy in range(1, enemy_count):
			if rng.randf() <= coverage:
				total += primary_damage if rng.randf() <= 0.25 else primary_damage * GameStats.EXPLOSION_OUTER_DAMAGE_MULTIPLIER
	return total


func get_expected_targets_per_attack(
	stats: Dictionary,
	traits: Dictionary,
	scenario: Dictionary
) -> float:
	var enemies := maxi(int(scenario["enemies"]), 1)
	var targets := float(mini(maxi(int(stats.get("projectile_count", 1)), 1), enemies))
	targets += float(mini(int(stats.get("bounce_count", 0)), maxi(enemies - int(targets), 0)))
	var pierce := int(stats.get("pierce_count", 0))
	if traits["flags"].get("infinite_pierce", false):
		pierce = enemies
	targets += float(mini(pierce, maxi(enemies - int(targets), 0)))
	if traits["primary_type"] == &"explosive":
		var radius := float(stats.get("splash_radius", 0.0))
		targets += float(maxi(enemies - int(targets), 0)) * clampf(0.12 + radius * 0.055, 0.12, 0.75)
	return clampf(targets, 1.0, float(enemies))


func get_control_value(stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	var enemies := maxi(int(scenario["enemies"]), 1)
	var interval := maxf(float(stats.get("firerate", 1.0)), 0.01)
	var targets := get_expected_targets_per_attack(stats, traits, scenario)
	var value := 0.0
	var slow_duration := float(stats.get("slow_duration", 0.0))
	if slow_duration > 0.0:
		value += minf(slow_duration / interval, 1.0) * targets * (1.0 - GameStats.SLOW_SPEED_MULTIPLIER)
	var stun_duration := float(stats.get("stun_duration", 0.0))
	if stun_duration > 0.0 and (not bool(scenario["boss"]) or bool(stats.get("stun_affects_bosses", false))):
		# Repeated stuns quickly settle into fatigue, so sustained control uses the middle fatigue tier.
		value += minf(stun_duration / interval, 1.0) * targets * 0.40
	if stats.has("hook_duration"):
		var pull_strength := clampf(
			float(stats.get("hook_pull_speed", 0.0))
			/ maxf(float(scenario.get("speed", 1.0)), 1.0),
			0.0,
			1.0
		)
		value += (
			minf(float(stats.get("hook_duration", 1.2)) / interval, 1.0)
			* targets
			* pull_strength
			* 0.15
		)
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	if flags.get("reaver_time_bubble", false):
		var bubble_uptime := minf(
			float(values.get("time_bubble_active_duration", 3.0))
			/ maxf(
				float(values.get("time_bubble_active_duration", 3.0))
				+ float(values.get("time_bubble_cooldown", 7.0)),
				0.01
			),
			1.0
		)
		value += bubble_uptime * float(enemies) * (1.0 - GameStats.SLOW_SPEED_MULTIPLIER)
	if flags.get("energy_shockwave", false) and not bool(scenario["boss"]):
		value += (
			float(values.get("shockwave_stun_duration", 1.0))
			/ maxf(float(values.get("shockwave_cooldown", 5.0)), 0.01)
			* float(enemies)
			* 0.40
		)
	if flags.get("energy_branching_current", false):
		var primary_bolts := mini(maxi(int(stats.get("projectile_count", 1)), 1), enemies)
		var branches := mini(int(values.get("branch_additional_targets", 2)), maxi(enemies - 1, 0))
		value += minf(0.5 / interval, 1.0) * float(primary_bolts * branches) * (1.0 - GameStats.SLOW_SPEED_MULTIPLIER)
	if flags.get("orbital_solar_lance", false):
		var lance_uptime := minf(float(values.get("solar_lance_duration", 1.5)) / interval, 1.0)
		value += lance_uptime * targets * (1.0 - GameStats.SLOW_SPEED_MULTIPLIER)
	if flags.get("void_singularity", false):
		var pull_uptime := minf(
			float(values.get("singularity_pull_duration", 1.0))
			/ maxf(float(values.get("singularity_cooldown", 10.0)), 0.01),
			1.0
		)
		value += pull_uptime * float(enemies) * 0.15
	return value


func get_voidcaller_volley_damage(
	projectile_damage: float,
	stats: Dictionary,
	scenario: Dictionary
) -> float:
	var projectile_total := maxi(int(stats.get("projectile_count", 1)), 1)
	var volley_width := maxf(float(stats.get("volley_width", 0.0)), 0.0)
	var splash_radius := maxf(float(stats.get("splash_radius", 0.0)), 0.0)
	var enemy_count := int(scenario["enemies"])
	var total := 0.0
	var coverage := clampf(0.12 + splash_radius * 0.055, 0.12, 0.75)

	for projectile_index in projectile_total:
		var spread_ratio := 0.0
		if projectile_total > 1:
			spread_ratio = (
				float(projectile_index) / float(projectile_total - 1) - 0.5
			)
		var target_offset := absf(volley_width * spread_ratio)
		if target_offset <= splash_radius * GameStats.EXPLOSION_INNER_RADIUS_RATIO:
			total += projectile_damage
		elif target_offset <= splash_radius:
			total += projectile_damage * GameStats.EXPLOSION_OUTER_DAMAGE_MULTIPLIER

		for _enemy in range(1, enemy_count):
			if rng.randf() <= coverage:
				total += (
					projectile_damage
					if rng.randf() <= 0.25
					else projectile_damage * GameStats.EXPLOSION_OUTER_DAMAGE_MULTIPLIER
				)
	return total


func get_slinger_contact_explosion_damage(
	attack_damage: float,
	stats: Dictionary,
	traits: Dictionary,
	scenario: Dictionary
) -> float:
	var enemy_count := int(scenario["enemies"])
	var contact_count := 1 + mini(
		int(stats.get("bounce_count", 0)),
		enemy_count - 1
	)
	if traits["flags"].get("infinite_pierce", false):
		contact_count = enemy_count
	else:
		contact_count += mini(
			int(stats.get("pierce_count", 0)),
			enemy_count - contact_count
		)
	var values: Dictionary = traits["values"]
	var explosion_damage := float(roundi(
		attack_damage
		* float(values.get("contact_explosion_damage_multiplier", 1.0))
	))
	explosion_damage = apply_armor(
		explosion_damage,
		&"explosive",
		float(scenario["armor"]),
		false
	)
	var total := explosion_damage * float(contact_count)
	var bystander_count := maxi(enemy_count - contact_count, 0)
	if bystander_count <= 0:
		return total
	var radius := float(values.get("contact_explosion_radius", 2.5))
	var coverage_per_contact := clampf(0.12 + radius * 0.055, 0.12, 0.75)
	var combined_coverage := 1.0 - pow(
		1.0 - coverage_per_contact,
		float(contact_count)
	)
	var average_splash_multiplier := (
		0.25 + 0.75 * GameStats.EXPLOSION_OUTER_DAMAGE_MULTIPLIER
	)
	total += (
		explosion_damage
		* float(bystander_count)
		* combined_coverage
		* average_splash_multiplier
	)
	return total


func apply_armor(amount: float, damage_type: StringName, armor: float, ignores_armor: bool) -> float:
	if ignores_armor or damage_type == &"beam": return amount
	return maxf(
		amount * GameStats.get_armor_damage_multiplier(armor, damage_type),
		1.0
	)


func get_beholder_ramp_average(values: Dictionary, lock_duration: float) -> float:
	var start := float(values.get("beam_ramp_start_multiplier", 0.5))
	var step := float(values.get("beam_ramp_step_multiplier", 0.25))
	var step_interval := float(values.get("beam_ramp_step_interval", 0.5))
	var maximum := float(values.get("beam_ramp_max_multiplier", 2.5))
	var total := 0.0
	var ticks := maxi(floori(lock_duration / step_interval), 1)
	for index in ticks: total += minf(start + step * float(index), maximum)
	return total / float(ticks)


func simulate_periodic_specials(tower_id: StringName, damage: float, stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	var total := 0.0
	var enemies := int(scenario["enemies"])
	var armor := float(scenario["armor"])
	if flags.get("gauss_heavy_shot", false):
		var count := floori(duration / maxf(float(values.get("heavy_shot_interval", 4.0)), 0.1))
		var heavy_damage := maxi(roundi(
			damage * float(values.get("heavy_shot_damage_multiplier", 3.0))
		), 1)
		var heavy_line_damage := 0.0
		for hit_index in enemies:
			if hit_index > 0 and rng.randf() > 0.25:
				continue
			heavy_line_damage += minf(apply_armor(
				float(GameStats.get_piercing_damage(heavy_damage, hit_index)),
				traits["primary_type"],
				armor,
				true
			), float(scenario["health"]))
		total += float(count) * heavy_line_damage
	if flags.get("void_singularity", false):
		var count := floori(duration / maxf(float(values.get("singularity_cooldown", 10.0)), 0.1))
		var coverage_target_cap := maxi(
			roundi(float(values.get("singularity_explosion_radius", 5.0))) + 2,
			1
		)
		total += (
			float(count)
			* minf(apply_armor(
				damage * float(values.get("singularity_damage_multiplier", 3.0)),
				&"explosive",
				armor,
				false
			), float(scenario["health"]))
			* minf(float(enemies), float(coverage_target_cap))
		)
	if flags.get("energy_shockwave", false):
		var count := floori(duration / maxf(float(values.get("shockwave_cooldown", 5.0)), 0.1))
		total += float(count) * minf(apply_armor(
			maxf(roundf(damage * float(values.get("shockwave_damage_multiplier", 0.35))), 1.0),
			&"electric",
			armor,
			false
		), float(scenario["health"])) * float(enemies)
	if flags.get("energy_branching_current", false):
		var attacks := floori(duration / maxf(float(stats.get("firerate", 1.0)), 0.01))
		var primary_bolts := mini(
			maxi(int(stats.get("projectile_count", 1)), 1),
			enemies
		)
		var branches_per_bolt := mini(
			int(values.get("branch_additional_targets", 2)),
			enemies - 1
		)
		var branch_damage := maxf(roundf(
			damage * float(values.get("branch_damage_multiplier", 0.30))
		), 1.0)
		total += (
			float(attacks * primary_bolts * branches_per_bolt)
			* minf(apply_armor(branch_damage, &"electric", armor, false), float(scenario["health"]))
		)
	if tower_id == &"saucer" and flags.get("saucer_twin_rockets", false):
		var count := floori(duration / maxf(float(values.get("saucer_rocket_interval", 3.0)), 0.1))
		total += (
			float(count * 2)
			* apply_armor(
				damage * float(values.get("saucer_rocket_damage_multiplier", 2.0)),
				&"explosive",
				armor,
				false
			)
			* minf(float(enemies), 2.5)
			* get_saucer_pursuit_uptime(stats, scenario)
		)
	if tower_id == &"saucer" and flags.get("saucer_monster_drop", false):
		var monster: Dictionary = stats.get("monster_stats", {})
		var uptime := minf(
			float(monster.get("lifetime", 10.0))
				* get_saucer_expected_abductions(stats, scenario),
			duration
		)
		total += uptime / maxf(float(monster.get("attack_interval", 1.0)), 0.01) * apply_armor(float(monster.get("damage", 0)), &"melee", armor, false)
	return total


func get_saucer_pursuit_uptime(
	stats: Dictionary,
	scenario: Dictionary
) -> float:
	var attack_radius := float(stats.get("flyer_attack_radius", 5.0))
	var movement_speed := float(stats.get("flyer_move_speed", 165.0))
	var enemy_speed := float(scenario.get("speed", 75.0))
	return clampf(
		0.55
		+ attack_radius * 0.04
		+ movement_speed / 1000.0
		- enemy_speed / 1000.0,
		0.55,
		0.96
	)


func get_saucer_expected_abductions(
	stats: Dictionary,
	scenario: Dictionary
) -> float:
	var threshold := float(stats.get("abduction_health_threshold", 0.0))
	if threshold <= 0.0 or bool(scenario.get("boss", false)):
		return 0.0
	var cooldown := maxf(float(stats.get("abduction_cooldown", 16.0)), 0.1)
	var possible_uses := floori(duration / cooldown)
	var eligible_targets := maxi(int(scenario.get("primary_enemies", 1)), 0)
	return (
		float(mini(possible_uses, eligible_targets))
		* get_saucer_pursuit_uptime(stats, scenario)
		* 0.80
	)


func get_saucer_abduction_total(
	stats: Dictionary,
	scenario: Dictionary
) -> float:
	var threshold := float(stats.get("abduction_health_threshold", 0.0))
	var expected_abductions := get_saucer_expected_abductions(stats, scenario)
	if expected_abductions <= 0.0:
		return 0.0
	var removed_health := (
		float(scenario.get("health", 1.0)) * threshold
		+ float(scenario.get("spawned_health_per_primary", 0.0))
	)
	return expected_abductions * removed_health


func simulate_spawner_trial(tower_id: StringName, stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	var unit: Dictionary = stats["unit_stats"]
	var spawn_interval := maxf(float(stats.get("spawn_interval", 1.0)), 0.1)
	var spawn_limit := maxi(int(stats.get("spawn_limit", 1)), 1)
	var attack_interval := maxf(float(unit.get("attack_interval", 1.0)), 0.01)
	var damage := float(unit.get("damage", 0))
	var total := 0.0
	var active_units := 0
	var next_spawn := spawn_interval
	var time := 0.0
	while time < duration:
		if time >= next_spawn and active_units < spawn_limit:
			active_units += 1
			next_spawn += spawn_interval
		var uptime := 0.75 if tower_id == &"mechbay" else 0.90
		var attacks := float(active_units) * uptime
		var projectiles := maxi(int(unit.get("projectile_count", 1)), 1)
		var unit_traits := traits.duplicate(true)
		if unit.has("damage_tags"):
			unit_traits["primary_type"] = StringName(unit["damage_tags"][0])
		total += attacks * damage * float(projectiles) * 0.25 / attack_interval
		time += 0.25
	var damage_type: StringName = traits["primary_type"]
	if tower_id == &"mechbay": damage_type = &"melee"
	total = apply_armor(total, damage_type, float(scenario["armor"]), int(unit.get("pierce_count", 0)) > 0)
	if tower_id == &"dronedepot":
		var budget := float(unit.get("damage_budget", 0))
		var explodes_on_budget := bool(unit.get("explode_on_damage_budget", false))
		var recharge := (
			float(unit.get("budget_replacement_delay", 0.5))
			if explodes_on_budget
			else float(unit.get("recharge_duration", 0))
		)
		var active_time := budget / maxf(damage / attack_interval, 0.01)
		total *= active_time / maxf(active_time + recharge, 0.01)
		if explodes_on_budget:
			var cycles := duration / maxf(active_time + recharge, 0.01)
			total += cycles * float(spawn_limit) * damage * float(unit.get("budget_explosion_damage_multiplier", 6.0)) * minf(float(int(scenario["enemies"])), 3.0)
	return total / duration


func percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty(): return 0.0
	return values[clampi(roundi(float(values.size() - 1) * ratio), 0, values.size() - 1)]


func get_model_note(tower_id: StringName) -> String:
	match tower_id:
		&"gauss_repeater": return "spread tightening; overclock; tracking and Heavy Shot approximated"
		&"brainiac": return "Converging beams, interception/Pierce, and Withering Gaze self-amplification modeled"
		&"beholder": return "turn alignment; target-reset ramp and Psionic Link modeled"
		&"reaver": return "combo contact; stun fatigue; Time Bubble and Assassinate modeled"
		&"longshot": return "Anti-Materiel critical stats and Kill Chain execution reloads approximated"
		&"slinger": return "bounce availability; Pierce falloff and contact splash modeled"
		&"voidcaller": return "orb geometry; simultaneous Barrage and Singularity coverage modeled"
		&"orbitalcannon": return "accurate manual placement assumed; area; stun; Lance ramp and Slow modeled"
		&"energycore": return "distinct primary targets; Slow; Shockwave and Branching Current modeled"
		&"saucer": return "pursuit uptime; abduction execution; split prevention; rockets and specimen uptime modeled"
		&"fisherman": return "four-tick hook; shared pull immunity and three-target Harpoon Pierce modeled"
		&"hivemother", &"dronedepot", &"mechbay": return "spawn ramp and combat uptime approximated"
		_: return "generic event model"


func write_report(rows: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://balance_reports"))
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_line("tower_id,tower_name,level,variant,enemy_id,enemy_name,enemy_count,cost,mean_dps,p10_dps,p90_dps,dps_per_100_cost,control_target_seconds_per_second,model")
	for row in rows:
		var fields := PackedStringArray([
			str(row["tower_id"]), str(row["tower_name"]), str(row["level"]), str(row["variant"]), str(row["scenario"]), str(row["enemy_name"]), str(row["enemy_count"]), str(row["cost"]),
			"%.3f" % float(row["mean_dps"]), "%.3f" % float(row["p10_dps"]), "%.3f" % float(row["p90_dps"]), "%.3f" % float(row["dps_per_100"]), "%.3f" % float(row["control_value"]), str(row["model"])
		])
		file.store_line(",".join(fields))
	file.close()
	print("Monte Carlo report: ", ProjectSettings.globalize_path(report_path))


func print_summary(rows: Array[Dictionary]) -> void:
	print("Iterations: ", iterations, " | duration: ", duration, "s | seed: ", seed_value)
	for scenario in scenarios:
		var candidates: Array[Dictionary] = []
		for row in rows:
			if row["scenario"] == scenario["id"] and row["variant"] in ["path_a", "path_b"]:
				candidates.append(row)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dps_per_100"]) > float(b["dps_per_100"]))
		print("\n", String(scenario["id"]).to_upper(), " top max-path efficiency")
		for index in mini(5, candidates.size()):
			var row := candidates[index]
			print("  ", row["tower_name"], " ", row["variant"], ": DPS=", "%.1f" % row["mean_dps"], " /100$=", "%.2f" % row["dps_per_100"])
