extends SceneTree

const RoundControllerScript = preload(
	"res://prototype/prototype_round_controller.gd"
)

var total_spawned := 0
var lifecycle_events: Array[String] = []
var failure_count := 0


func _init() -> void:
	var controller: Node = RoundControllerScript.new()
	get_root().add_child(controller)
	controller.state_changed.connect(_on_state_changed)
	controller.wave_cleared.connect(_on_wave_cleared)
	controller.enemy_spawn_requested.connect(_on_enemy_spawn_requested.bind(controller))
	for expected_wave in range(1, 21):
		_assert(controller.start_next_wave(), "wave %d starts" % expected_wave)
		_assert(controller.current_wave == expected_wave, "wave number advances")
		var guard := 0
		while controller.phase == &"active" and guard < 1000:
			controller._process(0.10)
			guard += 1
		_assert(guard < 1000, "wave %d completes without a timer stall" % expected_wave)
		_assert(controller.completed_waves == expected_wave, "wave %d records completion" % expected_wave)
		_assert(
			lifecycle_events[-1] == "cleared:%d" % expected_wave,
			"wave %d clear is the final lifecycle notification" % expected_wave
		)
	_assert(controller.phase == &"victory", "twenty cleared waves produce victory")
	_assert(total_spawned > 0, "planned waves spawn enemies")

	var leak_controller: Node = RoundControllerScript.new()
	get_root().add_child(leak_controller)
	leak_controller.lives = 1
	leak_controller.enemy_spawn_requested.connect(
		func(_enemy_data: Dictionary) -> void:
			leak_controller.notify_enemy_resolved(true, 1)
	)
	_assert(leak_controller.start_next_wave(), "leak test wave starts")
	leak_controller._process(1.0)
	_assert(leak_controller.phase == &"defeat", "last leaked life produces defeat")
	var defeated_count: int = leak_controller.active_enemy_count
	leak_controller.notify_enemy_resolved(false, 0)
	_assert(
		leak_controller.active_enemy_count == defeated_count,
		"late enemy callbacks cannot mutate a finished round"
	)

	var counter_controller: Node = RoundControllerScript.new()
	get_root().add_child(counter_controller)
	var counter_states: Array[Dictionary] = []
	counter_controller.state_changed.connect(
		func(state: Dictionary) -> void: counter_states.append(state)
	)
	_assert(counter_controller.start_next_wave(), "counter test wave starts")
	counter_controller._process(0.31)
	var latest_counter_state: Dictionary = counter_states[-1]
	_assert(
		int(latest_counter_state.get("active_enemies", 0)) == 1,
		"spawn notifications immediately refresh the active counter"
	)
	_assert(
		int(latest_counter_state.get("remaining_spawns", -1)) == 4,
		"spawn notifications immediately refresh the scheduled counter"
	)
	_finish("PROTOTYPE_COMBAT_LOOP_SMOKE_OK")


func _on_enemy_spawn_requested(_enemy_data: Dictionary, controller: Node) -> void:
	total_spawned += 1
	controller.notify_enemy_resolved(false, 0)


func _on_state_changed(state: Dictionary) -> void:
	lifecycle_events.append("state:%s" % String(state.get("phase", &"")))


func _on_wave_cleared(wave: int) -> void:
	lifecycle_events.append("cleared:%d" % wave)


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype combat smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
