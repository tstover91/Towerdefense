class_name PrototypeRunStats
extends RefCounted

const CSV_PATH := "user://prototype_run_stats.csv"
const JSON_PATH := "user://prototype_run_stats.json"
const EXPORT_DIRECTORY := "res://balance_reports"
const DAMAGE_TYPES: Array[String] = ["gunslinger", "anti_materiel", "flamespitter", "bombardment", "atomic_strike"]

var rows: Array[Dictionary] = []
var active_wave := 0
var starting_credits := 0
var starting_lives := 0
var spawned_health := 0
var spawned_enemies := 0
var resolved_enemies := 0
var leaks := 0
var spawned_by_type: Dictionary = {}
var damage_by_type: Dictionary = {}
var damage_by_type_level: Dictionary = {}
var max_enemy_progress := 0.0
var enemies_reaching_75_percent := 0
var enemies_reaching_90_percent := 0
var planned_threat := 0
var spent_threat := 0
var spawned_director_threat := 0
var wave_style := ""
var run_enemy_roster := ""
var debut_enemy_types := ""
var planned_parent_count := 0
var expected_child_count := 0
var planned_total_count := 0
var pending_actions: Dictionary = _new_action_counts()
var wave_actions: Dictionary = _new_action_counts()


func begin_wave(
	wave: int,
	credits: int,
	lives: int,
	wave_plan: Dictionary = {}
) -> void:
	active_wave = wave
	starting_credits = credits
	starting_lives = lives
	spawned_health = 0
	spawned_enemies = 0
	resolved_enemies = 0
	leaks = 0
	spawned_by_type.clear()
	damage_by_type.clear()
	damage_by_type_level.clear()
	max_enemy_progress = 0.0
	enemies_reaching_75_percent = 0
	enemies_reaching_90_percent = 0
	planned_threat = int(wave_plan.get("threat_budget", 0))
	spent_threat = int(wave_plan.get("threat_spent", 0))
	spawned_director_threat = 0
	wave_style = String(wave_plan.get("style", ""))
	run_enemy_roster = _join_names(Array(wave_plan.get("run_roster", [])))
	debut_enemy_types = _join_names(Array(wave_plan.get("debut_enemies", [])))
	planned_parent_count = int(wave_plan.get("planned_parent_count", 0))
	expected_child_count = int(wave_plan.get("expected_child_count", 0))
	planned_total_count = int(wave_plan.get("planned_total_count", 0))
	wave_actions = pending_actions.duplicate(true)
	pending_actions = _new_action_counts()
	for tower_type in DAMAGE_TYPES:
		damage_by_type[tower_type] = 0
		for tower_level in range(1, 5):
			damage_by_type_level["%s_l%d" % [tower_type, tower_level]] = 0


func is_wave_active() -> bool:
	return active_wave > 0


func record_spawn(
	enemy_type: StringName,
	max_health: int,
	director_threat := 0
) -> void:
	if is_wave_active():
		spawned_health += maxi(max_health, 0)
		spawned_enemies += 1
		spawned_director_threat += maxi(director_threat, 0)
		var key := String(enemy_type)
		spawned_by_type[key] = int(spawned_by_type.get(key, 0)) + 1


func record_damage(tower_type: StringName, tower_level: int, amount: int) -> void:
	if not is_wave_active() or amount <= 0:
		return
	var key := String(tower_type)
	damage_by_type[key] = int(damage_by_type.get(key, 0)) + amount
	var level_key := "%s_l%d" % [key, clampi(tower_level, 1, 4)]
	damage_by_type_level[level_key] = int(damage_by_type_level.get(level_key, 0)) + amount


func record_enemy_resolved(leaked: bool, _leak_damage: int, progress_ratio: float) -> void:
	if not is_wave_active():
		return
	resolved_enemies += 1
	var safe_progress := clampf(progress_ratio, 0.0, 1.0)
	max_enemy_progress = maxf(max_enemy_progress, safe_progress)
	if safe_progress >= 0.75:
		enemies_reaching_75_percent += 1
	if safe_progress >= 0.90:
		enemies_reaching_90_percent += 1
	if leaked:
		leaks += 1


