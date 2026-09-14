extends Node

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
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	follow.add_child(mob)
	mob.set_path_follow(follow, 500.0)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"gauss_repeater"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(400.0, 50.0)
	tower.aim_direction = Vector2.RIGHT
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	tower.target = mob
	var component = tower.attack_component
	assert(component != null)
	assert(component.heavy_shot_enabled)
	assert(not component.tracking_cone_enabled)
	assert(component.overclock_enabled)
	assert(is_equal_approx(component.heavy_shot_interval, 4.0))

	var initial_spread: float = component.current_spread_degrees
	component.execute_attack(mob, tower.damage)
	assert(component.current_spread_degrees < initial_spread)
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 1)
	assert(not projectiles[0].infinite_pierce)

	component.heavy_shot_remaining = 0.0
	component.process_attack(0.0)
	projectiles = get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 2)
	var heavy_projectile: TowerProjectile
	for projectile in projectiles:
		if projectile.infinite_pierce:
			heavy_projectile = projectile
	assert(heavy_projectile != null)
	assert(heavy_projectile.damage == roundi(tower.damage * 3.0))
	assert(is_equal_approx(heavy_projectile.speed, tower.projectile_speed * 0.60))

	component.overclock_elapsed = component.overclock_ramp_duration
	assert(is_equal_approx(
		component.modify_attack_interval(tower.loaded_attack_interval),
		tower.loaded_attack_interval / 1.25
	))
	component.on_aim_direction_changed()
	assert(is_zero_approx(component.overclock_elapsed))
	assert(is_equal_approx(component.current_spread_degrees, component.maximum_spread_degrees))

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.heavy_shot_enabled)
	assert(component.tracking_cone_enabled)
	assert(is_equal_approx(component.tracking_cone_degrees, 45.0))
	tower.aim_direction = (
		mob.global_position - tower.muzzle.global_position
	).normalized()
	assert(component.is_target_in_tracking_cone(mob))
	assert(component.select_directional_target() == mob)

	var gunner := TOWER_SCENE.instantiate() as BaseTower
	gunner.tower_id = &"gauss_gunner"
	gunner.tower_level = 3
	gunner.main = fake_main
	gunner.position = Vector2(250.0, 220.0)
	add_child(gunner)
	gunner.confirm_placement()
	assert(not gunner.uses_directional_aim())
	assert(gunner.attack_component.shows_target_mode_control())
	assert(is_equal_approx(
		gunner.attack_component.get_standard_aim_tracking_speed(),
		1.6
	))
	gunner.target_mode = BaseTower.TargetMode.HIGHEST_HEALTH
	gunner.mobs_in_range.append(mob)
	gunner.rotator.rotation = PI
	gunner.targeting_controller.select_target()
	assert(gunner.target == mob)
	var facing_before_attack := gunner.rotator.rotation
	var projectile_count_before := get_tree().get_nodes_in_group(
		"tower_projectiles"
	).size()
	gunner.targeting_controller.request_attack_if_ready()
	await get_tree().process_frame
	var updated_projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(updated_projectiles.size() == projectile_count_before + 1)
	assert(is_equal_approx(gunner.rotator.rotation, facing_before_attack))
	var immediate_projectile := updated_projectiles[-1] as TowerProjectile
	var expected_direction: Vector2 = (
		mob.global_position - gunner.muzzle.global_position
	).normalized()
	assert(immediate_projectile.direction.dot(expected_direction) > 0.90)
	print("Gauss smoke test passed: legacy paths plus standalone radial targeting, slow tracking, and immediate acquisition fire.")
	get_tree().quit(0)
