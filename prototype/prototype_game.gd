extends Node

const RoundControllerScript = preload("res://prototype/prototype_round_controller.gd")
const EconomyScript = preload("res://prototype/prototype_economy.gd")
const RunStatsScript = preload("res://prototype/prototype_run_stats.gd")

@onready var board: Node2D = $GridBoard
var round_controller: Node
var economy: RefCounted
var run_stats: RefCounted


func _ready() -> void:
	round_controller = RoundControllerScript.new()
	economy = EconomyScript.new()
	run_stats = RunStatsScript.new()
	add_child(round_controller)
	board.configure_economy(economy)
	board.start_wave_requested.connect(_on_start_wave_requested)
	board.enemy_resolved.connect(round_controller.notify_enemy_resolved)
	board.enemies_added.connect(round_controller.notify_enemies_added)
	board.enemy_spawned_for_stats.connect(run_stats.record_spawn)
	board.tower_damage_recorded.connect(run_stats.record_damage)
	board.enemy_resolved_for_stats.connect(run_stats.record_enemy_resolved)
	board.structure_action_recorded.connect(run_stats.record_structure_action)
	board.export_stats_requested.connect(_on_export_stats_requested)
	board.new_map_requested.connect(_on_new_map_requested)
	round_controller.enemy_spawn_requested.connect(board.spawn_enemy)
	round_controller.wave_cleared.connect(_on_wave_cleared)
	round_controller.state_changed.connect(_on_combat_state_changed)
	board.set_combat_state(round_controller.get_state())
	_refresh_economy_state()


func _on_start_wave_requested() -> void:
	var next_wave: int = int(round_controller.completed_waves) + 1
	if round_controller.start_next_wave():
		economy.begin_wave(next_wave)
		run_stats.begin_wave(next_wave, economy.credits, round_controller.lives)
		board.mark_all_towers_participated()
		_refresh_economy_state()


func _on_wave_cleared(wave: int) -> void:
	# The final enemy's defeated signal is still unwinding here. Finish on the
	# deferred step so its killing hit and resolution are included in telemetry.
	call_deferred("_complete_wave_accounting", wave, float(round_controller.wave_elapsed))


func _complete_wave_accounting(wave: int, duration: float) -> void:
	var reward: Dictionary = economy.complete_wave(wave)
	run_stats.finish_wave(
		wave,
		duration,
		reward,
		economy.get_state(wave, false),
		board.get_telemetry_snapshot(),
		round_controller.lives
	)
	board.show_wave_reward(reward)
	_refresh_economy_state()


func _on_combat_state_changed(state: Dictionary) -> void:
	board.set_combat_state(state)
	_refresh_economy_state()
	if StringName(state.get("phase", &"")) == &"defeat" and run_stats.is_wave_active():
		run_stats.finish_wave(
			round_controller.current_wave,
			round_controller.wave_elapsed,
			{},
			economy.get_state(round_controller.current_wave, true),
			board.get_telemetry_snapshot(),
			round_controller.lives,
			"defeat"
		)


func _on_export_stats_requested() -> void:
	board.show_stats_export_result(run_stats.export_reports_to_project())


func _on_new_map_requested() -> void:
	# Reload the prototype so the board, economy, wave state, and telemetry all
	# begin together on the newly generated seed.
	get_tree().call_deferred("reload_current_scene")


func _refresh_economy_state() -> void:
	var terminal: bool = StringName(round_controller.phase) in [&"victory", &"defeat"]
	var next_wave: int = int(
		round_controller.current_wave
		if round_controller.phase == &"active"
		else mini(
			int(round_controller.completed_waves) + 1,
			RoundControllerScript.WAVES.size()
		)
	)
	var state: Dictionary = economy.get_state(
		next_wave,
		round_controller.phase == &"active"
	)
	if terminal:
		state["interest"] = 0
		state["interest_locked"] = false
	board.set_economy_state(state)
