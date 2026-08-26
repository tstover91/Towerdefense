class_name TowerItemController
extends Node

const GameStats = preload("res://stat_database.gd")

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


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


func is_item_compatible(item_id: StringName) -> bool:
	if not GameStats.has_tower_item(item_id):
		return false
	var available_tags := get_compatibility_tags()
	var item := GameStats.get_tower_item(item_id)
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
	tower.load_base_tags()
	tower.load_level_stats()
	if tower.selected and tower.main != null and tower.main.has_method("show_tower_details"):
		tower.main.show_tower_details(tower)
