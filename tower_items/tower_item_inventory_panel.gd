class_name TowerItemInventoryPanel
extends PanelContainer

const GameStats = preload("res://stat_database.gd")
const BOOGALOO_FONT = preload("res://assets/fonts/Boogaloo-Regular.ttf")

signal selected_item_changed(item_id: StringName)
signal selected_item_confirmed(item_id: StringName)

const RARITY_COLORS := {
	&"common": Color(0.08, 0.76, 0.84),
	&"uncommon": Color(0.86, 0.22, 0.70),
	&"rare": Color(0.96, 0.72, 0.12),
	&"legendary": Color(0.96, 0.95, 0.88),
}
const SELECTION_MINT := Color("84d7b0")
const EQUIPPED_CORAL := Color("ec7354")

@onready var item_grid: GridContainer = $Margin/Content/GridScroll/ItemGrid
@onready var empty_label: Label = $Margin/Content/EmptyLabel
@onready var selected_name: Label = $Margin/Content/SelectedName
@onready var selected_description: Label = $Margin/Content/SelectedDescription
@onready var status_label: Label = $Margin/Content/StatusLabel

var main_context: Node
var selected_item_id: StringName = &""
var item_buttons: Dictionary = {}
var comparison_tower: Node


func setup(owner_main: Node) -> void:
	main_context = owner_main
	refresh()


func refresh(preferred_tower: Node = null) -> void:
	if main_context == null or not is_node_ready():
		return
	_update_comparison_tower(preferred_tower)
	var previous_item_id := selected_item_id
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
	item_buttons.clear()
	var inventory: Dictionary = main_context.get_tower_item_inventory()
	var item_ids: Array[StringName] = []
	for item_key in inventory:
		var item_id := StringName(item_key)
		if int(inventory[item_key]) > 0:
			item_ids.append(item_id)
	item_ids.sort()
	for item_id in item_ids:
		var button := _create_item_button(item_id, int(inventory[item_id]))
		item_grid.add_child(button)
		item_buttons[item_id] = button
	empty_label.visible = item_ids.is_empty()
	if not item_ids.has(previous_item_id):
		selected_item_id = &""
	_refresh_selection_display()


func open_global_inventory() -> void:
	refresh(_get_selected_displayed_tower())
	show()


func open_for_tower_slot(tower: Node, _slot_index: int) -> void:
	refresh(tower)
	show()


func get_selected_inventory_item_id() -> StringName:
	return selected_item_id


func set_status(message: String) -> void:
	status_label.text = message


func _create_item_button(item_id: StringName, quantity: int) -> Button:
	var item := GameStats.get_tower_item(item_id)
	var display_name := String(item.get("display_name", item_id))
	var equipped_count := _get_equipped_count(item_id)
	var maximum_copies := int(item.get(
		"max_copies_per_tower", GameStats.TOWER_ITEM_STACK_LIMIT
	))
	var is_equipped := equipped_count > 0
	var is_at_maximum := equipped_count >= maximum_copies
	var button := Button.new()
	button.name = "Item_%s" % String(item_id)
	button.custom_minimum_size = Vector2(62.0, 62.0)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.icon = item.get("texture") as Texture2D
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 48)
	button.tooltip_text = "%s\n%s%s" % [
		display_name,
		String(item.get("description", "")),
		(
			"\nEquipped: %d/%d%s" % [
				equipped_count, maximum_copies,
				" · MAXIMUM" if is_at_maximum else "",
			]
			if is_equipped else ""
		),
	]
	var rarity := StringName(item.get("rarity", &"common"))
	var rarity_color: Color = RARITY_COLORS.get(
		rarity, Color(0.65, 0.68, 0.72)
	)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			Color("100d10") if state == "normal" else Color("2b2028")
		)
		style.border_color = (
			SELECTION_MINT
			if state == "pressed"
			else EQUIPPED_CORAL if is_equipped else rarity_color
		)
		style.set_border_width_all(3 if state == "pressed" else 1)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 7
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("f1e7d3"))
	button.add_theme_color_override("font_hover_color", Color("f1e7d3"))
	button.add_theme_color_override("font_pressed_color", Color("f1e7d3"))
	var count_label := Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_left = -26.0
	count_label.offset_top = -20.0
	count_label.offset_right = -4.0
	count_label.offset_bottom = -2.0
	count_label.text = "×%d" % quantity
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_color_override("font_color", Color("f1e7d3"))
	count_label.add_theme_color_override("font_shadow_color", Color("100d10"))
	count_label.add_theme_constant_override("shadow_offset_x", 1)
	count_label.add_theme_constant_override("shadow_offset_y", 1)
	count_label.add_theme_font_override("font", BOOGALOO_FONT)
	count_label.add_theme_font_size_override("font_size", 12)
	button.add_child(count_label)
	button.pressed.connect(_on_item_pressed.bind(item_id))
	return button


func _update_comparison_tower(preferred_tower: Node) -> void:
	if is_instance_valid(preferred_tower):
		comparison_tower = preferred_tower
		return
	comparison_tower = _get_selected_displayed_tower()


func _get_selected_displayed_tower() -> Node:
	if main_context == null:
		return null
	var tower = main_context.get("displayed_tower")
	if not is_instance_valid(tower) or not bool(tower.get("selected")):
		return null
	return tower


func _get_equipped_count(item_id: StringName) -> int:
	if (
		not is_instance_valid(comparison_tower)
		or comparison_tower.get("item_controller") == null
	):
		return 0
	return comparison_tower.item_controller.get_total_equipped_item_count(item_id)


func _on_item_pressed(item_id: StringName) -> void:
	var confirms_selection := selected_item_id == item_id
	selected_item_id = item_id
	status_label.text = "Click a highlighted tower or a specific item slot."
	_refresh_selection_display()
	selected_item_changed.emit(selected_item_id)
	if confirms_selection:
		selected_item_confirmed.emit(selected_item_id)


func clear_selection() -> void:
	selected_item_id = &""
	_refresh_selection_display()
	selected_item_changed.emit(selected_item_id)


func _refresh_selection_display() -> void:
	for item_key in item_buttons:
		(item_buttons[item_key] as Button).button_pressed = (
			StringName(item_key) == selected_item_id
		)
	if selected_item_id.is_empty():
		selected_name.text = "No item selected"
		selected_description.text = "Choose an item from the grid."
		status_label.text = ""
		return
	var item := GameStats.get_tower_item(selected_item_id)
	selected_name.text = "%s · %s" % [
		String(item.get("display_name", selected_item_id)),
		String(item.get("rarity", &"common")).capitalize(),
	]
	selected_description.text = String(item.get("description", ""))
