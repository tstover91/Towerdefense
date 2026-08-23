extends Node

const GameStats = preload("res://stat_database.gd")

const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var primary_path: Path2D
	var relics: Dictionary = {}
	var relic_lookup_calls := 0

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		relic_lookup_calls += 1
		return int(relics.get(relic_id, 0))

	func get_primary_enemy_path() -> Path2D:
		return primary_path


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var depot_levels: Array = GameStats.get_tower(&"dronedepot")["levels"]
	assert(int(depot_levels[1]["spawn_limit"]) == 2)
	assert(int(depot_levels[2]["spawn_limit"]) == 3)
	assert(depot_levels[1]["unit_stats"] == depot_levels[0]["unit_stats"])
	assert(depot_levels[2]["unit_stats"] == depot_levels[0]["unit_stats"])
	assert(float(depot_levels[1]["deployment_radius"]) == 11.0)
	assert(float(depot_levels[2]["deployment_radius"]) == 11.0)
	assert(int(depot_levels[3]["spawn_limit"]) == 3)
	assert(float(depot_levels[3]["deployment_radius"]) == 13.0)
	assert(int(depot_levels[3]["unit_stats"]["damage"]) == 150)
	assert(float(depot_levels[3]["unit_stats"]["attack_interval"]) == 0.25)
	assert(int(depot_levels[3]["unit_stats"]["damage_budget"]) == 5000)
	assert(float(depot_levels[3]["unit_stats"]["recharge_duration"]) == 2.0)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	fake_main.primary_path = path

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"dronedepot"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(400.0, 100.0)
	add_child(tower)
	tower.confirm_placement()
	assert(tower.tower_area.monitoring)
	var component = tower.attack_component
	assert(component != null)
	assert(component.spawned_unit_id == &"drone")
	assert(component.spawn_limit == 3)
	component.spawn_unit()
	assert(component.active_units.size() == 1)
	var drone = component.active_units[0]
	assert(drone.unit_id == &"drone")
	assert(drone.continuous_beam)
	assert(drone.damage_tags.has(&"beam"))

	component.clear_units()
	fake_main.relics[&"trade_agreement"] = 1
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.spawn_limit == 6)
	assert(component.spawn_batch_size == 2)
	component.spawn_unit()
	assert(component.active_units.size() == 2)
	for trade_drone in component.active_units:
		assert(trade_drone.damage == roundi(roundi(150.0 * 1.25) * 0.70))
		assert(trade_drone.target_refresh_remaining >= 0.0)
		assert(
			trade_drone.target_refresh_remaining
				< 0.15
		)
	assert(
		component.active_units[0].target_refresh_remaining
			!= component.active_units[1].target_refresh_remaining
	)

	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	follow.add_child(mob)
	mob.set_path_follow(follow, 450.0)
	tower.mobs_in_range.assign([mob])
	get_tree().set_meta(&"drone_assignment_refresh_bucket", -1)
	get_tree().set_meta(&"drone_assignment_cache", {})
	assert(component.active_units[0].select_distributed_drone_target() == mob)
	var assignment_cache: Dictionary = get_tree().get_meta(
		&"drone_assignment_cache", {}
	)
	assignment_cache[999_999] = true
	get_tree().set_meta(&"drone_assignment_cache", assignment_cache)
	assert(component.active_units[1].select_distributed_drone_target() == mob)
	assert(
		(get_tree().get_meta(&"drone_assignment_cache", {}) as Dictionary).has(
			999_999
		)
	)

	fake_main.relic_lookup_calls = 0
	var first_metadata := tower.get_attack_relic_metadata(
		tower.global_position,
		tower.range_radius_pixels,
		tower.type_tags,
		tower.damage_tags
	)
	var first_lookup_count := fake_main.relic_lookup_calls
	assert(first_lookup_count > 0)
	var second_metadata := tower.get_attack_relic_metadata(
		tower.global_position,
		tower.range_radius_pixels,
		tower.type_tags,
		tower.damage_tags
	)
	assert(fake_main.relic_lookup_calls == first_lookup_count)
	assert(not first_metadata.has("trade_agreement"))
	assert(second_metadata["enemies_in_range"] == 0)
	assert(tower.get_drone_target_mode() == BaseTower.DroneTargetMode.DISTRIBUTED)
	component.set_drone_target_mode(BaseTower.DroneTargetMode.FOCUS_MAX_HEALTH)
	assert(tower.get_drone_target_mode() == BaseTower.DroneTargetMode.FOCUS_MAX_HEALTH)
	assert(tower.get_drone_command_targets().has(mob))
	assert(tower.is_valid_drone_command_target(mob))

	component.on_round_ended()
	assert(component.active_units.is_empty())
	assert(tower.damage_timer.is_stopped())

	# Hive Mother and Mech Bay use the same reusable component rather than
	# retaining separate copies of the spawn lifecycle in BaseTower.
	for tower_id in [&"hivemother", &"mechbay"]:
		var sibling := TOWER_SCENE.instantiate() as BaseTower
		sibling.tower_id = tower_id
		sibling.main = fake_main
		add_child(sibling)
		sibling.confirm_placement()
		assert(sibling.attack_component != null)
		assert(not sibling.attack_component.spawned_unit_id.is_empty())
		assert(not sibling.tower_area.monitoring)
		assert(sibling.get_node("Tower/CollisionShape2D").disabled)
		sibling.queue_free()

	print("Spawner smoke test passed: Drone Depot commands and shared Hive/Drone/Mech spawn lifecycle.")
	get_tree().quit(0)
