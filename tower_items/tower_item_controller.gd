class_name TowerItemController
extends Node

const GameStats = preload("res://stat_database.gd")
const AreaDamage = preload("res://area_damage_helper.gd")

signal combat_event(event_id: StringName, payload: Dictionary)

var tower: BaseTower
var runtime_state_by_slot: Dictionary = {}
var attack_sequence := 0
var patient_hunter_charge_seconds := 0.0
var pending_patient_hunter_multiplier := 1.0


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower
	reset_runtime_state()


func get_slot_count() -> int:
	return GameStats.TOWER_ITEM_SLOT_COUNT


func get_equipped_item_ids() -> Array[StringName]:
	if tower.instance_progression == null:
		return []
	return tower.instance_progression.get_equipped_item_ids()


func get_equipped_item_counts() -> Array[int]:
	if tower.instance_progression == null:
		return []
	return tower.instance_progression.get_equipped_item_counts()


func get_equipped_item_count(slot_index: int) -> int:
	if tower.instance_progression == null:
		return 0
	return tower.instance_progression.get_equipped_item_count(slot_index)


func find_equipped_item_slot(item_id: StringName) -> int:
	return get_equipped_item_ids().find(item_id)


func get_total_equipped_item_count(item_id: StringName) -> int:
	var total := 0
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in item_ids.size():
		if item_ids[slot_index] == item_id:
			total += item_counts[slot_index]
	return total


func get_first_empty_slot() -> int:
	var item_ids := get_equipped_item_ids()
	for slot_index in item_ids.size():
		if item_ids[slot_index].is_empty():
			return slot_index
	return -1


func can_equip_item(item_id: StringName, slot_index := -1) -> bool:
	if tower.instance_progression == null or not GameStats.has_tower_item(item_id):
		return false
	var item := GameStats.get_tower_item(item_id)
	var maximum_copies := int(item.get("max_copies_per_tower", get_slot_count()))
	if get_total_equipped_item_count(item_id) >= maximum_copies:
		return false
	var existing_slot := find_equipped_item_slot(item_id)
	if existing_slot >= 0:
		return true
	var resolved_slot := slot_index
	if resolved_slot < 0:
		resolved_slot = get_first_empty_slot()
	if resolved_slot < 0 or resolved_slot >= get_slot_count():
		return false
	if not get_equipped_item_ids()[resolved_slot].is_empty():
		return false
	return true


func can_equip_or_swap_item(item_id: StringName, slot_index: int) -> bool:
	if (
		tower.instance_progression == null
		or not GameStats.has_tower_item(item_id)
		or slot_index < 0
		or slot_index >= get_slot_count()
	):
		return false
	var item := GameStats.get_tower_item(item_id)
	var maximum_copies := int(item.get("max_copies_per_tower", get_slot_count()))
	return get_total_equipped_item_count(item_id) < maximum_copies


func equip_item(item_id: StringName, slot_index := -1) -> bool:
	var existing_slot := find_equipped_item_slot(item_id)
	if existing_slot >= 0:
		if not can_equip_item(item_id, existing_slot):
			return false
		if not tower.instance_progression.add_equipped_item(
			existing_slot, item_id
		):
			return false
		_refresh_tower_after_item_change()
		return true
	var resolved_slot := slot_index
	if resolved_slot < 0:
		resolved_slot = get_first_empty_slot()
	if not can_equip_item(item_id, resolved_slot):
		return false
	if not tower.instance_progression.set_equipped_item(resolved_slot, item_id):
		return false
	_refresh_tower_after_item_change()
	return true


func unequip_item(slot_index: int) -> StringName:
	return StringName(unequip_item_stack(slot_index).get("item_id", &""))


func unequip_item_copy(slot_index: int) -> StringName:
	if tower.instance_progression == null:
		return &""
	var removed_item_id: StringName = (
		tower.instance_progression.remove_equipped_item(slot_index)
	)
	if not removed_item_id.is_empty():
		_refresh_tower_after_item_change()
	return removed_item_id


func unequip_item_stack(slot_index: int) -> Dictionary:
	if tower.instance_progression == null:
		return {}
	var removed_stack: Dictionary = (
		tower.instance_progression.clear_equipped_item_stack(slot_index)
	)
	if not removed_stack.is_empty():
		_refresh_tower_after_item_change()
	return removed_stack


func is_item_active_in_slot(slot_index: int) -> bool:
	var item_ids := get_equipped_item_ids()
	if slot_index < 0 or slot_index >= item_ids.size():
		return false
	var item_id := item_ids[slot_index]
	return not item_id.is_empty() and is_item_compatible(item_id)


func get_active_item_ids() -> Array[StringName]:
	var active_item_ids: Array[StringName] = []
	for item_id in get_equipped_item_ids():
		if not item_id.is_empty() and is_item_compatible(item_id):
			active_item_ids.append(item_id)
	return active_item_ids


