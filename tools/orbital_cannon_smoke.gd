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
	var targeting_tower: Node

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func is_world_position_in_playable_area(_position: Vector2) -> bool:
		return true

	func begin_manual_tower_targeting(selected_tower: Node) -> void:
		targeting_tower = selected_tower

	func finish_manual_tower_targeting(_selected_tower: Node) -> void:
		targeting_tower = null


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
	tower.tower_id = &"orbitalcannon"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(350.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	var component = tower.attack_component
	assert(component != null)
	assert(component.solar_lance_enabled)
	assert(not component.bombardment_enabled)
	assert(is_equal_approx(component.minimum_range_pixels, 5.0 * BaseTower.RANGE_PIXELS_PER_UNIT))
	assert(not component.is_valid_manual_target_position(tower.global_position + Vector2(20.0, 0.0)))
	assert(component.is_valid_manual_target_position(mob.global_position))
	component.target_position = mob.global_position
	component.has_target_position = true
	assert(component.has_manual_attack_opportunity())
	component.execute_manual_attack()
	assert(component.active_solar_lances.size() == 1)
	var lance = component.active_solar_lances[0]
	assert(is_equal_approx(lance.duration, 1.5))
	assert(is_equal_approx(lance.tick_interval, 0.2))
	component.on_round_ended()
	assert(component.active_solar_lances.is_empty())

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.solar_lance_enabled)
	assert(component.bombardment_enabled)
	component.bombardment_stagger = 0.0
	component.bombardment_spread_radius_pixels = 0.0
	component.target_position = mob.global_position
	component.has_target_position = true
	component.execute_manual_attack()
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 5)
	for projectile in projectiles:
		assert(is_equal_approx(
			projectile.splash_radius,
			tower.splash_radius_pixels * 0.70
		))
		projectile.queue_free()
	await get_tree().process_frame

	assert(GameStats.get_tower_evolutions(&"orbitalcannon").size() == 2)
	_level_to_mastery(tower)
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.bombardment_enabled)
	assert(component.bombardment_strike_count == 7)

	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.solar_lance_enabled)
	assert(not component.bombardment_enabled)
	assert(is_equal_approx(component.solar_lance_duration, 2.0))
	assert(is_equal_approx(component.solar_lance_tick_damage_multiplier, 0.30))
	assert(is_equal_approx(component.solar_lance_tick_end_damage_multiplier, 0.65))
	print("Orbital Cannon smoke test passed: both evolutions, manual targeting, and Level 20 capstones.")
	get_tree().quit(0)


func _level_to_mastery(tower: BaseTower) -> void:
	var target_xp: float = tower.instance_progression.get_total_xp_required_for_level(
		GameStats.TOWER_XP_MAX_LEVEL
	)
	tower.instance_progression.grant_xp(target_xp)
