class_name ShopChoiceCard
extends PanelContainer

signal chosen(item_id: StringName, quantity: int)

const COMMON_COLOR := Color(0.15, 0.85, 0.96)
const RARE_COLOR := Color(0.94, 0.27, 0.83)
const LEGENDARY_COLOR := Color(1.0, 0.72, 0.16)
const RELIC_RARITY_COLORS := {
	&"common": COMMON_COLOR,
	&"rare": RARE_COLOR,
	&"legendary": LEGENDARY_COLOR,
}

@onready var name_label: Label = $MarginContainer/CardLayout/NameLabel
@onready var category_label: Label = $MarginContainer/CardLayout/CategoryLabel
@onready var description_label: Label = $MarginContainer/CardLayout/DescriptionLabel
@onready var owned_label: Label = $MarginContainer/CardLayout/OwnedLabel
@onready var choose_button: Button = $MarginContainer/CardLayout/ChooseButton

var item_id: StringName = &""
var reward_quantity := 1
var default_panel_style: StyleBox
var default_name_color := Color.WHITE
var default_category_color := Color.WHITE
var default_owned_color := Color.WHITE


func _ready() -> void:
	default_panel_style = get_theme_stylebox("panel").duplicate()
	default_name_color = name_label.get_theme_color("font_color")
	default_category_color = category_label.get_theme_color("font_color")
	default_owned_color = owned_label.get_theme_color("font_color")
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
	apply_rarity_style(
		StringName(item_stats.get("rarity", &"")) if show_owned_count else &""
	)
	choose_button.disabled = false
	choose_button.text = get_choice_button_text(false)


func apply_rarity_style(rarity: StringName) -> void:
	if not RELIC_RARITY_COLORS.has(rarity):
		add_theme_stylebox_override("panel", default_panel_style)
		name_label.add_theme_color_override("font_color", default_name_color)
		category_label.add_theme_color_override(
			"font_color", default_category_color
		)
		owned_label.add_theme_color_override("font_color", default_owned_color)
		return
	var rarity_color: Color = RELIC_RARITY_COLORS[rarity]
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = rarity_color.darkened(0.84)
	panel_style.border_color = rarity_color
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(rarity_color, 0.28)
	panel_style.shadow_size = 5
	add_theme_stylebox_override("panel", panel_style)
	name_label.add_theme_color_override(
		"font_color", rarity_color.lightened(0.18)
	)
	category_label.add_theme_color_override("font_color", rarity_color)
	owned_label.add_theme_color_override(
		"font_color", rarity_color.lightened(0.30)
	)


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