func get_trigger_total(effect_id: StringName, default_value := 0.0) -> float:
	var total := 0.0
	var found := false
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var effects: Dictionary = GameStats.get_tower_item(
			item_ids[slot_index]
		).get("trigger_effects", {})
		if effects.has(effect_id):
			total += float(effects[effect_id]) * item_counts[slot_index]
			found = true
	return total if found else default_value


func get_item_effect_count(effect_id: StringName) -> int:
	var count := 0
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in item_ids.size():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(item_id).get(
			"item_effects", {}
		)
		count += (
			maxi(int(effects.get(effect_id, 0)), 0)
			* item_counts[slot_index]
		)
	return count


func notify_attack_started(_target: Node = null) -> void:
	attack_sequence += 1
	pending_patient_hunter_multiplier = 1.0
	if get_trigger_total(&"patient_hunter") > 0.0:
		pending_patient_hunter_multiplier += minf(
			patient_hunter_charge_seconds
				* GameStats.PATIENT_HUNTER_DAMAGE_PER_SECOND,
			GameStats.PATIENT_HUNTER_MAXIMUM_DAMAGE_BONUS
		)
		patient_hunter_charge_seconds = 0.0
	combat_event.emit(&"attack_started", {
		"tower": tower,
		"target": _target,
		"attack_sequence": attack_sequence,
	})


func get_attack_metadata() -> Dictionary:
	return {
		"tower_attack_sequence": attack_sequence,
		"patient_hunter_multiplier": pending_patient_hunter_multiplier,
	}


func get_pending_attack_damage_multiplier() -> float:
	return maxf(pending_patient_hunter_multiplier, 1.0)


func notify_damage_dealt(
	enemy: Node,
	actual_damage: int,
	attack_context: AttackContext,
	damage_type: StringName = &""
) -> void:
	if not _can_process_context(attack_context) or actual_damage <= 0:
		return
	combat_event.emit(&"hit", {
		"tower": tower,
		"enemy": enemy,
		"actual_damage": actual_damage,
		"context": attack_context,
	})
	if bool(attack_context.metadata.get("was_critical", false)):
		combat_event.emit(&"critical_hit", {
			"tower": tower,
			"enemy": enemy,
			"actual_damage": actual_damage,
			"context": attack_context,
		})
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(item_id).get(
			"trigger_effects", {}
		)
		if (
			damage_type != &"electric"
			and not bool(attack_context.metadata.get("radiation_tick", false))
			and int(effects.get("contributes_electric_hits", 0)) > 0
			and enemy.has_method("register_electric_hit")
		):
			enemy.register_electric_hit(actual_damage, attack_context)
		if (
			damage_type == &"electric"
			and float(effects.get("temporary_armor_reduction", 0.0)) > 0.0
			and enemy.has_method("apply_temporary_armor_reduction")
		):
			enemy.apply_temporary_armor_reduction(
				float(effects["temporary_armor_reduction"]),
				GameStats.CRIPPLING_CURRENT_DURATION
			)
		if (
			attack_context.immediate_source_kind == &"projectile"
			and int(effects.get("sticky_charge", 0)) > 0
		):
			_try_attach_sticky_charge(
				slot_index, item_id, enemy, actual_damage, attack_context
			)
		if (
			damage_type == &"explosive"
			and int(effects.get("secondary_detonation", 0)) > 0
		):
			_register_secondary_detonation(
				slot_index, item_id, actual_damage, attack_context
			)
		if (
			bool(attack_context.metadata.get("was_critical", false))
			and attack_context.immediate_source_kind == &"projectile"
			and not bool(attack_context.metadata.get("area_damage", false))
			and int(effects.get("critical_fragment_count", 0)) > 0
		):
			_launch_secondary_projectiles(
				slot_index,
				item_id,
				enemy.global_position,
				enemy,
				maxi(roundi(
					float(actual_damage)
						* GameStats.CRITICAL_FRAGMENTATION_DAMAGE_MULTIPLIER
				), 1),
				int(effects["critical_fragment_count"]),
				attack_context,
				&"critical_fragment"
			)
		if (
			float(effects.get("primary_hit_explosion_damage_multiplier", 0.0))
			> 0.0
			and not attack_context.is_secondary
		):
			for _copy_index in item_counts[slot_index]:
				_trigger_hit_explosion(
					slot_index, item_id, enemy, actual_damage, attack_context, effects
				)


