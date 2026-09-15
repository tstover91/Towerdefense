extends Node

const TowerScene = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var shop_open := false
	var game_ended := false
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var depot := await _create_tower(fake_main, &"drone_depot")
	assert(depot.has_bonus_tag(&"reveal"))
	assert(depot.attack_component.spawned_unit_id == &"drone")
	assert(depot.attack_component.spawn_limit == 1)
	assert(is_equal_approx(depot.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 8.0))
	var drone_stats: Dictionary = depot.get_current_effective_stats()["unit_stats"]
	assert(not bool(drone_stats.get("explode_on_damage_budget", false)))
	assert(bool(drone_stats["die_on_damage_budget"]))
	assert(is_zero_approx(float(drone_stats["recharge_duration"])))
	_set_level(depot, 3)
	assert(depot.attack_component.spawn_limit == 3)
	assert(is_equal_approx(depot.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 10.0))
	drone_stats = depot.get_current_effective_stats()["unit_stats"]
	assert(int(drone_stats["damage"]) == 175)
	assert(bool(drone_stats["explode_on_damage_budget"]))
	assert(int(drone_stats["damage_budget"]) == 4200)

	var mech_bay := await _create_tower(fake_main, &"mech_bay")
	assert(mech_bay.attack_component.spawned_unit_id == &"mech")
	assert(mech_bay.attack_component.spawn_limit == 1)
	var mech_stats: Dictionary = mech_bay.get_current_effective_stats()["unit_stats"]
	assert(not bool(mech_stats.get("periodic_ground_slam", false)))
	_set_level(mech_bay, 3)
	assert(mech_bay.attack_component.spawn_limit == 1)
	mech_stats = mech_bay.get_current_effective_stats()["unit_stats"]
	assert(int(mech_stats["damage"]) == 2400)
	assert(bool(mech_stats["periodic_ground_slam"]))
	assert(is_equal_approx(float(mech_stats["knockback_distance"]), 2.0))

	var sentry_array := await _create_tower(fake_main, &"sentry_array")
	assert(sentry_array.attack_component.spawned_unit_id == &"sentry_turret")
	assert(sentry_array.attack_component.spawn_limit == 1)
	assert(not sentry_array.has_bonus_tag(&"reveal"))
	var sentry_stats: Dictionary = sentry_array.get_current_effective_stats()["unit_stats"]
	assert(is_equal_approx(float(sentry_stats["aim_radius"]), 4.5))
	_set_level(sentry_array, 1)
	assert(sentry_array.has_bonus_tag(&"reveal"))
	sentry_stats = sentry_array.get_current_effective_stats()["unit_stats"]
	assert(Array(sentry_stats["additional_bonus_tags"]).has(&"reveal"))
	_set_level(sentry_array, 3)
	assert(sentry_array.attack_component.spawn_limit == 5)
	assert(is_equal_approx(sentry_array.attack_component.deployment_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 8.0))
	sentry_stats = sentry_array.get_current_effective_stats()["unit_stats"]
	assert(int(sentry_stats["damage"]) == 90)
	assert(is_equal_approx(float(sentry_stats["aim_radius"]), 5.5))

	print("Standalone spawner identity smoke test passed.")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TowerScene.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _set_level(tower: BaseTower, level_index: int) -> void:
	tower.tower_level = level_index
	tower.load_base_tags()
	tower.load_level_stats()
