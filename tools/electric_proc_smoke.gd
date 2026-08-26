extends Node

const GameStats = preload("res://stat_database.gd")
const MOB_SCENE = preload("res://mob.tscn")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	assert(GameStats.ELECTRIC_HITS_TO_PROC == 5)
	assert(is_equal_approx(GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION, 0.30))
	assert(is_equal_approx(GameStats.STATIC_DISCHARGE_DAMAGE_RATIO, 0.35))
	assert_electric_stat_nerfs()

	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	follow.add_child(mob)
	mob.set_path_follow(follow, 500.0)

	var starting_health: int = mob.health
	var hit_damage := [40, 100, 60, 80, 120]
	var source_towers := [
		&"energycore",
		&"energycore",
		&"saucer",
		&"saucer",
		&"fisherman",
	]
	for hit_index in 4:
		var context := AttackContext.legacy(
			source_towers[hit_index],
			&"electric_primary"
		)
		assert(mob.apply_damage(
			hit_damage[hit_index], &"electric", true, true, context
		) == hit_damage[hit_index])
	assert(mob.electric_hit_count == 4)
	assert(is_equal_approx(mob.electric_proc_damage, 84.0))

	var fifth_context := AttackContext.legacy(
		source_towers[4],
		&"fisherman_hook_tick"
	)
	assert(mob.apply_damage(120, &"electric", true, true, fifth_context) == 120)
	assert(mob.health == starting_health - 520, "Five normal hits plus the 30% lightning proc must deal 520 total damage.")
	assert(mob.electric_hit_count == 0, "Lightning damage must not recursively add a hit.")
	assert(is_zero_approx(mob.electric_proc_damage), "Lightning damage must not recursively add stored damage.")
	assert(get_tree().get_node_count_in_group("electric_proc_effects") == 1)

	for _index in 3:
		mob.apply_damage(
			10,
			&"electric",
			true,
			true,
			AttackContext.legacy(&"gauss_repeater", &"projectile")
		)
	var persistent_damage: float = mob.electric_proc_damage
	mob._process_control_effects(60.0)
	assert(mob.electric_hit_count == 3, "Electric buildup must not decay over time.")
	assert(is_equal_approx(mob.electric_proc_damage, persistent_damage))
	mob.electric_hit_count = 0
	mob.electric_proc_damage = 0.0
	mob.armor = 20.0
	var mitigated_damage: int = mob.apply_damage(
		100,
		&"electric",
		false,
		true,
		AttackContext.legacy(&"energycore", &"electric_primary")
	)
	assert(mitigated_damage < 100)
	assert(is_equal_approx(
		mob.electric_proc_damage,
		float(mitigated_damage) * GameStats.ELECTRIC_PROC_DAMAGE_CONTRIBUTION
	), "Buildup must use final damage received after mitigation.")
	assert_overcharged_capacitor()
	assert_static_discharge()
	assert_chain_lightning()

	print("Electric proc smoke test passed: shared buildup, relic thresholds, area discharge, chain lightning, recursion guard, persistence, visuals, and stat nerfs.")
	get_tree().quit()


func assert_overcharged_capacitor() -> void:
	var mob := spawn_test_mob(Vector2(2000.0, 0.0))
	var context := AttackContext.legacy(&"gauss_repeater", &"projectile")
	context.metadata["overcharged_capacitor"] = 1
	assert(mob.get_electric_proc_hit_requirement(context) == 8)
	assert(is_equal_approx(mob.get_electric_proc_damage_multiplier(context), 3.0))
	var starting_health: int = mob.health
	for _index in 7:
		mob.apply_damage(10, &"electric", true, true, context)
	assert(mob.health == starting_health - 70)
	assert(mob.electric_hit_count == 7)
	mob.apply_damage(10, &"electric", true, true, context)
	assert(mob.health == starting_health - 152, "Eight 10-damage hits must store 24 damage, then proc for 72 damage.")
	context.metadata["overcharged_capacitor"] = 2
	assert(mob.get_electric_proc_hit_requirement(context) == 12)
	assert(is_equal_approx(mob.get_electric_proc_damage_multiplier(context), 9.0))


func assert_static_discharge() -> void:
	var primary := spawn_test_mob(Vector2(3000.0, 0.0))
	var nearby := spawn_test_mob(Vector2(3030.0, 0.0))
	var outside := spawn_test_mob(
		Vector2(3000.0 + GameStats.STATIC_DISCHARGE_RADIUS + 1.0, 0.0)
	)
	var primary_health: int = primary.health
	var nearby_health: int = nearby.health
	var outside_health: int = outside.health
	var context := AttackContext.legacy(&"energycore", &"electric_primary")
	context.metadata["static_discharge"] = 1
	primary.trigger_electric_lightning_proc(100, context)
	assert(primary.health == primary_health - 50)
	assert(nearby.health == nearby_health - 35)
	assert(outside.health == outside_health)


func assert_chain_lightning() -> void:
	var primary := spawn_test_mob(Vector2(4000.0, 0.0))
	var closest := spawn_test_mob(Vector2(4070.0, 0.0))
	var farther := spawn_test_mob(Vector2(4200.0, 0.0))
	var closest_health: int = closest.health
	var farther_health: int = farther.health
	var context := AttackContext.legacy(&"saucer", &"electric_primary")
	context.metadata["chain_lightning"] = 2
	primary.trigger_electric_lightning_proc(100, context)
	assert(closest.health == closest_health - 100)
	assert(farther.health == farther_health - 100)
	assert(get_tree().get_node_count_in_group("electric_arc_effects") == 2)


func spawn_test_mob(at_position: Vector2) -> Node2D:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	add_child(mob)
	mob.global_position = at_position
	return mob


func assert_electric_stat_nerfs() -> void:
	assert_level_damage(&"gauss_repeater", [16, 16, 32, 56])
	assert_level_damage(&"energycore", [16, 22, 30, 75])
	assert_level_damage(&"saucer", [154, 218, 336, 378])
	var live_wire: Dictionary = GameStats.get_tower_path(&"fisherman", &"a")
	assert(is_equal_approx(
		float(live_wire["stat_multipliers"]["damage"]),
		1.40
	))
	var rockets: Dictionary = GameStats.get_tower_path(&"saucer", &"a")
	assert(is_equal_approx(
		float(rockets["behavior_values"]["saucer_rocket_damage_multiplier"]),
		2.0
	))
	var preserved_rocket_damage := [308, 436, 672, 756]
	var saucer_levels: Array = GameStats.get_tower(&"saucer")["levels"]
	for level_index in saucer_levels.size():
		assert(
			roundi(
				float(saucer_levels[level_index]["damage"])
				* float(rockets["behavior_values"]["saucer_rocket_damage_multiplier"])
			) == preserved_rocket_damage[level_index]
		)


func assert_level_damage(tower_id: StringName, expected_damage: Array) -> void:
	var levels: Array = GameStats.get_tower(tower_id)["levels"]
	assert(levels.size() == expected_damage.size())
	for level_index in levels.size():
		assert(int(levels[level_index]["damage"]) == int(expected_damage[level_index]))
