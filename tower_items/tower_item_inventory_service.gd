class_name TowerItemInventoryService
extends RefCounted

const GameStats = preload("res://stat_database.gd")

var run_state: RunState


func setup(active_run_state: RunState) -> void:
	run_state = active_run_state


func equip_item(
	tower: Node,
	item_id: StringName,
	slot_index: int
) -> bool:
	if (
		run_state == null
		or not is_instance_valid(tower)
		or not bool(tower.get("is_placed"))
		or not GameStats.has_tower_item(item_id)
		or slot_index < 0
		or slot_index >= GameStats.TOWER_ITEM_SLOT_COUNT
		or not tower.item_controller.can_equip_or_swap_item(item_id, slot_index)
		or not run_state.remove_tower_item(item_id)
	):
		return false
	var existing_stack_slot: int = tower.item_controller.find_equipped_item_slot(
		item_id
	)
	if existing_stack_slot >= 0:
		if tower.equip_item(item_id, existing_stack_slot):
			return true
		run_state.add_tower_item(item_id)
		return false
	var previous_item_id: StringName = tower.get_equipped_item_ids()[slot_index]
	var previous_quantity: int = tower.get_equipped_item_count(slot_index)
	if not previous_item_id.is_empty():
		tower.unequip_item_stack(slot_index)
	if tower.equip_item(item_id, slot_index):
		if not previous_item_id.is_empty():
			run_state.add_tower_item(previous_item_id, previous_quantity)
		return true
	run_state.add_tower_item(item_id)
	if not previous_item_id.is_empty():
		for _copy_index in previous_quantity:
			tower.equip_item(previous_item_id, slot_index)
	return false


func unequip_item(tower: Node, slot_index: int) -> bool:
	if (
		run_state == null
		or not is_instance_valid(tower)
		or slot_index < 0
		or slot_index >= GameStats.TOWER_ITEM_SLOT_COUNT
	):
		return false
	var item_id: StringName = tower.unequip_item_copy(slot_index)
	if item_id.is_empty():
		return false
	return run_state.add_tower_item(item_id)


func return_all_items(tower: Node) -> int:
	if run_state == null or not is_instance_valid(tower):
		return 0
	var returned_count := 0
	for slot_index in GameStats.TOWER_ITEM_SLOT_COUNT:
		var removed_stack: Dictionary = tower.unequip_item_stack(slot_index)
		if removed_stack.is_empty():
			continue
		var quantity := int(removed_stack["quantity"])
		if run_state.add_tower_item(
			StringName(removed_stack["item_id"]), quantity
		):
			returned_count += quantity
	return returned_count