func record_structure_action(action: StringName, _tower_type: StringName, _tower_level: int, amount: int) -> void:
	var target := wave_actions if is_wave_active() else pending_actions
	var action_key := String(action)
	if target.has(action_key):
		target[action_key] = int(target[action_key]) + 1
	match action:
		&"tower_built", &"tower_upgraded":
			target["credits_spent"] = int(target["credits_spent"]) + maxi(amount, 0)
		&"tower_sold":
			target["credits_refunded"] = int(target["credits_refunded"]) + maxi(amount, 0)


func _new_action_counts() -> Dictionary:
	return {
		"tower_built": 0,
		"tower_upgraded": 0,
		"tower_sold": 0,
		"wall_built": 0,
		"wall_removed": 0,
		"credits_spent": 0,
		"credits_refunded": 0,
	}


func _join_names(values: Array) -> String:
	var names := PackedStringArray()
	for value in values:
		names.append(String(value))
	return "|".join(names)


func finish_wave(
	wave: int,
	duration: float,
	reward: Dictionary,
	economy_state: Dictionary,
	board_state: Dictionary,
	lives_remaining: int,
	outcome := "cleared"
) -> Dictionary:
	if active_wave != wave:
		return {}
	var levels: Array = board_state.get("tower_levels", [0, 0, 0, 0])
	var type_counts: Dictionary = board_state.get("tower_type_counts", {})
	var type_levels: Dictionary = board_state.get("tower_type_levels", {})
	var type_investment: Dictionary = board_state.get("tower_type_investment", {})
	var total_damage := 0
	for amount in damage_by_type.values():
		total_damage += int(amount)
	var row := {
		"wave": wave,
		"map_seed": int(board_state.get("map_seed", 0)),
		"initial_route_steps": int(board_state.get("initial_route_steps", 0)),
		"outcome": outcome,
		"wave_style": wave_style,
		"planned_threat": planned_threat,
		"spent_threat": spent_threat,
		"spawned_director_threat": spawned_director_threat,
		"run_enemy_roster": run_enemy_roster,
		"debut_enemy_types": debut_enemy_types,
		"planned_parent_count": planned_parent_count,
		"expected_child_count": expected_child_count,
		"planned_total_count": planned_total_count,
		"duration_seconds": snappedf(duration, 0.01),
		"base_reward": int(reward.get("base_reward", 0)),
		"interest_reward": int(reward.get("interest_reward", 0)),
		"starting_credits": starting_credits,
		"ending_credits": int(economy_state.get("credits", 0)),
		"tower_count": int(board_state.get("tower_count", 0)),
		"level_1_towers": int(levels[0]) if levels.size() > 0 else 0,
		"level_2_towers": int(levels[1]) if levels.size() > 1 else 0,
		"level_3_towers": int(levels[2]) if levels.size() > 2 else 0,
		"level_4_towers": int(levels[3]) if levels.size() > 3 else 0,
		"gunslinger_count": int(type_counts.get("gunslinger", 0)),
		"anti_materiel_count": int(type_counts.get("anti_materiel", 0)),
		"flamespitter_count": int(type_counts.get("flamespitter", 0)),
		"bombardment_count": int(type_counts.get("bombardment", 0)),
		"atomic_strike_count": int(type_counts.get("atomic_strike", 0)),
		"gunslinger_investment": int(type_investment.get("gunslinger", 0)),
		"anti_materiel_investment": int(type_investment.get("anti_materiel", 0)),
		"flamespitter_investment": int(type_investment.get("flamespitter", 0)),
		"bombardment_investment": int(type_investment.get("bombardment", 0)),
		"atomic_strike_investment": int(type_investment.get("atomic_strike", 0)),
		"power_used": int(economy_state.get("used_power", 0)),
		"power_limit": int(economy_state.get("power_limit", 0)),
		"wall_count": int(board_state.get("wall_count", 0)),
		"wall_limit": int(economy_state.get("wall_limit", 0)),
		"route_steps": int(board_state.get("route_steps", 0)),
		"spawned_enemies": spawned_enemies,
		"spawned_health": spawned_health,
		"defeated_enemies": maxi(resolved_enemies - leaks, 0),
		"soldier_spawns": int(spawned_by_type.get("soldier", 0)),
		"runner_spawns": int(spawned_by_type.get("runner", 0)),
		"giant_spawns": int(spawned_by_type.get("giant", 0)),
		"juggernaut_spawns": int(spawned_by_type.get("juggernaut", 0)),
		"carrier_spawns": int(spawned_by_type.get("carrier", 0)),
		"armored_spawns": int(spawned_by_type.get("armored", 0)),
		"heavy_armored_spawns": int(spawned_by_type.get("heavy_armored", 0)),
		"shielded_spawns": int(spawned_by_type.get("shielded", 0)),
		"barrier_guard_spawns": int(spawned_by_type.get("barrier_guard", 0)),
		"healer_spawns": int(spawned_by_type.get("healer", 0)),
		"witch_spawns": int(spawned_by_type.get("witch", 0)),
		"swarmling_spawns": int(spawned_by_type.get("swarmling", 0)),
		"golem_spawns": int(spawned_by_type.get("golem", 0)),
		"golemite_spawns": int(spawned_by_type.get("golemite", 0)),
		"total_damage": total_damage,
		"gunslinger_damage": int(damage_by_type.get("gunslinger", 0)),
		"anti_materiel_damage": int(damage_by_type.get("anti_materiel", 0)),
		"flamespitter_damage": int(damage_by_type.get("flamespitter", 0)),
		"bombardment_damage": int(damage_by_type.get("bombardment", 0)),
		"atomic_strike_damage": int(damage_by_type.get("atomic_strike", 0)),
		"max_enemy_progress_percent": snappedf(max_enemy_progress * 100.0, 0.1),
		"enemies_reaching_75_percent": enemies_reaching_75_percent,
		"enemies_reaching_90_percent": enemies_reaching_90_percent,
		"towers_built": int(wave_actions.get("tower_built", 0)),
		"towers_upgraded": int(wave_actions.get("tower_upgraded", 0)),
		"towers_sold": int(wave_actions.get("tower_sold", 0)),
		"walls_built": int(wave_actions.get("wall_built", 0)),
		"walls_removed": int(wave_actions.get("wall_removed", 0)),
		"credits_spent": int(wave_actions.get("credits_spent", 0)),
		"credits_refunded": int(wave_actions.get("credits_refunded", 0)),
		"leaks": leaks,
		"lives_lost": maxi(starting_lives - lives_remaining, 0),
		"lives_remaining": lives_remaining,
	}
	for tower_type in DAMAGE_TYPES:
		for tower_level in range(1, 5):
			var type_level_key := "%s_l%d" % [tower_type, tower_level]
			row["%s_count" % type_level_key] = int(type_levels.get(type_level_key, 0))
			row["%s_damage" % type_level_key] = int(damage_by_type_level.get(type_level_key, 0))
	rows.append(row)
	active_wave = 0
	_write_reports()
	print("PROTOTYPE_STATS %s" % JSON.stringify(row))
	return row


