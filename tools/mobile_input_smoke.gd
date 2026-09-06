extends Node

const MainScript = preload("res://main.gd")

func _ready() -> void:
	var game = MainScript.new()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	assert(game.is_pointer_press_event(touch))
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	assert(game.is_pointer_press_event(mouse))
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	assert(not game.is_pointer_press_event(mouse))
	# A synthetic click must exit before accessing gameplay/UI state.
	game._input(mouse)
	game._unhandled_input(mouse)
	game.begin_placement_drag_candidate(&"tower", 0, Vector2(100, 100), 0)
	var other_finger := InputEventScreenDrag.new()
	other_finger.index = 1
	assert(not game.handle_placement_drag_input(other_finger))
	assert(game.placement_drag_pointer_index == 0)
	touch.pressed = false
	touch.canceled = true
	assert(game.handle_placement_drag_input(touch))
	assert(game.placement_drag_candidate_kind.is_empty())
	assert(game.active_placement_drag_kind.is_empty())
	game.free()
	print("Mobile input smoke passed")
	get_tree().quit()
