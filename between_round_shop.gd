class_name BetweenRoundShop
extends Control

signal reward_chosen(item_id: StringName)
signal next_round_requested

@onready var title_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/TitleLabel
@onready var subtitle_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/SubtitleLabel
@onready var owned_items_label: Label = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/OwnedItemsLabel
@onready var start_next_round_button: Button = $InputBlocker/ShopPanel/MarginContainer/ShopLayout/StartNextRoundButton
@onready var cards: Array[Control] = [
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard1,
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard2,
	$InputBlocker/ShopPanel/MarginContainer/ShopLayout/ShopCards/ShopChoiceCard3,
]

var selection_locked := false


func _ready() -> void:
	for card in cards:
		card.chosen.connect(_on_card_chosen)
	start_next_round_button.pressed.connect(_on_start_next_round_pressed)


func open_shop(
	completed_round: int,
	maximum_rounds: int,
	offers: Array[StringName],
	owned_items: Dictionary
) -> void:
	assert(offers.size() == cards.size(), "The shop requires one offer per card.")
	selection_locked = false
	title_label.text = "Round %d Complete" % completed_round
	subtitle_label.text = "Choose one reward for Round %d" % min(
		completed_round + 1,
		maximum_rounds
	)

	for index in cards.size():
		var item_id := offers[index]
		cards[index].display_item(
			StatDatabase.get_shop_item(item_id),
			int(owned_items.get(item_id, 0))
		)

	update_owned_items_display(owned_items)
	start_next_round_button.text = "Choose a Reward"
	start_next_round_button.disabled = true
	show()


func confirm_reward_choice(item_id: StringName, owned_items: Dictionary) -> void:
	if not selection_locked:
		return
	for card in cards:
		card.set_choice_locked(card.item_id == item_id)
		card.update_owned_count(int(owned_items.get(card.item_id, 0)))
	update_owned_items_display(owned_items)
	subtitle_label.text = "%s selected" % StatDatabase.get_shop_item(item_id)["display_name"]
	start_next_round_button.text = "Start Next Round"
	start_next_round_button.disabled = false


func build_owned_items_text(owned_items: Dictionary) -> String:
	if owned_items.is_empty():
		return "Owned rewards: None"

	var parts: PackedStringArray = []
	for item_key in owned_items:
		var item_id := StringName(item_key)
		var stats := StatDatabase.get_shop_item(item_id)
		parts.append("%s x%d" % [stats["display_name"], owned_items[item_key]])
	return "Owned rewards: " + ", ".join(parts)


func update_owned_items_display(owned_items: Dictionary) -> void:
	var owned_text := build_owned_items_text(owned_items)
	owned_items_label.text = owned_text
	owned_items_label.tooltip_text = owned_text


func _on_card_chosen(item_id: StringName) -> void:
	if selection_locked:
		return
	selection_locked = true
	reward_chosen.emit(item_id)


func _on_start_next_round_pressed() -> void:
	if not selection_locked:
		return
	start_next_round_button.disabled = true
	next_round_requested.emit()
