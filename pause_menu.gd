class_name PauseMenu
extends Control

const GameStats = preload("res://stat_database.gd")

@onready var empty_items_label: Label = $PausePanel/MarginContainer/PauseLayout/ContentRow/ItemsArea/EmptyItemsLabel
@onready var items_scroll: ScrollContainer = $PausePanel/MarginContainer/PauseLayout/ContentRow/ItemsArea/ItemsScroll
@onready var items_grid: GridContainer = $PausePanel/MarginContainer/PauseLayout/ContentRow/ItemsArea/ItemsScroll/ItemsGrid
@onready var enemy_header: Label = $PausePanel/MarginContainer/PauseLayout/ContentRow/EnemyArea/EnemyHeader
@onready var empty_enemies_label: Label = $PausePanel/MarginContainer/PauseLayout/ContentRow/EnemyArea/EmptyEnemiesLabel
@onready var enemies_scroll: ScrollContainer = $PausePanel/MarginContainer/PauseLayout/ContentRow/EnemyArea/EnemiesScroll
@onready var enemies_grid: GridContainer = $PausePanel/MarginContainer/PauseLayout/ContentRow/EnemyArea/EnemiesScroll/EnemiesGrid


func open_menu(
	owned_items: Dictionary,
	enemy_ids: Array[StringName] = [],
	enemy_round: int = 1
) -> void:
	if get_tree().paused:
		return
	populate_owned_items(owned_items)
	populate_enemy_pool(enemy_ids, enemy_round)
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
		if not GameStats.has_tower_item(item_id):
			continue
		var item_stats: Dictionary = GameStats.get_tower_item(item_id)
		var owned_count := int(owned_items[item_id])
		var item_tile := Button.new()
		item_tile.custom_minimum_size = Vector2(185, 64)
		item_tile.focus_mode = Control.FOCUS_NONE
		item_tile.text = "%s  ×%d\n%s" % [
			item_stats["display_name"],
			owned_count,
			String(item_stats["rarity"]).capitalize(),
		]
		item_tile.tooltip_text = (
			"%s\n%s %s\n\n%s\n\nTotal owned: %d"
			% [
				item_stats["display_name"],
				String(item_stats["rarity"]).capitalize(),
				String(item_stats["category"]).capitalize(),
				item_stats["description"],
				owned_count,
			]
		)
		items_grid.add_child(item_tile)


func populate_enemy_pool(enemy_ids: Array[StringName], enemy_round: int) -> void:
	for card in enemies_grid.get_children():
		enemies_grid.remove_child(card)
		card.queue_free()

	enemy_header.text = "Enemy Pool — Round %d" % enemy_round
	empty_enemies_label.visible = enemy_ids.is_empty()
	enemies_scroll.visible = not enemy_ids.is_empty()
	if enemy_ids.is_empty():
		return

	var sorted_ids := enemy_ids.duplicate()
	sorted_ids.sort_custom(func(first: StringName, second: StringName) -> bool:
		return String(GameStats.get_enemy(first)["display_name"]) < String(
			GameStats.get_enemy(second)["display_name"]
		)
	)
	for enemy_id in sorted_ids:
		var enemy := GameStats.get_enemy(enemy_id)
		var enemy_tile := Button.new()
		enemy_tile.custom_minimum_size = Vector2(185, 58)
		enemy_tile.focus_mode = Control.FOCUS_NONE
		enemy_tile.text = String(enemy["display_name"])
		enemy_tile.tooltip_text = get_enemy_tooltip(enemy_id, enemy_round)
		enemies_grid.add_child(enemy_tile)


func get_enemy_tooltip(enemy_id: StringName, enemy_round: int) -> String:
	var enemy := GameStats.get_enemy(enemy_id)
	var scaled_health := roundi(
		float(enemy["health"])
		* GameStats.get_enemy_health_multiplier(enemy_round, enemy_id)
	)
	var traits: Array[String] = []
	for trait_id in enemy.get("traits", []):
		traits.append(String(trait_id).replace("_", " ").capitalize())
	return "%s\nStandard health: %d\nSpeed: %.1f\nArmor: %d\nTraits: %s" % [
		enemy["display_name"],
		scaled_health,
		float(enemy["move_speed"]) * GameStats.STANDARD_ENEMY_SPEED_MULTIPLIER,
		int(enemy.get("armor", 0)),
		", ".join(traits) if not traits.is_empty() else "None",
	]


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
	SessionState.return_to_main_menu()
