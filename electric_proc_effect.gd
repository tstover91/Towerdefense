class_name ElectricProcEffect
extends Node2D

const LIFETIME := 0.32

var elapsed := 0.0
var area_radius := 0.0


func setup_area_radius(radius: float) -> void:
	area_radius = maxf(radius, 0.0)
	queue_redraw()


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	add_to_group("electric_proc_effects")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf(elapsed / LIFETIME, 0.0, 1.0)
	var outer_color := Color(0.15, 0.70, 1.0, 0.45 * alpha)
	var core_color := Color(0.80, 0.97, 1.0, alpha)
	var bolt := PackedVector2Array([
		Vector2(-8.0, -96.0),
		Vector2(7.0, -76.0),
		Vector2(-5.0, -57.0),
		Vector2(9.0, -38.0),
		Vector2(-3.0, -19.0),
		Vector2.ZERO,
	])
	draw_polyline(bolt, outer_color, 9.0, true)
	draw_polyline(bolt, core_color, 3.0, true)
	draw_circle(Vector2.ZERO, 22.0 * alpha, outer_color)
	draw_arc(
		Vector2.ZERO,
		30.0 * alpha,
		0.0,
		TAU,
		24,
		core_color,
		3.0,
		true
	)
	if area_radius > 0.0:
		var expansion := 0.65 + 0.35 * clampf(elapsed / LIFETIME, 0.0, 1.0)
		draw_arc(
			Vector2.ZERO,
			area_radius * expansion,
			0.0,
			TAU,
			32,
			Color(0.35, 0.85, 1.0, 0.75 * alpha),
			2.0,
			true
		)
