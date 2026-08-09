class_name HitscanEffect
extends Node2D

var effect_type: StringName = &"ballistic"
var endpoint := Vector2.ZERO
var lifetime := 0.10
var elapsed := 0.0


func setup(
	start_position: Vector2,
	end_position: Vector2,
	attack_type: StringName
) -> void:
	global_position = start_position
	endpoint = end_position - start_position
	effect_type = attack_type
	match effect_type:
		&"electric":
			lifetime = 0.14
		&"melee":
			lifetime = 0.12
		&"beam":
			lifetime = 0.08
		_:
			lifetime = 0.10
	add_to_group("tower_attack_visuals")
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var alpha := 1.0 - progress
	match effect_type:
		&"electric":
			draw_electric_arc(alpha)
		&"melee":
			draw_melee_slash(alpha, progress)
		&"beam":
			draw_beam_pulse(alpha)
		_:
			draw_ballistic_tracer(alpha, progress)


func draw_ballistic_tracer(alpha: float, progress: float) -> void:
	var bullet_position := endpoint * minf(progress * 2.5, 1.0)
	var trail_start := endpoint * maxf(progress * 2.5 - 0.22, 0.0)
	draw_line(
		trail_start,
		bullet_position,
		Color(1.0, 0.72, 0.2, 0.75 * alpha),
		2.0,
		true
	)
	draw_circle(bullet_position, 2.4, Color(1.0, 0.92, 0.55, alpha))


func draw_electric_arc(alpha: float) -> void:
	var distance := endpoint.length()
	if distance <= 0.0:
		return
	var direction := endpoint / distance
	var perpendicular := direction.orthogonal()
	var points := PackedVector2Array()
	var segment_count := maxi(ceili(distance / 18.0), 3)
	for index in range(segment_count + 1):
		var ratio := float(index) / float(segment_count)
		var offset := 0.0
		if index > 0 and index < segment_count:
			offset = (4.0 if index % 2 == 0 else -4.0) * sin(PI * ratio)
		points.append(endpoint * ratio + perpendicular * offset)
	draw_polyline(points, Color(0.45, 0.9, 1.0, alpha), 2.5, true)


func draw_melee_slash(alpha: float, progress: float) -> void:
	var attack_angle := endpoint.angle()
	var slash_center := endpoint
	var sweep_start := attack_angle - 1.15 + progress * 0.5
	var sweep_end := attack_angle + 1.15 + progress * 0.5
	draw_arc(
		slash_center,
		14.0,
		sweep_start,
		sweep_end,
		18,
		Color(1.0, 0.88, 0.65, alpha),
		3.0,
		true
	)


func draw_beam_pulse(alpha: float) -> void:
	draw_line(endpoint * 0.02, endpoint, Color(0.65, 0.25, 1.0, 0.35 * alpha), 6.0, true)
	draw_line(endpoint * 0.02, endpoint, Color(0.95, 0.75, 1.0, alpha), 2.0, true)
