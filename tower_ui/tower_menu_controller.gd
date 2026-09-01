class_name TowerMenuController
extends Node

const GameStats = preload("res://stat_database.gd")
const MENU_HALF_WIDTH := 120.0
const MENU_EDGE_MARGIN := 8.0

var tower: BaseTower
var confirmation_menu: Control
var main_menu: Control
var target_menu: Control
var path_menu: Control
var upgrade_button: Button
var sell_button: Button
var target_mode_button: Button
var path_a_button: Button
var path_b_button: Button
var path_confirm_button: Button
var path_description: Label


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower
	confirmation_menu = tower.get_node("towerconfirm")
	main_menu = tower.get_node("HBoxContainer")
	target_menu = tower.get_node("targetui")
	path_menu = tower.get_node("pathui")
	upgrade_button = tower.get_node("HBoxContainer/upgradetower")
	sell_button = tower.get_node("HBoxContainer/selltower")
	target_mode_button = tower.get_node("HBoxContainer/targetmode")
	path_a_button = tower.get_node("pathui/PathA")
	path_b_button = tower.get_node("pathui/PathB")
	path_confirm_button = tower.get_node("pathui/ConfirmPath")
	path_description = tower.get_node("pathui/Description")
	update_menu_buttons()


func set_selected(value: bool) -> void:
	tower.selected = value
	if value:
		show_main_menu()
		tower.show_current_range_preview()
		if tower.main != null:
			tower.main.show_tower_details(tower)
	else:
		close_menus()


func show_main_menu() -> void:
	tower.pending_action = BaseTower.MenuAction.NONE
	tower.pending_path_choice = &""
	main_menu.visible = false
	target_menu.visible = false
	path_menu.visible = false
	update_menu_buttons()
	_show_tower_details_if_selected()


func show_target_menu() -> void:
	tower.pending_action = BaseTower.MenuAction.NONE
	tower.pending_path_choice = &""
	tower.show_current_range_preview()
	main_menu.visible = false
	target_menu.visible = false
	_configure_target_menu()
	path_menu.visible = false
	_show_tower_details_if_selected()


func show_path_menu() -> void:
	if not tower.has_path_options():
		return
	tower.pending_action = BaseTower.MenuAction.NONE
	tower.pending_path_choice = &""
	tower.show_current_range_preview()
	main_menu.visible = false
	target_menu.visible = false
	path_menu.visible = false
	update_path_menu()
	_show_tower_details_if_selected()


func close_menus() -> void:
	tower.pending_action = BaseTower.MenuAction.NONE
	tower.pending_path_choice = &""
	tower.selected = false
	main_menu.visible = false
	target_menu.visible = false
	path_menu.visible = false
	tower.set_range_preview(false)
	if tower.main != null:
		tower.main.clear_tower_details(tower)


func hide_action_menus() -> void:
	main_menu.visible = false
	target_menu.visible = false
	path_menu.visible = false


func update_menu_buttons() -> void:
	_update_upgrade_button()
	_update_sell_button()
	var shows_target_control := (
		tower.attack_component == null
		or tower.attack_component.shows_target_mode_control()
	)
	if tower.uses_standard_spawner_system() and not tower.uses_drone_targeting():
		shows_target_control = false
	target_mode_button.visible = shows_target_control
	if not shows_target_control:
		target_mode_button.text = "Target\nFirst"
		target_mode_button.disabled = true
	elif tower.uses_drone_targeting():
		target_mode_button.text = "Drones\n%s" % _get_drone_target_mode_name()
		target_mode_button.disabled = false
	elif tower.uses_manual_ground_targeting():
		target_mode_button.disabled = false
		target_mode_button.text = "Target\nGround"
	elif tower.uses_directional_aim():
		target_mode_button.disabled = false
		target_mode_button.text = "Set Aim\nDirection"
	else:
		target_mode_button.disabled = false
		target_mode_button.text = "Target\n%s" % _get_target_mode_name()


func refresh_attack_controls() -> void:
	update_menu_buttons()


func _update_sell_button() -> void:
	var sell_price := tower.get_sell_price()
	if tower.pending_action == BaseTower.MenuAction.SELL:
		sell_button.text = "Confirm\n$%s" % GameStats.format_money(sell_price)
	else:
		sell_button.text = "Sell\n$%s" % GameStats.format_money(sell_price)


func _update_upgrade_button() -> void:
	if tower.instance_progression != null:
		upgrade_button.hide()
		return
	upgrade_button.show()
	var levels: Array = GameStats.get_tower(tower.tower_id)["levels"]
	var next_level := tower.tower_level + 1
	if next_level >= levels.size():
		if tower.has_path_options() and tower.has_available_path_purchase():
			upgrade_button.text = "Final\nPaths"
			upgrade_button.disabled = false
		else:
			upgrade_button.text = "MAX LEVEL"
			upgrade_button.disabled = true
		return
	var upgrade_cost: int = levels[next_level]["upgrade_cost"]
	if tower.pending_action == BaseTower.MenuAction.UPGRADE:
		upgrade_button.text = "Confirm\n$%s" % GameStats.format_money(upgrade_cost)
	else:
		upgrade_button.text = "Upgrade\n$%s" % GameStats.format_money(upgrade_cost)
	upgrade_button.disabled = tower.main == null or tower.main.money < upgrade_cost


