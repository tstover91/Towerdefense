extends Node

const MapData = preload("res://map_database.gd")
const MAIN_MENU_SCENE := "res://ui/screens/main_menu_visual.tscn"

var sandbox_mode := false
var selected_map_id: StringName = MapData.DEFAULT_MAP_ID


func select_map(map_id: StringName) -> void:
	selected_map_id = (
		map_id if MapData.has_map(map_id) else MapData.DEFAULT_MAP_ID
	)


func return_to_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
