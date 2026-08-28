extends Node

const GameStats = preload("res://stat_database.gd")
const MOB_SCENE = preload("res://mob.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	assert_family_registration()
	assert_radiation_decay_curve()
	assert_attack_modes()
	print("Irradiator smoke test passed: family registration, Radiation ticks, decay, reapplication, debug events, and Reactor capstone data.")
	get_tree().quit()


func assert_family_registration() -> void:
	assert(GameStats.is_playable_tower_family(&"irradiator"))
	var data := GameStats.get_tower(&"irradiator")
	assert(data["damage_tags"].has(&"radiation"))
	assert(data["primary_damage_type"] == &"radiation")
	assert(GameStats.get_tower_evolutions(&"irradiator").has(&"reactor"))
	var reactor: Dictionary = data["paths"]["a"]
	assert(reactor["behavior_flags"]["irradiator_reactor"])
	assert(reactor["level_20"]["behavior_values"]["reactor_radius"] > reactor["behavior_values"]["reactor_radius"])
	assert(reactor["level_20"]["behavior_values"]["reactor_application_interval"] < reactor["behavior_values"]["reactor_application_interval"])


func assert_radiation_decay_curve() -> void:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	add_child(mob)
	mob.armor = 0.0
	var context := AttackContext.legacy(&"irradiator", &"irradiator_cone")
	var starting_health: int = mob.health
	mob.apply_radiation(8, 2, context, 1.0)
	assert(mob.health == starting_health, "Applying Radiation must deal no direct damage.")
	assert(mob.get_radiation_stacks() == 8)
	mob._process_radiation(1.0)
	assert(mob.health == starting_health - 16)
	assert(mob.get_radiation_stacks() == 7)
	mob._process_radiation(1.0)
	assert(mob.health == starting_health - 30)
	assert(mob.get_radiation_stacks() == 6)
	mob.apply_radiation(3, 2, context, 1.0)
	assert(mob.get_radiation_stacks() == 9, "Reapplication must extend the damage tail.")
	var debug_state: Dictionary = mob.get_radiation_debug_state()
	assert(debug_state["stacks"] == 9)
	var event_types: Array[StringName] = []
	for event in debug_state["events"]:
		event_types.append(StringName(event["type"]))
	assert(event_types.has(&"apply"))
	assert(event_types.has(&"tick"))
	assert(event_types.has(&"decay"))
	mob.record_radiation_spread_event({"test": true})
	mob.record_critical_mass_trigger({"test": true})
	debug_state = mob.get_radiation_debug_state()
	assert(debug_state["events"][-2]["type"] == &"spread")
	assert(debug_state["events"][-1]["type"] == &"critical_mass")


func assert_attack_modes() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var cone_tower := _create_tower(fake_main, Vector2(500.0, 500.0))
	var first := _create_mob(Vector2(550.0, 495.0))
	var second := _create_mob(Vector2(560.0, 505.0))
	cone_tower.target = first
	var first_health: int = first.health
	var second_health: int = second.health
	var cone_component := cone_tower.attack_component as IrradiatorAttackComponent
	cone_component.process_attack(0.0)
	assert(first.health == first_health and second.health == second_health)
	assert(first.get_radiation_stacks() == 1)
	assert(second.get_radiation_stacks() == 1)

	var reactor := _create_tower(fake_main, Vector2(900.0, 500.0), &"a", 3)
	var inside := _create_mob(Vector2(950.0, 500.0))
	var outside := _create_mob(Vector2(1200.0, 500.0))
	var reactor_component := reactor.attack_component as IrradiatorAttackComponent
	assert(reactor_component.reactor_enabled)
	reactor_component.process_attack(0.0)
	assert(inside.get_radiation_stacks() == 1)
	assert(outside.get_radiation_stacks() == 0)
	assert(reactor_component.total_reactor_applications >= 1)


func _create_tower(
	fake_main: Node,
	position_value: Vector2,
	path_id: StringName = &"",
	legacy_level := 0
) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"irradiator"
	tower.tower_level = legacy_level
	if not path_id.is_empty():
		tower.purchased_paths.assign([path_id])
	tower.main = fake_main
	tower.position = position_value
	add_child(tower)
	tower.confirm_placement()
	return tower


func _create_mob(position_value: Vector2) -> Node2D:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	add_child(mob)
	mob.global_position = position_value
	return mob
