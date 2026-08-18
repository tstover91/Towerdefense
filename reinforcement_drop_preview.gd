class_name ReinforcementDropPreview
extends Node2D

var command_radius_pixels := 1.0
var placement_valid := true


func _ready() -> void:
	z_index = 50


func configure(radius_pixels: float) -> void:
	command_radius_pixels = maxf(radius_pixels, 1.0)
	queue_redraw()


func set_preview_position(world_position: Vector2, is_valid: bool) -> void:
	global_position = world_position
	if placement_valid != is_valid:
		placement_valid = is_valid
		queue_redraw()


func _draw() -> void:
	var color := (
		Color(0.35, 1.0, 0.5, 0.75)
		if placement_valid
		else Color(1.0, 0.25, 0.2, 0.75)
	)
	draw_circle(Vector2.ZERO, command_radius_pixels, Color(color, 0.06))
	draw_arc(Vector2.ZERO, command_radius_pixels, 0.0, TAU, 64, color, 2.0, true)
	draw_circle(Vector2.ZERO, 7.0, Color(color, 0.3))
	for unit_index in 3:
		var angle := -PI * 0.5 + TAU * float(unit_index) / 3.0
		draw_circle(Vector2.from_angle(angle) * 18.0, 5.0, color)
