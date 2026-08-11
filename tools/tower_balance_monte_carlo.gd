extends SceneTree

const GameStats = preload("res://stat_database.gd")
const DEFAULT_ITERATIONS := 1000
const DEFAULT_DURATION := 30.0
const RANGE_PIXELS_PER_UNIT := 12.9
const TARGET_HIT_RADIUS := 12.0
const REPORT_PATH := "res://balance_reports/tower_monte_carlo.csv"

const SCENARIOS := [
	{"id": "single", "enemies": 1, "defense": 0.0, "speed": 70.0, "distance_min": 0.45, "distance_max": 0.85},
	{"id": "armored_elite", "enemies": 1, "defense": 0.45, "speed": 68.25, "distance_min": 0.55, "distance_max": 0.90},
	{"id": "fast_pack", "enemies": 4, "defense": 0.10, "speed": 112.0, "distance_min": 0.35, "distance_max": 0.85},
	{"id": "horde", "enemies": 12, "defense": 0.10, "speed": 70.0, "distance_min": 0.30, "distance_max": 0.90},
]

var rng := RandomNumberGenerator.new()
var iterations := DEFAULT_ITERATIONS
var duration := DEFAULT_DURATION
var seed_value := 730241


func _init() -> void:
	call_deferred("run_balance_simulation")


func run_balance_simulation() -> void:
	read_arguments()
	rng.seed = seed_value
	validate_tower_progression()
	print("Balance simulator: %d towers, %d iterations, %.1f seconds" % [GameStats.TOWERS.size(), iterations, duration])
	var rows := run_simulation()
	write_report(rows)
	print_summary(rows)
	quit()


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


func run_simulation() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tower_key in GameStats.TOWERS:
		var tower_id := StringName(tower_key)
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
		if paths.has("a") and paths.has("b"):
			rows.append_array(simulate_variant(tower_id, maximum_level, [&"a", &"b"], "dual"))
	return rows


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
	for scenario in SCENARIOS:
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
			"cost": cost,
			"mean_dps": mean,
			"p10_dps": percentile(samples, 0.10),
			"p90_dps": percentile(samples, 0.90),
			"dps_per_100": mean * 100.0 / maxf(float(cost), 1.0),
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
	if stats.has("unit_stats"):
		return simulate_spawner_trial(tower_id, stats, traits, scenario)
	var damage := float(stats.get("damage", 0))
	var interval := maxf(float(stats.get("firerate", 1.0)), 0.01)
	var attacks := floori((duration + rng.randf() * interval) / interval)
	var total := 0.0
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	var primary_type: StringName = traits["primary_type"]
	if tower_id != &"reaver":
		attacks *= maxi(int(stats.get("projectile_count", 1)), 1)
	if flags.get("orbital_bombardment", false):
		attacks *= maxi(int(values.get("bombardment_strike_count", 5)), 1)
	for attack_index in attacks:
		var attack_damage := get_reaver_combo_damage(damage, stats, flags) if tower_id == &"reaver" else damage
		if tower_id != &"reaver" and traits["bonus_tags"].has(&"critical"):
			var guaranteed_finisher: bool = bool(flags.get("reaver_assassinate", false)) and attack_index % maxi(int(stats.get("combo_hit_count", 3)), 1) == maxi(int(stats.get("combo_hit_count", 3)), 1) - 1
			if guaranteed_finisher or rng.randf() < GameStats.DEFAULT_CRITICAL_CHANCE:
				attack_damage *= GameStats.DEFAULT_CRITICAL_MULTIPLIER
		if flags.get("orbital_solar_lance", false):
			attack_damage *= (
				float(values.get("solar_lance_duration", 2.0))
				/ maxf(float(values.get("solar_lance_tick_interval", 0.2)), 0.01)
				* float(values.get("solar_lance_tick_damage_multiplier", 0.25))
			)
		elif flags.get("orbital_bombardment", false):
			attack_damage *= float(values.get("bombardment_damage_multiplier", 0.45))
		var distance_ratio := rng.randf_range(float(scenario["distance_min"]), float(scenario["distance_max"]))
		if flags.get("longshot_distance_damage", false):
			attack_damage *= get_longshot_distance_multiplier(values, distance_ratio)
		var hit_chance := get_hit_chance(tower_id, stats, traits, scenario, distance_ratio, attack_index, attacks)
		if rng.randf() > hit_chance and primary_type != &"explosive":
			continue
		var hit_damage := apply_armor(attack_damage, primary_type, float(scenario["defense"]), int(stats.get("pierce_count", 0)) > 0)
		total += get_attack_total_damage(hit_damage, stats, traits, scenario)
	if flags.get("beholder_ramping_beam", false):
		total *= get_beholder_ramp_average(values)
	total += simulate_periodic_specials(tower_id, damage, stats, traits, scenario)
	return total / duration


