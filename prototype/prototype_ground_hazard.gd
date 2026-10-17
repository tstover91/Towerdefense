class_name PrototypeGroundHazard
extends Node2D

const FILL_COLOR := Color(0.93, 0.18, 0.06, 0.24)
const EDGE_COLOR := Color(1.0, 0.43, 0.08, 0.85)

var radius := 48.0
var duration := 3.0
var remaining := 3.0
var tick_interval := 0.5
var tick_remaining := 0.5
var damage := 1
var source_tower: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 5


func setup(new_radius: float, new_duration: float, new_tick_interval: float, new_damage: int, new_source_tower: Node = null) -> void:
	radius = maxf(new_radius, 1.0)
	duration = maxf(new_duration, 0.01)
	remaining = duration
	tick_interval = maxf(new_tick_interval, 0.01)
	tick_remaining = tick_interval
	damage = maxi(new_damage, 1)
	source_tower = new_source_tower
	queue_redraw()


func _process(delta: float) -> void:
	remaining -= delta
	tick_remaining -= delta
	while tick_remaining <= 0.0 and remaining >= -0.001:
		_apply_tick()
		tick_remaining += tick_interval
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()


func _apply_tick() -> void:
	var total_applied := 0
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or bool(candidate.get("finished")):
			continue
		if candidate.global_position.distance_to(global_position) <= radius:
			total_applied += int(candidate.apply_damage(damage, &"fire", false, true))
	if total_applied > 0 and is_instance_valid(source_tower) and source_tower.has_method("record_damage"):
		source_tower.record_damage(total_applied)


func _draw() -> void:
	var life_ratio := clampf(remaining / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, FILL_COLOR)
	draw_arc(Vector2.ZERO, radius * life_ratio, 0.0, TAU, 48, EDGE_COLOR, 3.0, true)
