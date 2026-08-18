extends Node

const MAIN_SCENE = preload("res://main.tscn")
const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)
	await get_tree().process_frame

	var option := GameStats.get_reinforcement_option(&"grunt_squad")
	assert(StringName(option["unit_id"]) == &"reinforcement_alien")
	assert(int(option["unit_count"]) == 3)
	assert(float(option["cooldown"]) == 25.0)

	director.round_number = 1
	director.round_active = true
	director._create_mob(&"normal", 120.0)
	await get_tree().process_frame
	var mobs := get_tree().get_nodes_in_group("mobs")
	assert(mobs.size() == 1)
	var mob = mobs[0]
	director.begin_reinforcement_targeting()
	assert(director.reinforcement_targeting)
	assert(is_instance_valid(director.reinforcement_preview))

	var drop_position: Vector2 = mob.global_position
	assert(director.deploy_reinforcements(drop_position))
	assert(not director.reinforcement_targeting)
	assert(is_equal_approx(director.reinforcement_cooldown_remaining, 25.0))
	var drops := get_tree().get_nodes_in_group("reinforcement_drops")
	assert(drops.size() == 1)
	var units := drops[0].get_children()
	assert(units.size() == 3)
	for unit in units:
		assert(unit.unit_id == &"reinforcement_alien")
		assert(unit.movement_type == GameStats.MOVEMENT_GUARD)
		assert(unit.slow_duration > unit.attack_interval)
		assert(unit.damage == 5)

	director._process_reinforcements(1.0)
	assert(is_equal_approx(director.reinforcement_cooldown_remaining, 24.0))
	var health_before := int(mob.health)
	await get_tree().create_timer(1.2).timeout
	assert(int(mob.health) < health_before)
	assert(float(mob.slow_remaining) > 0.0)
	director.clear_reinforcement_drops()
	print("Reinforcement smoke test passed: targeting, deployment, combat stall, and cooldown.")
	get_tree().quit(0)
