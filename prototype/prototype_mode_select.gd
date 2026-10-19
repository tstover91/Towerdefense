extends Control

const GRID_MAZE_SCENE := "res://prototype/prototype_main.tscn"
const SIEGE_SCENE := "res://siege_prototype/siege_main.tscn"


func _ready() -> void:
	$Page/Content/ModeButtons/GridMazeButton.pressed.connect(_open_grid_maze)
	$Page/Content/ModeButtons/SiegeButton.pressed.connect(_open_siege_prototype)
	$Page/Content/ModeButtons/GridMazeButton.grab_focus()


func _open_grid_maze() -> void:
	get_tree().change_scene_to_file(GRID_MAZE_SCENE)


func _open_siege_prototype() -> void:
	get_tree().change_scene_to_file(SIEGE_SCENE)
