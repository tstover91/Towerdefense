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

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


class DamageTarget:
	extends Node2D
	var traits: Array[StringName] = []
	var finished := false
	var health := 10_000
	var received_contexts: Array[AttackContext] = []

	func apply_damage_from_tower(
		attack_damage: int,
		_attack_type: StringName,
		_ignores_armor: bool,
		_source_tower_id: StringName,
		attack_context: AttackContext
	) -> int:
		health -= attack_damage
		received_contexts.append(attack_context)
		return attack_damage

	func get_projectile_hit_radius() -> float:
		return 8.0


func _ready() -> void:
	call_deferred("run_test")


func create_target(position: Vector2) -> DamageTarget:
	var target := DamageTarget.new()
	add_child(target)
	target.global_position = position
	target.add_to_group("mobs")
	return target


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"invader"
	tower.main = fake_main
	add_child(tower)
	tower.global_position = Vector2.ZERO
	assert(tower.attack_delivery_controller != null)
	assert(tower.attack_delivery_controller.tower == tower)

	var direct_context := tower.create_attack_context(&"ownership_check")
	assert(direct_context.get_root_tower() == tower)
	assert(direct_context.get_immediate_source() == tower)
	assert(direct_context.root_tower_type == &"invader")

	var primary := create_target(Vector2(100.0, 0.0))
	var bounced := create_target(Vector2(150.0, 0.0))
	var pierced := create_target(Vector2(200.0, 0.0))
	tower.range_radius_pixels = 300.0
	tower.bounce_count = 1
	tower.bounce_range_pixels = 100.0
	tower.pierce_count = 1
	tower.apply_hitscan_damage(primary, 100)
	assert(primary.health == 9_900)
	assert(bounced.health == 9_900)
	assert(pierced.health < 10_000)
	assert(primary.received_contexts[0].attack_kind == &"hitscan")
	assert(bounced.received_contexts[0].attack_kind == &"bounce")
	assert(pierced.received_contexts[0].attack_kind == &"pierce")
	for target in [primary, bounced, pierced]:
		assert(target.received_contexts[0].get_root_tower() == tower)
	assert(bounced.received_contexts[0].is_secondary)
	assert(pierced.received_contexts[0].is_secondary)

	var projectile := tower.launch_projectile_from_position(
		primary,
		tower.muzzle.global_position,
		primary.global_position,
		300.0,
		75,
		0.0
	)
	assert(projectile != null)
	assert(projectile.attack_context.get_root_tower() == tower)
	assert(projectile.attack_context.get_immediate_source() == projectile)
	assert(projectile.attack_context.immediate_source_kind == &"projectile")
	assert(tower.is_target_intersecting_line(
		primary, Vector2.ZERO, Vector2(250.0, 0.0)
	))
	assert(tower.get_targets_along_line(
		Vector2.ZERO, Vector2(250.0, 0.0)
	).size() == 3)

	print("Attack delivery smoke test passed: ownership, hitscan, bounce, pierce, projectile, and line queries.")
	get_tree().quit(0)
