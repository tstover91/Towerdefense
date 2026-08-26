class_name TowerItemController
extends Node

const GameStats = preload("res://stat_database.gd")

signal combat_event(event_id: StringName, payload: Dictionary)

var tower: BaseTower
var runtime_state_by_slot: Dictionary = {}
var attack_sequence := 0


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower
	reset_runtime_state()


func get_slot_count() -> int:
	return GameStats.TOWER_ITEM_SLOT_COUNT


func get_equipped_item_ids() -> Array[StringName]:
	if tower.instance_progression == null:
		return []
	return tower.instance_progression.get_equipped_item_ids()


func get_first_empty_slot() -> int:
	var item_ids := get_equipped_item_ids()
	for slot_index in item_ids.size():
		if item_ids[slot_index].is_empty():
			return slot_index
	return -1


func can_equip_item(item_id: StringName, slot_index := -1) -> bool:
	if tower.instance_progression == null or not GameStats.has_tower_item(item_id):
		return false
	var resolved_slot := slot_index
	if resolved_slot < 0:
		resolved_slot = get_first_empty_slot()
	if resolved_slot < 0 or resolved_slot >= get_slot_count():
		return false
	if not get_equipped_item_ids()[resolved_slot].is_empty():
		return false
	var item := GameStats.get_tower_item(item_id)
	var maximum_copies := int(item.get("max_copies_per_tower", get_slot_count()))
	if get_equipped_item_ids().count(item_id) >= maximum_copies:
		return false
	return is_item_compatible(item_id)


func equip_item(item_id: StringName, slot_index := -1) -> bool:
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
	if tower.instance_progression == null:
		return &""
	var removed_item_id: StringName = (
		tower.instance_progression.clear_equipped_item(slot_index)
	)
	if not removed_item_id.is_empty():
		_refresh_tower_after_item_change()
	return removed_item_id


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
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var effects: Dictionary = GameStats.get_tower_item(
			item_ids[slot_index]
		).get("trigger_effects", {})
		if effects.has(effect_id):
			total += float(effects[effect_id])
			found = true
	return total if found else default_value


func notify_attack_started(_target: Node = null) -> void:
	attack_sequence += 1
	combat_event.emit(&"attack_started", {
		"tower": tower,
		"target": _target,
		"attack_sequence": attack_sequence,
	})


func get_attack_metadata() -> Dictionary:
	return {"tower_attack_sequence": attack_sequence}


