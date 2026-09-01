extends Control

const MapData = preload("res://map_database.gd")

@onready var map_selector: OptionButton = $Content/Card/Content/MapSelector
@onready var normal_button: Button = $Content/Card/Content/LevelButtons/NormalButton
@onready var sandbox_button: Button = $Content/Card/Content/LevelButtons/SandboxButton
@onready var footer: Label = $Content/Card/Content/Footer

var map_ids: Array[StringName] = []


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	populate_map_selector()
	if not SessionState.gameplay_transition_failed.is_connected(
		_on_gameplay_transition_failed
	):
		SessionState.gameplay_transition_failed.connect(
			_on_gameplay_transition_failed
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
	_show_starting_state()
	SessionState.start_normal_game(get_selected_map_id())


func _on_sandbox_button_pressed() -> void:
	_show_starting_state()
	SessionState.start_sandbox_game(get_selected_map_id())


func _show_starting_state() -> void:
	normal_button.disabled = true
	sandbox_button.disabled = true
	footer.text = "Opening match..."


func _on_gameplay_transition_failed(message: String) -> void:
	normal_button.disabled = false
	sandbox_button.disabled = false
	footer.text = message


func _on_quit_button_pressed() -> void:
	get_tree().quit()
