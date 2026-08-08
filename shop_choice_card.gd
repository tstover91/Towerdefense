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


func display_item(
	item_stats: Dictionary,
	owned_count: int,
	show_owned_count := true
) -> void:
	item_id = item_stats["id"]
	name_label.text = item_stats["display_name"]
	category_label.text = "%s • %s" % [
		String(item_stats["rarity"]).capitalize(),
		String(item_stats["category"]).capitalize(),
	]
	description_label.text = item_stats["description"]
	owned_label.visible = show_owned_count
	owned_label.text = "Owned: %d" % owned_count
	choose_button.disabled = false
	choose_button.text = "Choose"


func set_selected(selected: bool) -> void:
	choose_button.disabled = false
	choose_button.text = "Selected" if selected else "Choose"


func update_owned_count(owned_count: int) -> void:
	owned_label.text = "Owned: %d" % owned_count


func _on_choose_pressed() -> void:
	if item_id.is_empty():
		return
	chosen.emit(item_id)
