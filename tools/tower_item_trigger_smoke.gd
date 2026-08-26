extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")

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
	assert(nearby.health == 965)
	assert(nearby.received_contexts.size() == 1)
	assert(nearby.received_contexts[0].is_item_proc())
	assert(nearby.received_contexts[0].generation == 1)
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
	assert(not wire_tower.can_equip_item(&"split_chamber"))
	assert(wire_tower.equip_item(&"live_wire"))
	var wire_primary := _create_enemy(Vector2(100.0, 0.0))
	var wire_neighbor := _create_enemy(Vector2(108.0, 0.0))
	var wire_context := AttackContext.from_tower(wire_tower)
	for _hit_index in 4:
		wire_tower.notify_damage_dealt(wire_primary, 50, wire_context)
	assert(wire_neighbor.health == 980)
	assert(wire_neighbor.received_contexts[0].attack_kind == &"item_live_wire")
	assert(
		int(wire_tower.item_controller.runtime_state_by_slot[0].get("hit_count", -1))
		== 0
	)

	wire_tower.item_controller.reset_runtime_state()
	assert(
		int(wire_tower.item_controller.runtime_state_by_slot[0].get("hit_count", 0))
		== 0
	)
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
