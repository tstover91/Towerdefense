class_name PrototypeEnemy
extends "res://prototype/grid_route_follower.gd"

signal defeated(enemy: Node2D)

const TYPE_SOLDIER: StringName = &"soldier"
const TYPE_RUNNER: StringName = &"runner"
const TYPE_GIANT: StringName = &"giant"
const TYPE_CARRIER: StringName = &"carrier"
const TYPE_DATA := {
	TYPE_SOLDIER: {"health": 20, "speed": 1.15, "leak": 1, "radius": 0.17, "color": Color("2b2b29")},
	TYPE_RUNNER: {"health": 13, "speed": 1.85, "leak": 1, "radius": 0.14, "color": Color("d94f3d")},
	TYPE_GIANT: {"health": 95, "speed": 0.88, "leak": 3, "radius": 0.27, "color": Color("3c5264")},
	TYPE_CARRIER: {"health": 70, "speed": 0.96, "leak": 2, "radius": 0.24, "color": Color("75559a"), "releases": 4},
}
const BODY_INSET := Color("ece8da")
const DAMAGE_FLASH_COLOR := Color("ef624d")
const HEALTH_BACKGROUND := Color("171717")
const HEALTH_COLOR := Color("e9b949")

var enemy_type: StringName = TYPE_SOLDIER
var traits: Array[StringName] = []
var finished := false
var health := 1
var max_health := 1
var route_progress := 0.0
var leak_damage := 1
var visual_radius := 10.0
var damage_flash_remaining := 0.0
var current_cell_size := 48.0
var base_speed_cells_per_second := 1.15
var current_speed_cells_per_second := 1.15
var formation_id := -1
var formation_index := 0
var released_children := false


func setup_combat(new_type: StringName, health_scale: float, cell_size_pixels: float, new_formation_id := -1, new_formation_index := 0) -> void:
	enemy_type = new_type if TYPE_DATA.has(new_type) else TYPE_SOLDIER
	var data: Dictionary = TYPE_DATA[enemy_type]
	max_health = maxi(roundi(float(data["health"]) * maxf(health_scale, 0.1)), 1)
	health = max_health
	base_speed_cells_per_second = float(data["speed"])
	current_speed_cells_per_second = base_speed_cells_per_second
	leak_damage = int(data["leak"])
	formation_id = new_formation_id
	formation_index = new_formation_index
	current_cell_size = maxf(cell_size_pixels, 1.0)
	speed_pixels_per_second = base_speed_cells_per_second * current_cell_size
	visual_radius = maxf(current_cell_size * float(data["radius"]), 6.0)


func update_cell_scale(cell_size_pixels: float, _unused_speed := 0.0) -> void:
	current_cell_size = maxf(cell_size_pixels, 1.0)
	speed_pixels_per_second = current_speed_cells_per_second * current_cell_size
	visual_radius = maxf(current_cell_size * float(TYPE_DATA[enemy_type]["radius"]), 6.0)
	queue_redraw()


func _ready() -> void:
	add_to_group("mobs")
	queue_redraw()


func _process(delta: float) -> void:
	if finished:
		return
	_update_formation_speed()
	var previous_position := position
	super._process(delta)
	route_progress += previous_position.distance_to(position) / current_cell_size
	damage_flash_remaining = maxf(damage_flash_remaining - delta, 0.0)
	queue_redraw()


func _update_formation_speed() -> void:
	current_speed_cells_per_second = base_speed_cells_per_second
	if enemy_type == TYPE_RUNNER or formation_id < 0:
		speed_pixels_per_second = current_speed_cells_per_second * current_cell_size
		return
	var nearest_ahead: PrototypeEnemy
	var nearest_gap := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if candidate == self or not candidate is PrototypeEnemy or candidate.finished:
			continue
		if candidate.formation_id != formation_id or candidate.formation_index >= formation_index:
			continue
		var gap: float = route_progress - candidate.route_progress
		if gap < 0.0:
			gap = -gap
		if gap < nearest_gap:
			nearest_ahead = candidate
			nearest_gap = gap
	if nearest_ahead != null:
		if nearest_gap < 0.48:
			current_speed_cells_per_second = minf(current_speed_cells_per_second, nearest_ahead.current_speed_cells_per_second * 0.35)
		elif nearest_gap < 0.85:
			current_speed_cells_per_second = minf(current_speed_cells_per_second, nearest_ahead.current_speed_cells_per_second)
	speed_pixels_per_second = maxf(current_speed_cells_per_second * current_cell_size, 1.0)


func apply_damage(requested_damage: int, _damage_type: StringName = &"ballistic", _ignores_armor := false, _from_tower := true, _attack_context = null) -> int:
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


func apply_damage_from_tower(requested_damage: int, damage_type: StringName, ignores_armor: bool, _source_tower_id: StringName, attack_context = null) -> int:
	return apply_damage(requested_damage, damage_type, ignores_armor, true, attack_context)


func mark_leaked() -> void:
	finished = true
	active = false


func get_projectile_hit_radius() -> float:
	return visual_radius


func get_route_progress() -> float:
	return route_progress


func get_release_count() -> int:
	if released_children:
		return 0
	released_children = true
	return int(TYPE_DATA[enemy_type].get("releases", 0))


func _draw() -> void:
	var body_color: Color = DAMAGE_FLASH_COLOR if damage_flash_remaining > 0.0 else TYPE_DATA[enemy_type]["color"]
	if enemy_type == TYPE_GIANT:
		draw_circle(Vector2.ZERO, visual_radius, body_color)
		draw_arc(Vector2.ZERO, visual_radius, 0.0, TAU, 24, Color("111111"), 3.0, true)
		draw_rect(Rect2(Vector2(-visual_radius * 0.58, -visual_radius * 0.28), Vector2(visual_radius * 1.16, visual_radius * 0.56)), BODY_INSET, true)
	elif enemy_type == TYPE_CARRIER:
		var rect := Rect2(Vector2.ONE * -visual_radius, Vector2.ONE * visual_radius * 2.0)
		draw_rect(rect, body_color, true)
		draw_rect(rect, Color("111111"), false, 3.0)
		for offset in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)]:
			draw_circle(offset * visual_radius, visual_radius * 0.16, BODY_INSET)
	else:
		var points := PackedVector2Array([Vector2(0.0, -visual_radius), Vector2(visual_radius, 0.0), Vector2(0.0, visual_radius), Vector2(-visual_radius, 0.0)])
		draw_colored_polygon(points, body_color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("111111"), 3.0, true)
		draw_circle(Vector2.ZERO, visual_radius * (0.25 if enemy_type == TYPE_RUNNER else 0.36), BODY_INSET)
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	var bar_size := Vector2(visual_radius * 2.4, 4.0)
	var bar_position := Vector2(-bar_size.x * 0.5, -visual_radius - 9.0)
	draw_rect(Rect2(bar_position, bar_size), HEALTH_BACKGROUND, true)
	draw_rect(Rect2(bar_position, Vector2(bar_size.x * health_ratio, bar_size.y)), HEALTH_COLOR, true)
