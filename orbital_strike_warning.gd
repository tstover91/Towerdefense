class_name OrbitalStrikeWarning
extends Node2D

var radius := 64.0
var duration := 1.0
var elapsed := 0.0
var strike_callback: Callable


func setup(warning_radius: float, warning_duration: float, callback: Callable) -> void:
	radius = maxf(warning_radius, 1.0)
	duration = maxf(warning_duration, 0.05)
	strike_callback = callback
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed < duration:
		return
	if strike_callback.is_valid():
		strike_callback.call()
	queue_free()


func _draw() -> void:
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var pulse := 0.55 + sin(elapsed * 18.0) * 0.20
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.15, 0.05, 0.08 + progress * 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.35, 0.12, pulse), 3.0, true)
	draw_arc(Vector2.ZERO, radius * (1.0 - progress), 0.0, TAU, 48, Color(1.0, 0.9, 0.35, 0.9), 2.0, true)

