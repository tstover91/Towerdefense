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
	assert_isotope_converter()
	assert_attack_modes()
	assert_decay_suppressor()
	print("Irradiator smoke test passed: family registration, Radiation decay, Isotope Converter safety, cone/Reactor modes, and Decay Suppressor.")
	get_tree().quit()


func assert_family_registration() -> void:
	assert(GameStats.is_playable_tower_family(&"irradiator"))
	var data := GameStats.get_tower(&"irradiator")
	assert(data["damage_tags"].has(&"radiation"))
	assert(data["primary_damage_type"] == &"radiation")
	assert(GameStats.get_tower_evolutions(&"irradiator").has(&"reactor"))
	assert(GameStats.get_tower_evolutions(&"irradiator").has(&"decay_suppressor"))
	var reactor: Dictionary = data["paths"]["a"]
	assert(reactor["behavior_flags"]["irradiator_reactor"])
	assert(not reactor["behavior_values"].has("reactor_radius"))
	assert(not reactor["level_20"]["behavior_values"].has("reactor_radius"))
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
	assert(mob.get_radiation_stacks() == 16)
	mob._process_radiation(1.0)
	assert(mob.health == starting_health - 16)
	assert(mob.get_radiation_stacks() == 8)
	mob._process_radiation(1.0)
	assert(mob.health == starting_health - 24)
	assert(mob.get_radiation_stacks() == 4)
	mob.apply_radiation(3, 2, context, 1.0)
	assert(mob.get_radiation_stacks() == 10, "Reapplication must extend the damage tail.")
	assert(
		mob.radiation_stack_entries.size() == 1,
		"Repeated Radiation from one source must share one bounded entry."
	)
	var debug_state: Dictionary = mob.get_radiation_debug_state()
	assert(debug_state["stacks"] == 10)
	var event_types: Array[StringName] = []
	for event in debug_state["events"]:
		event_types.append(StringName(event["type"]))
	assert(event_types.has(&"apply"))
	assert(event_types.has(&"tick"))
	assert(event_types.has(&"decay"))

	var split_mob := MOB_SCENE.instantiate()
	split_mob.enemy_id = &"brute"
	add_child(split_mob)
	split_mob.armor = 0.0
	var first_context := AttackContext.legacy(&"irradiator")
	first_context.root_tower_instance_id = 101
	var second_context := AttackContext.legacy(&"irradiator")
	second_context.root_tower_instance_id = 202
	split_mob.apply_radiation(5, 1, first_context, 1.0)
	split_mob.apply_radiation(3, 1, second_context, 1.0)
	split_mob._process_radiation(1.0)
	var surviving_by_source := {101: 0, 202: 0}
	for entry in split_mob.radiation_stack_entries:
		var entry_context: AttackContext = entry["context"] as AttackContext
		surviving_by_source[entry_context.root_tower_instance_id] += int(entry["damage"])
	assert(surviving_by_source[101] == 2)
	assert(surviving_by_source[202] == 1)
	assert(split_mob.get_radiation_stacks() == 3)
	mob.record_radiation_spread_event({"test": true})
	mob.record_critical_mass_trigger({"test": true})
	debug_state = mob.get_radiation_debug_state()
	assert(debug_state["events"][-2]["type"] == &"spread")
	assert(debug_state["events"][-1]["type"] == &"critical_mass")


