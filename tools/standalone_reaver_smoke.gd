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
	var assassin := _create_tower(&"assassin", fake_main, Vector2(100.0, 100.0))
	var assassin_component := assassin.attack_component as ReaverAttackComponent
	assert(assassin_component.assassinate_enabled)
	assert(not assassin_component.time_bubble_enabled)
	assassin.tower_level = 3
	assassin.load_base_tags()
	assassin.load_level_stats()
	assert(assassin_component.time_bubble_enabled)
	assert(assassin.has_bonus_tag(&"psionic"))
	var nearby_mob := MOB_SCENE.instantiate()
	nearby_mob.enemy_id = &"brute"
	add_child(nearby_mob)
	nearby_mob.global_position = Vector2(130.0, 100.0)
	assassin_component.on_round_started()
	assassin_component.process_attack(0.0)
	assert(nearby_mob.slow_remaining > 0.0)

	var enforcer := _create_tower(&"enforcer", fake_main, Vector2(300.0, 100.0))
	var enforcer_component := enforcer.attack_component as ReaverAttackComponent
	assert(enforcer_component.enforcer_enabled)
	assert(enforcer_component.champion_enabled)
	assert(enforcer_component.melee_arc_degrees == 180.0)
	print("Standalone Reaver smoke test passed: Assassin gains Time Bubble only at level four and Enforcer combines slam and spin behavior.")
	get_tree().quit(0)


func _create_tower(tower_id: StringName, fake_main: Node, position: Vector2) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	tower.position = position
	add_child(tower)
	tower.confirm_placement()
	return tower
