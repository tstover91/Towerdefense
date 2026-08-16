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
	var relics: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


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
	tower.tower_id = &"voidcaller"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	var component = tower.attack_component
	assert(component != null)
	assert(not component.singularity_enabled)
	assert(tower.projectile_count == 5)
	assert(is_zero_approx(tower.volley_stagger))

	component.execute_attack(mob, tower.damage)
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 5, "Orb Barrage must launch five simultaneous orbs.")
	var launch_position: Vector2 = projectiles[0].global_position
	var distinct_destinations: Dictionary = {}
	for projectile in projectiles:
		assert(projectile.global_position.is_equal_approx(launch_position))
		distinct_destinations[Vector2(
			snappedf(projectile.impact_position.x, 0.01),
			snappedf(projectile.impact_position.y, 0.01)
		)] = true
	assert(distinct_destinations.size() == 5, "Void orbs must fan outward from one muzzle point.")

	for projectile in projectiles:
		projectile.queue_free()
	await get_tree().process_frame

	# Singularity configuration, preserved cooldown state, and both Psionic and
	# Explosive relic scaling now belong to the component.
	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.singularity_enabled)
	assert(is_equal_approx(component.singularity_cooldown, 10.0))
	assert(is_equal_approx(component.singularity_pull_duration, 1.0))
	assert(is_equal_approx(
		component.singularity_pull_radius_pixels,
		7.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	assert(is_equal_approx(
		component.singularity_explosion_radius_pixels,
		5.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	))

	component.singularity_remaining = 4.0
	fake_main.relics[&"lingering_thoughts"] = 1
	fake_main.relics[&"quick_thinking"] = 1
	fake_main.relics[&"high_yield"] = 1
	fake_main.relics[&"maximum_payload"] = 1
	tower.load_level_stats()
	var expected_duration := (
		GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER
		* GameStats.QUICK_THINKING_DURATION_MULTIPLIER
	)
	var expected_cooldown := (
		10.0
		* GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER
		* GameStats.MAXIMUM_PAYLOAD_INTERVAL_MULTIPLIER
	)
	var expected_radius := (
		5.0
		* BaseTower.RANGE_PIXELS_PER_UNIT
		* GameStats.HIGH_YIELD_RADIUS_MULTIPLIER
		* GameStats.MAXIMUM_PAYLOAD_RADIUS_MULTIPLIER
	)
	assert(is_equal_approx(component.singularity_pull_duration, expected_duration))
	assert(is_equal_approx(component.singularity_cooldown, expected_cooldown))
	assert(is_equal_approx(component.singularity_explosion_radius_pixels, expected_radius))
	assert(component.singularity_remaining <= expected_cooldown)

	component.singularity_remaining = 0.0
	component.process_attack(0.0)
	assert(component.active_singularities.size() == 1)
	var singularity := component.active_singularities[0] as VoidSingularity
	assert(singularity != null)
	assert(is_equal_approx(singularity.pull_duration, expected_duration))
	assert(is_equal_approx(singularity.explosion_radius, expected_radius))
	assert(singularity.explosion_damage == tower.damage * 3)
	assert(singularity.attack_context != null)
	assert(singularity.attack_context.attack_kind == &"void_singularity")

	component.on_round_ended()
	assert(component.active_singularities.is_empty())
	assert(is_equal_approx(component.singularity_remaining, component.singularity_cooldown))

	print("Void Caller smoke test passed: fan volley, Singularity lifecycle, cooldown preservation, and relic scaling.")
	get_tree().quit(0)
