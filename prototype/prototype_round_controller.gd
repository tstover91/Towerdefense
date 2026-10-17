class_name PrototypeRoundController
extends Node

signal enemy_spawn_requested(enemy_data: Dictionary)
signal state_changed(state: Dictionary)
signal wave_cleared(wave: int)

const EnemyDirectorScript = preload("res://prototype/prototype_enemy_director.gd")

const PHASE_BUILD: StringName = &"build"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_VICTORY: StringName = &"victory"
const PHASE_DEFEAT: StringName = &"defeat"
const MAX_WAVES := EnemyDirectorScript.MAX_WAVES
const MAX_EMPTY_FIELD_DELAY := 1.25
const GROUP_GAP_MULTIPLIER := 4.0
const SPAWN_INTERVAL_MULTIPLIER := 1.35

var director: RefCounted
var wave_plans: Array[Dictionary] = []
var run_seed := 1
var phase: StringName = PHASE_BUILD
var completed_waves := 0
var current_wave := 0
var lives := 20
var schedule: Array[Dictionary] = []
var schedule_index := 0
var wave_elapsed := 0.0
var active_enemy_count := 0
var resolved_enemy_count := 0


func _init(seed := 1) -> void:
	configure_run(seed)


func _ready() -> void:
	_emit_state()


func configure_run(seed: int) -> void:
	if phase == PHASE_ACTIVE:
		return
	run_seed = maxi(seed, 1)
	director = EnemyDirectorScript.new()
	wave_plans.assign(director.generate_run(run_seed))


func start_next_wave() -> bool:
	if phase != PHASE_BUILD or completed_waves >= wave_plans.size():
		return false
	current_wave = completed_waves + 1
	schedule = _build_schedule(wave_plans[current_wave - 1])
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
	phase = PHASE_VICTORY if completed_waves >= wave_plans.size() else PHASE_BUILD
	_emit_state()
	wave_cleared.emit(completed_waves)
	return true


func _build_schedule(wave_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var event_time := 0.30
	var group_index := 0
	for group_data in Array(wave_data.get("groups", [])):
		event_time += float(group_data.get("gap", 0.0)) * GROUP_GAP_MULTIPLIER
		var members: Array = group_data.get("members", [])
		var interval := float(group_data.get("interval", 0.48)) * SPAWN_INTERVAL_MULTIPLIER
		for enemy_index in members.size():
			var enemy_type := StringName(members[enemy_index])
			result.append({
				"time": event_time,
				"enemy_type": enemy_type,
				"health_scale": float(wave_data.get("scale", 1.0)),
				"director_threat": director.get_enemy_cost(enemy_type),
				"group_index": group_index,
				"index_in_group": enemy_index,
			})
			event_time += interval
		group_index += 1
	return result


func get_wave_plan(wave: int) -> Dictionary:
	if wave <= 0 or wave > wave_plans.size():
		return {}
	return wave_plans[wave - 1].duplicate(true)


func get_run_roster() -> Array[StringName]:
	if director == null:
		return []
	return director.roster.duplicate()


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
			else mini(completed_waves + 1, wave_plans.size())
		),
		"max_waves": wave_plans.size(),
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
