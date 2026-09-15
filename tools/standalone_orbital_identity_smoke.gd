extends Node

const GameStats = preload("res://stat_database.gd")
const SolarLanceScene = preload("res://solar_lance.tscn")
const TowerScene = preload("res://base_tower.tscn")

class FakeTarget:
	extends Node2D
	var path_follow: PathFollow2D

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
	var solar := GameStats.get_tower(&"solar_lance")
	var bombardment := GameStats.get_tower(&"bombardment")
	var atomic := GameStats.get_tower(&"atomic_strike")
	assert(float(solar["levels"][0]["range"]) == 9.0)
	assert(float(solar["levels"][3]["range"]) == 11.0)
	assert(float(solar["levels"][0]["behavior_values"]["solar_lance_duration"]) == 1.4)
	assert(float(solar["levels"][3]["behavior_values"]["solar_lance_duration"]) == 3.0)
	assert(int(bombardment["levels"][0]["behavior_values"]["bombardment_strike_count"]) == 3)
	assert(int(bombardment["levels"][3]["behavior_values"]["bombardment_strike_count"]) == 7)
	assert(float(atomic["levels"][0]["firerate"]) == 8.0)
	assert(float(atomic["levels"][3]["behavior_values"]["fallout_duration"]) == 10.0)
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var solar_tower := await _create_tower(fake_main, &"solar_lance")
	assert(not solar_tower.uses_manual_ground_targeting())
	assert(is_equal_approx(solar_tower.range_radius_pixels / BaseTower.RANGE_PIXELS_PER_UNIT, 9.0))
	assert(is_equal_approx(solar_tower.attack_component.solar_lance_duration, 1.4))
	_set_level(solar_tower, 3)
	assert(is_equal_approx(solar_tower.attack_component.solar_lance_duration, 3.0))
	var bombardment_tower := await _create_tower(fake_main, &"bombardment")
	assert(not bombardment_tower.uses_manual_ground_targeting())
	assert(bombardment_tower.attack_component.bombardment_strike_count == 3)
	_set_level(bombardment_tower, 3)
	assert(bombardment_tower.attack_component.bombardment_strike_count == 7)
	var atomic_tower := await _create_tower(fake_main, &"atomic_strike")
	assert(not atomic_tower.uses_manual_ground_targeting())
	assert(is_equal_approx(atomic_tower.attack_component.atomic_warning_duration, 1.25))
	_set_level(atomic_tower, 3)
	assert(is_equal_approx(atomic_tower.attack_component.atomic_warning_duration, 1.0))

	var lance := SolarLanceScene.instantiate()
	add_child(lance)
	var path := Path2D.new()
	path.curve = Curve2D.new()
	path.curve.add_point(Vector2.ZERO)
	path.curve.add_point(Vector2(300.0, 0.0))
	add_child(path)
	var follow := PathFollow2D.new()
	path.add_child(follow)
	follow.progress = 100.0
	var target := FakeTarget.new()
	follow.add_child(target)
	target.path_follow = follow
	lance.tracked_target = weakref(target)
	lance.tracked_path = path
	lance.path_progress = 50.0
	lance.tracking_speed = 20.0
	lance._update_route_tracking(1.0)
	assert(is_equal_approx(lance.path_progress, 70.0))
	assert(is_equal_approx(lance.global_position.x, 70.0))

	print("Standalone orbital identity smoke test passed.")
	get_tree().quit()


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
