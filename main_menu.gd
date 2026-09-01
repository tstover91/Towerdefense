extends Control

const MapData = preload("res://map_database.gd")
const BUILD_LABEL := "v0.1.2 · Android build 3"

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
	if not SessionState.gameplay_transition_failed.is_connected(
		_on_gameplay_transition_failed
	):
		SessionState.gameplay_transition_failed.connect(
			_on_gameplay_transition_failed
		)
	if not SessionState.gameplay_transition_status.is_connected(
		_on_gameplay_transition_status
	):
		SessionState.gameplay_transition_status.connect(
			_on_gameplay_transition_status
		)
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
	SessionState.start_normal_game(get_selected_map_id())


func _on_sandbox_button_pressed() -> void:
	if start_requested:
		return
	start_requested = true
	_show_starting_state()
	SessionState.start_sandbox_game(get_selected_map_id())


func _show_starting_state() -> void:
	normal_button.disabled = true
	sandbox_button.disabled = true
	subtitle.text = "Opening match..."
	footer.text = "Opening match..."


func _on_gameplay_transition_failed(message: String) -> void:
	start_requested = false
	normal_button.disabled = false
	sandbox_button.disabled = false
	subtitle.text = message
	footer.text = message


func _on_gameplay_transition_status(message: String) -> void:
	subtitle.text = message
	footer.text = "%s · %s" % [BUILD_LABEL, message]


func _on_quit_button_pressed() -> void:
	get_tree().quit()
