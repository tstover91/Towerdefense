class_name BetweenRoundShop
extends Control

const GameStats = preload("res://stat_database.gd")

signal draft_confirmed(item_id: StringName, quantity: int)
signal draft_health_requested
signal item_purchase_requested(slot_index: int, item_id: StringName)
signal item_lock_toggled(slot_index: int)
signal item_reroll_requested
signal item_shop_closed

const DRAFT_TOWER: StringName = &"tower"
const DRAFT_ITEM: StringName = &"item"

@onready var title_label := find_child("TitleLabel", true, false) as Label
@onready var subtitle_label := find_child("SubtitleLabel", true, false) as Label
@onready var health_label := find_child("HealthLabel", true, false) as Label
@onready var money_label := find_child("MoneyLabel", true, false) as Label
@onready var owned_items_label := find_child("OwnedItemsLabel", true, false) as Label
@onready var health_button := find_child("HealthButton", true, false) as Button
@onready var reroll_button := find_child("RerollButton", true, false) as Button
@onready var continue_button := find_child("ContinueButton", true, false) as Button
@onready var inventory_panel := find_child(
	"TowerItemInventoryPanel", true, false
) as Control
@onready var cards: Array[Control] = _collect_choice_cards()

var selected_item_id: StringName = &""
var selected_quantity := 1
var active_draft_type: StringName = DRAFT_TOWER


func _ready() -> void:
	for card_index in cards.size():
		cards[card_index].chosen.connect(
			_on_card_chosen.bind(card_index)
		)
		cards[card_index].lock_toggled.connect(
			_on_card_lock_toggled.bind(card_index)
		)
	if health_button != null:
		health_button.pressed.connect(_on_health_pressed)
	if reroll_button != null:
		reroll_button.pressed.connect(_on_reroll_pressed)
	continue_button.pressed.connect(_on_continue_pressed)


func setup(owner_main: Node) -> void:
	if inventory_panel != null:
		inventory_panel.setup(owner_main)


func open_draft(
	completed_round: int,
	maximum_rounds: int,
	draft_type: StringName,
	offers: Array[StringName],
	owned_items: Dictionary,
	choice_quantities: Dictionary = {},
	health_recovery := 0,
	health_cost := 0,
	can_buy_health := false,
	current_health := 0,
	maximum_health := 0,
	current_money := 0
) -> void:
	assert(
		offers.size() <= cards.size(),
		"The draft has more offers than available cards."
	)
	selected_item_id = &""
	selected_quantity = 1
	active_draft_type = draft_type
	if reroll_button != null:
		reroll_button.hide()
	if inventory_panel != null:
		inventory_panel.hide()
	update_player_status(current_health, maximum_health, current_money)
	if health_button != null:
		health_button.hide()
	var choice_name := "tower"
	title_label.text = "ROUND %d COMPLETE" % completed_round
	if subtitle_label != null:
		subtitle_label.text = "Choose one %s before Round %d" % [
			choice_name,
			min(completed_round + 1, maximum_rounds),
		]

	for index in cards.size():
		if index >= offers.size():
			cards[index].hide()
			cards[index].set_selected(false)
			continue
		cards[index].show()
		var item_id := offers[index]
		cards[index].display_item(
			get_choice_data(item_id),
			int(owned_items.get(item_id, 0)),
			false,
			int(choice_quantities.get(item_id, 1))
		)
		cards[index].set_selected(false)

	update_owned_items_display(owned_items)
	update_health_button(health_recovery, health_cost, can_buy_health)
	continue_button.text = "SELECT A TOWER"
	continue_button.disabled = true
	show()


func open_item_shop(
	completed_round: int,
	maximum_rounds: int,
	offers: Array[StringName],
	locked_slots: Array[bool],
	inventory: Dictionary,
	current_money: int,
	reroll_cost: int,
	health_recovery: int,
	health_cost: int,
	can_buy_health: bool,
	current_health := 0,
	maximum_health := 0
) -> void:
	active_draft_type = DRAFT_ITEM
	selected_item_id = &""
	title_label.text = "ROUND %d COMPLETE" % completed_round
	if subtitle_label != null:
		subtitle_label.text = (
			"Buy any number of items or save your funds for Round %d"
			% min(completed_round + 1, maximum_rounds)
		)
	if reroll_button != null:
		reroll_button.show()
	if inventory_panel != null:
		inventory_panel.hide()
	update_player_status(current_health, maximum_health, current_money)
	if health_button != null:
		health_button.show()
	continue_button.text = "CLOSE SHOP  >"
	continue_button.disabled = false
	refresh_item_shop(
		offers,
		locked_slots,
		inventory,
		current_money,
		reroll_cost
	)
	update_health_button(health_recovery, health_cost, can_buy_health)
	show()


