extends SceneTree

const RoundControllerScript = preload(
	"res://prototype/prototype_round_controller.gd"
)
const DirectorScript = preload(
	"res://prototype/prototype_enemy_director.gd"
)

var total_spawned := 0
var lifecycle_events: Array[String] = []
var failure_count := 0


func _init() -> void:
	var controller: Node = RoundControllerScript.new(4242)
	get_root().add_child(controller)
	_validate_run_plan(controller)
	var opening_schedule: Array[Dictionary] = controller._build_schedule(
		controller.get_wave_plan(1)
	)
	_assert(
		float(opening_schedule[-1]["time"]) >= 7.0,
		"opening wave is paced across multiple pushes"
	)
	controller.state_changed.connect(_on_state_changed)
	controller.wave_cleared.connect(_on_wave_cleared)
	controller.enemy_spawn_requested.connect(
		_on_enemy_spawn_requested.bind(controller)
	)
	for expected_wave in range(1, RoundControllerScript.MAX_WAVES + 1):
		_assert(controller.start_next_wave(), "wave %d starts" % expected_wave)
		_assert(controller.current_wave == expected_wave, "wave number advances")
		var guard := 0
		while controller.phase == &"active" and guard < 4000:
			controller._process(0.10)
			guard += 1
		_assert(guard < 4000, "wave %d completes without a timer stall" % expected_wave)
		_assert(controller.completed_waves == expected_wave, "wave %d records completion" % expected_wave)
		_assert(
			lifecycle_events[-1] == "cleared:%d" % expected_wave,
			"wave %d clear is the final lifecycle notification" % expected_wave
		)
	_assert(controller.phase == &"victory", "twenty cleared waves produce victory")
	_assert(total_spawned > 0, "planned waves spawn enemies")

	var leak_controller: Node = RoundControllerScript.new(4242)
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

	var counter_controller: Node = RoundControllerScript.new(4242)
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
		int(latest_counter_state.get("remaining_spawns", -1)) == 7,
		"spawn notifications immediately refresh the scheduled counter"
	)
	_validate_seeded_variation()
	_finish("PROTOTYPE_COMBAT_LOOP_SMOKE_OK")


func _validate_run_plan(controller: Node) -> void:
	var roster: Array[StringName] = controller.get_run_roster()
	_assert(roster.size() == 9, "each run uses nine parent enemy types across three tiers")
	_assert(
		roster.has(&"armored") != roster.has(&"shielded"),
		"each run selects exactly one defensive family"
	)
	_assert(
		roster.has(&"heavy_armored") != roster.has(&"barrier_guard"),
		"each run selects the matching advanced defensive family"
	)
	_assert(
		roster.has(&"armored") == roster.has(&"heavy_armored"),
		"Armored runs progress into Heavy Armored"
	)
	_assert(
		roster.has(&"shielded") == roster.has(&"barrier_guard"),
		"Shielded runs progress into Barrier Guards"
	)
	_assert(roster.has(&"juggernaut"), "every run gains an advanced Giant")
	_assert(
		roster.has(&"healer") != roster.has(&"witch"),
		"each run selects exactly one support family"
	)
	var previous_budget := 0
	for wave in range(1, RoundControllerScript.MAX_WAVES + 1):
		var plan: Dictionary = controller.get_wave_plan(wave)
		var budget := int(plan.get("threat_budget", 0))
		var spent := int(plan.get("threat_spent", 0))
		_assert(budget > previous_budget, "wave %d raises its threat target" % wave)
		_assert(spent == budget, "wave %d spends its complete integer threat budget" % wave)
		_assert(
			is_equal_approx(float(plan.get("scale", 0.0)), _expected_enemy_scale(wave)),
			"wave %d uses its discrete enemy level" % wave
		)
		var available: Array = plan.get("available_enemies", [])
		var scheduled_types: Array[StringName] = []
		var wave_support_count := 0
		for group_value in Array(plan.get("groups", [])):
			var group: Dictionary = group_value
			var members: Array = group.get("members", [])
			_assert(not members.is_empty(), "wave %d contains no empty formations" % wave)
			var group_cost := 0
			var support_count := 0
			for enemy_value in members:
				var enemy := StringName(enemy_value)
				scheduled_types.append(enemy)
				_assert(enemy in available, "wave %d only schedules debuted enemies" % wave)
				group_cost += controller.director.get_enemy_cost(enemy)
				if controller.director.get_enemy_role(enemy) == DirectorScript.ROLE_SUPPORT:
					support_count += 1
					wave_support_count += 1
			_assert(group_cost == int(group.get("threat", -1)), "formation threat is exact")
			_assert(support_count <= 1, "a formation contains at most one support")
		for debut_value in Array(plan.get("debut_enemies", [])):
			_assert(
				StringName(debut_value) in scheduled_types,
				"wave %d visibly introduces every debut enemy" % wave
			)
		_assert(
			wave_support_count <= controller.director._get_support_limit(wave),
			"wave %d respects its support limit" % wave
		)
		if wave >= 13:
			_assert(&"golem" in scheduled_types, "late waves retain a heavy anchor")
		_assert(
			int(plan.get("planned_parent_count", -1)) == scheduled_types.size(),
			"wave %d records its planned parent count" % wave
		)
		_assert(
			int(plan.get("planned_total_count", -1))
			== scheduled_types.size() + int(plan.get("expected_child_count", -1)),
			"wave %d records expected released and summoned children" % wave
		)
		_assert(
			int(plan.get("planned_total_count", 0)) <= _population_limit(wave),
			"wave %d remains within its expected population target" % wave
		)
		previous_budget = budget


