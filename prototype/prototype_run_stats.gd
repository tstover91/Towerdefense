class_name PrototypeRunStats
extends RefCounted

const CSV_PATH := "user://prototype_run_stats.csv"
const JSON_PATH := "user://prototype_run_stats.json"
const EXPORT_DIRECTORY := "res://balance_reports"
const DAMAGE_TYPES: Array[String] = ["gun", "mortar", "beam"]

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


func begin_wave(wave: int, credits: int, lives: int) -> void:
	active_wave = wave
	starting_credits = credits
	starting_lives = lives
	spawned_health = 0
	spawned_enemies = 0
	resolved_enemies = 0
	leaks = 0
	spawned_by_type.clear()
	damage_by_type.clear()
	for tower_type in DAMAGE_TYPES:
		damage_by_type[tower_type] = 0


func is_wave_active() -> bool:
	return active_wave > 0


func record_spawn(enemy_type: StringName, max_health: int) -> void:
	if is_wave_active():
		spawned_health += maxi(max_health, 0)
		spawned_enemies += 1
		var key := String(enemy_type)
		spawned_by_type[key] = int(spawned_by_type.get(key, 0)) + 1


func record_damage(tower_type: StringName, amount: int) -> void:
	if not is_wave_active() or amount <= 0:
		return
	var key := String(tower_type)
	damage_by_type[key] = int(damage_by_type.get(key, 0)) + amount


func record_enemy_resolved(leaked: bool, _leak_damage: int) -> void:
	if not is_wave_active():
		return
	resolved_enemies += 1
	if leaked:
		leaks += 1


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
	var total_damage := 0
	for amount in damage_by_type.values():
		total_damage += int(amount)
	var row := {
		"wave": wave,
		"outcome": outcome,
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
		"carrier_spawns": int(spawned_by_type.get("carrier", 0)),
		"total_damage": total_damage,
		"gun_damage": int(damage_by_type.get("gun", 0)),
		"mortar_damage": int(damage_by_type.get("mortar", 0)),
		"beam_damage": int(damage_by_type.get("beam", 0)),
		"leaks": leaks,
		"lives_lost": maxi(starting_lives - lives_remaining, 0),
		"lives_remaining": lives_remaining,
	}
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
		return false
	destination.store_buffer(source.get_buffer(source.get_length()))
	return true


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
		"wave", "outcome", "duration_seconds", "base_reward", "interest_reward",
		"starting_credits", "ending_credits", "tower_count", "level_1_towers",
		"level_2_towers", "level_3_towers", "level_4_towers", "power_used",
		"power_limit", "wall_count", "wall_limit", "route_steps", "spawned_enemies",
		"spawned_health", "defeated_enemies", "soldier_spawns", "runner_spawns",
		"giant_spawns", "carrier_spawns",
		"total_damage", "gun_damage", "mortar_damage", "beam_damage", "leaks",
		"lives_lost", "lives_remaining",
	]
	csv_file.store_csv_line(PackedStringArray(headers))
	for row in rows:
		var values := PackedStringArray()
		for header in headers:
			values.append(str(row.get(header, "")))
		csv_file.store_csv_line(values)
	csv_file.close()
	return json_file != null
