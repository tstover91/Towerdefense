extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func create_tower(tower_id: StringName, fake_main: Node) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	return tower


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var registered_ids: Array[StringName] = [
		&"fisherman",
		&"energycore",
		&"reaver",
		&"brainiac",
		&"voidcaller",
		&"longshot",
		&"gauss_repeater",
		&"beholder",
		&"orbitalcannon",
		&"saucer",
		&"slinger",
		&"irradiator",
	]
	for tower_id in registered_ids:
		var registered_tower := create_tower(tower_id, fake_main)
		assert(registered_tower.attack_component != null)
		registered_tower.queue_free()

	var gauss := create_tower(&"gauss_repeater", fake_main)
	assert(gauss.uses_directional_aim())
	assert(not gauss.uses_manual_ground_targeting())
	assert(not gauss.uses_finite_directional_range())

	var fisherman := create_tower(&"fisherman", fake_main)
	assert(not fisherman.uses_directional_aim())
	assert(not fisherman.uses_tracking_cone())
	assert(not fisherman.uses_finite_directional_range())

	var orbital := create_tower(&"orbitalcannon", fake_main)
	assert(not orbital.uses_manual_ground_targeting())
	assert(not orbital.uses_directional_aim())

	var brainiac := create_tower(&"brainiac", fake_main)
	assert(brainiac.uses_continuous_beam())
	assert(brainiac.get_continuous_beam_origin() == brainiac.global_position)

	var saucer := create_tower(&"saucer", fake_main)
	assert(not saucer.attack_component.uses_standard_targeting())
	assert(not saucer.uses_shared_attack_scheduler())
	assert(not saucer.attack_component.shows_target_mode_control())
	assert(not saucer.get_node("HBoxContainer/targetmode").visible)
	assert(saucer.damage_timer.is_stopped())

	for spawner_id in [&"hivemother", &"dronedepot", &"mechbay"]:
		var spawner := create_tower(spawner_id, fake_main)
		assert(spawner.attack_component != null)
		assert(spawner.uses_standard_spawner_system())
		assert(not spawner.uses_shared_attack_scheduler())
		assert(not spawner.uses_drone_targeting())
	var drone_depot := create_tower(&"dronedepot", fake_main)
	drone_depot.purchased_paths.assign([&"a"])
	drone_depot.load_base_tags()
	drone_depot.load_level_stats()
	assert(drone_depot.uses_drone_targeting())

	var invader := create_tower(&"invader", fake_main)
	assert(invader.attack_component == null)
	assert(not invader.uses_directional_aim())
	assert(invader.uses_shared_attack_scheduler())
	assert(not invader.uses_standard_spawner_system())

	print("Attack component capability smoke test passed: registry, targeting, scheduler, beam, and spawner routing.")
	get_tree().quit(0)
