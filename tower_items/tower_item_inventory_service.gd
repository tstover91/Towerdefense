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
		or not tower.item_controller.is_item_compatible(item_id)
		or not run_state.remove_tower_item(item_id)
	):
		return false
	var previous_item_id: StringName = tower.get_equipped_item_ids()[slot_index]
	if not previous_item_id.is_empty():
		tower.unequip_item(slot_index)
	if tower.equip_item(item_id, slot_index):
		if not previous_item_id.is_empty():
			run_state.add_tower_item(previous_item_id)
		return true
	run_state.add_tower_item(item_id)
	if not previous_item_id.is_empty():
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
	var item_id: StringName = tower.unequip_item(slot_index)
	if item_id.is_empty():
		return false
	return run_state.add_tower_item(item_id)


func return_all_items(tower: Node) -> int:
	if run_state == null or not is_instance_valid(tower):
		return 0
	var returned_count := 0
	for slot_index in GameStats.TOWER_ITEM_SLOT_COUNT:
		var item_id: StringName = tower.unequip_item(slot_index)
		if not item_id.is_empty() and run_state.add_tower_item(item_id):
			returned_count += 1
	return returned_count