func notify_enemy_killed(_enemy: Node, attack_context: AttackContext) -> void:
	if not _can_process_context(attack_context):
		return
	combat_event.emit(&"enemy_killed", {
		"tower": tower,
		"enemy": _enemy,
		"context": attack_context,
	})
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(
			item_id
		).get("trigger_effects", {})
		if (
			int(effects.get("afterimage_projectile_count", 0)) > 0
			and (
				attack_context.immediate_source_kind == &"projectile"
				or StringName(attack_context.metadata.get(
					"radiation_original_source_kind", &""
				)) == &"projectile"
			)
			and not bool(attack_context.metadata.get("area_damage", false))
		):
			var killing_damage := maxi(
				int(attack_context.metadata.get("resolved_attack_damage", tower.damage)),
				1
			)
			_launch_secondary_projectiles(
				slot_index,
				item_id,
				_enemy.global_position if is_instance_valid(_enemy) else tower.global_position,
				_enemy,
				maxi(roundi(
					float(killing_damage)
						* GameStats.AFTERIMAGE_ROUND_DAMAGE_MULTIPLIER
				), 1),
				int(effects["afterimage_projectile_count"]),
				attack_context,
				&"afterimage_round"
			)
		var normal_multiplier := float(
			effects.get("kill_cooldown_remaining_multiplier", 1.0)
		)
		if normal_multiplier >= 1.0:
			continue
		var multiplier := normal_multiplier
		if bool(attack_context.metadata.get("was_critical", false)):
			multiplier = float(effects.get(
				"critical_kill_cooldown_remaining_multiplier", multiplier
			))
		# Hitscan kills resolve before the shared scheduler starts its timer.
		# Deferring produces the same result for hitscan and traveling attacks.
		for _copy_index in item_counts[slot_index]:
			call_deferred("_reduce_remaining_attack_cooldown", multiplier)


func notify_spawned_unit_created(spawned_unit: Node) -> void:
	combat_event.emit(&"spawned_unit_created", {
		"tower": tower,
		"spawned_unit": spawned_unit,
	})


func notify_spawned_unit_removed(spawned_unit: Node, wave_cleanup := false) -> void:
	combat_event.emit(&"spawned_unit_removed", {
		"tower": tower,
		"spawned_unit": spawned_unit,
		"wave_cleanup": wave_cleanup,
	})


func notify_status_applied(
	enemy: Node,
	status_id: StringName,
	attack_context: AttackContext
) -> void:
	if not _can_process_context(attack_context):
		return
	combat_event.emit(&"status_applied", {
		"tower": tower,
		"enemy": enemy,
		"status_id": status_id,
		"context": attack_context,
	})
	if status_id != &"stun" or not is_instance_valid(enemy):
		return
	var item_ids := get_equipped_item_ids()
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(item_id).get(
			"trigger_effects", {}
		)
		if int(effects.get("aftershock", 0)) > 0:
			_schedule_aftershock(slot_index, item_id, enemy, attack_context)


func notify_projectile_terminated(
	position: Vector2,
	projectile_damage: int,
	attack_context: AttackContext
) -> void:
	if not _can_process_context(attack_context):
		return
	var item_ids := get_equipped_item_ids()
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(item_id).get(
			"trigger_effects", {}
		)
		var fragment_count := maxi(
			int(effects.get("terminal_fragment_count", 0)), 0
		)
		if fragment_count > 0:
			_launch_secondary_projectiles(
				slot_index,
				item_id,
				position,
				null,
				maxi(roundi(
					float(projectile_damage)
						* GameStats.FRACTURE_ROUNDS_FRAGMENT_DAMAGE_MULTIPLIER
				), 1),
				fragment_count,
				attack_context,
				&"fracture_round"
			)


func reset_runtime_state() -> void:
	runtime_state_by_slot.clear()
	patient_hunter_charge_seconds = 0.0
	pending_patient_hunter_multiplier = 1.0
	for slot_index in get_slot_count():
		runtime_state_by_slot[slot_index] = {}


func _can_process_context(attack_context: AttackContext) -> bool:
	return (
		attack_context != null
		and not attack_context.is_item_proc()
		and attack_context.get_root_tower() == tower
	)


func _get_slot_runtime_state(slot_index: int) -> Dictionary:
	if not runtime_state_by_slot.has(slot_index):
		runtime_state_by_slot[slot_index] = {}
	return runtime_state_by_slot[slot_index]


func _make_proc_context(
	parent_context: AttackContext,
	slot_index: int,
	item_id: StringName,
	attack_kind: StringName
) -> AttackContext:
	return parent_context.derive(
		tower,
		&"item_proc",
		attack_kind,
		true,
		{
			"item_proc": true,
			"item_proc_id": item_id,
			"item_proc_slot": slot_index,
		}
	)


