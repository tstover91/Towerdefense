extends Control


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	$Content/Card/Content/LevelButtons/NormalButton.grab_focus()


func _on_normal_button_pressed() -> void:
	SessionState.start_normal_game()


func _on_sandbox_button_pressed() -> void:
	SessionState.start_sandbox_game()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
