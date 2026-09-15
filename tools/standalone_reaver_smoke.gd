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
	assert(assassin_component.roaming_enabled)
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

	var champion := _create_tower(&"champion", fake_main, Vector2(300.0, 100.0))
	var champion_component := champion.attack_component as ReaverAttackComponent
	assert(champion_component.roaming_enabled)
	assert(not champion_component.enforcer_enabled)
	assert(not champion_component.champion_enabled)
	assert(not champion.has_bonus_tag(&"stun"))
	assert(champion_component.melee_arc_degrees == 120.0)
	champion.tower_level = 3
	champion.load_base_tags()
	champion.load_level_stats()
	assert(champion_component.melee_arc_degrees == 360.0)
	assert(champion_component.melee_max_targets == 8)
	var roaming_target := MOB_SCENE.instantiate()
	roaming_target.enemy_id = &"brute"
	add_child(roaming_target)
	roaming_target.global_position = Vector2(380.0, 100.0)
	champion.target = roaming_target
	champion_component.process_pre_targeting(0.25)
	assert(champion_component.roaming_offset.x > 0.0)
	assert(champion.visual_sprite.position == champion_component.roaming_offset)
	assert(champion.global_position == Vector2(300.0, 100.0))
	print("Standalone Reaver smoke test passed: Assassin and Champion roam while their bases remain fixed; Champion gains a 360-degree level-four sweep without Enforcer control.")
	get_tree().quit(0)


func _create_tower(tower_id: StringName, fake_main: Node, position: Vector2) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	tower.position = position
	add_child(tower)
	tower.confirm_placement()
	return tower
