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
	var component := fisherman.attack_component as FishermanAttackComponent
	assert(component != null)
	assert(component.hook_target_count == 1)
	assert(not component.electric_tether_enabled)
	assert(not component.mines_enabled)

	fisherman.tower_level = 2
	fisherman.load_base_tags()
	fisherman.load_level_stats()
	assert(component.hook_target_count == 2)
	assert(not component.electric_tether_enabled)

	fisherman.tower_level = 3
	fisherman.load_base_tags()
	fisherman.load_level_stats()
	assert(component.hook_target_count == 3)
	assert(component.electric_tether_enabled)
	assert(not component.mines_enabled)
	assert(fisherman.has_damage_tag(&"electric"))
	assert(fisherman.get_primary_damage_type() == &"electric")
	print("Standalone Fisherman smoke test passed: one hook, two-hook upgrade, and final three-hook electric tether.")
	get_tree().quit(0)
