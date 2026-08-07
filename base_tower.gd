class_name BaseTower
extends Node2D

const GameStats = preload("res://stat_database.gd")
const DEFAULT_PROJECTILE_SCENE = preload("res://projectile.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const BUILD_CELL_SIZE := GameStats.BUILD_CELL_SIZE
const MENU_HALF_WIDTH := 106.0
const MENU_EDGE_MARGIN := 8.0

const TYPE_TECHNOLOGY: StringName = &"technology"
const TYPE_BIOLOGICAL: StringName = &"biological"

const ATTACK_BALLISTIC: StringName = &"ballistic"
const ATTACK_BEAM: StringName = &"beam"
const ATTACK_EXPLOSIVE: StringName = &"explosive"
const ATTACK_MELEE: StringName = &"melee"
const ATTACK_ELECTRIC: StringName = &"electric"

const BONUS_CRITICAL: StringName = &"critical"
const BONUS_PSIONIC: StringName = &"psionic"
const BONUS_REVEAL: StringName = &"reveal"
const BONUS_PIERCE: StringName = &"pierce"
const BONUS_STUN: StringName = &"stun"
const BONUS_SPAWNER: StringName = &"spawner"

enum TargetMode {
	FIRST,
	LAST,
	LOWEST_HEALTH,
	HIGHEST_HEALTH,
}

enum MenuAction {
	NONE,
	UPGRADE,
	SELL,
}



signal tower_confirmed(tower: Node2D)
signal tower_cancelled(tower: Node2D)
signal tower_sold(tower: Node2D)

var type_tags: Array[StringName] = []
var attack_tags: Array[StringName] = []
var bonus_tags: Array[StringName] = []
@export var target_mode: TargetMode = TargetMode.FIRST
@export var tower_id: StringName = GameStats.DEFAULT_TOWER_ID
@export var projectile_scene: PackedScene = DEFAULT_PROJECTILE_SCENE
@onready var tower_area: Area2D = $Tower
@onready var rotator: Node2D = $Rotator
@onready var muzzle: Marker2D = $Rotator/Muzzle
@onready var damage_timer: Timer = $Timer
@onready var upgrade_button: Button = $HBoxContainer/upgradetower
var tower_level := 0
var damage: int
var damage_type: StringName = &"physical"
var projectile_speed := 600.0
var splash_radius_pixels := 0.0
var footprint_size_pixels := Vector2(BUILD_CELL_SIZE, BUILD_CELL_SIZE)
var target: Node2D = null
var mobs_in_range: Array = []
var selected := false
var is_placed := false
var pending_action: MenuAction = MenuAction.NONE
var range_radius_pixels := 0.0
var upgrade_range_radius_pixels := -1.0
var range_preview_visible := false
var range_preview_valid := true
var main: Node


func _draw() -> void:
	if not range_preview_visible:
		return

	if not is_placed:
		var footprint_rect := Rect2(-footprint_size_pixels * 0.5, footprint_size_pixels)
		var footprint_fill := Color(0.2, 0.85, 0.3, 0.2)
		var footprint_border := Color(0.25, 1.0, 0.35, 0.95)
		if not range_preview_valid:
			footprint_fill = Color(1.0, 0.15, 0.15, 0.22)
			footprint_border = Color(1.0, 0.2, 0.2, 0.95)
		draw_rect(footprint_rect, footprint_fill, true)
		draw_rect(footprint_rect, footprint_border, false, 2.0)

	if upgrade_range_radius_pixels >= 0.0:
		draw_circle(
			Vector2.ZERO,
			upgrade_range_radius_pixels,
			Color(1.0, 0.75, 0.15, 0.12)
		)
		draw_arc(
			Vector2.ZERO,
			upgrade_range_radius_pixels,
			0.0,
			TAU,
			96,
			Color(1.0, 0.8, 0.2, 0.9),
			2.0,
			true
		)

	var fill_color := Color(0.2, 0.85, 0.3, 0.16)
	var border_color := Color(0.25, 1.0, 0.35, 0.8)

	if not range_preview_valid:
		fill_color = Color(1.0, 0.15, 0.15, 0.16)
		border_color = Color(1.0, 0.2, 0.2, 0.8)

	draw_circle(Vector2.ZERO, range_radius_pixels, fill_color)
	draw_arc(Vector2.ZERO, range_radius_pixels, 0.0, TAU, 96, border_color, 2.0, true)


func set_range_preview(value: bool, placement_is_valid := true) -> void:
	if (
		range_preview_visible == value
		and range_preview_valid == placement_is_valid
		and upgrade_range_radius_pixels < 0.0
	):
		return

	range_preview_visible = value
	range_preview_valid = placement_is_valid
	upgrade_range_radius_pixels = -1.0
	queue_redraw()


func show_current_range_preview() -> void:
	range_preview_visible = true
	range_preview_valid = true
	upgrade_range_radius_pixels = -1.0
	queue_redraw()


func show_upgrade_range_preview() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		show_current_range_preview()
		return

	range_preview_visible = true
	range_preview_valid = true
	upgrade_range_radius_pixels = (
		get_effective_stats_for_level(next_level)["range"]
		* RANGE_PIXELS_PER_UNIT
	)
	queue_redraw()

func set_selected(value: bool) -> void:
	selected = value
	$HBoxContainer.visible = value
	
	if value:
		show_main_menu()
		show_current_range_preview()
		if main != null:
			main.show_tower_details(self)
	else:
		close_menus()

func show_main_menu() -> void:
	pending_action = MenuAction.NONE
	$HBoxContainer.visible = true
	$targetui.visible = false
	update_menu_buttons()

func show_target_menu() -> void:
	pending_action = MenuAction.NONE
	show_current_range_preview()
	$HBoxContainer.visible = false
	$targetui.visible = true

func update_sell_button() -> void:
	var sell_price := get_sell_price()

	if pending_action == MenuAction.SELL:
		$HBoxContainer/selltower.text = "Confirm\n$%d" % sell_price
	else:
		$HBoxContainer/selltower.text = "Sell\n$%d" % sell_price

func update_upgrade_button() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		upgrade_button.text = "MAX LEVEL"
		upgrade_button.disabled = true
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if pending_action == MenuAction.UPGRADE:
		upgrade_button.text = "Confirm\n$%d" % upgrade_cost
	else:
		upgrade_button.text = "Upgrade\n$%d" % upgrade_cost

	upgrade_button.disabled = main == null or main.money < upgrade_cost


func update_menu_buttons() -> void:
	update_upgrade_button()
	update_sell_button()
	$HBoxContainer/targetmode.text = "Target\n%s" % get_target_mode_name()

func close_menus() -> void:
	pending_action = MenuAction.NONE
	selected = false
	$HBoxContainer.visible = false
	$targetui.visible = false
	set_range_preview(false)
	if main != null:
		main.clear_tower_details(self)


func get_target_mode_name() -> String:
	match target_mode:
		TargetMode.FIRST:
			return "First"
		TargetMode.LAST:
			return "Last"
		TargetMode.LOWEST_HEALTH:
			return "Lowest HP"
		TargetMode.HIGHEST_HEALTH:
			return "Highest HP"
	return "Unknown"


func get_total_invested() -> int:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var total: int = tower_data["placement_cost"]

	for level in range(1, tower_level + 1):
		total += levels[level]["upgrade_cost"]

	return total

func get_sell_price() -> int:
	return floori(get_total_invested() / 3.0)

func _ready() -> void:
	load_base_tags()
	load_level_stats()
	update_menu_buttons()
	if main != null:
		main.money_changed.connect(_on_main_money_changed)
	tower_area.body_entered.connect(_on_body_entered)
	tower_area.body_exited.connect(_on_body_exited)
	damage_timer.timeout.connect(_apply_damage)
	begin_placement()
	add_to_group("towers")


func _on_main_money_changed(_new_amount: int) -> void:
	update_menu_buttons()


func begin_placement() -> void:
	is_placed = false
	damage_timer.stop()
	tower_area.monitoring = false
	$Tower/CollisionShape2D.disabled = true
	$clickarea.monitoring = false
	$clickarea.input_pickable = false
	$clickarea/CollisionShape2D.disabled = true


func confirm_placement() -> void:
	is_placed = true
	tower_area.monitoring = true
	$Tower/CollisionShape2D.disabled = false
	$clickarea.monitoring = true
	$clickarea.input_pickable = true
	$clickarea/CollisionShape2D.disabled = false
	damage_timer.start()


func load_level_stats() -> void:
	var stats := get_effective_stats_for_level(tower_level)
	var tower_data := GameStats.get_tower(tower_id)
	footprint_size_pixels = (
		Vector2(tower_data.get("footprint_cells", Vector2i.ONE))
		* BUILD_CELL_SIZE
	)
	var click_shape := $clickarea/CollisionShape2D.shape.duplicate() as RectangleShape2D
	click_shape.size = footprint_size_pixels
	$clickarea/CollisionShape2D.shape = click_shape
	damage = stats["damage"]
	damage_type = stats.get("damage_type", &"physical")
	projectile_speed = stats.get("projectile_speed", 600.0)
	splash_radius_pixels = float(stats.get("splash_radius", 0.0)) * RANGE_PIXELS_PER_UNIT
	damage_timer.wait_time = stats["firerate"]
	var range_shape := $Tower/CollisionShape2D.shape.duplicate() as CircleShape2D
	range_radius_pixels = stats["range"] * RANGE_PIXELS_PER_UNIT
	range_shape.radius = range_radius_pixels
	$Tower/CollisionShape2D.shape = range_shape
	queue_redraw()


func get_effective_stats_for_level(level: int) -> Dictionary:
	var stats := GameStats.get_tower_level(tower_id, level)
	stats["damage"] = roundi(
		float(stats["damage"]) + get_main_bonus(&"tower_damage_flat")
	)
	stats["firerate"] = maxf(
		float(stats["firerate"]) / get_main_multiplier(&"tower_attack_speed"),
		0.01
	)
	stats["range"] = float(stats["range"]) * get_main_multiplier(&"tower_range")
	stats["dps"] = float(stats["damage"]) / float(stats["firerate"])
	return stats


func get_sidebar_stats() -> Dictionary:
	var tower_data := GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var current_stats := get_effective_stats_for_level(tower_level)
	var next_level := tower_level + 1
	var result := {
		"display_name": tower_data["display_name"],
		"is_placed": is_placed,
		"level": tower_level,
		"maximum_level": levels.size() - 1,
		"dps": current_stats["dps"],
		"has_next_level": next_level < levels.size(),
		"show_upgrade_info": is_placed and pending_action == MenuAction.UPGRADE,
	}

	if next_level < levels.size():
		var next_stats := get_effective_stats_for_level(next_level)
		result["next_level"] = next_level
		result["next_dps"] = next_stats["dps"]
	return result


func get_main_bonus(effect: StringName) -> float:
	if main == null:
		return 0.0
	return main.get_run_bonus(effect)


func get_main_multiplier(effect: StringName) -> float:
	return 1.0 + get_main_bonus(effect)

func _apply_damage() -> void:
	if not is_placed:
		return

	_select_target()
	if is_valid_target(target):
		attack(target)


func attack(current_target: Node2D) -> void:
	if not is_instance_valid(current_target):
		return

	var target_position := current_target.global_position
	if splash_radius_pixels > 0.0:
		apply_splash_damage(target_position)
	else:
		current_target.apply_damage(damage, damage_type)

	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate() as TowerProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.setup(target_position, projectile_speed)


func apply_splash_damage(impact_position: Vector2) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if (
			is_valid_target(mob)
			and mob.global_position.distance_to(impact_position) <= splash_radius_pixels
		):
			mob.apply_damage(damage, damage_type)

func _process(delta: float) -> void:
	update_menu_layout()
	if not is_placed:
		return
	if not is_valid_target(target):
		_select_target()
	if is_valid_target(target):
		var desired_angle = (target.global_position - rotator.global_position).angle()
		rotator.rotation = lerp_angle(rotator.rotation, desired_angle, 5.0 * delta)


func update_menu_layout() -> void:
	if (
		not $towerconfirm.visible
		and not $HBoxContainer.visible
		and not $targetui.visible
	):
		return

	var viewport_size := get_viewport_rect().size
	var screen_position := get_global_transform_with_canvas().origin
	var menu_right_edge := viewport_size.x
	if main != null and main.has_method("get_playable_right_edge"):
		menu_right_edge = minf(menu_right_edge, main.get_playable_right_edge())
	var menu_center_x := clampf(
		screen_position.x,
		MENU_HALF_WIDTH + MENU_EDGE_MARGIN,
		menu_right_edge - MENU_HALF_WIDTH - MENU_EDGE_MARGIN
	)
	var x_offset := menu_center_x - screen_position.x
	var place_below := screen_position.y < 240.0
	var target_y: float = 50.0 if place_below else -$targetui.size.y - MENU_EDGE_MARGIN
	target_y = clampf(
		target_y,
		MENU_EDGE_MARGIN - screen_position.y,
		viewport_size.y - MENU_EDGE_MARGIN - $targetui.size.y - screen_position.y
	)

	$towerconfirm.position = Vector2(-40.0 + x_offset, 50.0 if place_below else -106.0)
	$HBoxContainer.position = Vector2(-106.0 + x_offset, 50.0 if place_below else -90.0)
	$targetui.position = Vector2(-60.0 + x_offset, target_y)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs") and not mobs_in_range.has(body):
		mobs_in_range.append(body)
		if not is_valid_target(target):
			_select_target()

func _on_body_exited(body: Node2D) -> void:
	mobs_in_range.erase(body)
	if body == target:
		target = null

func is_valid_target(candidate: Node) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)


