extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics: Dictionary = {}
	var path_positions: Array[Vector2] = []

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))

	func get_path_cell_positions_near(_origin: Vector2, _radius: float) -> Array:
		return path_positions.duplicate()


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"longshot"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(300.0, 300.0)
	add_child(tower)
	tower.confirm_placement()
	tower.attack_on_cooldown = true
	var component = tower.attack_component
	assert(component != null)
	assert(component.distance_damage_enabled)
	assert(not component.mines_enabled)

	var target := Node2D.new()
	add_child(target)
	target.global_position = tower.global_position
	assert(component.modify_base_attack_damage(target, tower.damage) == roundi(tower.damage * 0.75))
	target.global_position = tower.global_position + Vector2(tower.range_radius_pixels * 0.5, 0.0)
	assert(component.modify_base_attack_damage(target, tower.damage) == tower.damage)
	target.global_position = tower.global_position + Vector2(tower.range_radius_pixels, 0.0)
	assert(component.modify_base_attack_damage(target, tower.damage) == roundi(tower.damage * 2.25))

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(not component.distance_damage_enabled)
	assert(component.mines_enabled)
	assert(is_equal_approx(component.mine_interval, 6.0))
	assert(component.mine_maximum_count == 3)
	component.mine_remaining = 4.0
	tower.load_level_stats()
	assert(is_equal_approx(component.mine_remaining, 4.0))

	fake_main.path_positions.assign([
		tower.global_position + Vector2(20.0, 0.0),
		tower.global_position + Vector2(40.0, 0.0),
	])
	component.mine_remaining = 0.0
	component.process_attack(0.0)
	assert(component.active_mines.size() == 1)
	var mine = component.active_mines[0]
	assert(mine.damage == roundi(tower.damage * 1.25))
	assert(is_equal_approx(mine.trigger_radius, BaseTower.RANGE_PIXELS_PER_UNIT))
	assert(is_equal_approx(mine.explosion_radius, 2.5 * BaseTower.RANGE_PIXELS_PER_UNIT))
	assert(mine.attack_context != null)
	assert(mine.attack_context.attack_kind == &"mine_explosion")

	component.on_round_ended()
	assert(component.active_mines.is_empty())
	assert(is_equal_approx(component.mine_remaining, component.mine_interval))
	print("Longshot smoke test passed: distance curve, Minefield placement, cooldown preservation, and cleanup.")
	get_tree().quit(0)
