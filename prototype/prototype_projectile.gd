class_name PrototypeProjectile
extends Node2D

const BODY_COLOR := Color("efb83d")
const OUTLINE_COLOR := Color("171717")
const PROJECTILE_RADIUS := 4.0

var target: Node2D
var speed := 420.0
var damage := 1
var splash_radius := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(new_target: Node2D, new_speed: float, new_damage: int, new_splash_radius := 0.0) -> void:
	target = new_target
	speed = maxf(new_speed, 1.0)
	damage = maxi(new_damage, 1)
	splash_radius = maxf(new_splash_radius, 0.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _is_valid_target():
		queue_free()
		return
	var offset := target.global_position - global_position
	var hit_radius := PROJECTILE_RADIUS
	if target.has_method("get_projectile_hit_radius"):
		hit_radius += float(target.get_projectile_hit_radius())
	var travel_distance := speed * delta
	if offset.length() <= hit_radius + travel_distance:
		if splash_radius > 0.0:
			_apply_splash(target.global_position)
		elif target.has_method("apply_damage"):
			target.apply_damage(damage, &"ballistic", false, true)
		queue_free()
		return
	if not offset.is_zero_approx():
		var direction := offset.normalized()
		global_position += direction * travel_distance
		rotation = direction.angle()


func _apply_splash(impact_position: Vector2) -> void:
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or bool(candidate.get("finished")):
			continue
		if candidate.global_position.distance_to(impact_position) <= splash_radius:
			candidate.apply_damage(damage, &"explosive", false, true)


func _is_valid_target() -> bool:
	return (
		target != null
		and is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and not bool(target.get("finished"))
	)


func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(-6.0, -3.0),
		Vector2(5.0, -3.0),
		Vector2(9.0, 0.0),
		Vector2(5.0, 3.0),
		Vector2(-6.0, 3.0),
	])
	draw_colored_polygon(points, BODY_COLOR)
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]),
		OUTLINE_COLOR,
		2.0,
		true
	)
