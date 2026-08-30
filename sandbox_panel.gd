class_name SandboxPanel
extends Control

const GameStats = preload("res://stat_database.gd")

@onready var panel: PanelContainer = $Panel
@onready var toggle_button: Button = $ToggleButton
@onready var wave_number: SpinBox = $Panel/Margin/Layout/WaveSettings/WaveNumber
@onready var enemy_selector: OptionButton = $Panel/Margin/Layout/EnemyControls/EnemySelector
@onready var enemy_count: SpinBox = $Panel/Margin/Layout/EnemyControls/EnemyCount
@onready var variant_selector: OptionButton = $Panel/Margin/Layout/EnemyControls/VariantSelector
@onready var status_label: Label = $Panel/Margin/Layout/StatusLabel
@onready var selected_tower_label: Label = $Panel/Margin/Layout/TowerLevelSection/SelectedTower
@onready var tower_level: SpinBox = $Panel/Margin/Layout/TowerLevelSection/LevelControls/TowerLevel

var main: Node
var enemy_ids: Array[StringName] = []
var variant_ids: Array[StringName] = [&"normal", &"horde", &"elite", &"payday"]


func configure(game: Node) -> void:
	main = game
	enemy_selector.clear()
	enemy_ids.clear()
	for enemy_key in GameStats.ENEMIES:
		var enemy_id := StringName(enemy_key)
		enemy_ids.append(enemy_id)
		enemy_selector.add_item(GameStats.get_enemy(enemy_id)["display_name"])
	variant_selector.clear()
	for variant_id in variant_ids:
		variant_selector.add_item(String(variant_id).capitalize())
	wave_number.value = 10
	status_label.text = "Ready. All towers and items are available."
	clear_tower_level()
	show()


func set_status(message: String) -> void:
	status_label.text = message


func show_tower_level(tower: Node) -> void:
	if not is_instance_valid(tower) or tower.get("instance_progression") == null:
		clear_tower_level()
		return
	var tower_data := GameStats.get_tower(StringName(tower.get("tower_id")))
	selected_tower_label.text = String(tower_data.get("display_name", "Selected Tower"))
	tower_level.set_value_no_signal(int(tower.instance_progression.level))
	tower_level.editable = true


func clear_tower_level() -> void:
	selected_tower_label.text = "Select a tower to set its level"
	tower_level.set_value_no_signal(1)
	tower_level.editable = false


func _selected_wave() -> int:
	return int(wave_number.value)


func _on_toggle_button_pressed() -> void:
	panel.visible = not panel.visible
	toggle_button.text = "Hide Sandbox" if panel.visible else "Show Sandbox"


func _on_standard_pressed() -> void:
	main.sandbox_spawn_wave(&"standard", _selected_wave())


func _on_horde_pressed() -> void:
	main.sandbox_spawn_wave(&"horde", _selected_wave())


func _on_elite_pressed() -> void:
	main.sandbox_spawn_wave(&"elite", _selected_wave())


func _on_gauntlet_pressed() -> void:
	main.sandbox_spawn_wave(&"gauntlet", _selected_wave())


func _on_boss_pressed() -> void:
	main.sandbox_spawn_wave(&"boss", _selected_wave())


func _on_spawn_enemy_pressed() -> void:
	if enemy_selector.selected < 0:
		return
	main.sandbox_spawn_enemy(
		enemy_ids[enemy_selector.selected],
		int(enemy_count.value),
		variant_ids[variant_selector.selected],
		_selected_wave()
	)


func _on_clear_pressed() -> void:
	main.sandbox_clear_enemies()


func _on_restore_health_pressed() -> void:
	main.sandbox_restore_health()


func _on_apply_level_pressed() -> void:
	if main.sandbox_set_selected_tower_level(int(tower_level.value)):
		set_status("Selected tower set to LV %02d." % int(tower_level.value))
	else:
		set_status("Select a placed tower first.")


func _on_main_menu_pressed() -> void:
	SessionState.return_to_main_menu()
