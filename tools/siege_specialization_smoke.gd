extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const CombatScript = preload("res://siege_prototype/siege_combat_controller.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var expected_paths := {
		&"cannon": [&"siege_cannon", &"ricochet_cannon"],
		&"archer_tower": [&"pulse_repeater", &"pulse_sniper"],
		&"mortar": [&"scatter_bombard", &"orbital_bombard"],
		&"air_defense": [&"chain_arc", &"sky_arc"],
		&"wizard_tower": [&"plasma_caster", &"inferno_beam"],
	}
	for kind in expected_paths:
		_assert(StructureCatalogScript.get_specialization_ids(kind) == expected_paths[kind], "%s exposes exactly its two intended paths" % kind)
	var repeater := StructureCatalogScript.get_definition(&"archer_tower", 6, &"pulse_repeater")
	var sniper := StructureCatalogScript.get_definition(&"archer_tower", 6, &"pulse_sniper")
	_assert(float(repeater.get("attack_interval", 1.0)) < 0.5 and float(repeater.get("attack_range_cells", 0.0)) < float(sniper.get("attack_range_cells", 0.0)), "Pulse paths separate rapid close coverage from long-range heavy shots")
	var siege := StructureCatalogScript.get_definition(&"cannon", 6, &"siege_cannon")
	var ricochet := StructureCatalogScript.get_definition(&"cannon", 6, &"ricochet_cannon")
	_assert(float(siege.get("attack_damage", 0.0)) > float(ricochet.get("attack_damage", 0.0)) and StringName(ricochet.get("attack_mode", &"")) == &"ricochet", "Cannon paths separate heavy single hits from automatic ricochets")
	var scatter := StructureCatalogScript.get_definition(&"mortar", 3, &"scatter_bombard")
	var orbital := StructureCatalogScript.get_definition(&"mortar", 3, &"orbital_bombard")
	_assert(float(scatter.get("splash_radius_cells", 0.0)) > float(orbital.get("splash_radius_cells", 0.0)) and is_zero_approx(float(orbital.get("minimum_range_cells", -1.0))), "Bombard paths separate broad scatter coverage from autonomous map-wide strikes")
	var chain := StructureCatalogScript.get_definition(&"air_defense", 3, &"chain_arc")
	var sky := StructureCatalogScript.get_definition(&"air_defense", 3, &"sky_arc")
	_assert(StringName(chain.get("target_type", &"")) == &"ground_air" and StringName(sky.get("target_type", &"")) == &"air", "Arc paths separate flexible chains from dedicated anti-air")
	var base := StructureCatalogScript.get_definition(&"wizard_tower", 2)
	var plasma := StructureCatalogScript.get_definition(&"wizard_tower", 2, &"plasma_caster")
	var inferno := StructureCatalogScript.get_definition(&"wizard_tower", 2, &"inferno_beam")
	_assert(StringName(plasma.get("target_type", &"")) == &"ground_air" and float(plasma.get("splash_radius_cells", 0.0)) > float(base.get("splash_radius_cells", 0.0)), "Plasma Caster preserves ground-and-air splash and expands it")
	_assert(float(plasma.get("reference_dps", 0.0)) > float(base.get("reference_dps", 0.0)), "Plasma Caster strengthens the base splash output")
	_assert(StringName(inferno.get("target_type", &"")) == &"ground_air" and StringName(inferno.get("attack_mode", &"")) == &"ramping_beam", "Inferno Beam is a ground-and-air ramping weapon")
	_assert(is_zero_approx(float(inferno.get("splash_radius_cells", -1.0))) and float(inferno.get("attack_interval", 1.0)) < float(base.get("attack_interval", 0.0)), "Inferno Beam trades splash for rapid ticks")
	_assert(is_equal_approx(float(inferno.get("max_health", 0.0)), float(base.get("max_health", -1.0))), "specializing does not replace Town Hall-scaled health")

	var harness := Node.new()
	get_root().add_child(harness)
	var board: Node2D = BoardScript.new()
	board.name = "SiegeBoard"
	harness.add_child(board)
	var combat: Node2D = CombatScript.new()
	combat.name = "SiegeCombat"
	harness.add_child(combat)
	await process_frame
	combat.set_physics_process(false)
	var blueprint: Array[Dictionary] = [
		{"id": &"core", "kind": &"command_core", "level": 5, "cell": Vector2i(34, 20), "footprint": Vector2i(4, 4)},
		{"id": &"thermal", "kind": &"wizard_tower", "level": 2, "cell": Vector2i(24, 20), "footprint": Vector2i(3, 3)},
		{"id": &"cannon", "kind": &"cannon", "level": 6, "cell": Vector2i(18, 20), "footprint": Vector2i(3, 3)},
	]
	board.load_blueprint(blueprint)
	_assert(board.specialize_structure(&"thermal", &"inferno_beam"), "an unspecialized Thermal Projector accepts one valid path")
	_assert(not board.specialize_structure(&"thermal", &"plasma_caster"), "a permanent tower path cannot be replaced")
	var thermal: Node2D = board.get_structure(&"thermal")
	_assert(thermal.specialization == &"inferno_beam", "the live tower records its chosen path")
	var saved: Array[Dictionary] = board.capture_current_blueprint()
	board.load_blueprint(saved)
	thermal = board.get_structure(&"thermal")
	_assert(thermal.specialization == &"inferno_beam" and StringName(thermal.definition.get("attack_mode", &"")) == &"ramping_beam", "the chosen path survives blueprint reconstruction")
	board.apply_structure_levels({&"command_core": 6, &"wizard_tower": 3})
	thermal = board.get_structure(&"thermal")
	_assert(thermal.level == 3 and thermal.specialization == &"inferno_beam", "Town Hall scaling preserves the chosen path")
	_assert(is_equal_approx(thermal.max_health, float(StructureCatalogScript.get_definition(&"wizard_tower", 3)["max_health"])), "a specialized tower receives its new Town Hall health")

	var target: Node2D = combat._spawn_attacker(&"dragon", 20, 2)
	var hit_damage: Array[float] = []
	for _shot in 4:
		var health_before: float = target.health
		combat._apply_tower_damage(thermal, target)
		hit_damage.append(health_before - target.health)
	_assert(is_equal_approx(hit_damage[0], hit_damage[1]) and hit_damage[3] > hit_damage[2], "Inferno Beam damage rises only after sustained ticks on one target")
	combat._reset_tower_ramp(thermal.structure_id)
	var health_before_reset: float = target.health
	combat._apply_tower_damage(thermal, target)
	_assert(is_equal_approx(health_before_reset - target.health, hit_damage[0]), "Inferno Beam returns to its opening damage after losing target lock")
	_assert(board.specialize_structure(&"cannon", &"ricochet_cannon"), "the Cannon accepts its ricochet path")
	var ricochet_tower: Node2D = board.get_structure(&"cannon")
	var ricochet_primary: Node2D = combat._spawn_attacker(&"brute", 10, 4)
	var bounce_one: Node2D = combat._spawn_attacker(&"brute", 10, 4)
	var bounce_two: Node2D = combat._spawn_attacker(&"brute", 10, 4)
	var out_of_range: Node2D = combat._spawn_attacker(&"brute", 10, 4)
	ricochet_primary.grid_position = Vector2(10.0, 10.0)
	bounce_one.grid_position = Vector2(12.0, 10.0)
	bounce_two.grid_position = Vector2(14.0, 10.0)
	out_of_range.grid_position = Vector2(30.0, 30.0)
	var bounce_one_health: float = bounce_one.health
	var bounce_two_health: float = bounce_two.health
	var out_of_range_health: float = out_of_range.health
	combat._apply_tower_damage(ricochet_tower, ricochet_primary)
	_assert(bounce_one.health < bounce_one_health and bounce_two.health < bounce_two_health, "Ricochet Cannon automatically reaches two nearby follow-up targets")
	_assert(is_equal_approx(out_of_range.health, out_of_range_health), "ricochets stop outside their search radius")
	harness.queue_free()
	await process_frame

	var main_scene: PackedScene = load("res://siege_prototype/siege_main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	main._close_wall_menu()
	var main_board: Node2D = main.get_node("SiegeBoard")
	main.run_state.town_hall = 5
	main.run_state.currency = 20
	main_board.load_blueprint(blueprint)
	main_board.select_structure(main_board.get_structure(&"thermal"))
	var path_a: Button = main.get_node("HUD/SelectionPanel/Margin/Stack/Actions/PathAButton")
	var path_b: Button = main.get_node("HUD/SelectionPanel/Margin/Stack/Actions/PathBButton")
	_assert(path_a.visible and path_b.visible, "selecting an unspecialized Thermal Projector shows both concise path buttons")
	_assert(path_a.text.contains("PLASMA CASTER") and path_b.text.contains("INFERNO BEAM"), "the path buttons name their resulting roles without description text")
	main._specialize_selected(0)
	var specialized: Node2D = main_board.get_structure(&"thermal")
	_assert(main.run_state.currency == 8 and specialized.specialization == &"plasma_caster", "choosing a path spends its Gold exactly once")
	_assert(not path_a.visible and not path_b.visible, "a specialized tower no longer offers replacement paths")
	_assert(main.get_node("HUD/SelectionPanel/Margin/Stack/SelectedLabel").text.contains("PLASMA CASTER"), "the selected-tower label uses the chosen role name")
	var saved_currency: int = main.run_state.currency
	main._specialize_selected(1)
	_assert(main.run_state.currency == saved_currency and specialized.specialization == &"plasma_caster", "a second path attempt cannot spend more Gold")
	main.queue_free()
	await process_frame
	_finish("SIEGE_SPECIALIZATION_SMOKE_OK")


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Siege specialization smoke failed: %s" % description)
	failure_count += 1


func _finish(success_message: String) -> void:
	if failure_count > 0:
		quit(1)
		return
	print(success_message)
	quit(0)