func _trigger_hit_explosion(
	slot_index: int,
	item_id: StringName,
	enemy: Node,
	actual_damage: int,
	attack_context: AttackContext,
	effects: Dictionary
) -> void:
	if not is_instance_valid(enemy) or not enemy is Node2D:
		return
	var radius := maxf(
		float(effects.get("primary_hit_explosion_radius", 0.0))
		* BaseTower.RANGE_PIXELS_PER_UNIT,
		0.0
	)
	if radius <= 0.0:
		return
	var base_damage := maxi(roundi(
		float(actual_damage)
		* float(effects.get("primary_hit_explosion_damage_multiplier", 0.0))
	), 1)
	var center: Vector2 = enemy.global_position
	_spawn_explosion_visual(center, radius)
	var proc_context := _make_proc_context(
		attack_context, slot_index, item_id, &"item_hit_explosion"
	)
	for candidate in AreaDamage.get_targets_near(tower.get_tree(), center, radius):
		if not tower.is_valid_target(candidate):
			continue
		var distance := center.distance_to(candidate.global_position)
		if distance > radius:
			continue
		tower.apply_tower_damage(
			candidate,
			GameStats.get_explosion_damage(base_damage, distance, radius),
			&"explosive",
			false,
			proc_context
		)


func _launch_secondary_projectiles(
	slot_index: int,
	item_id: StringName,
	origin: Vector2,
	excluded_enemy: Node,
	projectile_damage: int,
	projectile_count: int,
	parent_context: AttackContext,
	attack_kind: StringName
) -> void:
	if tower.attack_delivery_controller == null or tower.projectile_scene == null:
		return
	var candidates: Array[Node2D] = []
	var maximum_distance := 5.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), origin, maximum_distance
	):
		if (
			candidate == excluded_enemy
			or not candidate is Node2D
			or not tower.is_valid_target(candidate)
		):
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	var launched := 0
	var proc_context := _make_proc_context(
		parent_context, slot_index, item_id, attack_kind
	)
	for candidate in candidates:
		if origin.distance_to(candidate.global_position) > maximum_distance:
			continue
		tower.attack_delivery_controller.launch_projectile_from_position(
			candidate,
			origin,
			candidate.global_position,
			maximum_distance,
			projectile_damage,
			0.0,
			proc_context
		)
		launched += 1
		if launched >= projectile_count:
			break


func _try_attach_sticky_charge(
	slot_index: int,
	item_id: StringName,
	enemy: Node,
	actual_damage: int,
	attack_context: AttackContext
) -> void:
	if not is_instance_valid(enemy) or not enemy is Node2D:
		return
	var normalized_interval := maxf(tower.get_current_attack_interval(), 0.01)
	var projectile_total := maxi(tower.projectile_count, 1)
	var proc_chance := 1.0 - pow(
		1.0 - GameStats.STICKY_CHARGE_BASE_CHANCE,
		normalized_interval / float(projectile_total)
	)
	if tower.spawn_rng.randf() > clampf(proc_chance, 0.01, 0.75):
		return
	var enemy_reference: WeakRef = weakref(enemy)
	var fallback_position: Vector2 = enemy.global_position
	var charge_damage := maxi(roundi(
		float(actual_damage) * GameStats.STICKY_CHARGE_DAMAGE_MULTIPLIER
	), 1)
	var proc_context := _make_proc_context(
		attack_context, slot_index, item_id, &"sticky_charge"
	)
	tower.get_tree().create_timer(
		GameStats.STICKY_CHARGE_DELAY, false
	).timeout.connect(func() -> void:
		if not is_instance_valid(tower) or tower.is_queued_for_deletion():
			return
		var charge_enemy: Variant = enemy_reference.get_ref()
		var center := fallback_position
		if is_instance_valid(charge_enemy) and not charge_enemy.is_queued_for_deletion():
			center = charge_enemy.global_position
		_deal_item_explosion(
			center,
			charge_damage,
			GameStats.STICKY_CHARGE_RADIUS,
			proc_context
		)
	)


func _register_secondary_detonation(
	slot_index: int,
	item_id: StringName,
	actual_damage: int,
	attack_context: AttackContext
) -> void:
	if (
		attack_context == null
		or not bool(attack_context.metadata.get("area_damage", false))
	):
		return
	var state := _get_slot_runtime_state(slot_index)
	var pending: Dictionary = state.get("secondary_detonations", {})
	var context_id := attack_context.get_instance_id()
	if pending.has(context_id):
		pending[context_id]["damage"] = maxi(
			int(pending[context_id]["damage"]), actual_damage
		)
		return
	var center: Vector2 = attack_context.metadata.get(
		"explosion_center", tower.global_position
	)
	var radius := maxf(
		float(attack_context.metadata.get("explosion_radius", 0.0)),
		BaseTower.BUILD_CELL_SIZE
	)
	pending[context_id] = {
		"damage": actual_damage,
		"center": center,
		"radius": radius,
		"context": _make_proc_context(
			attack_context, slot_index, item_id, &"secondary_detonation"
		),
	}
	state["secondary_detonations"] = pending
	tower.get_tree().create_timer(
		GameStats.SECONDARY_DETONATOR_DELAY, false
	).timeout.connect(_finish_secondary_detonation.bind(slot_index, context_id))


