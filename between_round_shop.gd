class_name BetweenRoundShop
extends Control

signal draft_confirmed(item_id: StringName, quantity: int)
signal draft_health_requested

const DRAFT_TOWER: StringName = &"tower"
const DRAFT_RELIC: StringName = &"relic"

@onready var title_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/TitleLabel
@onready var subtitle_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/SubtitleLabel
@onready var owned_items_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/OwnedItemsLabel
@onready var health_button: Button = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/HealthButton
@onready var continue_button: Button = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/ContinueButton
@onready var cards: Array[Control] = [
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard1,
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard2,
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard3,
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard4,
]

var selected_item_id: StringName = &""
var selected_quantity := 1
var active_draft_type: StringName = DRAFT_RELIC


func _ready() -> void:
	for card in cards:
		card.chosen.connect(_on_card_chosen)
	health_button.pressed.connect(_on_health_pressed)
	continue_button.pressed.connect(_on_continue_pressed)


func open_draft(
	completed_round: int,
	maximum_rounds: int,
	draft_type: StringName,
	offers: Array[StringName],
	owned_items: Dictionary,
	choice_quantities: Dictionary = {},
	health_recovery := 0,
	health_cost := 0,
	can_buy_health := false
) -> void:
	assert(
		offers.size() <= cards.size(),
		"The draft has more offers than available cards."
	)
	selected_item_id = &""
	selected_quantity = 1
	active_draft_type = draft_type
	var choice_name := "tower" if draft_type == DRAFT_TOWER else "relic"
	title_label.text = "%s Draft - Round %d Complete" % [
		choice_name.capitalize(),
		completed_round,
	]
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
			draft_type == DRAFT_RELIC,
			int(choice_quantities.get(item_id, 1))
		)
		cards[index].set_selected(false)

	update_owned_items_display(owned_items)
	update_health_button(health_recovery, health_cost, can_buy_health)
	continue_button.text = "Confirm"
	continue_button.disabled = true
	show()


func build_owned_items_text(owned_items: Dictionary) -> String:
	if active_draft_type == DRAFT_TOWER:
		var tower_names := PackedStringArray()
		for tower_key in owned_items:
			tower_names.append(
				StatDatabase.get_tower(StringName(tower_key))["display_name"]
			)
		return "Current roster: " + ", ".join(tower_names)
	if owned_items.is_empty():
		return "Owned relics: None"

	var parts: PackedStringArray = []
	for item_key in owned_items:
		var item_id := StringName(item_key)
		var stats := StatDatabase.get_relic(item_id)
		parts.append("%s x%d" % [stats["display_name"], owned_items[item_key]])
	return "Owned relics: " + ", ".join(parts)


func update_owned_items_display(owned_items: Dictionary) -> void:
	var owned_text := build_owned_items_text(owned_items)
	owned_items_label.text = owned_text
	owned_items_label.tooltip_text = owned_text


func update_health_button(
	health_recovery: int,
	health_cost: int,
	can_buy_health: bool
) -> void:
	if health_recovery <= 0:
		health_button.text = "Health Full"
		health_button.disabled = true
		return
	health_button.text = "Recover %d Health - $%d" % [
		health_recovery,
		health_cost,
	]
	health_button.disabled = not can_buy_health


func mark_health_purchased(health_recovered: int) -> void:
	health_button.text = "Recovered %d Health" % health_recovered
	health_button.disabled = true


func _on_card_chosen(item_id: StringName, quantity: int) -> void:
	selected_item_id = item_id
	selected_quantity = maxi(quantity, 1)
	for card in cards:
		card.set_selected(card.item_id == item_id)
	var quantity_text := " x%d" % selected_quantity if selected_quantity > 1 else ""
	subtitle_label.text = "%s%s selected - press Confirm" % [
		get_choice_data(item_id)["display_name"],
		quantity_text,
	]
	continue_button.disabled = false


func get_choice_data(item_id: StringName) -> Dictionary:
	if active_draft_type == DRAFT_TOWER:
		return StatDatabase.get_tower_draft_entry(item_id)
	return StatDatabase.get_relic(item_id)


func _on_continue_pressed() -> void:
	if selected_item_id.is_empty():
		return
	continue_button.disabled = true
	draft_confirmed.emit(selected_item_id, selected_quantity)


func _on_health_pressed() -> void:
	if health_button.disabled:
		return
	health_button.disabled = true
	draft_health_requested.emit()