func update_path_menu() -> void:
	var path_ids: Array[StringName] = [&"a", &"b"]
	var buttons: Array[Button] = [path_a_button, path_b_button]
	var paths := GameStats.get_tower_paths(tower.tower_id)
	for index in path_ids.size():
		var path_id := path_ids[index]
		var button := buttons[index]
		if not paths.has(path_id):
			button.hide()
			continue
		button.show()
		var path: Dictionary = paths[path_id]
		var path_name: String = path.get(
			"display_name", "Path %s" % path_id.to_upper()
		)
		var path_cost := int(path.get("cost", 0))
		button.tooltip_text = path.get("description", "")
		if tower.purchased_paths.has(path_id):
			button.text = "%s\nOWNED" % path_name
			button.disabled = true
		elif (
			not tower.purchased_paths.is_empty()
			and not tower.can_purchase_multiple_paths()
		):
			button.text = "%s\nLOCKED" % path_name
			button.disabled = true
		else:
			button.text = "%s\n$%s" % [path_name, GameStats.format_money(path_cost)]
			button.disabled = not tower.can_purchase_path(path_id)
		button.button_pressed = tower.pending_path_choice == path_id
	path_confirm_button.disabled = tower.pending_path_choice.is_empty()
	if tower.pending_path_choice.is_empty():
		path_confirm_button.text = "Select a Path"
		path_description.text = "Select a path to view its effect."
	else:
		path_confirm_button.text = "Confirm"
		path_description.text = paths[tower.pending_path_choice].get(
			"description", ""
		)


func handle_target_mode_pressed() -> void:
	if (
		tower.attack_component != null
		and not tower.attack_component.shows_target_mode_control()
	):
		return
	if tower.uses_standard_spawner_system() and not tower.uses_drone_targeting():
		return
	if tower.uses_manual_ground_targeting() or tower.uses_directional_aim():
		tower.begin_manual_targeting()
		return
	show_target_menu()
	_show_tower_details_if_selected()


func select_target_option(mode: int) -> void:
	if tower.uses_drone_targeting():
		if tower.attack_component != null:
			tower.attack_component.set_drone_target_mode(mode)
		update_menu_buttons()
		show_main_menu()
		return
	tower.target_mode = mode
	tower._select_target()
	show_main_menu()


func update_layout() -> void:
	if (
		not confirmation_menu.visible
		and not main_menu.visible
		and not target_menu.visible
		and not path_menu.visible
	):
		return
	var viewport_size := tower.get_viewport_rect().size
	var screen_position := tower.get_global_transform_with_canvas().origin
	var menu_right_edge := viewport_size.x
	if tower.main != null and tower.main.has_method("get_playable_right_edge"):
		menu_right_edge = minf(menu_right_edge, tower.main.get_playable_right_edge())
	var menu_center_x := clampf(
		screen_position.x,
		MENU_HALF_WIDTH + MENU_EDGE_MARGIN,
		menu_right_edge - MENU_HALF_WIDTH - MENU_EDGE_MARGIN
	)
	var x_offset := menu_center_x - screen_position.x
	var place_below := screen_position.y < 240.0
	var target_y: float = (
		50.0 if place_below else -target_menu.size.y - MENU_EDGE_MARGIN
	)
	target_y = clampf(
		target_y,
		MENU_EDGE_MARGIN - screen_position.y,
		viewport_size.y - MENU_EDGE_MARGIN - target_menu.size.y - screen_position.y
	)
	confirmation_menu.position = Vector2(
		-40.0 + x_offset, 50.0 if place_below else -106.0
	)
	main_menu.position = Vector2(
		-106.0 + x_offset, 50.0 if place_below else -90.0
	)
	target_menu.position = Vector2(-60.0 + x_offset, target_y)
	var path_y: float = 50.0 if place_below else -path_menu.size.y - MENU_EDGE_MARGIN
	path_y = clampf(
		path_y,
		MENU_EDGE_MARGIN - screen_position.y,
		viewport_size.y - MENU_EDGE_MARGIN - path_menu.size.y - screen_position.y
	)
	path_menu.position = Vector2(-120.0 + x_offset, path_y)


func hide_confirmation_menu() -> void:
	confirmation_menu.visible = false


func _configure_target_menu() -> void:
	var drone_menu := tower.uses_drone_targeting()
	target_menu.get_node("button_first").text = (
		"Distributed" if drone_menu else "First"
	)
	target_menu.get_node("button_last").text = (
		"Focus: Max HP" if drone_menu else "Last"
	)
	target_menu.get_node("button_low").visible = not drone_menu
	target_menu.get_node("button_high").visible = not drone_menu


func _get_target_mode_name() -> String:
	match tower.target_mode:
		BaseTower.TargetMode.FIRST:
			return "First"
		BaseTower.TargetMode.LAST:
			return "Last"
		BaseTower.TargetMode.LOWEST_HEALTH:
			return "Lowest HP"
		BaseTower.TargetMode.HIGHEST_HEALTH:
			return "Highest HP"
	return "Unknown"


func _get_drone_target_mode_name() -> String:
	return (
		"Focus"
		if tower.get_drone_target_mode() == BaseTower.DroneTargetMode.FOCUS_MAX_HEALTH
		else "Distributed"
	)




func _show_tower_details_if_selected() -> void:
	if tower.main != null and tower.selected:
		tower.main.show_tower_details(tower)
