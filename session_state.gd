extends Node

signal gameplay_transition_failed(message: String)
signal gameplay_transition_status(message: String)

const MapData = preload("res://map_database.gd")
const MAIN_MENU_SCENE := "res://ui/screens/main_menu_visual.tscn"
const GAMEPLAY_SCENE_PATH := "res://main.tscn"
const GAMEPLAY_SCENE: PackedScene = preload("res://main.tscn")

var sandbox_mode := false
var selected_map_id: StringName = MapData.DEFAULT_MAP_ID
var _game_start_pending := false
var _startup_overlay: PanelContainer
var _startup_label: Label


func _ready() -> void:
	_create_startup_overlay()


func _create_startup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1000
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_startup_overlay = PanelContainer.new()
	_startup_overlay.visible = false
	_startup_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_startup_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_startup_overlay.position = Vector2(-230.0, 18.0)
	_startup_overlay.size = Vector2(460.0, 54.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.043, 0.059, 0.96)
	panel_style.border_color = Color(0.486, 0.851, 0.718, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	_startup_overlay.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(_startup_overlay)

	_startup_label = Label.new()
	_startup_label.custom_minimum_size = Vector2(450.0, 48.0)
	_startup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_startup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_startup_label.add_theme_color_override(
		"font_color", Color(0.945, 0.906, 0.827, 1.0)
	)
	_startup_label.add_theme_font_size_override("font_size", 20)
	_startup_overlay.add_child(_startup_label)


func set_startup_status(message: String) -> void:
	if _startup_overlay == null or _startup_label == null:
		return
	_startup_label.text = message
	_startup_overlay.visible = true


func select_map(map_id: StringName) -> void:
	selected_map_id = (
		map_id if MapData.has_map(map_id) else MapData.DEFAULT_MAP_ID
	)


func start_normal_game(map_id: StringName = &"") -> void:
	set_startup_status("1 · Normal start handler entered")
	if _game_start_pending:
		set_startup_status("STOP · A match start is already pending")
		return
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = false
	_queue_gameplay_scene_change()


func start_sandbox_game(map_id: StringName = &"") -> void:
	set_startup_status("1 · Sandbox start handler entered")
	if _game_start_pending:
		set_startup_status("STOP · A match start is already pending")
		return
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = true
	_queue_gameplay_scene_change()


func _queue_gameplay_scene_change() -> void:
	_game_start_pending = true
	set_startup_status("2 · Match request queued")
	gameplay_transition_status.emit("Request received")
	call_deferred("_change_to_gameplay_scene")


func _change_to_gameplay_scene() -> void:
	set_startup_status("3 · Opening gameplay scene")
	gameplay_transition_status.emit("Opening gameplay scene")
	var error := get_tree().change_scene_to_packed(GAMEPLAY_SCENE)
	if error != OK:
		_report_transition_failure(error)
		return
	_verify_gameplay_transition()


func _verify_gameplay_transition() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var current_scene := get_tree().current_scene
	if (
		current_scene != null
		and current_scene.scene_file_path == GAMEPLAY_SCENE_PATH
	):
		return
	gameplay_transition_status.emit("Scene switch stalled; retrying")
	set_startup_status("4 · Scene switch stalled; retrying")
	_install_gameplay_scene_manually()


func _install_gameplay_scene_manually() -> void:
	var gameplay_scene := GAMEPLAY_SCENE.instantiate()
	if gameplay_scene == null:
		_report_transition_failure(ERR_CANT_CREATE)
		return
	var tree := get_tree()
	var previous_scene := tree.current_scene
	tree.root.add_child(gameplay_scene)
	tree.current_scene = gameplay_scene
	if previous_scene != null and previous_scene != gameplay_scene:
		previous_scene.queue_free()


func _report_transition_failure(error: Error) -> void:
	_game_start_pending = false
	var message := "Unable to open match (error %d)." % error
	set_startup_status(message)
	push_error("%s Scene: %s" % [message, GAMEPLAY_SCENE_PATH])
	gameplay_transition_failed.emit(message)


func return_to_main_menu() -> void:
	_game_start_pending = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
