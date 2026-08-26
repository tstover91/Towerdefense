extends Node

const MAIN_SCENE = preload("res://main.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const RoundControllerScript = preload("res://round_controller.gd")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var gameplay := MAIN_SCENE.instantiate()
	add_child(gameplay)
	assert(gameplay.round_controller != null)
	assert(gameplay.round_number == 0)
	assert(not gameplay.round_active)

	var starting_money: int = gameplay.money
	gameplay.start_round()
	assert(gameplay.round_number == 1)
	assert(gameplay.round_active)
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_ACTIVE)
	assert(gameplay.round_duration > 0.0)

	gameplay.end_round()
	assert(not gameplay.round_active)
	assert(gameplay.money > starting_money)
	assert(gameplay.shop_open)
	assert(gameplay.active_draft_type == &"item")
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_DRAFT)
	assert(gameplay.item_shop_manager.offers.size() == 4)
	await get_tree().process_frame
	var viewport_size: Vector2 = gameplay.get_viewport_rect().size
	var shop_panel := gameplay.between_round_shop.get_node(
		"InputBlocker/ShopPanel"
	) as Control
	var continue_button := gameplay.between_round_shop.continue_button as Control
	var inventory_panel := gameplay.between_round_shop.inventory_panel as Control
	var main_column := gameplay.between_round_shop.get_node(
		"InputBlocker/ShopPanel/MarginContainer/ShopContent/MainColumn"
	) as Control
	for control in [shop_panel, continue_button, inventory_panel]:
		var control_rect: Rect2 = control.get_global_rect()
		assert(control_rect.position.x >= 0.0)
		assert(control_rect.position.y >= 0.0)
		assert(control_rect.end.x <= viewport_size.x)
		assert(control_rect.end.y <= viewport_size.y)
	assert(inventory_panel.get_global_rect().position.x >= main_column.get_global_rect().end.x)
	for card in gameplay.between_round_shop.cards:
		var name_label := card.name_label as Label
		assert(name_label.autowrap_mode != TextServer.AUTOWRAP_OFF)
		assert(name_label.get_global_rect().end.y <= viewport_size.y)
	var purchased_item_id: StringName = gameplay.item_shop_manager.offers[0]
	var purchase_price := int(
		StatDatabase.get_tower_item(purchased_item_id)["price"]
	)
	var money_before_purchase: int = gameplay.money
	gameplay._on_item_purchase_requested(0, purchased_item_id)
	assert(gameplay.shop_open)
	assert(gameplay.item_shop_manager.offers[0].is_empty())
	assert(gameplay.run_state.get_tower_item_count(purchased_item_id) == 1)
	assert(gameplay.money == money_before_purchase - purchase_price)
	gameplay._on_item_lock_toggled(1)
	assert(not gameplay.run_state.locked_tower_item_offers.is_empty())
	gameplay._on_item_shop_closed()
	assert(not gameplay.shop_open)
	assert(gameplay.round_controller.phase == RoundControllerScript.PHASE_BUILD)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = gameplay
	gameplay.add_child(tower)
	await get_tree().process_frame
	tower.is_placed = true
	gameplay.run_state.add_tower_item(&"live_wire")
	assert(gameplay.equip_inventory_item_to_tower(
		&"live_wire",
		tower,
		0
	))
	gameplay.start_round()
	assert(gameplay.round_active)
	assert(not gameplay.unequip_tower_item_to_inventory(tower, 0))
	assert(tower.get_equipped_item_ids()[0] == &"live_wire")

	print("Round lifecycle smoke test passed: rewards, responsive side inventory, readable cards, multi-buy shop, locks, build-phase equipment, and active-wave equipment lock.")
	get_tree().quit(0)