func notify_damage_dealt(
	enemy: Node,
	actual_damage: int,
	attack_context: AttackContext
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
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var item_id := item_ids[slot_index]
		var effects: Dictionary = GameStats.get_tower_item(item_id).get(
			"trigger_effects", {}
		)
		if (
			float(effects.get("primary_hit_explosion_damage_multiplier", 0.0))
			> 0.0
			and not attack_context.is_secondary
		):
			_trigger_hit_explosion(
				slot_index, item_id, enemy, actual_damage, attack_context, effects
			)
		var hits_per_arc := maxi(int(effects.get("hits_per_arc", 0)), 0)
		if hits_per_arc > 0:
			var state := _get_slot_runtime_state(slot_index)
			state["hit_count"] = int(state.get("hit_count", 0)) + 1
			if int(state["hit_count"]) >= hits_per_arc:
				state["hit_count"] = 0
				_trigger_live_wire(
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
	for slot_index in get_slot_count():
		if not is_item_active_in_slot(slot_index):
			continue
		var effects: Dictionary = GameStats.get_tower_item(
			item_ids[slot_index]
		).get("trigger_effects", {})
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


func reset_runtime_state() -> void:
	runtime_state_by_slot.clear()
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
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if candidate == enemy or not tower.is_valid_target(candidate):
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


func _trigger_live_wire(
	slot_index: int,
	item_id: StringName,
	original_enemy: Node,
	actual_damage: int,
	attack_context: AttackContext,
	effects: Dictionary
) -> void:
	if not is_instance_valid(original_enemy) or not original_enemy is Node2D:
		return
	var maximum_range := maxf(
		float(effects.get("arc_range", 0.0)) * BaseTower.RANGE_PIXELS_PER_UNIT,
		0.0
	)
	var candidates: Array[Node2D] = []
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if (
			candidate == original_enemy
			or not tower.is_valid_target(candidate)
			or original_enemy.global_position.distance_to(candidate.global_position)
			> maximum_range
		):
			continue
		candidates.append(candidate)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return original_enemy.global_position.distance_squared_to(a.global_position) < original_enemy.global_position.distance_squared_to(b.global_position)
	)
	var arc_damage := maxi(roundi(
		float(actual_damage) * float(effects.get("arc_damage_multiplier", 0.0))
	), 1)
	var proc_context := _make_proc_context(
		attack_context, slot_index, item_id, &"item_live_wire"
	)
	for target_index in mini(
		candidates.size(), maxi(int(effects.get("arc_target_count", 0)), 0)
	):
		tower.apply_tower_damage(
			candidates[target_index], arc_damage, &"electric", false, proc_context
		)


func _reduce_remaining_attack_cooldown(multiplier: float) -> void:
	if tower.damage_timer.is_stopped():
		return
	var reduced_time := tower.damage_timer.time_left * clampf(multiplier, 0.0, 1.0)
	tower.damage_timer.start(maxf(reduced_time, 0.001))


func _spawn_explosion_visual(center: Vector2, radius: float) -> void:
	var current_scene := tower.get_tree().current_scene
	if current_scene != null and current_scene.has_method("spawn_explosion_visual"):
		current_scene.spawn_explosion_visual(center, radius)


func is_item_compatible(item_id: StringName) -> bool:
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
	return true


func get_incompatibility_reason(item_id: StringName) -> String:
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
	return ""


func get_compatibility_tags() -> Array[StringName]:
	var tags: Array[StringName] = [&"attack"]
	for tag_group in [tower.type_tags, tower.damage_tags, tower.bonus_tags]:
		for tag in tag_group:
			if not tags.has(tag):
				tags.append(tag)
	if (
		tower.delivery_type == GameStats.DELIVERY_PROJECTILE
		and not tower.damage_tags.has(BaseTower.DAMAGE_BEAM)
		and not tags.has(&"projectile")
	):
		tags.append(&"projectile")
	return tags


func apply_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	for item_id in get_active_item_ids():
		var item := GameStats.get_tower_item(item_id)
		_apply_stat_defaults(stats, item.get("stat_defaults", {}))
		_apply_numeric_modifiers(stats, item.get("stat_multipliers", {}), true)
		_apply_numeric_modifiers(stats, item.get("stat_additions", {}), false)
		_apply_numeric_minimums(stats, item.get("stat_minimums", {}))
		for key in item.get("stat_overrides", {}):
			stats[key] = item["stat_overrides"][key]
		if stats.has("unit_stats"):
			var unit_stats: Dictionary = stats["unit_stats"]
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


func _apply_stat_defaults(stats: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]


func apply_tag_changes() -> int:
	var pierce_addition := 0
	for item_id in get_equipped_item_ids():
		if item_id.is_empty() or not is_item_compatible(item_id):
			continue
		var item := GameStats.get_tower_item(item_id)
		for tag in item.get("add_type_tags", []):
			tower.stats_controller.add_type_tag(StringName(tag))
		for tag in item.get("add_damage_tags", []):
			tower.stats_controller.add_damage_tag(StringName(tag))
		for tag in item.get("add_bonus_tags", []):
			tower.stats_controller.add_bonus_tag(StringName(tag))
		pierce_addition += int(item.get("pierce_count_add", 0))
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
	reset_runtime_state()
	tower.load_base_tags()
	tower.load_level_stats()
	if tower.selected and tower.main != null and tower.main.has_method("show_tower_details"):
		tower.main.show_tower_details(tower)
