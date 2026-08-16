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
	tower.tower_id = &"brainiac"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"b"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	# Keep the shared acquisition scheduler from launching independently; this
	# test invokes the component once so projectile geometry is deterministic.
	tower.attack_on_cooldown = true
	var component := tower.attack_component as BrainiacAttackComponent
	assert(component != null)
	assert(component.psionic_link_enabled)
	assert(not component.convergence_explosion_enabled)
	assert(is_equal_approx(component.link_duration, 2.0))
	assert(is_equal_approx(component.link_cooldown, 6.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	component.execute_attack(mob, tower.damage)

	assert(mob.brainiac_link_remaining > 0.0)
	assert(is_equal_approx(mob.brainiac_link_radius, 3.5 * BaseTower.RANGE_PIXELS_PER_UNIT))
	assert(is_equal_approx(mob.brainiac_link_damage_share, 0.35))
	assert(component.link_cooldown_remaining > 0.0)
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 5, "Level-three Brainiac must launch all five converging bolts.")
	var convergence_point: Vector2 = projectiles[0].impact_position
	var distinct_launch_positions: Dictionary = {}
	for projectile in projectiles:
		assert(projectile.impact_position.is_equal_approx(convergence_point))
		distinct_launch_positions[Vector2(
			snappedf(projectile.global_position.x, 0.01),
			snappedf(projectile.global_position.y, 0.01)
		)] = true
	assert(distinct_launch_positions.size() == 5, "Brainiac bolts must fan out at launch and converge on one point.")

	# Link cooldown must survive a stat reload and receive Psionic relic scaling
	# inside the component.
	component.link_cooldown_remaining = 4.0
	fake_main.relics[&"lingering_thoughts"] = 1
	fake_main.relics[&"quick_thinking"] = 1
	tower.load_level_stats()
	assert(is_equal_approx(
		component.link_duration,
		2.0
			* GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER
			* GameStats.QUICK_THINKING_DURATION_MULTIPLIER
	))
	assert(is_equal_approx(
		component.link_cooldown,
		6.0 * GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER
	))
	assert(component.link_cooldown_remaining <= component.link_cooldown)

	# Switching to Piercing Volley clears Link state while retaining the shared
	# converging projectile execution.
	for projectile in projectiles:
		projectile.queue_free()
	await get_tree().process_frame
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.psionic_link_enabled)
	assert(is_zero_approx(component.link_cooldown_remaining))
	assert(tower.pierce_count == 1)
	component.execute_attack(mob, tower.damage)
	projectiles = get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 5)
	for projectile in projectiles:
		assert(projectile.pierce_count == 1)

	print("Brainiac smoke test passed: converging volley, Piercing Volley, Psionic Link, cooldown state, and relic scaling.")
	get_tree().quit(0)
