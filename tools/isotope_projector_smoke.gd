extends Node

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

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"isotope_projector"
	tower.main = fake_main
	tower.position = Vector2(100.0, 100.0)
	add_child(tower)
	tower.confirm_placement()

	var target := _create_mob(Vector2(300.0, 100.0))
	var between := _create_mob(Vector2(200.0, 104.0))
	var outside := _create_mob(Vector2(200.0, 150.0))
	tower.target = target
	var component := tower.attack_component as IrradiatorAttackComponent
	assert(component != null)
	assert(component.isotope_beam_enabled)
	component.process_attack(0.0)
	assert(target.get_radiation_stacks() > 0)
	assert(between.get_radiation_stacks() > 0)
	assert(outside.get_radiation_stacks() == 0)
	assert(component.get_radiation_debug_state()["mode"] == &"isotope_beam")
	print("Isotope Projector smoke test passed: locked beam irradiates its target and intervening enemies without area spill.")
	get_tree().quit(0)


func _create_mob(position: Vector2) -> Node2D:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	add_child(mob)
	mob.global_position = position
	return mob