func refresh_item_shop(
	offers: Array[StringName],
	locked_slots: Array[bool],
	inventory: Dictionary,
	current_money: int,
	reroll_cost: int
) -> void:
	for card_index in cards.size():
		var card := cards[card_index]
		card.show()
		if card_index >= offers.size() or offers[card_index].is_empty():
			card.display_empty_slot()
			continue
		var item_id := offers[card_index]
		var item := StatDatabase.get_tower_item(item_id)
		card.display_shop_item(
			item,
			int(inventory.get(item_id, 0)),
			card_index < locked_slots.size() and locked_slots[card_index],
			current_money >= int(item.get("price", 0))
		)
	update_owned_items_display(inventory)
	money_label.text = "$%s" % GameStats.format_money(current_money)
	if reroll_button != null:
		reroll_button.text = "REROLL   $%s" % GameStats.format_money(reroll_cost)
	var has_unlocked_slot := false
	for slot_index in cards.size():
		if slot_index >= locked_slots.size() or not locked_slots[slot_index]:
			has_unlocked_slot = true
			break
	if reroll_button != null:
		reroll_button.disabled = (
			current_money < reroll_cost or not has_unlocked_slot
		)
	if inventory_panel != null:
		inventory_panel.refresh()


func refresh_inventory_panel(preferred_tower: Node = null) -> void:
	if inventory_panel != null:
		inventory_panel.refresh(preferred_tower)


func build_owned_items_text(owned_items: Dictionary) -> String:
	if active_draft_type == DRAFT_TOWER:
		var tower_names := PackedStringArray()
		for tower_key in owned_items:
			tower_names.append(
				StatDatabase.get_tower(StringName(tower_key))["display_name"]
			)
		return "Current roster: " + ", ".join(tower_names)
	if active_draft_type == DRAFT_ITEM:
		if owned_items.is_empty():
			return "INVENTORY: EMPTY"
		var item_parts: PackedStringArray = []
		for item_key in owned_items:
			var item_id := StringName(item_key)
			item_parts.append("%s ×%d" % [
				StatDatabase.get_tower_item(item_id)["display_name"],
				int(owned_items[item_key]),
			])
		return "INVENTORY: " + ", ".join(item_parts)
	return ""


func update_owned_items_display(owned_items: Dictionary) -> void:
	if owned_items_label == null:
		return
	var owned_text := build_owned_items_text(owned_items)
	owned_items_label.text = owned_text
	owned_items_label.tooltip_text = owned_text


func update_player_status(
	current_health: int,
	maximum_health: int,
	current_money: int
) -> void:
	health_label.text = "HEALTH %d/%d" % [current_health, maximum_health]
	money_label.text = "$%s" % GameStats.format_money(current_money)


func update_health_button(
	health_recovery: int,
	health_cost: int,
	can_buy_health: bool
) -> void:
	if health_button == null:
		return
	if health_recovery <= 0:
		health_button.text = "HEALTH FULL"
		health_button.disabled = true
		return
	health_button.text = "RECOVER %d HEALTH · $%s" % [
		health_recovery,
		GameStats.format_money(health_cost),
	]
	health_button.disabled = not can_buy_health


func mark_health_purchased(
	health_recovered: int,
	current_health := -1,
	maximum_health := -1
) -> void:
	if health_button == null:
		return
	health_button.text = "RECOVERED %d HEALTH" % health_recovered
	health_button.disabled = true
	if current_health >= 0 and maximum_health >= 0:
		health_label.text = "HEALTH %d/%d" % [current_health, maximum_health]


func _on_card_chosen(
	item_id: StringName,
	quantity: int,
	card_index: int
) -> void:
	if active_draft_type == DRAFT_ITEM:
		item_purchase_requested.emit(card_index, item_id)
		return
	selected_item_id = item_id
	selected_quantity = maxi(quantity, 1)
	for card in cards:
		card.set_selected(card.item_id == item_id)
	var quantity_text := " x%d" % selected_quantity if selected_quantity > 1 else ""
	if subtitle_label != null:
		subtitle_label.text = "%s%s selected - press Confirm" % [
			get_choice_data(item_id)["display_name"],
			quantity_text,
		]
	continue_button.disabled = false
	continue_button.text = "CONFIRM TOWER  >"


func get_choice_data(item_id: StringName) -> Dictionary:
	if active_draft_type == DRAFT_TOWER:
		return StatDatabase.get_tower_draft_entry(item_id)
	return StatDatabase.get_tower_item(item_id)


func _on_continue_pressed() -> void:
	if active_draft_type == DRAFT_ITEM:
		continue_button.disabled = true
		item_shop_closed.emit()
		return
	if selected_item_id.is_empty():
		return
	continue_button.disabled = true
	draft_confirmed.emit(selected_item_id, selected_quantity)


func _on_health_pressed() -> void:
	if health_button.disabled:
		return
	health_button.disabled = true
	draft_health_requested.emit()


func _on_card_lock_toggled(_is_locked: bool, card_index: int) -> void:
	if active_draft_type == DRAFT_ITEM:
		item_lock_toggled.emit(card_index)


func _on_reroll_pressed() -> void:
	if (
		active_draft_type != DRAFT_ITEM
		or reroll_button == null
		or reroll_button.disabled
	):
		return
	item_reroll_requested.emit()


func _collect_choice_cards() -> Array[Control]:
	var found_cards: Array[Control] = []
	var card_container := find_child("ShopCards", true, false) as Container
	if card_container == null:
		return found_cards
	for child in card_container.get_children():
		if child is Control and child.has_signal("chosen"):
			found_cards.append(child as Control)
	return found_cards
