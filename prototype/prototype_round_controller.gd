class_name PrototypeRoundController
extends Node

signal enemy_spawn_requested(enemy_data: Dictionary)
signal state_changed(state: Dictionary)
signal wave_cleared(wave: int)

const PHASE_BUILD: StringName = &"build"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_VICTORY: StringName = &"victory"
const PHASE_DEFEAT: StringName = &"defeat"
const MAX_EMPTY_FIELD_DELAY := 1.25
const GROUP_GAP_MULTIPLIER := 4.0
const SPAWN_INTERVAL_MULTIPLIER := 1.35
const LARGE_GROUP_SPLIT_GAP := 3.5

const WAVES: Array[Dictionary] = [
	{"scale": 1.00, "groups": [{"type": &"soldier", "count": 5, "interval": 0.58}, {"type": &"soldier", "count": 4, "interval": 0.52, "gap": 1.10}]},
	{"scale": 1.08, "groups": [{"type": &"soldier", "count": 6, "interval": 0.52}, {"type": &"runner", "count": 4, "interval": 0.46, "gap": 1.00}]},
	{"scale": 1.16, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.48}, {"type": &"runner", "count": 5, "interval": 0.42, "gap": 1.10}]},
	{"scale": 1.25, "groups": [{"type": &"soldier", "count": 7, "interval": 0.44}, {"members": [&"carrier", &"soldier", &"soldier", &"soldier"], "interval": 0.50, "gap": 1.00}]},
	{"scale": 1.38, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.45}, {"type": &"runner", "count": 6, "interval": 0.36, "gap": 1.10}]},
	{"scale": 1.50, "groups": [{"type": &"soldier", "count": 8, "interval": 0.40}, {"type": &"carrier", "count": 2, "interval": 0.80, "gap": 1.00}]},
	{"scale": 1.64, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.42}, {"type": &"runner", "count": 7, "interval": 0.32, "gap": 1.00}]},
	{"scale": 1.80, "groups": [{"type": &"soldier", "count": 9, "interval": 0.37}, {"members": [&"carrier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.44, "gap": 0.95}]},
	{"scale": 1.98, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.40}, {"type": &"runner", "count": 9, "interval": 0.29, "gap": 0.90}]},
	{"scale": 2.20, "groups": [{"type": &"carrier", "count": 3, "interval": 0.65}, {"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.38, "gap": 1.00}]},
	{"scale": 2.35, "groups": [{"type": &"soldier", "count": 10, "interval": 0.34}, {"type": &"runner", "count": 8, "interval": 0.27, "gap": 0.85}]},
	{"scale": 2.55, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.36}, {"type": &"carrier", "count": 3, "interval": 0.60, "gap": 0.95}]},
	{"scale": 2.75, "groups": [{"type": &"runner", "count": 10, "interval": 0.25}, {"type": &"soldier", "count": 10, "interval": 0.32, "gap": 0.90}]},
	{"scale": 3.00, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"carrier", &"soldier", &"soldier", &"soldier"], "interval": 0.38}, {"type": &"runner", "count": 8, "interval": 0.24, "gap": 0.90}]},
	{"scale": 3.30, "groups": [{"type": &"giant", "count": 4, "interval": 0.70}, {"type": &"carrier", "count": 4, "interval": 0.58, "gap": 0.90}]},
	{"scale": 3.50, "groups": [{"type": &"soldier", "count": 12, "interval": 0.30}, {"type": &"runner", "count": 12, "interval": 0.22, "gap": 0.82}]},
	{"scale": 3.75, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"carrier", &"soldier", &"soldier"], "interval": 0.34}, {"type": &"runner", "count": 10, "interval": 0.21, "gap": 0.85}]},
	{"scale": 4.00, "groups": [{"type": &"carrier", "count": 5, "interval": 0.52}, {"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.32, "gap": 0.80}]},
	{"scale": 4.30, "groups": [{"type": &"runner", "count": 14, "interval": 0.20}, {"type": &"soldier", "count": 14, "interval": 0.28, "gap": 0.78}]},
	{"scale": 4.80, "groups": [{"members": [&"giant", &"giant", &"soldier", &"soldier", &"carrier", &"soldier", &"soldier"], "interval": 0.36}, {"type": &"carrier", "count": 5, "interval": 0.48, "gap": 0.85}, {"type": &"runner", "count": 12, "interval": 0.20, "gap": 0.85}]},
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


func notify_enemies_added(count: int) -> void:
	if phase != PHASE_ACTIVE or count <= 0:
		return
	active_enemy_count += count
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
		event_time += float(group_data.get("gap", 0.0)) * GROUP_GAP_MULTIPLIER
		var members: Array = group_data.get("members", [])
		var enemy_count := members.size() if not members.is_empty() else int(group_data["count"])
		var interval := float(group_data["interval"]) * SPAWN_INTERVAL_MULTIPLIER
		var split_index := ceili(float(enemy_count) * 0.5) if members.is_empty() and enemy_count >= 5 else -1
		for enemy_index in enemy_count:
			if enemy_index == split_index:
				event_time += LARGE_GROUP_SPLIT_GAP
			result.append({
				"time": event_time,
				"enemy_type": members[enemy_index] if not members.is_empty() else group_data.get("type", &"soldier"),
				"health_scale": float(wave_data.get("scale", 1.0)),
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
