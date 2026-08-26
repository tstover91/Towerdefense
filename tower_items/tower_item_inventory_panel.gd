class_name TowerItemInventoryPanel
extends PanelContainer

const GameStats = preload("res://stat_database.gd")

@onready var inventory_option: OptionButton = $Margin/Content/Selectors/InventoryOption
@onready var tower_option: OptionButton = $Margin/Content/Selectors/TowerOption
@onready var slot_option: OptionButton = $Margin/Content/Selectors/SlotOption
@onready var equip_button: Button = $Margin/Content/Actions/EquipButton
@onready var unequip_button: Button = $Margin/Content/Actions/UnequipButton
@onready var status_label: Label = $Margin/Content/StatusLabel

var main_context: Node
var tower_choices: Array[Node] = []


func _ready() -> void:
	inventory_option.item_selected.connect(_on_selection_changed)
	tower_option.item_selected.connect(_on_tower_selected)
	slot_option.item_selected.connect(_on_selection_changed)
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)


func setup(owner_main: Node) -> void:
	main_context = owner_main
	refresh()


func refresh(preferred_tower: Node = null) -> void:
	if main_context == null:
		return
	var previous_item_id := _get_selected_inventory_item_id()
	var previous_tower_uid := _get_selected_tower_uid()
	if is_instance_valid(preferred_tower):
		previous_tower_uid = StringName(
			preferred_tower.instance_progression.instance_uid
		)
	_populate_inventory(previous_item_id)
	_populate_towers(previous_tower_uid)
	_populate_slots()
	_refresh_controls()


func _populate_inventory(preferred_item_id: StringName) -> void:
	inventory_option.clear()
	var inventory: Dictionary = main_context.get_tower_item_inventory()
	var item_ids: Array[StringName] = []
	for item_key in inventory:
		var item_id := StringName(item_key)
		if int(inventory[item_key]) > 0:
			item_ids.append(item_id)
	item_ids.sort()
	for item_id in item_ids:
		var item := GameStats.get_tower_item(item_id)
		inventory_option.add_item("%s ×%d" % [
			item["display_name"],
			int(inventory[item_id]),
		])
		var index := inventory_option.item_count - 1
		inventory_option.set_item_metadata(index, item_id)
		if item_id == preferred_item_id:
			inventory_option.select(index)
	if inventory_option.item_count == 0:
		inventory_option.add_item("Inventory Empty")
		inventory_option.set_item_metadata(0, &"")
		inventory_option.disabled = true
	else:
		inventory_option.disabled = false


func _populate_towers(preferred_tower_uid: StringName) -> void:
	tower_option.clear()
	tower_choices.clear()
	for candidate in main_context.get_placed_towers_for_item_management():
		tower_choices.append(candidate)
		var tower_data := GameStats.get_tower(candidate.tower_id)
		tower_option.add_item("%s · Lv %d" % [
			tower_data["display_name"],
			candidate.instance_progression.level,
		])
		var index := tower_option.item_count - 1
		tower_option.set_item_metadata(
			index,
			candidate.instance_progression.instance_uid
		)
		if candidate.instance_progression.instance_uid == preferred_tower_uid:
			tower_option.select(index)
	if tower_choices.is_empty():
		tower_option.add_item("No Placed Towers")
		tower_option.disabled = true
	else:
		tower_option.disabled = false


func _populate_slots() -> void:
	var previous_slot := maxi(slot_option.selected, 0)
	slot_option.clear()
	var tower := _get_selected_tower()
	for slot_index in GameStats.TOWER_ITEM_SLOT_COUNT:
		var slot_text := "%d. Empty" % (slot_index + 1)
		if is_instance_valid(tower):
			var item_id: StringName = tower.get_equipped_item_ids()[slot_index]
			if not item_id.is_empty():
				var item := GameStats.get_tower_item(item_id)
				var quantity: int = tower.get_equipped_item_count(slot_index)
				var quantity_text := " ×%d" % quantity if quantity > 1 else ""
				var inactive_text := (
					" · INACTIVE"
					if not tower.item_controller.is_item_active_in_slot(slot_index)
					else ""
				)
				slot_text = "%d. %s%s%s" % [
					slot_index + 1,
					item["display_name"],
					quantity_text,
					inactive_text,
				]
		slot_option.add_item(slot_text)
		slot_option.set_item_metadata(slot_index, slot_index)
	if slot_option.item_count > 0:
		slot_option.select(mini(previous_slot, slot_option.item_count - 1))