func assert_isotope_converter() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = fake_main
	add_child(tower)
	assert(tower.equip_item(&"isotope_converter"))
	assert(tower.can_equip_item(&"explosive_payload"))
	var target := _create_mob(Vector2(300.0, 300.0))
	target.armor = 0.0
	var starting_health: int = target.health
	var context := tower.create_attack_context(&"direct_hit")
	target.apply_damage_from_tower(
		40, &"ballistic", false, tower.tower_id, context
	)
	assert(target.health == starting_health - 20)
	assert(target.get_radiation_stacks() == 13)
	target._process_radiation(1.0)
	assert(target.health == starting_health - 33)
	assert(target.get_radiation_stacks() == 6)

	var proc_target := _create_mob(Vector2(340.0, 300.0))
	proc_target.armor = 0.0
	var proc_health: int = proc_target.health
	var proc_context := context.derive(
		tower, &"item_proc", &"test_item_proc", true,
		{"item_proc": true}
	)
	proc_target.apply_damage_from_tower(
		40, &"ballistic", false, tower.tower_id, proc_context
	)
	assert(proc_target.health == proc_health - 20)
	assert(proc_target.get_radiation_stacks() == 13)
	proc_target._process_radiation(1.0)
	assert(proc_target.health == proc_health - 33)

	var electric_target := _create_mob(Vector2(360.0, 300.0))
	electric_target.armor = 0.0
	var electric_context := tower.create_attack_context(&"electric_hit")
	var electric_health: int = electric_target.health
	electric_target.apply_damage_from_tower(
		40, &"electric", false, tower.tower_id, electric_context
	)
	assert(electric_target.health == electric_health - 20)
	assert(electric_target.electric_hit_count == 1)
	assert(electric_target.electric_proc_damage == 6.0)
	electric_target._process_radiation(1.0)
	assert(electric_target.electric_hit_count == 1)
	assert(electric_target.electric_proc_damage == 6.0)
	var radiation_before_lightning: int = electric_target.get_radiation_stacks()

	var lightning_context := electric_context.derive(
		electric_target, &"enemy", &"electric_lightning_proc", true,
		{"electric_proc": true}
	)
	var health_before_lightning: int = electric_target.health
	electric_target.apply_damage(
		40, &"electric", true, false, lightning_context
	)
	assert(electric_target.health == health_before_lightning - 40)
	assert(electric_target.get_radiation_stacks() == radiation_before_lightning)
	assert(electric_target.electric_hit_count == 1)

	var irradiator := _create_tower(fake_main, Vector2(400.0, 300.0))
	assert(irradiator.can_equip_item(&"isotope_converter"))
	assert(irradiator.equip_item(&"isotope_converter"))
	var native_target := _create_mob(Vector2(420.0, 300.0))
	native_target.armor = 0.0
	var native_context := irradiator.create_attack_context(&"radiation_pulse")
	native_target.apply_radiation(1, 20, native_context, 1.0)
	var native_health: int = native_target.health
	native_target._process_radiation(1.0)
	assert(native_target.health == native_health - 27)


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
	assert(first.get_radiation_stacks() == cone_tower.damage * 6)
	assert(second.get_radiation_stacks() == cone_tower.damage * 6)

	var reactor := _create_tower(fake_main, Vector2(900.0, 500.0), &"a", 3)
	var inside := _create_mob(Vector2(950.0, 500.0))
	var outside := _create_mob(Vector2(1200.0, 500.0))
	var reactor_component := reactor.attack_component as IrradiatorAttackComponent
	assert(reactor_component.reactor_enabled)
	assert(is_equal_approx(
		reactor_component.reactor_radius_pixels,
		reactor.range_radius_pixels
	))
	reactor_component.process_attack(0.0)
	assert(inside.get_radiation_stacks() == reactor.damage * 5)
	assert(outside.get_radiation_stacks() == 0)
	assert(reactor_component.total_reactor_applications >= 1)


func assert_decay_suppressor() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := _create_tower(fake_main, Vector2(500.0, 700.0), &"b", 3)
	var target := _create_mob(Vector2(550.0, 700.0))
	tower.target = target
	var component := tower.attack_component as IrradiatorAttackComponent
	assert(component.decay_suppressor_enabled)
	assert(not component.reactor_enabled)
	var outside_context := AttackContext.legacy(&"invader", &"external_radiation")
	target.apply_radiation(1, 100, outside_context, 1.0)
	var starting_health: int = target.health
	target._process_radiation(1.0)
	assert(target.health == starting_health - 100)
	assert(target.get_radiation_stacks() == 75)
	target.global_position = Vector2(900.0, 700.0)
	starting_health = target.health
	target._process_radiation(1.0)
	assert(target.health == starting_health - 75)
	assert(target.get_radiation_stacks() == 37)


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
