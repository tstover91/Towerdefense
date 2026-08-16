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
	var relics: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


func _ready() -> void:
	call_deferred("run_test")


func add_mob(path: Path2D, progress: float) -> Node2D:
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	follow.add_child(mob)
	mob.set_path_follow(follow, progress)
	return mob


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var target_mob := add_mob(path, 500.0)
	var nearby_mob := add_mob(path, 520.0)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"beholder"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"b"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	tower.target = target_mob
	tower.mobs_in_range.assign([target_mob, nearby_mob])
	var component = tower.attack_component
	assert(component != null)
	assert(component.ramping_beam_enabled)
	assert(not component.death_explosion_enabled)

	component.process_attack(0.0)
	assert(component.beam_lock_target_id == target_mob.get_instance_id())
	var previous_damage := int(tower.get_effective_stats_for_level(2)["damage"])
	assert(component.get_continuous_beam_damage(tower.damage) == roundi(previous_damage * 0.50))
	component.process_attack(0.5)
	assert(component.get_continuous_beam_damage(tower.damage) == roundi(previous_damage * 0.75))
	component.beam_lock_elapsed = 20.0
	assert(component.get_continuous_beam_damage(tower.damage) == roundi(previous_damage * 2.50))

	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.ramping_beam_enabled)
	assert(component.death_explosion_enabled)
	assert(is_equal_approx(
		component.death_explosion_radius_pixels,
		3.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	tower.target = target_mob
	component.on_target_updated()
	assert(component.observed_target == target_mob)
	var previous_nearby_health: int = nearby_mob.health
	target_mob.mob_died.emit(target_mob)
	assert(target_mob.get_meta("beholder_death_explosion_triggered", false))
	assert(nearby_mob.health < previous_nearby_health)
	assert(component.observed_target == null)

	component.on_round_ended()
	assert(component.observed_target == null)
	print("Beholder smoke test passed: Escalating Beam ramp, target switching, Death Burst, and observer cleanup.")
	get_tree().quit(0)
