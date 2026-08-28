extends Node

const MAIN_SCENE = preload("res://main.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var hud := main.get_node("MainUI/HUDRoot")
	var round_count = main.round_count_display
	assert(round_count.get_parent().get_parent().name == "TopCenterRoundPanel")
	assert(main.lives_display.get_parent() == main.money_display.get_parent())
	var edge_buttons = main.pause_button.get_parent()
	assert(edge_buttons.get_child(0) == main.pause_button)
	assert(edge_buttons.get_child(1) == main.speed_button)
	assert(main.enemy_toggle_button.get_parent() == edge_buttons)
	assert(main.enemy_info_panel.get_parent() == hud)
	assert(main.sidebar.anchor_left == 0.0 and main.sidebar.anchor_bottom == 1.0)
	assert(main.tower_fan.visible)
	assert(not main.build_toggle_button.visible)
	assert(main.inventory_button.get_parent() == main.thumb_controls)
	assert(main.inventory_button.position.x < main.reinforcement_button.position.x)
	assert(main.tower_item_inventory_panel.get_parent() == hud)
	assert(main.tower_item_slot_buttons.size() == 4)
	assert(main.tower_items_section.get_parent() == main.tower_inspector)
	assert(main.tower_path_section.get_parent() == main.tower_inspector)
	assert(main.tower_information_content.get_parent() == main.tower_detail_popup)
	assert(not main.tower_detail_popup.visible)
	main.round_active = true
	assert(main.can_manage_tower_items(), "Items should remain manageable during waves.")
	main.run_state.add_tower_item(&"ricochet_module")
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = main
	main.add_child(tower)
	tower.confirm_placement()
	main.inventory_button.button_pressed = true
	main._on_inventory_button_pressed()
	assert(main.selected_inventory_item_id == &"ricochet_module")
	assert(main.try_equip_selected_inventory_item_to_tower(tower))
	assert(tower.get_equipped_item_ids()[0] == &"ricochet_module")
	print("Minimal HUD smoke test passed: corner status, centered round/towers, right controls, lower-left cards, four item slots, and inventory placement.")
	get_tree().quit()
