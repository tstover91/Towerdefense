extends Node

const MAIN_SCENE = preload("res://main.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const GameStats = preload("res://stat_database.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud := main.get_node("MainUI/HUDRoot")
	var round_count = main.round_count_display
	assert(round_count.find_parent("TopCenterRoundPanel") != null)
	assert(main.lives_display.get_parent() == main.money_display.get_parent())
	var edge_buttons = main.pause_button.get_parent()
	assert(edge_buttons.get_child(0) == main.pause_button)
	assert(edge_buttons.get_child(1) == main.speed_button)
	assert(main.enemy_toggle_button.get_parent() == hud)
	assert(main.enemy_toggle_button.position.y > main.pause_button.position.y)
	assert(main.enemy_info_panel.get_parent() == hud)
	assert(main.sidebar.anchor_left == 0.0 and main.sidebar.anchor_bottom == 1.0)
	assert(not main.tower_fan.visible)
	assert(main.build_toggle_button.visible)
	assert(main.build_toggle_button.size == Vector2(96.0, 96.0))
	main._on_build_toggle_pressed()
	assert(main.tower_fan_open and main.tower_fan.visible)
	var outside_touch := InputEventScreenTouch.new()
	outside_touch.position = Vector2(400.0, 200.0)
	outside_touch.pressed = true
	main._unhandled_input(outside_touch)
	assert(not main.tower_fan_open and not main.tower_fan.visible)
	assert(main.inventory_button.get_parent() == main.thumb_controls)
	assert(main.inventory_button.position.x < main.reinforcement_button.position.x)
	assert(main.tower_item_inventory_panel.get_parent() == hud)
	assert(main.tower_item_slot_buttons.size() == 4)
	assert(main.tower_item_slot_bar.get_parent() == hud)
	assert(not main.tower_item_slot_bar.visible)
	assert(main.tower_items_section.get_parent() == main.tower_inspector)
	assert(main.tower_path_section.get_parent() == main.tower_inspector)
	assert(main.tower_information_content.get_parent() == main.tower_detail_popup)
	assert(not main.tower_detail_popup.visible)
	main.round_active = true
	assert(main.can_manage_tower_items(), "Items should remain manageable during waves.")
	main.run_state.add_tower_item(&"ricochet_module")
	main.run_state.add_tower_item(&"training_manual")
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = main
	main.add_child(tower)
	tower.confirm_placement()
	main.show_tower_details(tower)
	assert(main.tower_item_slot_bar.visible)
	assert(not main.tower_items_section.visible)
	assert(main.tower_upgrade_button.get_parent().visible)
	assert(main.tower_upgrade_button.disabled)
	tower.instance_progression.grant_xp(
		tower.instance_progression.get_total_xp_required_for_level(
			GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL
		)
	)
	main.add_money(100_000)
	main.show_tower_details(tower)
	assert(not main.tower_upgrade_button.disabled)
	main._on_sidebar_upgrade_pressed()
	assert(main.tower_evolution_panel_open)
	assert(main.tower_upgrade_button.text == "BACK")
	main._on_sidebar_upgrade_pressed()
	assert(not main.tower_evolution_panel_open)
	assert(main.tower_upgrade_button.text == "UPGRADE")
	main.inventory_button.button_pressed = true
	main._on_inventory_button_pressed()
	assert(main.tower_item_inventory_panel.item_buttons.size() == 2)
	main.tower_item_inventory_panel._on_item_pressed(&"ricochet_module")
	assert(main.selected_inventory_item_id == &"ricochet_module")
	assert(main.try_equip_selected_inventory_item_to_tower(tower))
	assert(tower.get_equipped_item_ids()[0] == &"ricochet_module")
	main.tower_item_inventory_panel._on_item_pressed(&"training_manual")
	main.show_tower_details(tower)
	main._on_tower_item_slot_pressed(2)
	assert(tower.get_equipped_item_ids()[2] == &"training_manual")
	main.clear_tower_details(tower)
	assert(not main.tower_item_slot_bar.visible)
	print("Minimal HUD smoke test passed: collapsible build drawer, corner status, tower controls, and inventory placement.")
	get_tree().quit()
