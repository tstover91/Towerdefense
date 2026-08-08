class_name ExplosionZone
extends Node2D

const GameStats = preload("res://stat_database.gd")
const DISPLAY_DURATION := 0.45

var outer_radius := 0.0
var inner_radius := 0.0
var remaining_duration := DISPLAY_DURATION


func setup(explosion_radius: float) -> void:
	outer_radius = maxf(explosion_radius, 0.0)
	inner_radius = outer_radius * GameStats.EXPLOSION_INNER_RADIUS_RATIO
	remaining_duration = DISPLAY_DURATION
	queue_redraw()


func _process(delta: float) -> void:
	remaining_duration = maxf(remaining_duration - delta, 0.0)
	if remaining_duration <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if outer_radius <= 0.0:
		return
	var fade := clampf(remaining_duration / DISPLAY_DURATION, 0.0, 1.0)
	draw_circle(
		Vector2.ZERO,
		outer_radius,
		Color(1.0, 0.22, 0.08, 0.16 * fade)
	)
	draw_circle(
		Vector2.ZERO,
		inner_radius,
		Color(1.0, 0.78, 0.12, 0.30 * fade)
	)
	draw_arc(
		Vector2.ZERO,
		outer_radius,
		0.0,
		TAU,
		64,
		Color(1.0, 0.32, 0.12, 0.90 * fade),
		2.0,
		true
	)
	draw_arc(
		Vector2.ZERO,
		inner_radius,
		0.0,
		TAU,
		48,
		Color(1.0, 0.9, 0.3, 0.95 * fade),
		2.0,
		true
	)
