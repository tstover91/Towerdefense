class_name PrototypeRunStats
extends RefCounted

const CSV_PATH := "user://prototype_run_stats.csv"
const JSON_PATH := "user://prototype_run_stats.json"
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


func _write_reports() -> void:
	var json_file := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(rows, "\t"))
	var csv_file := FileAccess.open(CSV_PATH, FileAccess.WRITE)
	if csv_file == null:
		return
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
