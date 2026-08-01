extends Node2D 

const GameStats = preload("res://stat_database.gd")
const RANGE_PIXELS_PER_UNIT := 12.9

enum TargetMode {
	FIRST,
	LAST,
	LOWEST_HEALTH,
	HIGHEST_HEALTH
	}

signal tower_confirmed()
signal tower_cancelled()
signal sell_tower

@export var target_mode: TargetMode = TargetMode.FIRST
@export var tower_id: StringName = GameStats.DEFAULT_TOWER_ID
@onready var tower_area: Area2D = $Tower  
@onready var rotator: Node2D = $Rotator
@onready var damage_timer: Timer = $Timer
@onready var upgrade_button: Button = $HBoxContainer/upgradetower
var tower_level := 0
var damage: int
var target: Node2D = null
var mobs_in_range: Array = []
var selected := false
var tower_confirm := false
var main : Node

func set_selected(value: bool):
	selected = value
	$HBoxContainer.visible = value
	
	if value:
		show_main_menu()
	else:
		close_menus()

func show_main_menu() -> void:
	$HBoxContainer.visible = true
	$targetui.visible = false
	update_upgrade_button()

func show_target_menu() -> void:
	$HBoxContainer.visible = false
	$targetui.visible = true

func update_upgrade_button() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]
	upgrade_button.text = "Upgrade\n$%d" % upgrade_cost
	upgrade_button.disabled = false

func show_upgrade_menu() -> void:
	$HBoxContainer.visible = false

func close_menus() -> void:
	selected = false
	$HBoxContainer.visible = false
	$targetui.visible = false

func confirm_menu(value: bool):
	tower_confirm = value
	$towerconfirm.visible = value
	
func _ready() -> void:
	load_level_stats()
	update_upgrade_button()
	tower_area.connect("body_entered", Callable(self, "_on_body_entered"))
	tower_area.connect("body_exited", Callable(self, "_on_body_exited"))
	damage_timer.timeout.connect(_apply_damage)
	damage_timer.start()
	$Tower.input_event.connect(_on_clickarea_input_event)
	add_to_group("towers")


func load_level_stats() -> void:
	var stats: Dictionary = GameStats.get_tower_level(tower_id, tower_level)
	damage = stats["damage"]
	damage_timer.wait_time = stats["firerate"]
	var range_shape := $Tower/CollisionShape2D.shape.duplicate() as CircleShape2D
	range_shape.radius = stats["range"] * RANGE_PIXELS_PER_UNIT
	$Tower/CollisionShape2D.shape = range_shape

func _apply_damage():
	if target != null :
		target.apply_damage(damage)

func _process(delta: float) -> void:
	var screen_top_limit := 100  # adjust as needed
	var global_y := global_position.y
	if global_y < screen_top_limit:
		$towerconfirm.position.y = 60  # move menu below tower
	_select_target()
	if target and is_instance_valid(target):
		var desired_angle = (target.global_position - rotator.global_position).angle()
		rotator.rotation = lerp_angle(rotator.rotation, desired_angle, 5.0 * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs"):
		mobs_in_range.append(body)

func _on_body_exited(body: Node2D) -> void:
	mobs_in_range.erase(body)
	if body == target:
		target = null

func _sort_by_progress(a, b):
	return a.path_follow.progress < b.path_follow.progress

func _sort_by_health(a, b):
	return a.health < b.health

func _select_target():
	mobs_in_range = mobs_in_range.filter(
		func(mob): return is_instance_valid(mob)
	)
	
	if mobs_in_range.is_empty():
		target = null
		return

	match target_mode:
		TargetMode.FIRST:
			mobs_in_range.sort_custom(Callable(self, "_sort_by_progress"))
			target = mobs_in_range.back()

		TargetMode.LAST:
			mobs_in_range.sort_custom(Callable(self, "_sort_by_progress"))
			target = mobs_in_range.front()

		TargetMode.LOWEST_HEALTH:
			mobs_in_range.sort_custom(Callable(self, "_sort_by_health"))
			target = mobs_in_range.front()

		TargetMode.HIGHEST_HEALTH:
			mobs_in_range.sort_custom(Callable(self, "_sort_by_health"))
			target = mobs_in_range.back()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		for tower in get_tree().get_nodes_in_group("towers"):
			tower.set_selected(false)

func _on_clickarea_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.pressed and not main.build_mode:
		for tower in get_tree().get_nodes_in_group("towers"):
			if tower != self:
				tower.set_selected(false)

		set_selected(true)

func _on_button_first_pressed() -> void:
	target_mode = TargetMode.FIRST
	close_menus()

func _on_button_last_pressed() -> void:
	target_mode = TargetMode.LAST
	close_menus()
	
func _on_button_low_pressed() -> void:
	target_mode = TargetMode.LOWEST_HEALTH
	close_menus()

func _on_button_high_pressed() -> void:
	target_mode = TargetMode.HIGHEST_HEALTH
	close_menus()

func _on_confirm_pressed() -> void:
	var sprite = $Rotator
	sprite.modulate = Color(1, 1, 1, 1)
	$clickarea/CollisionShape2D.disabled = false
	$Tower/CollisionShape2D.disabled = false
	$clickarea.set_process_input(true)
	$clickarea.set_physics_process(true)
	$clickarea.monitoring = true
	$clickarea.input_pickable = true
	$towerconfirm.visible = false
	emit_signal("tower_confirmed", self)
	
func _on_cancel_pressed() -> void:
	$towerconfirm.visible = false
	emit_signal("tower_cancelled", self)
	queue_free()

func _on_targetmode_pressed() -> void:
	show_target_menu()

func _on_upgradetower_pressed() -> void:	
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if main.spend_money(upgrade_cost):
		tower_level = next_level
		load_level_stats()
		update_upgrade_button()

func _on_selltower_pressed() -> void:
	pass # Replace with function body.
