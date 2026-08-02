class_name ShopChoiceCard
extends PanelContainer

signal chosen(item_id: StringName)

@onready var name_label: Label = $MarginContainer/CardLayout/NameLabel
@onready var category_label: Label = $MarginContainer/CardLayout/CategoryLabel
@onready var description_label: Label = $MarginContainer/CardLayout/DescriptionLabel
@onready var owned_label: Label = $MarginContainer/CardLayout/OwnedLabel
@onready var choose_button: Button = $MarginContainer/CardLayout/ChooseButton

var item_id: StringName = &""


func _ready() -> void:
	choose_button.pressed.connect(_on_choose_pressed)


func display_item(item_stats: Dictionary, owned_count: int) -> void:
	item_id = item_stats["id"]
	name_label.text = item_stats["display_name"]
	category_label.text = String(item_stats.get("category", &"general")).capitalize()
	description_label.text = item_stats["description"]
	owned_label.text = "Owned: %d" % owned_count
	choose_button.disabled = false
	choose_button.text = "Choose"


func set_choice_locked(selected: bool) -> void:
	choose_button.disabled = true
	choose_button.text = "Selected" if selected else "Not Selected"


func update_owned_count(owned_count: int) -> void:
	owned_label.text = "Owned: %d" % owned_count


func _on_choose_pressed() -> void:
	if item_id.is_empty():
		return
	choose_button.disabled = true
	chosen.emit(item_id)
