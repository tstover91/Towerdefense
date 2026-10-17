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
	{"scale": 1.0, "groups": [{"type": &"soldier", "count": 4, "interval": 0.65}, {"type": &"soldier", "count": 4, "interval": 0.60, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"type": &"soldier", "count": 6, "interval": 0.58}, {"type": &"runner", "count": 3, "interval": 0.50, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"type": &"soldier", "count": 6, "interval": 0.55}, {"type": &"runner", "count": 4, "interval": 0.45, "gap": 1.1}, {"type": &"soldier", "count": 4, "interval": 0.52, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.52}, {"type": &"runner", "count": 4, "interval": 0.44, "gap": 1.1}]},
	{"scale": 1.0, "groups": [{"members": [&"armored", &"soldier", &"soldier", &"armored", &"soldier", &"soldier"], "interval": 0.52}, {"members": [&"armored", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.48, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"members": [&"carrier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.52}, {"type": &"runner", "count": 5, "interval": 0.42, "gap": 1.1}]},
	{"scale": 1.0, "groups": [{"members": [&"shielded", &"soldier", &"shielded", &"soldier", &"shielded"], "interval": 0.52}, {"type": &"soldier", "count": 6, "interval": 0.48, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"healer", &"soldier"], "interval": 0.48}, {"type": &"runner", "count": 6, "interval": 0.40, "gap": 1.1}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"witch"], "interval": 0.50}, {"type": &"runner", "count": 6, "interval": 0.38, "gap": 1.1}]},
	{"scale": 1.0, "groups": [{"members": [&"armored", &"shielded", &"soldier", &"armored", &"shielded", &"soldier"], "interval": 0.48}, {"members": [&"carrier", &"soldier", &"soldier", &"soldier", &"soldier"], "interval": 0.46, "gap": 1.0}, {"type": &"runner", "count": 5, "interval": 0.38, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"soldier", &"soldier", &"soldier", &"giant", &"soldier", &"soldier"], "interval": 0.48}, {"members": [&"shielded", &"shielded", &"shielded", &"shielded"], "interval": 0.50, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"members": [&"armored", &"armored", &"soldier", &"healer", &"soldier", &"armored"], "interval": 0.48}, {"members": [&"carrier", &"soldier", &"soldier", &"carrier"], "interval": 0.54, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"type": &"soldier", "count": 6, "interval": 0.46}, {"type": &"golem", "count": 1, "interval": 0.70, "gap": 1.0}, {"type": &"runner", "count": 4, "interval": 0.38, "gap": 1.1}]},
	{"scale": 1.0, "groups": [{"members": [&"golem", &"soldier", &"soldier"], "interval": 0.55}, {"members": [&"shielded", &"shielded", &"shielded", &"shielded"], "interval": 0.48, "gap": 1.1}, {"type": &"runner", "count": 5, "interval": 0.36, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"golem", &"soldier", &"soldier"], "interval": 0.55}, {"members": [&"carrier", &"carrier", &"soldier", &"soldier"], "interval": 0.52, "gap": 1.0}, {"type": &"runner", "count": 6, "interval": 0.35, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"armored", &"soldier", &"healer", &"soldier", &"armored"], "interval": 0.46}, {"members": [&"giant", &"soldier", &"soldier", &"healer", &"soldier"], "interval": 0.44, "gap": 1.0}, {"type": &"runner", "count": 6, "interval": 0.34, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"shielded", &"shielded", &"shielded", &"shielded"], "interval": 0.46}, {"members": [&"shielded", &"soldier", &"shielded", &"soldier", &"shielded"], "interval": 0.44, "gap": 1.0}, {"members": [&"carrier", &"shielded", &"shielded"], "interval": 0.50, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"armored", &"armored", &"armored", &"armored"], "interval": 0.46}, {"members": [&"armored", &"soldier", &"armored", &"soldier", &"armored"], "interval": 0.44, "gap": 1.0}, {"members": [&"carrier", &"armored", &"armored"], "interval": 0.50, "gap": 0.9}]},
	{"scale": 1.0, "groups": [{"members": [&"giant", &"soldier", &"witch"], "interval": 0.50}, {"members": [&"carrier", &"soldier", &"soldier", &"carrier"], "interval": 0.50, "gap": 1.0}, {"members": [&"giant", &"soldier", &"witch"], "interval": 0.48, "gap": 1.0}]},
	{"scale": 1.0, "groups": [{"members": [&"golem", &"soldier", &"soldier"], "interval": 0.55}, {"members": [&"giant", &"armored", &"shielded", &"healer", &"witch"], "interval": 0.46, "gap": 1.1}, {"members": [&"carrier", &"carrier", &"runner", &"runner", &"runner", &"runner"], "interval": 0.42, "gap": 1.0}, {"type": &"golem", "count": 1, "interval": 0.70, "gap": 1.1}]},
]

var phase: StringName = PHASE_BUILD
var completed_waves := 0
var current_wave := 0
var lives := 20
var schedule: Array[Dictionary] = []
var schedule_index := 0
var wave_elapsed := 0.0
var active_enemy_count := 0
var resolved_enemy_count := 0


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
	resolved_enemy_count = 0
	phase = PHASE_ACTIVE
	_emit_state()
	return true


func notify_enemy_resolved(leaked: bool, leak_damage := 1) -> void:
	if phase != PHASE_ACTIVE:
		return
	active_enemy_count = maxi(active_enemy_count - 1, 0)
	resolved_enemy_count += 1
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
	var remaining_spawns := maxi(schedule.size() - schedule_index, 0)
	var wave_total := resolved_enemy_count + active_enemy_count + remaining_spawns
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
		"remaining_spawns": remaining_spawns,
		"wave_progress": (
			float(resolved_enemy_count) / float(wave_total)
			if wave_total > 0
			else (1.0 if completed_waves > 0 else 0.0)
		),
	}


func _emit_state() -> void:
	state_changed.emit(get_state())
