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

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


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
	var component = tower.attack_component
	assert(component != null)
	assert(not component.kill_chain_enabled)
	assert(tower.damage == roundi(2325.0 * 2.07))
	assert(is_equal_approx(tower.loaded_attack_interval, 1.65 * 1.25))
	assert(is_equal_approx(tower.critical_multiplier, 3.0))

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.kill_chain_enabled)
	assert(not tower.has_damage_tag(&"explosive"))
	assert(is_equal_approx(component.kill_reload_remaining_multiplier, 0.50))
	assert(is_equal_approx(
		component.critical_kill_reload_remaining_multiplier, 0.10
	))

	tower.attack_on_cooldown = true
	tower.damage_timer.start(1.0)
	# Merely firing or dealing nonlethal damage never invokes the kill callback,
	# so a normal reload remains untouched.
	var unreduced_reload := tower.damage_timer.time_left
	assert(unreduced_reload > 0.95)
	component._apply_kill_chain_reload_reduction(0.50)
	assert(tower.damage_timer.time_left <= 0.50)
	assert(tower.damage_timer.time_left > 0.45)
	tower.damage_timer.start(1.0)
	component._apply_kill_chain_reload_reduction(0.10)
	assert(tower.damage_timer.time_left <= 0.10)
	assert(tower.damage_timer.time_left > 0.05)

	print("Longshot smoke test passed: Anti-Materiel stats and death-only Kill Chain reload reductions.")
	get_tree().quit(0)