func _select_target() -> void:
	mobs_in_range = mobs_in_range.filter(
		func(mob):
			return is_valid_target(mob)
	)
	
	if mobs_in_range.is_empty():
		target = null
		return

	target = mobs_in_range[0]
	for candidate in mobs_in_range:
		match target_mode:
			TargetMode.FIRST:
				if candidate.path_follow.progress > target.path_follow.progress:
					target = candidate
			TargetMode.LAST:
				if candidate.path_follow.progress < target.path_follow.progress:
					target = candidate
			TargetMode.LOWEST_HEALTH:
				if candidate.health < target.health:
					target = candidate
			TargetMode.HIGHEST_HEALTH:
				if candidate.health > target.health:
					target = candidate

func _on_clickarea_input_event(_viewport, event, _shape_idx) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and main != null
		and main.can_select_tower()
	):
		main.close_all_tower_menus()
		set_selected(true)

func _on_button_first_pressed() -> void:
	target_mode = TargetMode.FIRST
	_select_target()
	close_menus()

func _on_button_last_pressed() -> void:
	target_mode = TargetMode.LAST
	_select_target()
	close_menus()
	
func _on_button_low_pressed() -> void:
	target_mode = TargetMode.LOWEST_HEALTH
	_select_target()
	close_menus()

func _on_button_high_pressed() -> void:
	target_mode = TargetMode.HIGHEST_HEALTH
	_select_target()
	close_menus()

