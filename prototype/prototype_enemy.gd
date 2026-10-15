class_name PrototypeEnemy
extends "res://prototype/grid_route_follower.gd"

signal defeated(enemy: Node2D)

const ENEMY_BODY_COLOR := Color("2b2b29")
const BODY_INSET := Color("ece8da")
const DAMAGE_FLASH_COLOR := Color("ef624d")
const HEALTH_BACKGROUND := Color("171717")
const HEALTH_COLOR := Color("e9b949")

var traits: Array[StringName] = []
var finished := false
var health := 1
var max_health := 1
var route_progress := 0.0
var leak_damage := 1
var visual_radius := 10.0
var damage_flash_remaining := 0.0
var current_cell_size := 48.0


func setup_combat(
	new_health: int,
	speed_cells_per_second: float,
	cell_size_pixels: float,
	new_leak_damage := 1
) -> void:
	max_health = maxi(new_health, 1)
	health = max_health
	speed_pixels_per_second = maxf(
		speed_cells_per_second * cell_size_pixels,
		1.0
	)
	leak_damage = maxi(new_leak_damage, 1)
	current_cell_size = maxf(cell_size_pixels, 1.0)
	visual_radius = maxf(cell_size_pixels * 0.18, 7.0)


func update_cell_scale(
	cell_size_pixels: float,
	speed_cells_per_second: float
) -> void:
	current_cell_size = maxf(cell_size_pixels, 1.0)
	speed_pixels_per_second = maxf(
		speed_cells_per_second * cell_size_pixels,
		1.0
	)
	visual_radius = maxf(cell_size_pixels * 0.18, 7.0)
	queue_redraw()


func _ready() -> void:
	add_to_group("mobs")
	queue_redraw()


func _process(delta: float) -> void:
	if finished:
		return
	var previous_position := position
	super._process(delta)
	route_progress += previous_position.distance_to(position) / current_cell_size
	damage_flash_remaining = maxf(damage_flash_remaining - delta, 0.0)
	queue_redraw()


func apply_damage(
	requested_damage: int,
	_damage_type: StringName = &"ballistic",
	_ignores_armor := false,
	_from_tower := true,
	_attack_context = null
) -> int:
	if finished or requested_damage <= 0:
		return 0
	var applied_damage := mini(requested_damage, health)
	health -= applied_damage
	damage_flash_remaining = 0.08
	if health <= 0:
		finished = true
		active = false
		defeated.emit(self)
	queue_redraw()
	return applied_damage


func apply_damage_from_tower(
	requested_damage: int,
	damage_type: StringName,
	ignores_armor: bool,
	_source_tower_id: StringName,
	attack_context = null
) -> int:
	return apply_damage(
		requested_damage,
		damage_type,
		ignores_armor,
		true,
		attack_context
	)


func mark_leaked() -> void:
	finished = true
	active = false


func get_projectile_hit_radius() -> float:
	return visual_radius


func get_route_progress() -> float:
	return route_progress


func _draw() -> void:
	var body_color := (
		DAMAGE_FLASH_COLOR if damage_flash_remaining > 0.0 else ENEMY_BODY_COLOR
	)
	var points := PackedVector2Array([
		Vector2(0.0, -visual_radius),
		Vector2(visual_radius, 0.0),
		Vector2(0.0, visual_radius),
		Vector2(-visual_radius, 0.0),
	])
	draw_colored_polygon(points, body_color)
	draw_polyline(PackedVector2Array([
		points[0], points[1], points[2], points[3], points[0]
	]), Color("111111"), 3.0, true)
	draw_circle(Vector2.ZERO, visual_radius * 0.36, BODY_INSET)
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	var bar_size := Vector2(visual_radius * 2.4, 4.0)
	var bar_position := Vector2(-bar_size.x * 0.5, -visual_radius - 9.0)
	draw_rect(Rect2(bar_position, bar_size), HEALTH_BACKGROUND, true)
	draw_rect(
		Rect2(bar_position, Vector2(bar_size.x * health_ratio, bar_size.y)),
		HEALTH_COLOR,
		true
	)
