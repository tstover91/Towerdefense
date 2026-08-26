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
	gameplay.run_state.add_tower_item(&"targeting_computer")
	assert(gameplay.equip_inventory_item_to_tower(
		&"targeting_computer",
		tower,
		0
	))
	gameplay.start_round()
	assert(gameplay.round_active)
	assert(not gameplay.unequip_tower_item_to_inventory(tower, 0))
	assert(tower.get_equipped_item_ids()[0] == &"targeting_computer")

	print("Round lifecycle smoke test passed: rewards, multi-buy shop, locks, build-phase equipment, and active-wave equipment lock.")
	get_tree().quit(0)