func _refresh_controls() -> void:
	var tower := _get_selected_tower()
	var item_id := _get_selected_inventory_item_id()
	var slot_index := _get_selected_slot_index()
	var can_manage: bool = main_context.can_manage_tower_items()
	var has_equipped_item := false
	if is_instance_valid(tower) and slot_index >= 0:
		has_equipped_item = not tower.get_equipped_item_ids()[slot_index].is_empty()
	var item_is_compatible: bool = (
		is_instance_valid(tower)
		and not item_id.is_empty()
		and tower.item_controller.can_equip_or_swap_item(item_id, slot_index)
	)
	equip_button.disabled = not can_manage or not item_is_compatible
	unequip_button.disabled = not can_manage or not has_equipped_item
	unequip_button.text = (
		"Unequip One"
		if has_equipped_item and tower.get_equipped_item_count(slot_index) > 1
		else "Unequip"
	)
	if not can_manage:
		status_label.text = "Equipment is locked during active waves."
	elif not is_instance_valid(tower):
		status_label.text = "Build a tower before equipping items."
	elif item_id.is_empty():
		status_label.text = "Select an inventory item or remove the selected slot."
	elif not item_is_compatible:
		var incompatibility_reason: String = (
			tower.item_controller.get_incompatibility_reason(item_id, slot_index)
		)
		status_label.text = (
			incompatibility_reason
			if not incompatibility_reason.is_empty()
			else "This tower already has the maximum number of this item."
		)
	elif tower.item_controller.find_equipped_item_slot(item_id) >= 0:
		var stack_slot: int = tower.item_controller.find_equipped_item_slot(item_id)
		status_label.text = "Adds to the ×%d stack in slot %d." % [
			tower.get_equipped_item_count(stack_slot),
			stack_slot + 1,
		]
	elif has_equipped_item:
		status_label.text = "Equip will return the entire current stack to inventory."
	else:
		status_label.text = "Equip the selected item into this slot."


func _get_selected_inventory_item_id() -> StringName:
	if inventory_option == null or inventory_option.item_count == 0:
		return &""
	return StringName(inventory_option.get_item_metadata(inventory_option.selected))


func _get_selected_tower_uid() -> StringName:
	if tower_option == null or tower_option.item_count == 0 or tower_option.disabled:
		return &""
	return StringName(tower_option.get_item_metadata(tower_option.selected))


func _get_selected_tower() -> Node:
	if tower_option == null or tower_option.disabled:
		return null
	var selected_index := tower_option.selected
	if selected_index < 0 or selected_index >= tower_choices.size():
		return null
	return tower_choices[selected_index]


func _get_selected_slot_index() -> int:
	if slot_option == null or slot_option.item_count == 0:
		return -1
	return int(slot_option.get_item_metadata(slot_option.selected))


func _on_selection_changed(_index: int) -> void:
	_refresh_controls()


func _on_tower_selected(_index: int) -> void:
	_populate_slots()
	_refresh_controls()


func _on_equip_pressed() -> void:
	var tower := _get_selected_tower()
	if not is_instance_valid(tower):
		return
	if main_context.equip_inventory_item_to_tower(
		_get_selected_inventory_item_id(),
		tower,
		_get_selected_slot_index()
	):
		refresh(tower)


func _on_unequip_pressed() -> void:
	var tower := _get_selected_tower()
	if not is_instance_valid(tower):
		return
	if main_context.unequip_tower_item_to_inventory(
		tower,
		_get_selected_slot_index()
	):
		refresh(tower)