func get_longshot_distance_multiplier(values: Dictionary, distance_ratio: float) -> float:
	var minimum := float(values.get("distance_minimum_multiplier", 1.0))
	var midpoint := float(values.get("distance_midpoint_multiplier", 1.0))
	var maximum := float(values.get("distance_maximum_multiplier", 2.0))
	if distance_ratio <= 0.5:
		return lerpf(minimum, midpoint, clampf(distance_ratio * 2.0, 0.0, 1.0))
	return lerpf(midpoint, maximum, clampf((distance_ratio - 0.5) * 2.0, 0.0, 1.0))


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
	if traits["delivery"] == GameStats.DELIVERY_HITSCAN:
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
	if tower_id == &"brainiac":
		return clampf(0.20 + 0.80 * pow(distance_ratio, 3.0), 0.0, 1.0)
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


func apply_armor(amount: float, damage_type: StringName, defense: float, ignores_armor: bool) -> float:
	if ignores_armor: return amount
	var effective_defense := defense * 0.5 if damage_type == &"explosive" else defense
	return maxf(amount * (1.0 - effective_defense), 1.0)


func get_beholder_ramp_average(values: Dictionary) -> float:
	var start := float(values.get("beam_ramp_start_multiplier", 0.5))
	var step := float(values.get("beam_ramp_step_multiplier", 0.25))
	var step_interval := float(values.get("beam_ramp_step_interval", 0.5))
	var maximum := float(values.get("beam_ramp_max_multiplier", 2.5))
	var total := 0.0
	var ticks := maxi(floori(duration / step_interval), 1)
	for index in ticks: total += minf(start + step * float(index), maximum)
	return total / float(ticks)


func simulate_periodic_specials(tower_id: StringName, damage: float, stats: Dictionary, traits: Dictionary, scenario: Dictionary) -> float:
	var flags: Dictionary = traits["flags"]
	var values: Dictionary = traits["values"]
	var total := 0.0
	var enemies := int(scenario["enemies"])
	var defense := float(scenario["defense"])
	if flags.get("gauss_heavy_shot", false):
		var count := floori(duration / maxf(float(values.get("heavy_shot_interval", 3.0)), 0.1))
		total += float(count) * apply_armor(damage * float(values.get("heavy_shot_damage_multiplier", 10.0)), traits["primary_type"], defense, true) * float(enemies)
	if flags.get("longshot_mines", false):
		var count := floori(duration / maxf(float(values.get("mine_interval", 5.0)), 0.1))
		total += float(count) * apply_armor(damage * float(values.get("mine_damage_multiplier", 1.5)), &"explosive", defense, false) * minf(float(enemies), 3.0)
	if flags.get("void_singularity", false):
		var count := floori(duration / maxf(float(values.get("singularity_cooldown", 10.0)), 0.1))
		total += float(count) * apply_armor(damage * float(values.get("singularity_damage_multiplier", 4.0)), &"explosive", defense, false) * minf(float(enemies), 5.0)
	if flags.get("energy_shockwave", false):
		var count := floori(duration / maxf(float(values.get("shockwave_cooldown", 6.0)), 0.1))
		total += float(count) * apply_armor(damage * float(values.get("shockwave_damage_multiplier", 1.0)), &"electric", defense, false) * minf(float(enemies), 5.0)
	if flags.get("energy_branching_current", false):
		var attacks := floori(duration / maxf(float(stats.get("firerate", 1.0)), 0.01))
		var branches := mini(int(values.get("branch_additional_targets", 2)), enemies - 1)
		for branch in branches:
			total += float(attacks) * apply_armor(damage * maxf(1.0 - float(values.get("branch_damage_loss", 0.25)) * float(branch + 1), 0.0), &"electric", defense, false)
	if tower_id == &"saucer" and flags.get("saucer_twin_rockets", false):
		var count := floori(duration / maxf(float(values.get("saucer_rocket_interval", 3.0)), 0.1))
		total += float(count * 2) * apply_armor(damage * float(values.get("saucer_rocket_damage_multiplier", 3.0)), &"explosive", defense, false) * minf(float(enemies), 2.5)
	if tower_id == &"saucer" and flags.get("saucer_monster_drop", false):
		var monster: Dictionary = stats.get("monster_stats", {})
		var uptime := minf(float(monster.get("lifetime", 10.0)), duration)
		total += uptime / maxf(float(monster.get("attack_interval", 1.0)), 0.01) * apply_armor(float(monster.get("damage", 0)), &"melee", defense, false)
	return total


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
	total = apply_armor(total, damage_type, float(scenario["defense"]), int(unit.get("pierce_count", 0)) > 0)
	if tower_id == &"dronedepot":
		var budget := float(unit.get("damage_budget", 0))
		var recharge := float(unit.get("recharge_duration", 0))
		var active_time := budget / maxf(damage / attack_interval, 0.01)
		total *= active_time / maxf(active_time + recharge, 0.01)
		if bool(unit.get("explode_on_damage_budget", false)):
			var cycles := duration / maxf(active_time + recharge, 0.01)
			total += cycles * float(spawn_limit) * damage * float(unit.get("budget_explosion_damage_multiplier", 5.0)) * minf(float(int(scenario["enemies"])), 3.0)
	return total / duration


func percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty(): return 0.0
	return values[clampi(roundi(float(values.size() - 1) * ratio), 0, values.size() - 1)]


func get_model_note(tower_id: StringName) -> String:
	match tower_id:
		&"gauss_repeater": return "spread and Heavy Shot approximated"
		&"brainiac": return "convergence accuracy and link excluded"
		&"beholder": return "continuous lock assumed; death explosions excluded"
		&"reaver": return "continuous combo contact assumed"
		&"longshot": return "mine availability approximated"
		&"voidcaller": return "orb spread and singularity coverage approximated"
		&"orbitalcannon": return "optimal manual zone assumed; path persistence excluded"
		&"saucer": return "travel and abduction removal excluded"
		&"hivemother", &"dronedepot", &"mechbay": return "spawn ramp and combat uptime approximated"
		_: return "generic event model"


func write_report(rows: Array[Dictionary]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://balance_reports"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	file.store_line("tower_id,tower_name,level,variant,scenario,cost,mean_dps,p10_dps,p90_dps,dps_per_100_cost,model")
	for row in rows:
		var fields := PackedStringArray([
			str(row["tower_id"]), str(row["tower_name"]), str(row["level"]), str(row["variant"]), str(row["scenario"]), str(row["cost"]),
			"%.3f" % float(row["mean_dps"]), "%.3f" % float(row["p10_dps"]), "%.3f" % float(row["p90_dps"]), "%.3f" % float(row["dps_per_100"]), str(row["model"])
		])
		file.store_line(",".join(fields))
	file.close()
	print("Monte Carlo report: ", ProjectSettings.globalize_path(REPORT_PATH))


func print_summary(rows: Array[Dictionary]) -> void:
	print("Iterations: ", iterations, " | duration: ", duration, "s | seed: ", seed_value)
	for scenario in SCENARIOS:
		var candidates: Array[Dictionary] = []
		for row in rows:
			if row["scenario"] == scenario["id"] and row["variant"] in ["path_a", "path_b"]:
				candidates.append(row)
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dps_per_100"]) > float(b["dps_per_100"]))
		print("\n", String(scenario["id"]).to_upper(), " top max-path efficiency")
		for index in mini(5, candidates.size()):
			var row := candidates[index]
			print("  ", row["tower_name"], " ", row["variant"], ": DPS=", "%.1f" % row["mean_dps"], " /100$=", "%.2f" % row["dps_per_100"])
