class_name TowerItemInventoryPanel
extends PanelContainer

const GameStats = preload("res://stat_database.gd")

signal selected_item_changed(item_id: StringName)

const RARITY_COLORS := {
	&"common": Color(0.08, 0.76, 0.84),
	&"uncommon": Color(0.86, 0.22, 0.70),
	&"rare": Color(0.96, 0.72, 0.12),
	&"legendary": Color(0.96, 0.95, 0.88),
}

@onready var item_grid: GridContainer = $Margin/Content/GridScroll/ItemGrid
@onready var empty_label: Label = $Margin/Content/EmptyLabel
@onready var selected_name: Label = $Margin/Content/SelectedName
@onready var selected_description: Label = $Margin/Content/SelectedDescription
@onready var status_label: Label = $Margin/Content/StatusLabel

var main_context: Node
var selected_item_id: StringName = &""
var item_buttons: Dictionary = {}


func setup(owner_main: Node) -> void:
	main_context = owner_main
	refresh()


func refresh(_preferred_tower: Node = null) -> void:
	if main_context == null or not is_node_ready():
		return
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
	refresh()
	show()


func open_for_tower_slot(_tower: Node, _slot_index: int) -> void:
	refresh()
	show()


func get_selected_inventory_item_id() -> StringName:
	return selected_item_id


func set_status(message: String) -> void:
	status_label.text = message


func _create_item_button(item_id: StringName, quantity: int) -> Button:
	var item := GameStats.get_tower_item(item_id)
	var display_name := String(item.get("display_name", item_id))
	var button := Button.new()
	button.name = "Item_%s" % String(item_id)
	button.custom_minimum_size = Vector2(62.0, 62.0)
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%s\n×%d" % [_get_item_initials(display_name), quantity]
	button.tooltip_text = "%s\n%s" % [
		display_name,
		String(item.get("description", "")),
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
		style.border_color = rarity_color
		style.set_border_width_all(3 if state == "pressed" else 1)
		style.corner_radius_top_left = 2
		style.corner_radius_top_right = 7
		style.corner_radius_bottom_right = 2
		style.corner_radius_bottom_left = 7
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("f1e7d3"))
	button.add_theme_color_override("font_hover_color", Color("f1e7d3"))
	button.add_theme_color_override("font_pressed_color", Color("f1e7d3"))
	button.pressed.connect(_on_item_pressed.bind(item_id))
	return button


func _get_item_initials(display_name: String) -> String:
	var words := display_name.split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(2).to_upper()
	return (words[0].left(1) + words[1].left(1)).to_upper()


func _on_item_pressed(item_id: StringName) -> void:
	selected_item_id = item_id
	status_label.text = "Click a highlighted tower or a specific item slot."
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
