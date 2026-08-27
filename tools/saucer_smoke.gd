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
	assert(GameStats.get_tower_evolutions(&"saucer").size() == 3)
	var saucer_levels: Array = GameStats.get_tower(&"saucer")["levels"]
	var expected_gun_damage := [154, 218, 336, 378]
	for level_index in saucer_levels.size():
		assert(
			int(saucer_levels[level_index]["damage"])
			== expected_gun_damage[level_index]
		)
	assert(component.twin_rockets_enabled)
	assert(is_equal_approx(component.rocket_damage_multiplier, 1.5))
	assert(component.rocket_count == 2)
	assert(is_zero_approx(component.abduction_health_threshold))
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
	var xp_before_abduction: float = tower.instance_progression.xp
	assert(component.try_abduction(abduct_target, abduct_target.global_position))
	assert(tower.instance_progression.xp > xp_before_abduction)
	assert(is_instance_valid(component.active_monster))
	assert(component.active_monster.unit_id == &"abducted_monster")
	component.on_round_ended()
	assert(component.active_monster == null)

	tower.purchased_paths.assign([&"c"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.vulnerability_field_enabled)
	assert(not component.twin_rockets_enabled)
	assert(not component.monster_drop_enabled)
	var field_target := add_mob(path, 500.0, &"bruiser")
	component.active_flyer.global_position = field_target.global_position
	component.process_attack(component.vulnerability_field_refresh_interval)
	assert(is_equal_approx(field_target.external_vulnerability_bonus, 0.15))
	var raw_damage := 100
	var field_health_before: int = field_target.health
	var support_xp_before: float = tower.instance_progression.control_credit
	field_target.apply_damage(raw_damage, &"ballistic", true, true, AttackContext.legacy(&"invader"))
	assert(field_health_before - field_target.health == 115)
	assert(tower.instance_progression.control_credit > support_xp_before)

	var level_20_xp: float = tower.instance_progression.get_total_xp_required_for_level(20)
	tower.instance_progression.grant_xp(level_20_xp)
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.rocket_count == 3)
	assert(is_equal_approx(component.rocket_interval, 2.0))
	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.maximum_monsters == 2)
	assert(is_equal_approx(component.elite_abduction_threshold, 0.25))
	component._spawn_monster(tower.global_position)
	component._spawn_monster(tower.global_position)
	assert(component.active_monsters.size() == 2)
	component.clear_monsters()
	tower.purchased_paths.assign([&"c"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(is_equal_approx(component.vulnerability_field_bonus, 0.25))
	assert(is_equal_approx(component.vulnerability_field_radius_pixels, 5.0 * BaseTower.BUILD_CELL_SIZE))
	assert(tower.damage == roundi(378.0 * GameStats.XP_MASTERY_DAMAGE_MULTIPLIER))
	print("Saucer smoke test passed: Gunship, hunting Abductor, Mothership support, abduction XP, and capstones.")
	get_tree().quit(0)