func _validate_seeded_variation() -> void:
	var first := RoundControllerScript.new(12345)
	var repeated := RoundControllerScript.new(12345)
	_assert(
		JSON.stringify(first.wave_plans) == JSON.stringify(repeated.wave_plans),
		"the same seed reproduces the complete run plan"
	)
	var signatures := {}
	var defensive_rosters := {}
	var support_rosters := {}
	var maximum_late_parent_count := 0
	for seed in range(1, 65):
		var candidate := RoundControllerScript.new(seed)
		var styles := PackedStringArray()
		var previous_style := ""
		for plan in candidate.wave_plans:
			var style := String(plan.get("style", ""))
			styles.append(style)
			_assert(
				style != previous_style or int(plan.get("wave", 0)) == RoundControllerScript.MAX_WAVES,
				"seed %d varies consecutive wave styles" % seed
			)
			previous_style = style
			_assert(
				int(plan.get("threat_spent", 0)) == int(plan.get("threat_budget", -1)),
				"seed %d spends every wave budget exactly" % seed
			)
			_assert(
				int(plan.get("planned_total_count", 0))
				<= _population_limit(int(plan.get("wave", 0))),
				"seed %d respects expected population limits" % seed
			)
			if int(plan.get("wave", 0)) >= 13:
				var parent_count := 0
				for group_value in Array(plan.get("groups", [])):
					parent_count += Array(group_value.get("members", [])).size()
				maximum_late_parent_count = maxi(maximum_late_parent_count, parent_count)
		var signature := "%s:%s" % [
			_join_names(candidate.get_run_roster()),
			"|".join(styles),
		]
		signatures[signature] = true
		defensive_rosters[&"armored" in candidate.get_run_roster()] = true
		support_rosters[&"healer" in candidate.get_run_roster()] = true
	_assert(signatures.size() >= 4, "different seeds produce varied rosters and formations")
	_assert(defensive_rosters.size() == 2, "seeded runs use both defensive roster variants")
	_assert(support_rosters.size() == 2, "seeded runs use both support roster variants")
	_assert(
		maximum_late_parent_count <= 45,
		"late budgets favor stronger enemies instead of oversized weak crowds"
	)


func _expected_enemy_scale(wave: int) -> float:
	if wave <= 5:
		return 1.0
	if wave <= 10:
		return 1.15
	if wave <= 15:
		return 1.40
	if wave <= 19:
		return 1.75
	return 2.10


func _population_limit(wave: int) -> int:
	if wave <= 5:
		return 16
	if wave <= 10:
		return 24
	if wave <= 15:
		return 30
	if wave <= 19:
		return 32
	return 35


func _join_names(values: Array[StringName]) -> String:
	var strings := PackedStringArray()
	for value in values:
		strings.append(String(value))
	return "|".join(strings)


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
