extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")
const GameStats = preload("res://stat_database.gd")


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
	tower.tower_id = &"slinger"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	var component = tower.attack_component
	assert(component != null)
	assert(tower.has_damage_tag(&"ballistic"))
	assert(not tower.has_damage_tag(&"melee"))
	assert(component.contact_explosions_enabled)
	var slinger_levels: Array = GameStats.get_tower(&"slinger")["levels"]
	var expected_ranges := [11.0, 11.5, 13.0, 13.0]
	for level_index in slinger_levels.size():
		assert(is_equal_approx(
			float(slinger_levels[level_index]["range"]),
			expected_ranges[level_index]
		))
	assert(is_equal_approx(
		component.contact_explosion_radius_pixels,
		2.5 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	tower.attack(mob)
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 1)
	assert(projectiles[0].contact_explosions_enabled)
	assert(is_equal_approx(projectiles[0].contact_explosion_damage_multiplier, 0.35))

	projectiles[0].queue_free()
	await get_tree().process_frame
	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.contact_explosions_enabled)
	assert(tower.infinite_pierce)
	tower.attack(mob)
	projectiles = get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 1)
	assert(not projectiles[0].contact_explosions_enabled)
	assert(projectiles[0].infinite_pierce)
	for projectile in projectiles:
		projectile.queue_free()
	await get_tree().process_frame

	assert(GameStats.get_tower_evolutions(&"slinger").size() == 2)
	var level_10_stats := GameStats.get_tower_xp_level_stats(&"slinger", 10)
	assert(int(level_10_stats["damage"]) == 44)
	assert(int(level_10_stats["bounce_count"]) == 1)
	_level_to_mastery(tower)
	tower.load_base_tags()
	tower.load_level_stats()
	assert(tower.infinite_pierce)
	assert(tower.pierce_loses_no_power)
	assert(is_equal_approx(tower.bounce_damage_multiplier, 0.75))

	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.contact_explosions_enabled)
	assert(is_equal_approx(
		component.contact_explosion_radius_pixels,
		3.25 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	assert(is_equal_approx(
		component.contact_explosion_damage_multiplier, 0.50
	))
	print("Slinger smoke test passed: both evolutions and Level 20 capstones.")
	get_tree().quit(0)


func _level_to_mastery(tower: BaseTower) -> void:
	var target_xp: float = tower.instance_progression.get_total_xp_required_for_level(
		GameStats.TOWER_XP_MAX_LEVEL
	)
	tower.instance_progression.grant_xp(target_xp)
