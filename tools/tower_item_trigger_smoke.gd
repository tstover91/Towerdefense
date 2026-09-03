extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const GameStats = preload("res://stat_database.gd")

var received_combat_events: Array[StringName] = []


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass


class FakeEnemy:
	extends Node2D
	var finished := false
	var traits: Array[StringName] = []
	var health := 1000
	var received_contexts: Array[AttackContext] = []
	var temporary_armor_reduction := 0.0
	var electric_hits := 0
	var electric_damage_contributed := 0

	func apply_damage_from_tower(
		amount: int,
		_damage_type: StringName,
		_ignores_armor: bool,
		_tower_id: StringName,
		context: AttackContext
	) -> int:
		var received := mini(amount, health)
		health -= received
		received_contexts.append(context)
		var source_tower := context.get_root_tower()
		if is_instance_valid(source_tower):
			source_tower.notify_damage_dealt(self, received, context)
		return received

	func apply_temporary_armor_reduction(amount: float, _duration: float) -> void:
		temporary_armor_reduction += amount

	func register_electric_hit(
		received_damage: int,
		_attack_context: AttackContext
	) -> void:
		electric_hits += 1
		electric_damage_contributed += received_damage


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var trigger_tower := await _create_tower(fake_main, &"slinger")
	trigger_tower.item_controller.combat_event.connect(_on_combat_event)
	assert(trigger_tower.equip_item(&"kill_chain"))
	assert(trigger_tower.equip_item(&"explosive_payload"))
	assert(trigger_tower.equip_item(&"split_chamber"))
	assert(not trigger_tower.equip_item(&"split_chamber"))
	assert(trigger_tower.get_equipped_item_ids().count(&"split_chamber") == 1)
	assert(trigger_tower.item_controller.get_trigger_total(
		&"additional_projectiles"
	) == 1.0)

	trigger_tower.damage_timer.start(10.0)
	var critical_context := AttackContext.from_tower(
		trigger_tower, trigger_tower, &"tower", &"hitscan", {"was_critical": true}
	)
	trigger_tower.notify_enemy_killed(null, critical_context)
	await get_tree().process_frame
	assert(trigger_tower.damage_timer.time_left <= 4.6)

	var primary := _create_enemy(Vector2.ZERO)
	var nearby := _create_enemy(Vector2(6.0, 0.0))
	trigger_tower.notify_attack_started(primary)
	trigger_tower.notify_status_applied(primary, &"slow", critical_context)
	trigger_tower.notify_spawned_unit_created(primary)
	trigger_tower.notify_spawned_unit_removed(primary, true)
	trigger_tower.notify_damage_dealt(primary, 100, critical_context)
	var payload_effects: Dictionary = GameStats.get_tower_item(
		&"explosive_payload"
	)["trigger_effects"]
	var payload_radius := (
		float(payload_effects["primary_hit_explosion_radius"])
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	var payload_damage := GameStats.get_explosion_damage(
		roundi(100.0 * float(
			payload_effects["primary_hit_explosion_damage_multiplier"]
		)),
		primary.global_position.distance_to(nearby.global_position),
		payload_radius
	)
	var primary_payload_damage := GameStats.get_explosion_damage(
		roundi(100.0 * float(
			payload_effects["primary_hit_explosion_damage_multiplier"]
		)),
		0.0,
		payload_radius
	)
	assert(primary.health == 1000 - primary_payload_damage)
	assert(nearby.health == 1000 - payload_damage)
	assert(nearby.received_contexts.size() == 1)
	assert(nearby.received_contexts[0].is_item_proc())
	assert(nearby.received_contexts[0].generation == 1)

	var longshot := await _create_tower(fake_main, &"longshot")
	assert(longshot.delivery_type == GameStats.DELIVERY_HITSCAN)
	assert(longshot.equip_item(&"explosive_payload"))
	assert(longshot.item_controller.is_item_compatible(&"explosive_payload"))
	var longshot_primary := _create_enemy(Vector2(50.0, 100.0))
	var longshot_nearby := _create_enemy(Vector2(56.0, 100.0))
	var longshot_context := AttackContext.from_tower(
		longshot, longshot, &"tower", &"hitscan"
	)
	longshot.notify_damage_dealt(
		longshot_primary, 100, longshot_context, &"ballistic"
	)
	assert(longshot_primary.health == 1000 - primary_payload_damage)
	assert(longshot_nearby.health == 1000 - payload_damage)
	for event_id in [
		&"attack_started",
		&"status_applied",
		&"spawned_unit_created",
		&"spawned_unit_removed",
		&"hit",
		&"critical_hit",
	]:
		assert(received_combat_events.has(event_id))

	trigger_tower.attack_delivery_controller.launch_projectile(primary, 20)
	assert(get_tree().get_nodes_in_group("tower_projectiles").size() == 2)
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		projectile.queue_free()

	var wire_tower := await _create_tower(fake_main, &"invader")
	assert(wire_tower.can_equip_item(&"split_chamber"))
	assert(not wire_tower.item_controller.is_item_compatible(&"split_chamber"))
	var other_projectile_tower := await _create_tower(fake_main, &"voidcaller")
	assert(other_projectile_tower.can_equip_item(&"split_chamber"))
	assert(wire_tower.equip_item(&"live_wire"))
	var wire_primary := _create_enemy(Vector2(100.0, 0.0))
	var wire_context := AttackContext.from_tower(wire_tower)
	for _hit_index in GameStats.ELECTRIC_HITS_TO_PROC:
		wire_tower.notify_damage_dealt(wire_primary, 50, wire_context)
	assert(wire_primary.electric_hits == GameStats.ELECTRIC_HITS_TO_PROC)
	assert(
		wire_primary.electric_damage_contributed
		== 50 * GameStats.ELECTRIC_HITS_TO_PROC
	)

	var fragment_tower := await _create_tower(fake_main, &"longshot")
	fragment_tower.delivery_type = GameStats.DELIVERY_PROJECTILE
	assert(fragment_tower.equip_item(&"critical_fragmentation"))
	fragment_tower.delivery_type = GameStats.DELIVERY_PROJECTILE
	assert(fragment_tower.equip_item(&"fracture_rounds"))
	fragment_tower.delivery_type = GameStats.DELIVERY_PROJECTILE
	assert(fragment_tower.equip_item(&"afterimage_round"))
	fragment_tower.delivery_type = GameStats.DELIVERY_PROJECTILE
	var fragment_primary := _create_enemy(Vector2(200.0, 0.0))
	_create_enemy(Vector2(210.0, 0.0))
	_create_enemy(Vector2(220.0, 0.0))
	var projectile_context := AttackContext.from_tower(
		fragment_tower,
		fragment_tower,
		&"projectile",
		&"projectile",
		{"was_critical": true, "resolved_attack_damage": 100}
	)
	fragment_tower.notify_damage_dealt(
		fragment_primary, 100, projectile_context, &"ballistic"
	)
	assert(get_tree().get_nodes_in_group("tower_projectiles").size() == 2)
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		projectile.queue_free()
	await get_tree().process_frame
	fragment_tower.notify_projectile_terminated(
		fragment_primary.global_position, 100, projectile_context
	)
	assert(get_tree().get_nodes_in_group("tower_projectiles").size() == 2)
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		projectile.queue_free()
	await get_tree().process_frame
	fragment_tower.notify_enemy_killed(fragment_primary, projectile_context)
	assert(get_tree().get_nodes_in_group("tower_projectiles").size() == 1)
	for projectile in get_tree().get_nodes_in_group("tower_projectiles"):
		projectile.queue_free()

	var current_tower := await _create_tower(fake_main, &"energycore")
	assert(current_tower.equip_item(&"crippling_current"))
	var current_enemy := _create_enemy(Vector2(300.0, 0.0))
	current_tower.notify_damage_dealt(
		current_enemy,
		50,
		AttackContext.from_tower(current_tower),
		&"electric"
	)
	assert(is_equal_approx(current_enemy.temporary_armor_reduction, 2.0))

	var aftershock_tower := await _create_tower(fake_main, &"reaver")
	aftershock_tower.stats_controller.add_bonus_tag(BaseTower.BONUS_STUN)
	assert(aftershock_tower.equip_item(&"aftershock"))
	aftershock_tower.stats_controller.add_bonus_tag(BaseTower.BONUS_STUN)
	assert(aftershock_tower.item_controller.get_active_item_ids().has(&"aftershock"))
	aftershock_tower.stun_duration = 0.01
	var stunned_enemy := _create_enemy(Vector2(400.0, 0.0))
	var aftershock_neighbor := _create_enemy(Vector2(405.0, 0.0))
	aftershock_tower.notify_status_applied(
		stunned_enemy, &"stun", AttackContext.from_tower(aftershock_tower)
	)
	assert(not aftershock_tower.item_controller.runtime_state_by_slot[0].get(
		"aftershock_tokens", {}
	).is_empty())
	await get_tree().create_timer(0.08).timeout
	assert(aftershock_neighbor.health < 1000)

	var detonator_tower := await _create_tower(fake_main, &"orbitalcannon")
	assert(detonator_tower.equip_item(&"secondary_detonator"))
	var detonation_enemy := _create_enemy(Vector2(500.0, 0.0))
	var explosion_context := AttackContext.from_tower(
		detonator_tower,
		detonator_tower,
		&"projectile",
		&"explosion",
		{
			"area_damage": true,
			"explosion_center": detonation_enemy.global_position,
			"explosion_radius": 30.0,
		}
	)
	detonator_tower.notify_damage_dealt(
		detonation_enemy, 100, explosion_context, &"explosive"
	)
	await get_tree().create_timer(
		GameStats.SECONDARY_DETONATOR_DELAY + 0.05
	).timeout
	assert(detonation_enemy.health == 965)
	print("Tower item trigger smoke test passed: cooldown, explosion, multishot, live wire, runtime reset, and proc recursion guard.")
	get_tree().quit(0)


func _on_combat_event(event_id: StringName, _payload: Dictionary) -> void:
	received_combat_events.append(event_id)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _create_enemy(position: Vector2) -> FakeEnemy:
	var enemy := FakeEnemy.new()
	enemy.position = position
	add_child(enemy)
	enemy.add_to_group("mobs")
	return enemy
