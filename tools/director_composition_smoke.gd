extends Node

const MAIN_SCENE = preload("res://main.tscn")
const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)
	director.enemy_rng.seed = 77331
	director.generate_run_director_plan()
	director.round_number = 23
	director.current_round_type = &"standard"

	var styles: Array[StringName] = [
		&"standard",
		&"stream",
		&"burst",
		&"spaced",
		&"pulses",
		&"swarm_batch",
		&"convoy",
		&"hidden_probe",
		&"splitter_pack",
		&"support_column",
		&"rush_screen",
		&"summoner_escort",
		&"elite_escort",
		&"layered_assault",
		&"boss_rehearsal",
	]
	for style_name in styles:
		director.current_wave_spawn_style = style_name
		var schedule: Array[Dictionary] = director.build_director_group()
		assert(not schedule.is_empty())
		validate_schedule(schedule)
		if style_name in [&"elite_escort", &"boss_rehearsal"]:
			assert(schedule.any(func(event: Dictionary) -> bool:
				return StringName(event.get("variant", &"normal")) == &"elite"
			))

	for round_number in range(1, 24):
		var debuts := GameStats.get_debut_enemy_ids(
			round_number,
			director.enemy_debut_plan
		)
		debuts.erase(&"normal")
		var opening: Array[Dictionary] = director.build_debut_opening(
			round_number
		)
		for enemy_id in debuts:
			assert(opening.any(func(event: Dictionary) -> bool:
				return StringName(event["enemy_id"]) == enemy_id
			))
		validate_schedule(opening)

	director.round_number = 24
	var boss_opening: Array[Dictionary] = director.build_timed_boss_opening()
	validate_schedule(boss_opening)
	assert(boss_opening.any(func(event: Dictionary) -> bool:
		return StringName(event["enemy_id"]) == &"brute"
	))
	for event in boss_opening:
		var enemy_id := StringName(event["enemy_id"])
		if enemy_id != &"brute":
			assert(GameStats.get_enemy(enemy_id).get("role", &"fodder") != &"fodder")

	print("Director composition smoke checks passed.")
	director.queue_free()
	get_tree().quit(0)


func validate_schedule(schedule: Array[Dictionary]) -> void:
	for event in schedule:
		var enemy_id := StringName(event.get("enemy_id", &""))
		assert(not enemy_id.is_empty())
		assert(GameStats.ENEMIES.has(enemy_id))
		assert(float(event.get("delay_after", 0.0)) > 0.0)
