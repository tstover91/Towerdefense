class_name ShopChoiceCard
extends PanelContainer

const GameStats = preload("res://stat_database.gd")

signal chosen(item_id: StringName, quantity: int)
signal lock_toggled(is_locked: bool)

@export var selected_panel_style: StyleBox

const COMMON_COLOR := Color(0.08, 0.76, 0.84)
const UNCOMMON_COLOR := Color(0.86, 0.22, 0.70)
const RARE_COLOR := Color(0.96, 0.72, 0.12)
const LEGENDARY_COLOR := Color(0.96, 0.95, 0.88)
const RARITY_COLORS := {
	&"common": COMMON_COLOR,
	&"uncommon": UNCOMMON_COLOR,
	&"rare": RARE_COLOR,
	&"legendary": LEGENDARY_COLOR,
}
const SHOP_RARITY_COLORS := {
	&"common": Color("88d4d0"),
	&"uncommon": Color("d98bb8"),
	&"rare": Color("e6c36a"),
	&"legendary": Color("f5ede1"),
}
const SHOP_RARITY_NAMES := {
	&"common": "CLASSIFIED",
	&"uncommon": "TOP SECRET",
	&"rare": "REDACTED",
	&"legendary": "UNACKNOWLEDGED",
}
const SHOP_CARD_TEXTURES := {
	&"common": preload("res://assets/ui/shop/item_card_common.png"),
	&"uncommon": preload("res://assets/ui/shop/item_card_uncommon.png"),
	&"rare": preload("res://assets/ui/shop/item_card_rare.png"),
	&"legendary": preload("res://assets/ui/shop/item_card_legendary.png"),
}

@onready var card_layout := find_child("CardLayout", true, false) as Container
@onready var name_label := find_child("NameLabel", true, false) as Label
@onready var portrait := find_child("Portrait", true, false) as TextureRect
@onready var category_label := find_child("CategoryLabel", true, false) as Label
@onready var description_label := find_child(
	"DescriptionLabel", true, false
) as Label
@onready var owned_label := find_child("OwnedLabel", true, false) as Label
@onready var lock_button := find_child("LockButton", true, false) as Button
@onready var choose_button := find_child("ChooseButton", true, false) as Button
@onready var build_cost_label := find_child(
	"BuildCostLabel", true, false
) as Label
@onready var rarity_banner := find_child(
	"RarityBanner", true, false
) as PanelContainer

var item_id: StringName = &""
var reward_quantity := 1
var default_panel_style: StyleBox
var default_name_color := Color("20262a")
var default_category_color := Color("596166")
var default_owned_color := Color("596166")
var shop_mode := false
var item_price := 0
var offer_locked := false
var draft_build_cost := 0


func _ready() -> void:
	default_panel_style = get_theme_stylebox("panel").duplicate()
	default_name_color = name_label.get_theme_color("font_color")
	if category_label != null:
		default_category_color = category_label.get_theme_color("font_color")
	default_owned_color = owned_label.get_theme_color("font_color")
	choose_button.pressed.connect(_on_choose_pressed)
	lock_button.pressed.connect(_on_lock_pressed)


func display_item(
	item_stats: Dictionary,
	owned_count: int,
	show_owned_count := true,
	quantity := 1
) -> void:
	self_modulate = Color.WHITE
	shop_mode = false
	_set_card_content_visible(true)
	item_id = item_stats["id"]
	draft_build_cost = int(item_stats.get("placement_cost", 0))
	reward_quantity = maxi(quantity, 1)
	name_label.text = item_stats["display_name"]
	portrait.texture = item_stats.get("texture") as Texture2D
	portrait.visible = portrait.texture != null
	var rarity: StringName = item_stats["rarity"]
	var rarity_name := String(
		SHOP_RARITY_NAMES.get(rarity, String(rarity).to_upper())
	)
	if rarity_banner != null:
		_set_category_text(rarity_name)
	else:
		_set_category_text("%s • %s" % [
			String(item_stats["rarity"]).capitalize(),
			String(item_stats["category"]).capitalize(),
		])
	description_label.text = item_stats["description"]
	owned_label.visible = show_owned_count
	owned_label.text = "Owned: %d" % owned_count
	apply_rarity_style(
		StringName(item_stats.get("rarity", &"")) if show_owned_count else &""
	)
	choose_button.disabled = false
	if selected_panel_style != null:
		choose_button.text = ""
		if build_cost_label != null:
			build_cost_label.text = "BUILD\n$%s" % GameStats.format_money(draft_build_cost)
	else:
		choose_button.text = get_choice_button_text(false)
	lock_button.hide()


func display_shop_item(
	item_stats: Dictionary,
	inventory_count: int,
	is_locked: bool,
	can_afford: bool
) -> void:
	self_modulate = Color.WHITE
	shop_mode = true
	_set_card_content_visible(true)
	item_id = item_stats["id"]
	reward_quantity = 1
	item_price = int(item_stats.get("price", 0))
	offer_locked = is_locked
	name_label.text = item_stats["display_name"]
	portrait.texture = item_stats.get("texture") as Texture2D
	portrait.visible = portrait.texture != null
	var rarity: StringName = item_stats.get("rarity", &"common")
	var rarity_name := String(
		SHOP_RARITY_NAMES.get(rarity, String(rarity).to_upper())
	)
	if rarity_banner != null:
		_set_category_text(rarity_name)
	else:
		_set_category_text("%s • %s" % [
			String(item_stats.get("rarity", &"common")).capitalize(),
			String(item_stats.get("category", &"general")).capitalize(),
		])
	description_label.text = item_stats["description"]
	owned_label.show()
	owned_label.text = "Inventory: %d" % inventory_count
	apply_rarity_style(StringName(item_stats.get("rarity", &"common")))
	lock_button.show()
	lock_button.button_pressed = offer_locked
	lock_button.text = "LOCK"
	lock_button.tooltip_text = (
		"Unlock this offer" if offer_locked else "Keep this offer when rerolling"
	)
	choose_button.disabled = not can_afford
	choose_button.text = "$%s" % GameStats.format_money(item_price)


