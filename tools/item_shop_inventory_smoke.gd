extends Node

const GameStats = preload("res://stat_database.gd")
const ItemShopManagerScript = preload("res://tower_items/item_shop_manager.gd")
const InventoryServiceScript = preload(
	"res://tower_items/tower_item_inventory_service.gd"
)
const RunStateScript = preload("res://run_state.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := false
	var money := 100_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var run_state = RunStateScript.new()
	run_state.initialize(GameStats.get_mode(&"easy"), false)
	if not _check(run_state.tower_item_inventory.is_empty(), "New run item inventory was not empty."):
		return
	if not _check(run_state.add_tower_item(&"ricochet_module", 2), "Could not add a valid item to inventory."):
		return
	if not _check(run_state.get_tower_item_count(&"ricochet_module") == 2, "Inventory quantity was incorrect."):
		return
	if not _check(run_state.remove_tower_item(&"ricochet_module"), "Could not remove an inventory item."):
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 92831
	var shop = ItemShopManagerScript.new(rng)
	shop.open_shop(4, [&"ricochet_module"], GameStats.get_tower_item_ids())
	if not _check(shop.offers.size() == 4, "Item shop did not create four offer slots."):
		return
	if not _check(shop.offers[0] == &"ricochet_module" and shop.locked_slots[0], "Persisted locked offer was not restored."):
		return
	var unique_offers: Dictionary = {}
	for item_id in shop.offers:
		if not _check(not item_id.is_empty(), "Initial shop contained an empty offer."):
			return
		unique_offers[item_id] = true
	if not _check(unique_offers.size() == 4, "Initial shop rolled duplicate offers."):
		return
	if not _check(shop.get_reroll_cost() == 80, "Initial reroll cost was incorrect."):
		return
	shop.toggle_lock(2)
	if not _check(
		shop.locked_slots[2] and shop.locked_slots.count(true) == 1,
		"Moving the shop lock did not clear the previous locked slot."
	):
		return
	shop.toggle_lock(0)
	if not _check(
		shop.locked_slots[0] and shop.locked_slots.count(true) == 1,
		"The shop allowed more than one locked offer."
	):
		return
	var purchased_id: StringName = shop.offers[1]
	if not _check(shop.mark_purchased(1) and shop.offers[1].is_empty(), "Purchased offer was not marked sold."):
		return
	shop.reroll(4, GameStats.get_tower_item_ids())
	if not _check(shop.offers[0] == &"ricochet_module", "Reroll replaced a locked offer."):
		return
	if not _check(not shop.offers[1].is_empty(), "Reroll did not refill a sold slot."):
		return
	if not _check(shop.get_reroll_cost() == 105, "Reroll cost did not escalate."):
		return
	if not _check(purchased_id != &"", "Shop purchase fixture was invalid."):
		return

	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"slinger"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	tower.is_placed = true
	var service = InventoryServiceScript.new()
	service.setup(run_state)
	run_state.add_tower_item(&"live_wire")
	run_state.add_tower_item(&"ricochet_module", 2)
	if not _check(
		service.equip_item(tower, &"ricochet_module", 0)
		and service.equip_item(tower, &"ricochet_module", 1)
		and service.equip_item(tower, &"ricochet_module", 2),
		"Stackable inventory items could not be equipped."
	):
		return
	if not _check(
		run_state.get_tower_item_count(&"ricochet_module") == 0
		and tower.get_equipped_item_ids().count(&"ricochet_module") == 1
		and tower.get_equipped_item_count(0) == 3,
		"Duplicate items did not combine into one equipped slot."
	):
		return
	if not _check(
		service.unequip_item(tower, 0)
		and tower.get_equipped_item_count(0) == 2
		and run_state.get_tower_item_count(&"ricochet_module") == 1
		and service.equip_item(tower, &"ricochet_module", 2)
		and tower.get_equipped_item_count(0) == 3,
		"A stacked item could not be split and re-equipped one copy at a time."
	):
		return
	if not _check(service.equip_item(tower, &"live_wire", 0), "Inventory item could not replace an occupied slot."):
		return
	if not _check(
		run_state.get_tower_item_count(&"ricochet_module") == 3
		and tower.get_equipped_item_ids()[0] == &"live_wire",
		"Swapping did not return the replaced stack to global inventory."
	):
		return
	if not _check(service.unequip_item(tower, 0), "Equipped item could not be returned to inventory."):
		return
	if not _check(run_state.get_tower_item_count(&"live_wire") == 1, "Unequipping did not restore inventory quantity."):
		return
	run_state.add_tower_item(&"beam_optics")
	if not _check(
		service.equip_item(tower, &"beam_optics", 0)
		and run_state.get_tower_item_count(&"beam_optics") == 0
		and not tower.item_controller.is_item_active_in_slot(0),
		"A specialized item could not be equipped as an inactive item."
	):
		return
	if not _check(
		service.equip_item(tower, &"ricochet_module", 0)
		and service.equip_item(tower, &"live_wire", 1),
		"Could not prepare equipped items for tower-sale return testing."
	):
		return
	if not _check(
		service.return_all_items(tower) == 2
		and run_state.get_tower_item_count(&"ricochet_module") == 3
		and run_state.get_tower_item_count(&"live_wire") == 1,
		"Removing a tower did not return all equipped items to inventory."
	):
		return

	print("Item shop/inventory smoke test passed: offers, locks, rerolls, global quantities, single-slot stacks, whole-stack swaps, removals, compatibility, and tower-sale returns.")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