func _finish_secondary_detonation(slot_index: int, context_id: int) -> void:
	if not is_instance_valid(tower) or tower.is_queued_for_deletion():
		return
	var state := _get_slot_runtime_state(slot_index)
	var pending: Dictionary = state.get("secondary_detonations", {})
	if not pending.has(context_id):
		return
	var detonation: Dictionary = pending[context_id]
	pending.erase(context_id)
	_deal_item_explosion(
		detonation["center"],
		maxi(roundi(
			float(detonation["damage"])
				* GameStats.SECONDARY_DETONATOR_DAMAGE_MULTIPLIER
		), 1),
		float(detonation["radius"]),
		detonation["context"]
	)


func _schedule_aftershock(
	slot_index: int,
	item_id: StringName,
	enemy: Node,
	attack_context: AttackContext
) -> void:
	var state := _get_slot_runtime_state(slot_index)
	var tokens: Dictionary = state.get("aftershock_tokens", {})
	var enemy_id := enemy.get_instance_id()
	var token := int(tokens.get(enemy_id, 0)) + 1
	tokens[enemy_id] = token
	state["aftershock_tokens"] = tokens
	var enemy_reference: WeakRef = weakref(enemy)
	var delay := maxf(tower.stun_duration, 0.05)
	# Snapshot the proc when it is created. Mid-wave equipment changes may
	# recalculate tower.damage before the delayed blast resolves.
	var aftershock_damage := maxi(roundi(
		float(tower.damage) * GameStats.AFTERSHOCK_DAMAGE_MULTIPLIER
	), 1)
	var proc_context := _make_proc_context(
		attack_context, slot_index, item_id, &"aftershock"
	)
	tower.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if not is_instance_valid(tower) or tower.is_queued_for_deletion():
			return
		var current_tokens: Dictionary = _get_slot_runtime_state(
			slot_index
		).get("aftershock_tokens", {})
		if int(current_tokens.get(enemy_id, 0)) != token:
			return
		current_tokens.erase(enemy_id)
		var aftershock_enemy: Variant = enemy_reference.get_ref()
		if (
			not is_instance_valid(aftershock_enemy)
			or aftershock_enemy.is_queued_for_deletion()
			or bool(aftershock_enemy.get("finished"))
		):
			return
		_deal_item_explosion(
			aftershock_enemy.global_position,
			aftershock_damage,
			GameStats.AFTERSHOCK_RADIUS,
			proc_context
		)
	)


func _deal_item_explosion(
	center: Vector2,
	base_damage: int,
	radius: float,
	attack_context: AttackContext
) -> void:
	var resolved_radius := radius * tower.get_explosion_radius_multiplier()
	_spawn_explosion_visual(center, resolved_radius)
	attack_context.metadata["area_damage"] = true
	attack_context.metadata["explosion_center"] = center
	attack_context.metadata["explosion_radius"] = resolved_radius
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), center, resolved_radius
	):
		if not tower.is_valid_area_target(candidate):
			continue
		var distance := center.distance_to(candidate.global_position)
		if distance > resolved_radius:
			continue
		tower.apply_tower_damage(
			candidate,
			GameStats.get_explosion_damage(base_damage, distance, resolved_radius),
			&"explosive",
			false,
			attack_context
		)


func should_create_replication() -> bool:
	return (
		get_trigger_total(&"replication_matrix") > 0.0
		and tower.spawn_rng.randf() < GameStats.REPLICATION_MATRIX_CHANCE
	)


func modify_spawned_unit_stats(base_stats: Dictionary, is_replica := false) -> Dictionary:
	var stats := base_stats.duplicate(true)
	if get_trigger_total(&"experimental_blueprint") > 0.0:
		var roll := tower.spawn_rng.randf()
		var variant: StringName
		if roll < 0.12:
			variant = &"defective"
		elif roll < 0.296:
			variant = &"reinforced"
		elif roll < 0.472:
			variant = &"overclocked"
		elif roll < 0.648:
			variant = &"heavy"
		elif roll < 0.824:
			variant = &"mobile"
		else:
			variant = &"volatile"
		stats = apply_spawn_variant_to_stats(stats, variant, is_replica)
	elif is_replica:
		stats = apply_spawn_variant_to_stats(stats, &"", true)
	return stats