func display_empty_slot() -> void:
	shop_mode = true
	item_id = &""
	_set_card_content_visible(false)
	if rarity_banner != null:
		add_theme_stylebox_override("panel", default_panel_style)
		self_modulate = Color(1.0, 1.0, 1.0, 0.42)
		return
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(0.063, 0.051, 0.063, 0.62)
	empty_style.border_color = Color(0.357, 0.255, 0.302, 0.5)
	empty_style.set_border_width_all(1)
	empty_style.corner_radius_top_left = 3
	empty_style.corner_radius_top_right = 9
	empty_style.corner_radius_bottom_right = 3
	empty_style.corner_radius_bottom_left = 9
	add_theme_stylebox_override("panel", empty_style)


func display_sold_slot() -> void:
	display_empty_slot()


func _set_card_content_visible(is_visible: bool) -> void:
	for child in card_layout.get_children():
		child.visible = is_visible


func apply_rarity_style(rarity: StringName) -> void:
	if rarity_banner != null:
		add_theme_stylebox_override("panel", _build_shop_card_style(rarity))
		name_label.add_theme_color_override("font_color", Color("f1e7d3"))
		owned_label.add_theme_color_override("font_color", Color("b8a4aa"))
		var banner_color := Color("b8a4aa")
		if SHOP_RARITY_COLORS.has(rarity):
			banner_color = SHOP_RARITY_COLORS[rarity]
		rarity_banner.add_theme_stylebox_override(
			"panel", StyleBoxEmpty.new()
		)
		rarity_banner.show()
		if category_label != null:
			category_label.add_theme_color_override(
				"font_color", banner_color
			)
		return
	if not RARITY_COLORS.has(rarity):
		add_theme_stylebox_override("panel", default_panel_style)
		name_label.add_theme_color_override("font_color", default_name_color)
		if category_label != null:
			category_label.add_theme_color_override(
				"font_color", default_category_color
			)
		owned_label.add_theme_color_override("font_color", default_owned_color)
		return
	var rarity_color: Color = RARITY_COLORS[rarity]
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.094, 0.082, 0.09, 0.9)
	panel_style.border_color = rarity_color
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 3
	panel_style.corner_radius_bottom_left = 10
	panel_style.shadow_color = Color(0.09, 0.067, 0.086, 0.78)
	panel_style.shadow_size = 4
	add_theme_stylebox_override("panel", panel_style)
	name_label.add_theme_color_override("font_color", Color("f1e7d3"))
	if category_label != null:
		category_label.add_theme_color_override(
			"font_color", rarity_color
		)
	owned_label.add_theme_color_override("font_color", Color("b8a4aa"))


func _build_shop_card_style(rarity: StringName) -> StyleBoxTexture:
	var card_style := StyleBoxTexture.new()
	card_style.texture = SHOP_CARD_TEXTURES.get(
		rarity,
		SHOP_CARD_TEXTURES[&"common"]
	) as Texture2D
	card_style.texture_margin_left = 12.0
	card_style.texture_margin_top = 12.0
	card_style.texture_margin_right = 12.0
	card_style.texture_margin_bottom = 38.0
	card_style.content_margin_left = 0.0
	card_style.content_margin_top = 0.0
	card_style.content_margin_right = 0.0
	card_style.content_margin_bottom = 0.0
	return card_style


func _set_category_text(category_text: String) -> void:
	if category_label != null:
		category_label.text = category_text


func set_selected(selected: bool) -> void:
	choose_button.disabled = false
	if selected_panel_style != null:
		choose_button.text = ""
		if build_cost_label != null:
			build_cost_label.text = "BUILD\n$%s" % GameStats.format_money(draft_build_cost)
		add_theme_stylebox_override(
			"panel",
			selected_panel_style if selected else default_panel_style
		)
	else:
		choose_button.text = get_choice_button_text(selected)


func get_choice_button_text(selected: bool) -> String:
	var action := "SELECTED" if selected else "SELECT"
	if reward_quantity > 1:
		return "%s x%d" % [action, reward_quantity]
	return action


func update_owned_count(owned_count: int) -> void:
	owned_label.text = "Owned: %d" % owned_count


func _on_choose_pressed() -> void:
	if item_id.is_empty():
		return
	chosen.emit(item_id, reward_quantity)


func _on_lock_pressed() -> void:
	if not shop_mode or item_id.is_empty():
		return
	offer_locked = not offer_locked
	lock_button.button_pressed = offer_locked
	lock_button.text = "LOCK"
	lock_button.tooltip_text = (
		"Unlock this offer" if offer_locked else "Keep this offer when rerolling"
	)
	lock_toggled.emit(offer_locked)
