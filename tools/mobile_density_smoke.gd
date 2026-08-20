extends Node

const MAIN_SCENE = preload("res://main.tscn")
const MOB_SCENE = preload("res://mob.tscn")
const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var mode := GameStats.get_mode(&"easy")
	assert(int(mode["active_enemy_cap"]) == 160)
	assert(int(mode["horde_active_enemy_cap"]) == 200)
	assert(int(mode["gauntlet_active_enemy_cap"]) == 220)
	assert(int(mode["absolute_enemy_cap"]) == 240)

	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)

	var normal = MOB_SCENE.instantiate()
	normal.enemy_id = &"normal"
	director.add_child(normal)
	assert(not normal.health_bar_anchor.visible)
	normal.apply_damage(1, &"ballistic")
	assert(normal.health_bar_anchor.visible)

	var runner = MOB_SCENE.instantiate()
	runner.enemy_id = &"runner"
	director.add_child(runner)
	assert(runner.health_bar_anchor.visible)

	var armored = MOB_SCENE.instantiate()
	armored.enemy_id = &"armored"
	director.add_child(armored)
	var armored_health: int = armored.health
	assert(armored.apply_damage(100, &"ballistic") == 71)
	armored.health = armored_health
	assert(armored.apply_damage(100, &"explosive") == 67)
	armored.health = armored_health
	assert(armored.apply_damage(100, &"beam") == 100)
	armored.health = armored_health
	var conductive_context := AttackContext.legacy(&"energycore", &"direct")
	conductive_context.metadata["conductive"] = 1
	assert(armored.apply_damage(
		100, &"electric", false, true, conductive_context
	) == 129)
	normal.max_health = 1000
	normal.health = 1000
	var unarmored_health: int = normal.health
	assert(normal.apply_damage(
		100, &"electric", false, true, conductive_context
	) == 85)
	assert(normal.health == unarmored_health - 85)
	var missed_context := AttackContext.legacy(&"longshot", &"hitscan")
	missed_context.metadata["shot_missed"] = true
	assert(normal.apply_damage(
		1000, &"ballistic", false, true, missed_context
	) == 0)
	assert(normal.health == unarmored_health - 85)
	armored.health = armored_health
	var thermite_context := AttackContext.legacy(&"orbitalcannon", &"explosion")
	thermite_context.metadata["thermite_bombs"] = 1
	var starting_armor: float = armored.armor
	assert(armored.apply_damage(
		100, &"explosive", false, true, thermite_context
	) == 0)
	assert(armored.health == armored_health)
	assert(is_equal_approx(
		armored.armor,
		starting_armor - GameStats.THERMITE_BOMBS_PROTECTION_REMOVAL
	))

	var buffer = MOB_SCENE.instantiate()
	buffer.enemy_id = &"buffer"
	director.add_child(buffer)
	normal.global_position = Vector2.ZERO
	buffer.global_position = Vector2(20.0, 0.0)
	director.enemy_aura_refresh_remaining = 0.0
	director._process_enemy_speed_auras(0.2)
	assert(is_equal_approx(normal.cached_speed_aura_multiplier, 1.2))
	normal.global_position = Vector2(1000.0, 0.0)
	director.enemy_aura_refresh_remaining = 0.0
	director._process_enemy_speed_auras(0.2)
	assert(is_equal_approx(normal.cached_speed_aura_multiplier, 1.0))

	director.spawn_hitscan_visual(Vector2.ZERO, Vector2.RIGHT * 20.0, &"ballistic")
	var hitscan = get_tree().get_first_node_in_group("tower_attack_visuals")
	assert(hitscan != null)
	var hitscan_id := hitscan.get_instance_id()
	hitscan.recycle_now()
	assert(director.pooled_hitscan_effects.size() == 1)
	director.spawn_hitscan_visual(Vector2.ZERO, Vector2.RIGHT * 30.0, &"electric")
	assert(get_tree().get_first_node_in_group("tower_attack_visuals").get_instance_id() == hitscan_id)

	for visual in get_tree().get_nodes_in_group("tower_attack_visuals"):
		visual.recycle_now()
	director.spawn_explosion_visual(Vector2.ZERO, 32.0)
	var explosion = get_tree().get_first_node_in_group("tower_attack_visuals")
	assert(explosion != null)
	var explosion_id := explosion.get_instance_id()
	explosion.recycle_now()
	assert(director.pooled_explosion_effects.size() == 1)
	director.spawn_explosion_visual(Vector2.ONE, 48.0)
	assert(get_tree().get_first_node_in_group("tower_attack_visuals").get_instance_id() == explosion_id)

	print("Mobile density smoke checks passed.")
	director.queue_free()
	get_tree().quit(0)
