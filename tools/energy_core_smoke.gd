extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)

	var mobs: Array[Node2D] = []
	for progress in [480.0, 500.0, 520.0, 540.0]:
		var follow := PathFollow2D.new()
		path.add_child(follow)
		var mob := MOB_SCENE.instantiate()
		mob.enemy_id = &"brute"
		follow.add_child(mob)
		mob.set_path_follow(follow, progress)
		mobs.append(mob)

	var base_tower := TOWER_SCENE.instantiate() as BaseTower
	base_tower.tower_id = &"energycore"
	base_tower.main = fake_main
	base_tower.position = Vector2(500.0, 0.0)
	add_child(base_tower)
	var level_10_xp: float = base_tower.instance_progression.get_total_xp_required_for_level(10)
	base_tower.instance_progression.grant_xp(level_10_xp)
	base_tower.confirm_placement()
	base_tower.attack_on_cooldown = true
	base_tower.damage_timer.stop()
	base_tower.target = mobs[0]
	base_tower.mobs_in_range.assign(mobs)
	var base_component := base_tower.attack_component as EnergyCoreAttackComponent
	assert(base_component != null)
	assert(not base_component.branching_current_enabled)
	assert(base_tower.projectile_count == 3)
	var base_health_before: Array[int] = []
	for mob in mobs:
		base_health_before.append(int(mob.health))
	base_tower.attack(mobs[0])
	var independently_hit_targets := 0
	for mob_index in mobs.size():
		if mobs[mob_index].health < base_health_before[mob_index]:
			independently_hit_targets += 1
	assert(independently_hit_targets == 3)
	assert(base_component.branch_visual_segments.size() == 3)
	base_tower.queue_free()

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"energycore"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"b"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 0.0)
	add_child(tower)
	tower.confirm_placement()
	var component := tower.attack_component as EnergyCoreAttackComponent
	assert(component != null)
	assert(component.branching_current_enabled)
	assert(component.branch_additional_targets == 1)
	assert(is_equal_approx(component.branch_damage_multiplier, 0.25))
	assert(not component.shockwave_enabled)
	var starting_health: Array[int] = []
	for mob in mobs:
		starting_health.append(int(mob.health))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	for mob_index in mobs.size():
		assert(
			mobs[mob_index].health < starting_health[mob_index],
			"Three primary bolts plus nearby branches must damage the clustered enemies."
		)
		assert(is_equal_approx(
			mobs[mob_index].active_slow_speed_multiplier, 0.60
		))
	assert(component.branch_visual_segments.size() >= 3)
	assert(component.branch_visual_remaining > 0.0)

	# Reconfigure the same component to ensure path state resets cleanly and the
	# autonomous shockwave still uses the normal tower damage/context pipeline.
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.shockwave_enabled)
	assert(not component.branching_current_enabled)
	assert(is_equal_approx(component.shockwave_cooldown, 5.0))
	assert(is_equal_approx(component.shockwave_remaining, 5.0))
	var health_before_shockwave: Array[int] = []
	for mob in mobs:
		health_before_shockwave.append(int(mob.health))
	component.shockwave_remaining = 0.0
	component.process_attack(0.0)
	for mob_index in mobs.size():
		assert(
			mobs[mob_index].health < health_before_shockwave[mob_index],
			"Shockwave must damage every enemy in Energy Core range."
		)
	assert(component.shockwave_visual_remaining > 0.0)
	assert(is_equal_approx(
		component.shockwave_remaining,
		component.shockwave_cooldown
	))

	var levels: Array = GameStats.get_tower(&"energycore")["levels"]
	var expected_primary_targets := [1, 2, 3, 3]
	var expected_slow_strengths := [0.25, 0.25, 0.25, 0.40]
	for level_index in levels.size():
		assert(is_equal_approx(float(levels[level_index]["slow_duration"]), 0.50))
		assert(int(levels[level_index]["projectile_count"]) == expected_primary_targets[level_index])
		assert(is_equal_approx(float(levels[level_index]["slow_strength"]), expected_slow_strengths[level_index]))
	var level_1_stats := GameStats.get_tower_xp_level_stats(&"energycore", 1)
	var level_5_stats := GameStats.get_tower_xp_level_stats(&"energycore", 5)
	var level_10_stats := GameStats.get_tower_xp_level_stats(&"energycore", 10)
	var level_15_stats := GameStats.get_tower_xp_level_stats(&"energycore", 15)
	assert(int(level_1_stats["projectile_count"]) == 1)
	assert(int(level_5_stats["projectile_count"]) == 2)
	assert(int(level_10_stats["projectile_count"]) == 3)
	assert(is_equal_approx(float(level_10_stats["slow_strength"]), 0.25))
	assert(is_equal_approx(float(level_15_stats["slow_strength"]), 0.40))
	assert(GameStats.get_tower_evolutions(&"energycore").size() == 2)

	_level_to_mastery(tower)
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.shockwave_enabled)
	assert(is_equal_approx(component.shockwave_cooldown, 3.5))
	assert(is_equal_approx(component.shockwave_damage_multiplier, 0.50))
	assert(is_equal_approx(component.shockwave_stun_duration, 1.5))

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.shockwave_enabled)
	assert(component.branching_current_enabled)
	assert(component.branch_additional_targets == 2)
	assert(is_equal_approx(
		component.branch_range_pixels,
		6.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	assert(is_equal_approx(component.branch_damage_multiplier, 0.30))

	print("Energy Core smoke test passed: 25/40% Slow milestones, primary target progression, two evolutions, and Level 20 capstones.")
	get_tree().quit(0)


func _level_to_mastery(tower: BaseTower) -> void:
	var target_xp: float = tower.instance_progression.get_total_xp_required_for_level(
		GameStats.TOWER_XP_MAX_LEVEL
	)
	tower.instance_progression.grant_xp(target_xp)
