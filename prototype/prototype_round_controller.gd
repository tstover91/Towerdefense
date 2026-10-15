class_name PrototypeRoundController
extends Node

signal enemy_spawn_requested(enemy_data: Dictionary)
signal state_changed(state: Dictionary)
signal wave_cleared(wave: int)

const PHASE_BUILD: StringName = &"build"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_VICTORY: StringName = &"victory"
const PHASE_DEFEAT: StringName = &"defeat"
const MAX_EMPTY_FIELD_DELAY := 0.35

const WAVES: Array[Dictionary] = [
	{"health": 18, "speed": 1.25, "groups": [{"count": 4, "interval": 0.58}, {"count": 3, "interval": 0.52, "gap": 1.10}]},
	{"health": 22, "speed": 1.30, "groups": [{"count": 5, "interval": 0.52}, {"count": 4, "interval": 0.48, "gap": 1.00}]},
	{"health": 28, "speed": 1.35, "groups": [{"count": 5, "interval": 0.46}, {"count": 5, "interval": 0.42, "gap": 0.95}]},
	{"health": 35, "speed": 1.40, "groups": [{"count": 6, "interval": 0.42}, {"count": 5, "interval": 0.38, "gap": 0.90}]},
	{"health": 43, "speed": 1.45, "groups": [{"count": 5, "interval": 0.38}, {"count": 5, "interval": 0.36, "gap": 0.80}, {"count": 3, "interval": 0.32, "gap": 0.90}]},
	{"health": 52, "speed": 1.50, "groups": [{"count": 7, "interval": 0.36}, {"count": 7, "interval": 0.34, "gap": 0.80}]},
	{"health": 62, "speed": 1.55, "groups": [{"count": 6, "interval": 0.34}, {"count": 6, "interval": 0.32, "gap": 0.75}, {"count": 4, "interval": 0.28, "gap": 0.80}]},
	{"health": 72, "speed": 1.60, "groups": [{"count": 8, "interval": 0.32}, {"count": 8, "interval": 0.30, "gap": 0.72}]},
	{"health": 82, "speed": 1.65, "groups": [{"count": 7, "interval": 0.30}, {"count": 7, "interval": 0.28, "gap": 0.68}, {"count": 5, "interval": 0.25, "gap": 0.72}]},
	{"health": 95, "speed": 1.70, "groups": [{"count": 8, "interval": 0.28}, {"count": 8, "interval": 0.26, "gap": 0.65}, {"count": 8, "interval": 0.24, "gap": 0.65}]},
]

var phase: StringName = PHASE_BUILD
var completed_waves := 0
var current_wave := 0
var lives := 20
var schedule: Array[Dictionary] = []
var schedule_index := 0
var wave_elapsed := 0.0
var active_enemy_count := 0


func _ready() -> void:
	_emit_state()


func start_next_wave() -> bool:
	if phase != PHASE_BUILD or completed_waves >= WAVES.size():
		return false
	current_wave = completed_waves + 1
	schedule = _build_schedule(WAVES[current_wave - 1])
	schedule_index = 0
	wave_elapsed = 0.0
	active_enemy_count = 0
	phase = PHASE_ACTIVE
	_emit_state()
	return true


func notify_enemy_resolved(leaked: bool, leak_damage := 1) -> void:
	if phase != PHASE_ACTIVE:
		return
	active_enemy_count = maxi(active_enemy_count - 1, 0)
	if leaked:
		lives = maxi(lives - maxi(leak_damage, 1), 0)
		if lives <= 0:
			phase = PHASE_DEFEAT
			schedule.clear()
			_emit_state()
			return
	if not _try_complete_wave():
		_emit_state()


func _process(delta: float) -> void:
	if phase != PHASE_ACTIVE:
		return
	wave_elapsed += maxf(delta, 0.0)
	if active_enemy_count <= 0 and schedule_index < schedule.size():
		var next_spawn_time := float(schedule[schedule_index]["time"])
		wave_elapsed = maxf(
			wave_elapsed,
			next_spawn_time - MAX_EMPTY_FIELD_DELAY
		)
	var spawned_enemy := false
	while (
		phase == PHASE_ACTIVE
		and schedule_index < schedule.size()
		and wave_elapsed >= float(schedule[schedule_index]["time"])
	):
		var spawn_data := schedule[schedule_index].duplicate(true)
		schedule_index += 1
		active_enemy_count += 1
		enemy_spawn_requested.emit(spawn_data)
		spawned_enemy = true
	var wave_completed := _try_complete_wave()
	if spawned_enemy and not wave_completed and phase == PHASE_ACTIVE:
		_emit_state()


func _try_complete_wave() -> bool:
	if (
		phase != PHASE_ACTIVE
		or schedule_index < schedule.size()
		or active_enemy_count > 0
	):
		return false
	completed_waves = current_wave
	phase = PHASE_VICTORY if completed_waves >= WAVES.size() else PHASE_BUILD
	_emit_state()
	wave_cleared.emit(completed_waves)
	return true


func _build_schedule(wave_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var event_time := 0.30
	var group_index := 0
	for group_data in wave_data["groups"]:
		event_time += float(group_data.get("gap", 0.0))
		var enemy_count := int(group_data["count"])
		var interval := float(group_data["interval"])
		for enemy_index in enemy_count:
			result.append({
				"time": event_time,
				"health": int(wave_data["health"]),
				"speed_cells_per_second": float(wave_data["speed"]),
				"leak_damage": 1,
				"group_index": group_index,
				"index_in_group": enemy_index,
			})
			event_time += interval
		group_index += 1
	return result


func get_state() -> Dictionary:
	return {
		"phase": phase,
		"completed_waves": completed_waves,
		"current_wave": current_wave,
		"displayed_wave": (
			current_wave
			if phase == PHASE_ACTIVE
			else mini(completed_waves + 1, WAVES.size())
		),
		"max_waves": WAVES.size(),
		"lives": lives,
		"active_enemies": active_enemy_count,
		"remaining_spawns": maxi(schedule.size() - schedule_index, 0),
	}


func _emit_state() -> void:
	state_changed.emit(get_state())
