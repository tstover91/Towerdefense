class_name ShopChoiceCard
extends PanelContainer

signal chosen(item_id: StringName, quantity: int)

@onready var name_label: Label = $MarginContainer/CardLayout/NameLabel
@onready var category_label: Label = $MarginContainer/CardLayout/CategoryLabel
@onready var description_label: Label = $MarginContainer/CardLayout/DescriptionLabel
@onready var owned_label: Label = $MarginContainer/CardLayout/OwnedLabel
@onready var choose_button: Button = $MarginContainer/CardLayout/ChooseButton

var item_id: StringName = &""
var reward_quantity := 1


func _ready() -> void:
	choose_button.pressed.connect(_on_choose_pressed)


func display_item(
	item_stats: Dictionary,
	owned_count: int,
	show_owned_count := true,
	quantity := 1
) -> void:
	item_id = item_stats["id"]
	reward_quantity = maxi(quantity, 1)
	name_label.text = item_stats["display_name"]
	category_label.text = "%s • %s" % [
		String(item_stats["rarity"]).capitalize(),
		String(item_stats["category"]).capitalize(),
	]
	description_label.text = item_stats["description"]
	owned_label.visible = show_owned_count
	owned_label.text = "Owned: %d" % owned_count
	choose_button.disabled = false
	choose_button.text = get_choice_button_text(false)


func set_selected(selected: bool) -> void:
	choose_button.disabled = false
	choose_button.text = get_choice_button_text(selected)


func get_choice_button_text(selected: bool) -> String:
	var action := "Selected" if selected else "Choose"
	if reward_quantity > 1:
		return "%s x%d" % [action, reward_quantity]
	return action


func update_owned_count(owned_count: int) -> void:
	owned_label.text = "Owned: %d" % owned_count


func _on_choose_pressed() -> void:
	if item_id.is_empty():
		return
	chosen.emit(item_id, reward_quantity)
