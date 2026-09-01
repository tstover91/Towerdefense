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


func select_map(map_id: StringName) -> void:
	selected_map_id = (
		map_id if MapData.has_map(map_id) else MapData.DEFAULT_MAP_ID
	)


func start_normal_game(map_id: StringName = &"") -> void:
	if _game_start_pending:
		return
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = false
	_queue_gameplay_scene_change()


func start_sandbox_game(map_id: StringName = &"") -> void:
	if _game_start_pending:
		return
	if not map_id.is_empty():
		select_map(map_id)
	sandbox_mode = true
	_queue_gameplay_scene_change()


func _queue_gameplay_scene_change() -> void:
	_game_start_pending = true
	gameplay_transition_status.emit("Request received")
	call_deferred("_change_to_gameplay_scene")


func _change_to_gameplay_scene() -> void:
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
	push_error("%s Scene: %s" % [message, GAMEPLAY_SCENE_PATH])
	gameplay_transition_failed.emit(message)


func return_to_main_menu() -> void:
	_game_start_pending = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
