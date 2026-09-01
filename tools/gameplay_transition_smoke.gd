extends Node

const GAMEPLAY_SCENE_PATH := "res://main.tscn"
const MAIN_MENU_SCENE = preload("res://ui/screens/main_menu_visual.tscn")


class TransitionMonitor:
	extends Node

	var frames_waited := 0


	func _process(_delta: float) -> void:
		frames_waited += 1
		if frames_waited < 3:
			return
		var current_scene := get_tree().current_scene
		assert(current_scene != null, "Scene transition left no current scene.")
		assert(
			current_scene.scene_file_path == GAMEPLAY_SCENE_PATH,
			"Expected gameplay scene, found: %s"
			% current_scene.scene_file_path
		)
		print("Gameplay transition smoke test passed.")
		get_tree().quit(0)


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var monitor := TransitionMonitor.new()
	get_tree().root.add_child(monitor)
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	var play_button := main_menu.get_node(
		"Content/Card/Content/LevelButtons/NormalButton"
	) as Button
	play_button.button_down.emit()
