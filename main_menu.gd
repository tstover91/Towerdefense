extends Control

const MapData = preload("res://map_database.gd")
const GAMEPLAY_SCENE: PackedScene = preload("res://main.tscn")
const BUILD_LABEL := "v0.1.3 · Android build 4"

@onready var map_selector: OptionButton = $Content/Card/Content/MapSelector
@onready var normal_button: Button = $Content/Card/Content/LevelButtons/NormalButton
@onready var sandbox_button: Button = $Content/Card/Content/LevelButtons/SandboxButton
@onready var subtitle: Label = $Content/Card/Content/Subtitle
@onready var footer: Label = $Content/Card/Content/Footer

var map_ids: Array[StringName] = []
var start_requested := false


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	populate_map_selector()
	subtitle.text = "Choose a level · %s" % BUILD_LABEL
	footer.text = "%s · Choose a map, then select a game mode." % BUILD_LABEL
	if not normal_button.button_down.is_connected(
		_on_normal_button_pressed
	):
		normal_button.button_down.connect(_on_normal_button_pressed)
	if not sandbox_button.button_down.is_connected(
		_on_sandbox_button_pressed
	):
		sandbox_button.button_down.connect(_on_sandbox_button_pressed)
	normal_button.grab_focus()


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
	if start_requested:
		return
	start_requested = true
	_show_starting_state()
	_start_game(false)


func _on_sandbox_button_pressed() -> void:
	if start_requested:
		return
	start_requested = true
	_show_starting_state()
	_start_game(true)


func _start_game(use_sandbox_mode: bool) -> void:
	SessionState.selected_map_id = get_selected_map_id()
	SessionState.sandbox_mode = use_sandbox_mode
	get_tree().change_scene_to_packed.bind(GAMEPLAY_SCENE).call_deferred()


func _show_starting_state() -> void:
	normal_button.disabled = true
	sandbox_button.disabled = true
	subtitle.text = "Opening match..."
	footer.text = "Opening match..."


func _on_quit_button_pressed() -> void:
	get_tree().quit()
