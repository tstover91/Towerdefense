class_name TowerProgressionController
extends Node

const GameStats = preload("res://stat_database.gd")

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


func has_path_options() -> bool:
	return not GameStats.get_tower_paths(tower.tower_id).is_empty()


func get_path_unlock_level(path_id: StringName) -> int:
	var default_level: int = (
		GameStats.get_tower(tower.tower_id)["levels"].size() - 1
	)
	return int(
		GameStats.get_tower_path(tower.tower_id, path_id).get(
			"unlock_level",
			default_level
		)
	)


func can_purchase_multiple_paths() -> bool:
	return not tower.dual_path_relic_source.is_empty()


func grant_dual_path_relic(relic_id: StringName) -> void:
	if not tower.dual_path_relic_source.is_empty():
		return
	tower.dual_path_relic_source = relic_id
	tower.update_menu_buttons()
	_show_tower_details_if_selected()


func can_purchase_path(path_id: StringName, check_money := true) -> bool:
	var paths := GameStats.get_tower_paths(tower.tower_id)
	if not paths.has(path_id) or tower.purchased_paths.has(path_id):
		return false
	if tower.tower_level < get_path_unlock_level(path_id):
		return false
	if not tower.purchased_paths.is_empty() and not can_purchase_multiple_paths():
		return false
	if check_money:
		var path_cost := int(paths[path_id].get("cost", 0))
		if tower.main == null or tower.main.money < path_cost:
			return false
	return true


func has_available_path_purchase() -> bool:
	for path_key in GameStats.get_tower_paths(tower.tower_id):
		if can_purchase_path(StringName(path_key), false):
			return true
	return false


func select_path_choice(path_id: StringName) -> void:
	if not can_purchase_path(path_id):
		return
	tower.pending_path_choice = path_id
	tower.update_path_menu()
	_show_tower_details_if_selected()


func purchase_selected_path() -> void:
	if (
		tower.pending_path_choice.is_empty()
		or not can_purchase_path(tower.pending_path_choice)
	):
		return
	var path := GameStats.get_tower_path(
		tower.tower_id, tower.pending_path_choice
	)
	if not tower.main.spend_money(int(path.get("cost", 0))):
		return
	tower.purchased_paths.append(tower.pending_path_choice)
	tower.pending_path_choice = &""
	tower.load_base_tags()
	tower.load_level_stats()
	tower.update_menu_buttons()
	tower.show_main_menu()
	_show_tower_details_if_selected()


func get_path_status_text() -> String:
	if not has_path_options():
		return ""
	if tower.purchased_paths.is_empty():
		var paths := GameStats.get_tower_paths(tower.tower_id)
		var earliest_unlock := 999
		for path_key in paths:
			earliest_unlock = mini(
				earliest_unlock,
				get_path_unlock_level(StringName(path_key))
			)
		if tower.tower_level < earliest_unlock:
			return "Final paths unlock at Level %d" % (earliest_unlock + 1)
		return (
			"Both final paths available"
			if can_purchase_multiple_paths()
			else "Final path available"
		)
	var names: Array[String] = []
	for path_id in tower.purchased_paths:
		names.append(
			GameStats.get_tower_path(tower.tower_id, path_id)["display_name"]
		)
	return "Path: %s" % " + ".join(names)


func get_sell_price() -> int:
	if tower.tower_level <= 0 and tower.purchased_paths.is_empty():
		return (
			maxi(tower.purchase_price, 0)
			if tower.purchase_price >= 0
			else int(GameStats.get_tower(tower.tower_id)["placement_cost"])
		)
	var level_values: Array = GameStats.TOWER_UPGRADED_SELL_VALUES.get(
		tower.tower_id, []
	)
	if level_values.is_empty():
		return int(GameStats.get_tower(tower.tower_id)["placement_cost"])
	var level_index := mini(tower.tower_level, level_values.size() - 1)
	var sell_price := int(level_values[level_index])
	var path_sell_values: Variant = (
		GameStats.TOWER_PATH_SELL_VALUE_ADDITIONS.get(tower.tower_id, {})
	)
	for path_id in tower.purchased_paths:
		if path_sell_values is Dictionary:
			sell_price += int(path_sell_values.get(path_id, 0))
		else:
			sell_price += int(path_sell_values)
	return sell_price


func show_upgrade_range_preview() -> void:
	if tower.uses_directional_aim():
		tower.show_current_range_preview()
		return
	var levels: Array = GameStats.get_tower(tower.tower_id)["levels"]
	var next_level := tower.tower_level + 1
	if next_level >= levels.size():
		tower.show_current_range_preview()
		return
	tower.range_preview_visible = true
	tower.range_preview_valid = true
	tower.upgrade_range_radius_pixels = (
		tower.get_effective_stats_for_level(next_level)["range"]
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	tower.queue_redraw()


func handle_upgrade_pressed() -> void:
	var levels: Array = GameStats.get_tower(tower.tower_id)["levels"]
	var next_level := tower.tower_level + 1
	if next_level >= levels.size():
		if has_available_path_purchase():
			tower.show_path_menu()
		return
	if tower.pending_action != BaseTower.MenuAction.UPGRADE:
		tower.pending_action = BaseTower.MenuAction.UPGRADE
		show_upgrade_range_preview()
		tower.update_menu_buttons()
		_show_tower_details_if_selected()
		return
	var upgrade_cost: int = levels[next_level]["upgrade_cost"]
	if tower.main != null and tower.main.spend_money(upgrade_cost):
		tower.tower_level = next_level
		tower.load_base_tags()
		tower.load_level_stats()
	tower.pending_action = BaseTower.MenuAction.NONE
	tower.show_current_range_preview()
	tower.update_menu_buttons()
	_show_tower_details_if_selected()


func handle_sell_pressed() -> void:
	if tower.pending_action != BaseTower.MenuAction.SELL:
		tower.pending_action = BaseTower.MenuAction.SELL
		tower.show_current_range_preview()
		tower.update_menu_buttons()
		_show_tower_details_if_selected()
		return
	if tower.main == null:
		return
	tower.main.add_money(get_sell_price())
	tower.is_placed = false
	tower.tower_sold.emit(tower)
	tower.close_menus()
	tower.queue_free()


func _show_tower_details_if_selected() -> void:
	if tower.main != null and tower.selected:
		tower.main.show_tower_details(tower)
