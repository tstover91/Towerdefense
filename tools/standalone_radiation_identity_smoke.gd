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
	var reactor := await _create_tower(fake_main, &"reactor")
	assert(reactor.attack_component.reactor_enabled)
	assert(not reactor.attack_component.shows_target_mode_control())
	assert(is_equal_approx(reactor.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 7.0))
	assert(reactor.attack_component.stacks_per_application == 3)
	_set_level(reactor, 3)
	assert(is_equal_approx(reactor.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 9.5))
	assert(reactor.attack_component.stacks_per_application == 7)
	assert(is_equal_approx(reactor.attack_component.reactor_application_interval, 0.50))

	var isotope := await _create_tower(fake_main, &"isotope_projector")
	assert(isotope.attack_component.isotope_beam_enabled)
	assert(isotope.attack_component.shows_target_mode_control())
	assert(is_equal_approx(isotope.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 8.5))
	assert(isotope.attack_component.stacks_per_application == 4)
	_set_level(isotope, 3)
	assert(is_equal_approx(isotope.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 11.0))
	assert(isotope.attack_component.stacks_per_application == 10)
	assert(is_equal_approx(isotope.loaded_attack_interval, 0.42))

	print("Standalone Radiation identity smoke test passed.")
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