func _on_confirm_pressed() -> void:
	var sprite = $Rotator
	set_range_preview(false)
	sprite.modulate = Color(1, 1, 1, 1)
	confirm_placement()
	$towerconfirm.visible = false
	tower_confirmed.emit(self)
	
func _on_cancel_pressed() -> void:
	$towerconfirm.visible = false
	tower_cancelled.emit(self)
	queue_free()

func _on_targetmode_pressed() -> void:
	show_target_menu()
	if main != null and selected:
		main.show_tower_details(self)

func _on_upgradetower_pressed() -> void:
	if pending_action != MenuAction.UPGRADE:
		pending_action = MenuAction.UPGRADE
		show_upgrade_range_preview()
		update_menu_buttons()
		if main != null and selected:
			main.show_tower_details(self)
		return

	var tower_data: Dictionary = GameStats.get_tower(tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower_level + 1

	if next_level >= levels.size():
		return

	var upgrade_cost: int = levels[next_level]["upgrade_cost"]

	if main.spend_money(upgrade_cost):
		tower_level = next_level
		load_level_stats()

	pending_action = MenuAction.NONE
	show_current_range_preview()
	update_menu_buttons()
	if main != null and selected:
		main.show_tower_details(self)

func _on_selltower_pressed() -> void:
	if pending_action != MenuAction.SELL:
		pending_action = MenuAction.SELL
		show_current_range_preview()
		update_menu_buttons()
		if main != null and selected:
			main.show_tower_details(self)
		return

	main.add_money(get_sell_price())
	tower_sold.emit(self)
	close_menus()
	queue_free()

func has_type_tag(tag: StringName) -> bool:
	return type_tags.has(tag)

func has_attack_tag(tag: StringName) -> bool:
	return attack_tags.has(tag)

func has_bonus_tag(tag: StringName) -> bool:
	return bonus_tags.has(tag)


func add_type_tag(tag: StringName) -> void:
	if not type_tags.has(tag):
		type_tags.append(tag)


func add_attack_tag(tag: StringName) -> void:
	if not attack_tags.has(tag):
		attack_tags.append(tag)


func add_bonus_tag(tag: StringName) -> void:
	if not bonus_tags.has(tag):
		bonus_tags.append(tag)


func remove_type_tag(tag: StringName) -> void:
	type_tags.erase(tag)


func remove_attack_tag(tag: StringName) -> void:
	attack_tags.erase(tag)


func remove_bonus_tag(tag: StringName) -> void:
	bonus_tags.erase(tag)
	
func load_base_tags() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower_id)

	type_tags.clear()
	attack_tags.clear()
	bonus_tags.clear()

	for tag in tower_data.get("type_tags", []):
		type_tags.append(tag)

	for tag in tower_data.get("attack_tags", []):
		attack_tags.append(tag)

	for tag in tower_data.get("bonus_tags", []):
		bonus_tags.append(tag)
