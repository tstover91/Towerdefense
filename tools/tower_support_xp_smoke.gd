extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")
const XP_SERVICE = preload("res://tower_progression/tower_xp_credit_service.gd")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var controller := await _create_tower(fake_main, &"energycore")
	var other_controller := await _create_tower(fake_main, &"energycore")
	var damage_tower := await _create_tower(fake_main, &"invader")
	var enemy := await _create_enemy()
	var control_context := AttackContext.from_tower(controller)

	enemy.apply_slow(2.0, control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.104))
	enemy.apply_slow(2.0, control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.104))
	for _application in 6:
		enemy.slow_remaining = 0.0
		enemy.apply_slow(2.0, control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.26))

	var other_context := AttackContext.from_tower(other_controller)
	enemy.slow_remaining = 0.0
	enemy.apply_slow(2.0, other_context)
	assert(is_equal_approx(other_controller.instance_progression.control_credit, 0.104))

	for _application in 8:
		enemy.stun_remaining = 0.0
		enemy.stun_fatigue_tier = 0
		enemy.apply_stun(2.0, false, control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.585))

	var displacement_enemy := await _create_enemy()
	XP_SERVICE.award_control_xp(
		displacement_enemy, control_context, &"displacement", 20.0
	)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.975))
	XP_SERVICE.award_control_xp(
		displacement_enemy, control_context, &"displacement", 20.0
	)
	assert(is_equal_approx(controller.instance_progression.control_credit, 0.975))

	var hidden_enemy := await _create_enemy()
	hidden_enemy.traits.append(&"hidden")
	hidden_enemy.remove_hidden_trait(control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 1.30))
	hidden_enemy.remove_hidden_trait(control_context)
	assert(is_equal_approx(controller.instance_progression.control_credit, 1.30))

	var marked_enemy := await _create_enemy()
	marked_enemy.apply_beholder_damage_mark(5.0, 0.50, 1, control_context)
	var damage_context := AttackContext.from_tower(damage_tower)
	assert(marked_enemy.apply_damage(
		50, &"ballistic", true, true, damage_context
	) == 75)
	assert(is_equal_approx(controller.instance_progression.control_credit, 1.625))
	assert(is_equal_approx(damage_tower.instance_progression.xp, 0.975))

	var self_marked_enemy := await _create_enemy()
	self_marked_enemy.apply_beholder_damage_mark(5.0, 0.50, 1, control_context)
	self_marked_enemy.apply_damage(
		50, &"beam", true, true, control_context
	)
	assert(is_equal_approx(controller.instance_progression.control_credit, 1.625))
	assert(is_equal_approx(
		controller.instance_progression.xp,
		controller.instance_progression.control_credit + 0.975
	))

	print("Tower support XP smoke test passed: effective-duration credit, per-source caps, displacement, Reveal, ally vulnerability, self-assist prevention, and damage isolation.")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _create_enemy() -> Node:
	var enemy := MOB_SCENE.instantiate()
	add_child(enemy)
	await get_tree().process_frame
	enemy.enemy_id = &"normal"
	enemy.traits.assign([&"basic"])
	enemy.health = 100
	enemy.max_health = 100
	enemy.armor = 0.0
	enemy.finished = false
	enemy.health_bar.max_value = 100
	enemy.health_bar.value = 100
	return enemy