func get_rows() -> Array[Dictionary]:
	return rows.duplicate(true)


func get_report_paths() -> Dictionary:
	return {
		"csv": ProjectSettings.globalize_path(CSV_PATH),
		"json": ProjectSettings.globalize_path(JSON_PATH),
	}


func export_reports_to_project() -> Dictionary:
	var export_directory := ProjectSettings.globalize_path(EXPORT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(export_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return {
			"success": false,
			"message": "Could not create the balance_reports folder.",
		}
	var ignore_file := FileAccess.open(export_directory.path_join(".gdignore"), FileAccess.WRITE)
	if ignore_file != null:
		ignore_file.store_string("# Keep exported telemetry out of Godot's resource importer.\n")
		ignore_file.close()
	_remove_translation_import_artifacts(export_directory)
	var copied_files := 0
	for source_path_value in [CSV_PATH, JSON_PATH]:
		var source_path := String(source_path_value)
		if not FileAccess.file_exists(source_path):
			continue
		var file_name: String = source_path.get_file()
		var destination_path: String = ProjectSettings.globalize_path(
			EXPORT_DIRECTORY.path_join(file_name)
		)
		if _copy_file(source_path, destination_path):
			copied_files += 1
	if copied_files == 0 and not rows.is_empty():
		var direct_csv_path := export_directory.path_join(CSV_PATH.get_file())
		var direct_json_path := export_directory.path_join(JSON_PATH.get_file())
		if _write_reports_to_paths(direct_csv_path, direct_json_path):
			copied_files = 2
	if copied_files == 0:
		return {
			"success": false,
			"message": "No completed-round stats were found to export.",
		}
	return {
		"success": true,
		"message": "Stats exported to balance_reports (%d files)." % copied_files,
		"path": export_directory,
	}


func _copy_file(source_path: String, destination_path: String) -> bool:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		source.close()
		return false
	destination.store_buffer(source.get_buffer(source.get_length()))
	destination.close()
	source.close()
	return true


func _remove_translation_import_artifacts(export_directory: String) -> void:
	var directory := DirAccess.open(export_directory)
	if directory == null:
		return
	for file_name in directory.get_files():
		var is_report_import := file_name == "prototype_run_stats.csv.import"
		var is_report_translation := (
			file_name.begins_with("prototype_run_stats.")
			and file_name.ends_with(".translation")
		)
		if is_report_import or is_report_translation:
			directory.remove(file_name)


func _write_reports() -> void:
	_write_reports_to_paths(CSV_PATH, JSON_PATH)


func _write_reports_to_paths(csv_path: String, json_path: String) -> bool:
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(rows, "\t"))
		json_file.close()
	var csv_file := FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file == null:
		return false
	var headers: Array[String] = [
		"wave", "map_seed", "initial_route_steps", "outcome", "wave_style",
		"planned_threat", "spent_threat", "spawned_director_threat",
		"run_enemy_roster", "debut_enemy_types", "planned_parent_count",
		"expected_child_count", "planned_total_count", "duration_seconds",
		"base_reward", "interest_reward",
		"starting_credits", "ending_credits", "tower_count", "level_1_towers",
		"level_2_towers", "level_3_towers", "level_4_towers", "gunslinger_count",
		"anti_materiel_count", "flamespitter_count", "bombardment_count", "atomic_strike_count",
		"gunslinger_investment", "anti_materiel_investment",
		"flamespitter_investment", "bombardment_investment", "atomic_strike_investment",
	]
	for tower_type in DAMAGE_TYPES:
		for tower_level in range(1, 5):
			headers.append("%s_l%d_count" % [tower_type, tower_level])
	headers.append_array([
		"power_used",
		"power_limit", "wall_count", "wall_limit", "route_steps", "spawned_enemies",
		"spawned_health", "defeated_enemies", "soldier_spawns", "runner_spawns",
		"giant_spawns", "juggernaut_spawns", "carrier_spawns",
		"armored_spawns", "heavy_armored_spawns", "shielded_spawns",
		"barrier_guard_spawns",
		"healer_spawns", "witch_spawns", "swarmling_spawns", "golem_spawns",
		"golemite_spawns",
		"total_damage", "gunslinger_damage", "anti_materiel_damage",
		"flamespitter_damage", "bombardment_damage", "atomic_strike_damage",
	])
	for tower_type in DAMAGE_TYPES:
		for tower_level in range(1, 5):
			headers.append("%s_l%d_damage" % [tower_type, tower_level])
	headers.append_array([
		"max_enemy_progress_percent", "enemies_reaching_75_percent",
		"enemies_reaching_90_percent", "towers_built", "towers_upgraded",
		"towers_sold", "walls_built", "walls_removed", "credits_spent",
		"credits_refunded", "leaks", "lives_lost", "lives_remaining",
	])
	csv_file.store_csv_line(PackedStringArray(headers))
	for row in rows:
		var values := PackedStringArray()
		for header in headers:
			values.append(str(row.get(header, "")))
		csv_file.store_csv_line(values)
	csv_file.close()
	return json_file != null
