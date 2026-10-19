extends Node

const MODE_SELECT_SCENE := "res://prototype/prototype_mode_select.tscn"


func _ready() -> void:
	$HUD/TopBar/BackButton.pressed.connect(_return_to_mode_select)
	$HUD/BottomBar/AttackButton.pressed.connect(_start_attack)
	$HUD/BottomBar/RebuildButton.pressed.connect(_rebuild)
	$HUD/BottomBar/SpeedButton.pressed.connect(_toggle_speed)
	$HUD/BottomBar/ViewButton.pressed.connect(_reset_view)
	$HUD/BottomBar/EditButton.pressed.connect(_toggle_edit_mode)
	$SiegeCombat.status_changed.connect(_on_status_changed)
	$SiegeCombat.wave_started.connect(_on_wave_started)
	$SiegeCombat.wave_finished.connect(_on_wave_finished)
	$SiegeBoard.edit_status_changed.connect(_on_status_changed)
	$SiegeBoard.set_edit_mode(true)
	$HUD/TopBar/BackButton.grab_focus()


func _return_to_mode_select() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE)


func _start_attack() -> void:
	$SiegeBoard.capture_current_blueprint()
	$SiegeBoard.set_edit_mode(false)
	$HUD/BottomBar/EditButton.disabled = true
	$HUD/BottomBar/EditButton.text = "BASE LOCKED"
	$SiegeCombat.start_demo_wave()


func _rebuild() -> void:
	$SiegeCombat.reset_fortress()
	$SiegeBoard.set_edit_mode(true)
	$HUD/BottomBar/AttackButton.disabled = false
	$HUD/BottomBar/EditButton.disabled = false
	$HUD/BottomBar/EditButton.text = "EDIT: ON"


func _toggle_speed() -> void:
	var next_speed := 2.0 if is_equal_approx($SiegeCombat.combat_speed, 1.0) else 1.0
	$SiegeCombat.set_combat_speed(next_speed)
	$HUD/BottomBar/SpeedButton.text = "%d× SPEED" % int(next_speed)


func _reset_view() -> void:
	$SiegeBoard.reset_view()


func _toggle_edit_mode() -> void:
	var enabled: bool = not $SiegeBoard.is_edit_mode()
	$SiegeBoard.set_edit_mode(enabled)
	$HUD/BottomBar/EditButton.text = "EDIT: ON" if enabled else "EDIT: OFF"
	_on_status_changed("Tap a structure, then its destination" if enabled else "Base editing off · drag to inspect the fortress")


func _on_status_changed(text: String) -> void:
	$HUD/BottomBar/Status.text = text


func _on_wave_started() -> void:
	$HUD/BottomBar/AttackButton.disabled = true
	$HUD/BottomBar/EditButton.disabled = true


func _on_wave_finished(_result: StringName) -> void:
	$HUD/BottomBar/AttackButton.disabled = false
