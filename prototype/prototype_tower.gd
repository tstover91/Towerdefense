class_name PrototypeTower
extends Node2D

signal damage_dealt(tower_type: StringName, tower_level: int, amount: int)

const ProjectileScript = preload("res://prototype/prototype_projectile.gd")

const TYPE_GUN: StringName = &"gun"
const TYPE_MORTAR: StringName = &"mortar"
const TYPE_BEAM: StringName = &"beam"
const TARGET_SCAN_INTERVAL := 0.10
const PARTICIPATED_SELL_RATIO := 0.70
const TYPE_DATA := {
	# Each price curve follows the same broad TDS shape: a cheap, modest first
	# upgrade, a defining midgame jump, and an expensive late-game capstone.
	TYPE_GUN: {"name": "GUN", "cost": 150, "upgrade_costs": [50, 300, 900], "color": Color("e84f3d"), "stats": [
		{"damage": 8, "interval": 0.80, "range_cells": 2.5},
		{"damage": 8, "interval": 0.60, "range_cells": 2.6},
		{"damage": 18, "interval": 0.45, "range_cells": 2.8},
		{"damage": 40, "interval": 0.40, "range_cells": 3.1},
	]},
	TYPE_MORTAR: {"name": "MORTAR", "cost": 350, "upgrade_costs": [150, 600, 1800], "color": Color("efb83d"), "splash_cells": [1.15, 1.20, 1.40, 1.70], "stats": [
		{"damage": 20, "interval": 2.00, "range_cells": 3.3},
		{"damage": 24, "interval": 1.80, "range_cells": 3.4},
		{"damage": 55, "interval": 1.70, "range_cells": 3.6},
		{"damage": 130, "interval": 1.55, "range_cells": 4.0},
	]},
	TYPE_BEAM: {"name": "BEAM", "cost": 750, "upgrade_costs": [200, 700, 2700], "color": Color("8c69d4"), "stats": [
		{"damage": 2, "interval": 0.25, "range_cells": 2.8, "ramp": 2},
		{"damage": 2, "interval": 0.20, "range_cells": 2.9, "ramp": 2},
		{"damage": 4, "interval": 0.20, "range_cells": 3.1, "ramp": 4},
		{"damage": 8, "interval": 0.16, "range_cells": 3.4, "ramp": 8},
	]},
}
const BODY_DARK := Color("171717")
const BODY_LIGHT := Color("f1ead8")
const RANGE_COLOR := Color(0.91, 0.31, 0.24, 0.12)
const RANGE_EDGE_COLOR := Color(0.91, 0.31, 0.24, 0.45)

var grid_cell := Vector2i.ZERO
var tower_type: StringName = TYPE_GUN
var level := 1
var selected := false
var cell_size_provider: Callable
var attack_cooldown := 0.0
var target_scan_remaining := 0.0
var target: Node2D
var aim_direction := Vector2.RIGHT
var total_investment := 0
var has_participated := false
var target_lock_time := 0.0


func _ready() -> void:
	# The board keeps processing placement input while SceneTree is paused.
	# Towers must opt back into ordinary pausable combat processing.
	process_mode = Node.PROCESS_MODE_PAUSABLE


static func get_build_cost(type: StringName) -> int:
	return int(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUN])["cost"])


static func get_type_name(type: StringName) -> String:
	return String(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUN])["name"])


static func get_base_range(type: StringName) -> float:
	return float(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUN])["stats"][0]["range_cells"])


func configure(new_grid_cell: Vector2i, new_cell_size_provider: Callable, new_tower_type: StringName = TYPE_GUN) -> void:
	grid_cell = new_grid_cell
	cell_size_provider = new_cell_size_provider
	tower_type = new_tower_type if TYPE_DATA.has(new_tower_type) else TYPE_GUN
	total_investment = get_build_cost(tower_type)
	queue_redraw()


func _process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	target_scan_remaining = maxf(target_scan_remaining - delta, 0.0)
	if not _is_valid_target(target) or not _is_target_in_range(target):
		_set_target(null)
	if target == null and target_scan_remaining <= 0.0:
		target_scan_remaining = TARGET_SCAN_INTERVAL
		_set_target(_select_target())
	if _is_valid_target(target):
		target_lock_time += delta
		var offset := target.global_position - global_position
		if not offset.is_zero_approx():
			aim_direction = offset.normalized()
		if attack_cooldown <= 0.0:
			_fire_at(target)
	queue_redraw()


func _set_target(new_target: Node2D) -> void:
	if target == new_target:
		return
	target = new_target
	target_lock_time = 0.0


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func can_upgrade() -> bool:
	return level < _get_level_stats_array().size()


func get_next_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var upgrade_costs: Array = TYPE_DATA[tower_type]["upgrade_costs"]
	return int(upgrade_costs[level - 1])


func upgrade(paid_cost: int) -> bool:
	if not can_upgrade() or paid_cost != get_next_upgrade_cost():
		return false
	level += 1
	total_investment += paid_cost
	attack_cooldown = minf(attack_cooldown, get_attack_interval())
	queue_redraw()
	return true


func mark_participated() -> void:
	has_participated = true


func get_sell_refund() -> int:
	return total_investment if not has_participated else floori(float(total_investment) * PARTICIPATED_SELL_RATIO)


func _get_level_stats_array() -> Array:
	return TYPE_DATA[tower_type]["stats"]


func _get_stats() -> Dictionary:
	return _get_level_stats_array()[level - 1]


func get_damage() -> int:
	return int(_get_stats()["damage"])


