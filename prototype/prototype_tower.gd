class_name PrototypeTower
extends Node2D

const GameStats = preload("res://stat_database.gd")
const ProjectileScene = preload("res://projectile.tscn")

const LEVEL_STATS: Array[Dictionary] = [
	{"damage": 8, "interval": 0.75, "range_cells": 3.2},
	{"damage": 13, "interval": 0.68, "range_cells": 3.4},
	{"damage": 24, "interval": 0.58, "range_cells": 3.8},
	{"damage": 48, "interval": 0.45, "range_cells": 4.3},
]
const TARGET_SCAN_INTERVAL := 0.10
const BUILD_COST := 100
const UPGRADE_COSTS: Array[int] = [100, 300, 800]
const PARTICIPATED_SELL_RATIO := 0.70
const BODY_COLOR := Color("e84f3d")
const BODY_DARK := Color("171717")
const BODY_LIGHT := Color("f1ead8")
const RANGE_COLOR := Color(0.91, 0.31, 0.24, 0.12)
const RANGE_EDGE_COLOR := Color(0.91, 0.31, 0.24, 0.45)

var grid_cell := Vector2i.ZERO
var level := 1
var selected := false
var cell_size_provider: Callable
var attack_cooldown := 0.0
var target_scan_remaining := 0.0
var target: Node2D
var aim_direction := Vector2.RIGHT
var total_investment := BUILD_COST
var has_participated := false


func configure(
	new_grid_cell: Vector2i,
	new_cell_size_provider: Callable
) -> void:
	grid_cell = new_grid_cell
	cell_size_provider = new_cell_size_provider
	queue_redraw()


func _process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	target_scan_remaining = maxf(target_scan_remaining - delta, 0.0)
	if not _is_valid_target(target) or not _is_target_in_range(target):
		target = null
	if target_scan_remaining <= 0.0:
		target_scan_remaining = TARGET_SCAN_INTERVAL
		target = _select_first_target()
	if _is_valid_target(target):
		var offset := target.global_position - global_position
		if not offset.is_zero_approx():
			aim_direction = offset.normalized()
		if attack_cooldown <= 0.0:
			_fire_at(target)
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func can_upgrade() -> bool:
	return level < LEVEL_STATS.size()


func get_next_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	return UPGRADE_COSTS[level - 1]


func upgrade(paid_cost: int) -> bool:
	if not can_upgrade():
		return false
	var expected_cost := get_next_upgrade_cost()
	if paid_cost != expected_cost:
		return false
	level += 1
	total_investment += expected_cost
	attack_cooldown = minf(attack_cooldown, get_attack_interval())
	queue_redraw()
	return true


func mark_participated() -> void:
	has_participated = true


func get_sell_refund() -> int:
	if not has_participated:
		return total_investment
	return floori(float(total_investment) * PARTICIPATED_SELL_RATIO)


func get_damage() -> int:
	return int(LEVEL_STATS[level - 1]["damage"])


func get_attack_interval() -> float:
	return float(LEVEL_STATS[level - 1]["interval"])


func get_range_cells() -> float:
	return float(LEVEL_STATS[level - 1]["range_cells"])


func get_range_pixels() -> float:
	return get_range_cells() * get_cell_size()


func get_cell_size() -> float:
	if cell_size_provider.is_valid():
		return maxf(float(cell_size_provider.call()), 1.0)
	return 48.0


func get_summary() -> String:
	return "TOWER L%d  ·  %d DMG  ·  %.2fs  ·  %.1f RANGE" % [
		level,
		get_damage(),
		get_attack_interval(),
		get_range_cells(),
	]


func _select_first_target() -> Node2D:
	var selected_target: Node2D
	var greatest_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var progress := float(candidate.get("route_progress"))
		if selected_target == null or progress > greatest_progress:
			selected_target = candidate
			greatest_progress = progress
	return selected_target


func _is_valid_target(candidate) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not bool(candidate.get("finished"))
	)


func _is_target_in_range(candidate: Node2D) -> bool:
	return global_position.distance_squared_to(candidate.global_position) <= pow(
		get_range_pixels(), 2.0
	)


func _fire_at(current_target: Node2D) -> void:
	mark_participated()
	attack_cooldown = get_attack_interval()
	var projectile := ProjectileScene.instantiate() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + aim_direction * get_cell_size() * 0.22
	projectile.setup(
		current_target,
		current_target.global_position,
		maxf(get_cell_size() * 11.0, 420.0),
		get_range_pixels(),
		get_damage(),
		&"ballistic",
		GameStats.IMPACT_PRIMARY,
		0.0,
		0,
		0.0,
		0.0,
		false,
		0,
		0.0,
		false,
		0.0,
		false,
		false,
		&"prototype_basic",
		true
	)


func _draw() -> void:
	var cell_size := get_cell_size()
	if selected:
		draw_circle(Vector2.ZERO, get_range_pixels(), RANGE_COLOR)
		draw_arc(
			Vector2.ZERO,
			get_range_pixels(),
			0.0,
			TAU,
			96,
			RANGE_EDGE_COLOR,
			2.0,
			true
		)
	var body_size := cell_size * 0.76
	var body_rect := Rect2(
		Vector2.ONE * -body_size * 0.5,
		Vector2.ONE * body_size
	)
	draw_rect(body_rect, BODY_COLOR, true)
	draw_rect(body_rect, BODY_DARK, false, maxf(cell_size * 0.055, 2.0))
	draw_circle(Vector2.ZERO, cell_size * 0.20, BODY_LIGHT)
	draw_line(
		Vector2.ZERO,
		aim_direction * cell_size * 0.38,
		BODY_DARK,
		maxf(cell_size * 0.10, 4.0),
		true
	)
	for pip_index in level:
		var pip_x := (float(pip_index) - float(level - 1) * 0.5) * cell_size * 0.13
		draw_circle(
			Vector2(pip_x, body_size * 0.39),
			maxf(cell_size * 0.025, 1.5),
			BODY_DARK
		)
