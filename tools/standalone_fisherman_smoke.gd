extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var fisherman := TOWER_SCENE.instantiate() as BaseTower
	fisherman.tower_id = &"fisherman"
	fisherman.main = fake_main
	add_child(fisherman)
	fisherman.confirm_placement()
	assert(fisherman.get_sell_price() == 500)
	var component := fisherman.attack_component as FishermanAttackComponent
	assert(component != null)
	assert(component.hook_target_count == 1)
	assert(not component.electric_tether_enabled)
	assert(not component.electric_pulse_enabled)
	assert(not component.mines_enabled)
	assert(not fisherman.uses_directional_aim())
	assert(not fisherman.uses_tracking_cone())
	assert(not fisherman.uses_finite_directional_range())
	assert(is_equal_approx(
		fisherman.range_radius_pixels,
		8.5 * BaseTower.RANGE_PIXELS_PER_UNIT
	))

	fisherman.tower_level = 1
	fisherman.load_base_tags()
	fisherman.load_level_stats()
	assert(fisherman.damage == 225)

	fisherman.tower_level = 2
	fisherman.load_base_tags()
	fisherman.load_level_stats()
	assert(component.hook_target_count == 2)
	assert(not component.electric_tether_enabled)
	assert(not component.electric_pulse_enabled)
	assert(fisherman.get_sell_price() == 1500)
	assert(fisherman.damage == 325)

	fisherman.tower_level = 3
	fisherman.load_base_tags()
	fisherman.load_level_stats()
	assert(component.hook_target_count == 2)
	assert(not component.electric_tether_enabled)
	assert(component.electric_pulse_enabled)
	assert(component.electric_pulse_maximum_targets == 2)
	assert(not component.mines_enabled)
	assert(fisherman.has_damage_tag(&"electric"))
	assert(fisherman.get_primary_damage_type() == &"electric")
	assert(fisherman.get_sell_price() == 3200)

	var psionic := TOWER_SCENE.instantiate() as BaseTower
	psionic.tower_id = &"psionic"
	psionic.main = fake_main
	add_child(psionic)
	psionic.confirm_placement()
	assert(psionic.get_sell_price() == 2000)
	psionic.tower_level = 1
	psionic.load_base_tags()
	psionic.load_level_stats()
	assert(psionic.get_sell_price() == 2600)
	print("Standalone Fisherman smoke test passed: radial targeting, two hooks, and final electric pulses.")
	get_tree().quit(0)