func get_attack_interval() -> float:
	return float(_get_stats()["interval"])


func get_range_cells() -> float:
	return float(_get_stats()["range_cells"])


func get_range_pixels() -> float:
	return get_range_cells() * get_cell_size()


func get_cell_size() -> float:
	return maxf(float(cell_size_provider.call()), 1.0) if cell_size_provider.is_valid() else 48.0


func get_summary() -> String:
	var targeting := "DENSEST · FIRST TIE" if tower_type == TYPE_MORTAR else "FIRST LOCK"
	return "%s L%d  ·  %d DMG  ·  %.2fs  ·  %.1f RANGE  ·  %s" % [get_type_name(tower_type), level, get_damage(), get_attack_interval(), get_range_cells(), targeting]


func _select_target() -> Node2D:
	return _select_best_cluster() if tower_type == TYPE_MORTAR else _select_first_target()


func _select_first_target() -> Node2D:
	var selected_target: Node2D
	var least_route_remaining := INF
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		var route_remaining := _get_route_remaining(candidate)
		if route_remaining < least_route_remaining - 0.01 or (is_equal_approx(route_remaining, least_route_remaining) and distance < closest_distance):
			selected_target = candidate
			least_route_remaining = route_remaining
			closest_distance = distance
	return selected_target


func _select_best_cluster() -> Node2D:
	var candidates: Array[Node] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if _is_valid_target(candidate) and _is_target_in_range(candidate):
			candidates.append(candidate)
	var selected_target: Node2D
	var best_count := -1
	var least_route_remaining := INF
	var splash_range := _get_splash_pixels()
	for candidate in candidates:
		var nearby := 0
		for other in candidates:
			if candidate.global_position.distance_to(other.global_position) <= splash_range:
				nearby += 1
		var route_remaining := _get_route_remaining(candidate)
		if nearby > best_count or (nearby == best_count and route_remaining < least_route_remaining):
			selected_target = candidate
			best_count = nearby
			least_route_remaining = route_remaining
	return selected_target


func _get_route_remaining(candidate: Node2D) -> float:
	if bool(candidate.get("active")) and candidate.has_method("get_route_distance_remaining"):
		return float(candidate.get_route_distance_remaining())
	return -float(candidate.get("route_progress"))


func _is_valid_target(candidate) -> bool:
	return candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and not bool(candidate.get("finished"))


func _is_target_in_range(candidate: Node2D) -> bool:
	return global_position.distance_squared_to(candidate.global_position) <= pow(get_range_pixels(), 2.0)


func _get_splash_pixels() -> float:
	return float(TYPE_DATA[TYPE_MORTAR]["splash_cells"][level - 1]) * get_cell_size() if tower_type == TYPE_MORTAR else 0.0


func _fire_at(current_target: Node2D) -> void:
	mark_participated()
	attack_cooldown = get_attack_interval()
	if tower_type == TYPE_BEAM:
		var ramp_step := mini(floori(target_lock_time / 0.8), 3)
		var ramp_damage := int(_get_stats().get("ramp", 0)) * ramp_step
		var applied_damage := int(current_target.apply_damage(get_damage() + ramp_damage, &"energy", true, true))
		record_damage(applied_damage)
		return
	var projectile := ProjectileScript.new() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + aim_direction * get_cell_size() * 0.22
	projectile.setup(current_target, maxf(get_cell_size() * (7.0 if tower_type == TYPE_MORTAR else 11.0), 300.0), get_damage(), _get_splash_pixels(), self)


func record_damage(amount: int) -> void:
	if amount > 0:
		damage_dealt.emit(tower_type, level, amount)


func _draw() -> void:
	var cell_size := get_cell_size()
	if selected:
		draw_circle(Vector2.ZERO, get_range_pixels(), RANGE_COLOR)
		draw_arc(Vector2.ZERO, get_range_pixels(), 0.0, TAU, 96, RANGE_EDGE_COLOR, 2.0, true)
	var body_size := cell_size * 0.76
	var body_rect := Rect2(Vector2.ONE * -body_size * 0.5, Vector2.ONE * body_size)
	var body_color: Color = TYPE_DATA[tower_type]["color"]
	draw_rect(body_rect, body_color, true)
	draw_rect(body_rect, BODY_DARK, false, maxf(cell_size * 0.055, 2.0))
	if tower_type == TYPE_MORTAR:
		draw_circle(Vector2.ZERO, cell_size * 0.22, BODY_DARK)
		draw_circle(Vector2.ZERO, cell_size * 0.12, BODY_LIGHT)
	elif tower_type == TYPE_BEAM:
		draw_circle(Vector2.ZERO, cell_size * 0.23, BODY_LIGHT)
		draw_line(Vector2.ZERO, aim_direction * cell_size * 0.40, body_color.lightened(0.3), maxf(cell_size * 0.10, 4.0), true)
		if _is_valid_target(target) and _is_target_in_range(target):
			draw_line(Vector2.ZERO, to_local(target.global_position), Color(0.72, 0.52, 1.0, 0.75), maxf(cell_size * 0.045, 2.0), true)
	else:
		draw_circle(Vector2.ZERO, cell_size * 0.20, BODY_LIGHT)
		draw_line(Vector2.ZERO, aim_direction * cell_size * 0.38, BODY_DARK, maxf(cell_size * 0.10, 4.0), true)
	for pip_index in level:
		var pip_x := (float(pip_index) - float(level - 1) * 0.5) * cell_size * 0.13
		draw_circle(Vector2(pip_x, body_size * 0.39), maxf(cell_size * 0.025, 1.5), BODY_DARK)