func apply_spawn_variant_to_stats(
	base_stats: Dictionary,
	variant: StringName,
	is_replica: bool
) -> Dictionary:
	var stats := base_stats.duplicate(true)
	if not variant.is_empty():
		stats["blueprint_variant"] = variant
	match variant:
		&"defective":
			_multiply_spawn_stats(stats, 0.75, 1.0, 0.75)
		&"reinforced":
			if (
				float(stats.get("damage_budget", 0.0)) <= 0.0
				and float(stats.get("lifetime", 0.0)) <= 0.0
			):
				_multiply_spawn_stats(stats, 1.20, 1.0, 1.0)
			else:
				_multiply_spawn_stats(stats, 1.0, 1.0, 1.30)
		&"overclocked":
			_multiply_spawn_stats(stats, 1.0, 0.80, 1.0)
		&"heavy":
			_multiply_spawn_stats(stats, 1.30, 1.0, 1.0)
			stats["knockback_distance"] = maxf(
				float(stats.get("knockback_distance", 0.0)), 0.5
			)
		&"mobile":
			stats["move_speed"] = float(stats.get("move_speed", 0.0)) * 1.30
			stats["aim_radius"] = float(stats.get("aim_radius", 1.0)) * 1.20
			stats["acquisition_radius"] = float(
				stats.get("acquisition_radius", stats["aim_radius"])
			) * 1.20
		&"volatile":
			_multiply_spawn_stats(stats, 1.15, 1.0, 1.0)
			stats["explode_on_damage_budget"] = true
			stats["explode_on_expiration"] = true
			stats["budget_explosion_radius"] = maxf(
				float(stats.get("budget_explosion_radius", 0.0)), 1.5
			)
			stats["budget_explosion_damage_multiplier"] = maxf(
				float(stats.get("budget_explosion_damage_multiplier", 0.0)), 1.0
			)
	if is_replica:
		_multiply_spawn_stats(
			stats,
			GameStats.REPLICATION_MATRIX_UNIT_MULTIPLIER,
			1.0,
			GameStats.REPLICATION_MATRIX_UNIT_MULTIPLIER
		)
		stats["replicated_unit"] = true
	return stats


func _multiply_spawn_stats(
	stats: Dictionary,
	damage_multiplier: float,
	interval_multiplier: float,
	budget_multiplier: float
) -> void:
	if stats.has("damage"):
		stats["damage"] = maxi(roundi(
			float(stats["damage"]) * damage_multiplier
		), 1)
	if stats.has("attack_interval"):
		stats["attack_interval"] = maxf(
			float(stats["attack_interval"]) * interval_multiplier, 0.01
		)
	for budget_key in ["damage_budget", "lifetime"]:
		if stats.has(budget_key) and float(stats[budget_key]) > 0.0:
			stats[budget_key] = float(stats[budget_key]) * budget_multiplier


func _reduce_remaining_attack_cooldown(multiplier: float) -> void:
	if tower.damage_timer.is_stopped():
		return
	var reduced_time := tower.damage_timer.time_left * clampf(multiplier, 0.0, 1.0)
	tower.damage_timer.start(maxf(reduced_time, 0.001))


func _spawn_explosion_visual(center: Vector2, radius: float) -> void:
	var current_scene := tower.get_tree().current_scene
	if current_scene != null and current_scene.has_method("spawn_explosion_visual"):
		current_scene.spawn_explosion_visual(center, radius)


func is_item_compatible(item_id: StringName, ignored_slot_index := -1) -> bool:
	if not GameStats.has_tower_item(item_id):
		return false
	var available_tags := get_compatibility_tags()
	var item := GameStats.get_tower_item(item_id)
	var allowed_tower_ids: Array = item.get("allowed_tower_ids", [])
	if not allowed_tower_ids.is_empty() and not allowed_tower_ids.has(tower.tower_id):
		return false
	for required_tag in item.get("required_all_tags", []):
		if not available_tags.has(StringName(required_tag)):
			return false
	var required_any: Array = item.get("required_any_tags", [])
	if not required_any.is_empty():
		var has_required_tag := false
		for required_tag in required_any:
			if available_tags.has(StringName(required_tag)):
				has_required_tag = true
				break
		if not has_required_tag:
			return false
	for forbidden_tag in item.get("forbidden_tags", []):
		if available_tags.has(StringName(forbidden_tag)):
			return false
	if not _get_item_conflict(item_id, ignored_slot_index).is_empty():
		return false
	return true


