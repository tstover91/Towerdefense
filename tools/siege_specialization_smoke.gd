extends SceneTree

const BoardScript = preload("res://siege_prototype/siege_board.gd")
const CombatScript = preload("res://siege_prototype/siege_combat_controller.gd")
const StructureCatalogScript = preload("res://siege_prototype/siege_structure_catalog.gd")

var failure_count := 0


func _init() -> void:
	_run()


func _run() -> void:
	var paths: Array[StringName] = StructureCatalogScript.get_specialization_ids(&"wizard_tower")
	_assert(paths == [&"plasma_caster", &"inferno_beam"], "the Thermal Projector exposes exactly its two intended paths")
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
	harness.queue_free()
	await process_frame

	var main_scene: PackedScene = load("res://siege_prototype/siege_main.tscn")
	var main: Node = main_scene.instantiate()
	get_root().add_child(main)
	await process_frame
	main._close_wall_draft()
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
