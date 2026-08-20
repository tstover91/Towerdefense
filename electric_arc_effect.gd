class_name ElectricArcEffect
extends Node2D

const LIFETIME := 0.22

var elapsed := 0.0
var endpoint := Vector2.ZERO


func setup(start_position: Vector2, end_position: Vector2) -> void:
	global_position = start_position
	endpoint = end_position - start_position
	queue_redraw()


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	add_to_group("electric_arc_effects")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf(elapsed / LIFETIME, 0.0, 1.0)
	var direction := endpoint.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for index in 7:
		var ratio := float(index) / 6.0
		var offset := 0.0
		if index > 0 and index < 6:
			offset = (5.0 if index % 2 == 0 else -5.0)
		points.append(endpoint * ratio + perpendicular * offset)
	draw_polyline(points, Color(0.15, 0.70, 1.0, 0.55 * alpha), 7.0, true)
	draw_polyline(points, Color(0.80, 0.97, 1.0, alpha), 2.0, true)
