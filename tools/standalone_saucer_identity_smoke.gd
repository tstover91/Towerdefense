extends Node

const GameStats = preload("res://stat_database.gd")
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
	var gunship := await _create_tower(fake_main, &"gunship")
	assert(not gunship.has_bonus_tag(&"reveal"))
	assert(is_equal_approx(gunship.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 9.0))
	assert(gunship.attack_component.twin_rockets_enabled)
	assert(gunship.attack_component.rocket_count == 1)
	assert(is_equal_approx(gunship.attack_component.rocket_interval, 4.0))
	_set_level(gunship, 3)
	assert(gunship.damage == 450)
	assert(is_equal_approx(gunship.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 11.0))
	assert(gunship.attack_component.rocket_count == 4)
	assert(is_equal_approx(gunship.attack_component.rocket_interval, 2.8))

	var mothership := await _create_tower(fake_main, &"mothership")
	assert(mothership.has_bonus_tag(&"reveal"))
	assert(is_equal_approx(mothership.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 9.0))
	assert(mothership.attack_component.vulnerability_field_enabled)
	assert(is_equal_approx(mothership.attack_component.vulnerability_field_bonus, 0.08))
	assert(is_equal_approx(mothership.attack_component.vulnerability_field_radius_pixels / BaseTower.BUILD_CELL_SIZE, 2.5))
	_set_level(mothership, 3)
	# The Mothership's inherent support tradeoff applies its 0.8 damage
	# multiplier after the level value is loaded.
	assert(mothership.damage == 340)
	assert(is_equal_approx(mothership.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 11.0))
	assert(is_equal_approx(mothership.attack_component.vulnerability_field_bonus, 0.25))
	assert(is_equal_approx(mothership.attack_component.vulnerability_field_radius_pixels / BaseTower.BUILD_CELL_SIZE, 5.0))

	print("Standalone Saucer identity smoke test passed.")
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
