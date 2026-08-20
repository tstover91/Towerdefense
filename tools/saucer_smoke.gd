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


func add_mob(
	path: Path2D,
	progress: float,
	enemy_id: StringName = &"brute"
) -> Node2D:
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	follow.add_child(mob)
	mob.set_path_follow(follow, progress)
	return mob


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
	var gun_target := add_mob(path, 500.0)
	var rocket_target := add_mob(path, 530.0)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"saucer"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	var component = tower.attack_component
	assert(component != null)
	var saucer_levels: Array = GameStats.get_tower(&"saucer")["levels"]
	var expected_gun_damage := [154, 218, 336, 378]
	for level_index in saucer_levels.size():
		assert(
			int(saucer_levels[level_index]["damage"])
			== expected_gun_damage[level_index]
		)
	assert(component.twin_rockets_enabled)
	assert(is_equal_approx(component.rocket_damage_multiplier, 3.571429))
	assert(not component.monster_drop_enabled)
	assert(is_instance_valid(component.active_flyer))
	assert(component.active_flyer.saucer_behavior == component)

	var previous_health: int = gun_target.health
	component.fire_weapon(tower.global_position, gun_target)
	assert(gun_target.health < previous_health)
	assert(component.fire_rockets(tower.global_position, gun_target))
	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.size() == 2)
	for projectile in projectiles:
		assert(projectile.homing_enabled)
		assert(projectile.damage_type == &"explosive")
		assert(projectile.primary_target == rocket_target)

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.twin_rockets_enabled)
	assert(component.monster_drop_enabled)
	var abduct_target := add_mob(path, 500.0, &"normal")
	abduct_target.health = maxi(roundi(float(abduct_target.max_health) * 0.20), 1)
	assert(component.can_abduct_target(abduct_target))
	assert(component.try_abduction(abduct_target, abduct_target.global_position))
	assert(is_instance_valid(component.active_monster))
	assert(component.active_monster.unit_id == &"abducted_monster")
	component.on_round_ended()
	assert(component.active_monster == null)
	print("Saucer smoke test passed: flyer ownership, Electric gun, homing rockets, abduction, and monster deployment.")
	get_tree().quit(0)
