extends Control

const MapData = preload("res://map_database.gd")

@onready var map_selector: OptionButton = $Content/Card/Content/MapSelector

var map_ids: Array[StringName] = []


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	populate_map_selector()
	$Content/Card/Content/LevelButtons/NormalButton.grab_focus()


func populate_map_selector() -> void:
	map_selector.clear()
	map_ids = MapData.get_map_ids()
	for map_index in map_ids.size():
		var definition := MapData.get_map(map_ids[map_index])
		map_selector.add_item(String(definition["display_name"]), map_index)
		if map_ids[map_index] == SessionState.selected_map_id:
			map_selector.select(map_index)


func get_selected_map_id() -> StringName:
	var selected_index := map_selector.selected
	if selected_index < 0 or selected_index >= map_ids.size():
		return MapData.DEFAULT_MAP_ID
	return map_ids[selected_index]


func _on_normal_button_pressed() -> void:
	SessionState.start_normal_game(get_selected_map_id())


func _on_sandbox_button_pressed() -> void:
	SessionState.start_sandbox_game(get_selected_map_id())


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_menu_music_finished() -> void:
	# The WAV importer handles the sample-accurate loop. This is a fallback for
	# platforms or future import settings that do not preserve the loop flag.
	$MenuMusic.play()
