extends Node

const MAIN_MENU_SCENE := "res://main_menu.tscn"
const FARM_SCENE := "res://main.tscn"

var sandbox_mode := false


func start_normal_game() -> void:
	sandbox_mode = false
	get_tree().change_scene_to_file(FARM_SCENE)


func start_sandbox_game() -> void:
	sandbox_mode = true
	get_tree().change_scene_to_file(FARM_SCENE)


func return_to_main_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
