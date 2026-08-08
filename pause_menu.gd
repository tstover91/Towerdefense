class_name PauseMenu
extends Control

const GameStats = preload("res://stat_database.gd")

@onready var empty_items_label: Label = $PausePanel/MarginContainer/PauseLayout/ItemsArea/EmptyItemsLabel
@onready var items_scroll: ScrollContainer = $PausePanel/MarginContainer/PauseLayout/ItemsArea/ItemsScroll
@onready var items_grid: GridContainer = $PausePanel/MarginContainer/PauseLayout/ItemsArea/ItemsScroll/ItemsGrid


func open_menu(owned_items: Dictionary) -> void:
	if get_tree().paused:
		return
	populate_owned_items(owned_items)
	show()
	get_tree().paused = true


func populate_owned_items(owned_items: Dictionary) -> void:
	for card in items_grid.get_children():
		items_grid.remove_child(card)
		card.queue_free()

	empty_items_label.visible = owned_items.is_empty()
	items_scroll.visible = not owned_items.is_empty()
	if owned_items.is_empty():
		return

	var item_ids: Array[StringName] = []
	for item_key in owned_items:
		item_ids.append(StringName(item_key))
	item_ids.sort()

	for item_id in item_ids:
		var item_stats: Dictionary = GameStats.get_relic(item_id)
		var owned_count := int(owned_items[item_id])
		var item_tile := Button.new()
		item_tile.custom_minimum_size = Vector2(145, 56)
		item_tile.focus_mode = Control.FOCUS_NONE
		item_tile.text = "%s\nx%d" % [item_stats["display_name"], owned_count]
		item_tile.tooltip_text = (
			"%s\n%s %s\n\n%s\nOwned: %d"
			% [
				item_stats["display_name"],
				String(item_stats["rarity"]).capitalize(),
				String(item_stats["category"]).capitalize(),
				item_stats["description"],
				owned_count,
			]
		)
		items_grid.add_child(item_tile)


func resume_game() -> void:
	get_tree().paused = false
	hide()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_game()


func _on_resume_button_pressed() -> void:
	resume_game()


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
