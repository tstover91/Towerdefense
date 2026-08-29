extends Node

const MapData = preload("res://map_database.gd")
const MAIN_MENU_SCENE := "res://ui/screens/main_menu_visual.tscn"
const GAMEPLAY_SCENE := "res://main.tscn"

var sandbox_mode := false
var selected_map_id: StringName = MapData.DEFAULT_MAP_ID


func select_map(map_id: StringName) -> void:
	selected_map_id = (
		map_id if MapData.has_map(map_id) else MapData.DEFAULT_MAP_ID
	)


func start_normal_game(map_id: StringName = &"") -> void:
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = false
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func start_sandbox_game(map_id: StringName = &"") -> void:
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = true
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func return_to_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