func get_incompatibility_reason(
	item_id: StringName,
	_ignored_slot_index := -1
) -> String:
	if not GameStats.has_tower_item(item_id):
		return "Unknown item"
	var available_tags := get_compatibility_tags()
	var item := GameStats.get_tower_item(item_id)
	var allowed_tower_ids: Array = item.get("allowed_tower_ids", [])
	if not allowed_tower_ids.is_empty() and not allowed_tower_ids.has(tower.tower_id):
		return "Requires a compatible tower family"
	var missing_tags: PackedStringArray = []
	for required_tag in item.get("required_all_tags", []):
		if not available_tags.has(StringName(required_tag)):
			missing_tags.append(String(required_tag).capitalize())
	if not missing_tags.is_empty():
		return "Requires %s" % ", ".join(missing_tags)
	var required_any: Array = item.get("required_any_tags", [])
	if not required_any.is_empty():
		var names: PackedStringArray = []
		for required_tag in required_any:
			if available_tags.has(StringName(required_tag)):
				return ""
			names.append(String(required_tag).capitalize())
		return "Requires one of: %s" % ", ".join(names)
	for forbidden_tag in item.get("forbidden_tags", []):
		if available_tags.has(StringName(forbidden_tag)):
			return "Incompatible with %s" % String(forbidden_tag).capitalize()
	var conflict_id := _get_item_conflict(item_id, _ignored_slot_index)
	if not conflict_id.is_empty():
		return "Incompatible with %s" % GameStats.get_tower_item(
			conflict_id
		).get("display_name", String(conflict_id).capitalize())
	return ""


func _get_item_conflict(
	item_id: StringName,
	ignored_slot_index := -1
) -> StringName:
	var item := GameStats.get_tower_item(item_id)
	var item_exclusions: Array = item.get("exclusive_with", [])
	var equipped_ids := get_equipped_item_ids()
	for slot_index in equipped_ids.size():
		if slot_index == ignored_slot_index:
			continue
		var equipped_id := StringName(equipped_ids[slot_index])
		if equipped_id.is_empty() or equipped_id == item_id:
			continue
		var equipped_item := GameStats.get_tower_item(equipped_id)
		if (
			item_exclusions.has(equipped_id)
			or Array(equipped_item.get("exclusive_with", [])).has(item_id)
		):
			return equipped_id
	return &""


func get_compatibility_tags() -> Array[StringName]:
	var tags: Array[StringName] = [&"attack"]
	var tower_data := GameStats.get_tower(tower.tower_id)
	var projectile_item_eligible := bool(
		tower_data.get("projectile_item_eligible", true)
	)
	for path_id in tower.purchased_paths:
		var path := GameStats.get_tower_path(tower.tower_id, path_id)
		if path.has("projectile_item_eligible"):
			projectile_item_eligible = bool(path["projectile_item_eligible"])
	for tag_group in [tower.type_tags, tower.damage_tags, tower.bonus_tags]:
		for tag in tag_group:
			if not tags.has(tag):
				tags.append(tag)
	if (
		tower.delivery_type == GameStats.DELIVERY_PROJECTILE
		and projectile_item_eligible
		and not tower.damage_tags.has(BaseTower.DAMAGE_BEAM)
		and not tags.has(&"projectile")
	):
		tags.append(&"projectile")
	if tower.bounce_count > 0 and not tags.has(&"ricochet"):
		tags.append(&"ricochet")
	return tags


func process_combat_time(delta: float) -> void:
	if (
		delta > 0.0
		and tower != null
		and tower.is_placed
		and tower.is_combat_active()
		and not tower.uses_standard_spawner_system()
		and get_trigger_total(&"patient_hunter") > 0.0
	):
		patient_hunter_charge_seconds += delta


func modify_and_share_xp(raw_xp: float) -> float:
	var safe_xp := maxf(raw_xp, 0.0)
	if safe_xp <= 0.0:
		return 0.0
	var training_bonus := get_trigger_total(&"xp_gain_bonus")
	var modified_xp := safe_xp * (1.0 + training_bonus)
	if get_trigger_total(&"mentor") <= 0.0:
		return modified_xp
	var shared_pool := modified_xp * (1.0 - GameStats.MENTOR_PERSONAL_XP_MULTIPLIER)
	var recipients: Array[BaseTower] = []
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if (
			candidate == tower
			or not candidate is BaseTower
			or not candidate.is_placed
			or candidate.instance_progression == null
			or tower.global_position.distance_to(candidate.global_position)
				> GameStats.MENTOR_SHARE_RADIUS
		):
			continue
		recipients.append(candidate)
	if not recipients.is_empty():
		var share_each := shared_pool / float(recipients.size())
		for recipient in recipients:
			recipient.instance_progression.grant_xp(share_each)
	return modified_xp * GameStats.MENTOR_PERSONAL_XP_MULTIPLIER


func apply_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	for slot_index in item_ids.size():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var item := GameStats.get_tower_item(item_id)
		for _copy_index in item_counts[slot_index]:
			_apply_stat_defaults(stats, item.get("stat_defaults", {}))
			_apply_numeric_modifiers(stats, item.get("stat_multipliers", {}), true)
			_apply_numeric_modifiers(stats, item.get("stat_additions", {}), false)
			_apply_numeric_minimums(stats, item.get("stat_minimums", {}))
			for key in item.get("stat_overrides", {}):
				stats[key] = item["stat_overrides"][key]
			if stats.has("unit_stats"):
				var unit_stats: Dictionary = stats["unit_stats"]
				_append_unique_tags(
					unit_stats, "additional_type_tags", item.get("add_type_tags", [])
				)
				_append_unique_tags(
					unit_stats, "additional_damage_tags", item.get("add_damage_tags", [])
				)
				_append_unique_tags(
					unit_stats, "additional_bonus_tags", item.get("add_bonus_tags", [])
				)
				_apply_stat_defaults(
					unit_stats, item.get("unit_stat_defaults", {})
				)
				_apply_numeric_modifiers(
					unit_stats, item.get("unit_stat_multipliers", {}), true
				)
				_apply_numeric_modifiers(
					unit_stats, item.get("unit_stat_additions", {}), false
				)
				_apply_numeric_minimums(
					unit_stats, item.get("unit_stat_minimums", {})
				)
				stats["unit_stats"] = unit_stats
	return stats


func _append_unique_tags(
	stats: Dictionary,
	key: String,
	tags: Array
) -> void:
	var combined: Array = stats.get(key, []).duplicate()
	for tag in tags:
		var resolved_tag := StringName(tag)
		if not combined.has(resolved_tag):
			combined.append(resolved_tag)
	if not combined.is_empty():
		stats[key] = combined


func _apply_stat_defaults(stats: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]


func apply_tag_changes() -> int:
	var item_ids := get_equipped_item_ids()
	var item_counts := get_equipped_item_counts()
	# Resolve tag-granting prerequisites to a fixed point. This makes linked
	# builds independent of slot order: Conductive in slot 0 remains active
	# when Live Wire in slot 3 is what grants Electric, for example.
	for _pass in item_ids.size():
		var previous_tag_count := (
			tower.type_tags.size()
			+ tower.damage_tags.size()
			+ tower.bonus_tags.size()
		)
		for slot_index in item_ids.size():
			var item_id := item_ids[slot_index]
			if item_id.is_empty() or not is_item_active_in_slot(slot_index):
				continue
			var item := GameStats.get_tower_item(item_id)
			for tag in item.get("add_type_tags", []):
				tower.stats_controller.add_type_tag(StringName(tag))
			for tag in item.get("add_damage_tags", []):
				tower.stats_controller.add_damage_tag(StringName(tag))
			for tag in item.get("add_bonus_tags", []):
				tower.stats_controller.add_bonus_tag(StringName(tag))
		var current_tag_count := (
			tower.type_tags.size()
			+ tower.damage_tags.size()
			+ tower.bonus_tags.size()
		)
		if current_tag_count == previous_tag_count:
			break
	var pierce_addition := 0
	for slot_index in item_ids.size():
		var item_id := item_ids[slot_index]
		if item_id.is_empty() or not is_item_active_in_slot(slot_index):
			continue
		pierce_addition += (
			int(GameStats.get_tower_item(item_id).get("pierce_count_add", 0))
			* item_counts[slot_index]
		)
	return pierce_addition


func _apply_numeric_modifiers(
	stats: Dictionary,
	modifiers: Dictionary,
	is_multiplier: bool
) -> void:
	for key in modifiers:
		if not stats.has(key):
			continue
		var original: Variant = stats[key]
		if original is int:
			stats[key] = (
				roundi(float(original) * float(modifiers[key]))
				if is_multiplier
				else int(original) + roundi(float(modifiers[key]))
			)
		elif original is float:
			stats[key] = (
				float(original) * float(modifiers[key])
				if is_multiplier
				else float(original) + float(modifiers[key])
			)


func _apply_numeric_minimums(stats: Dictionary, minimums: Dictionary) -> void:
	for key in minimums:
		if not stats.has(key):
			stats[key] = minimums[key]
			continue
		if stats[key] is int:
			stats[key] = maxi(int(stats[key]), roundi(float(minimums[key])))
		elif stats[key] is float:
			stats[key] = maxf(float(stats[key]), float(minimums[key]))


func _refresh_tower_after_item_change() -> void:
	# Equipment is intentionally editable during combat. Recalculate the
	# tower's tags and stats without clearing charges or delayed proc records:
	# effects already created must resolve, while new attacks immediately use
	# the newly equipped loadout. Runtime state is reset at the next round.
	tower.load_base_tags()
	tower.load_level_stats()
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if candidate != tower and is_instance_valid(candidate) and bool(candidate.get("is_placed")):
			candidate.load_level_stats()
	if tower.selected and tower.main != null and tower.main.has_method("show_tower_details"):
		tower.main.show_tower_details(tower)
