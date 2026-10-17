class_name PrototypeProjectile
extends Node2D

const GroundHazardScript = preload("res://prototype/prototype_ground_hazard.gd")

const BODY_COLOR := Color("efb83d")
const OUTLINE_COLOR := Color("171717")
const PROJECTILE_RADIUS := 4.0

var target: Node2D
var target_position := Vector2.ZERO
var uses_fixed_target := false
var speed := 420.0
var damage := 1
var splash_radius := 0.0
var stun_duration := 0.0
var source_tower: Node
var ground_hazard_duration := 0.0
var ground_hazard_tick_interval := 0.5
var ground_hazard_damage := 0
var ground_hazard_radius := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(new_target: Node2D, new_speed: float, new_damage: int, new_splash_radius := 0.0, new_source_tower: Node = null) -> void:
	target = new_target
	uses_fixed_target = false
	speed = maxf(new_speed, 1.0)
	damage = maxi(new_damage, 1)
	splash_radius = maxf(new_splash_radius, 0.0)
	source_tower = new_source_tower
	queue_redraw()


func setup_position(
	new_target_position: Vector2,
	new_speed: float,
	new_damage: int,
	new_splash_radius: float,
	new_source_tower: Node = null,
	new_stun_duration := 0.0,
	new_ground_hazard_duration := 0.0,
	new_ground_hazard_tick_interval := 0.5,
	new_ground_hazard_damage := 0,
	new_ground_hazard_radius := 0.0
) -> void:
	target = null
	target_position = new_target_position
	uses_fixed_target = true
	speed = maxf(new_speed, 1.0)
	damage = maxi(new_damage, 1)
	splash_radius = maxf(new_splash_radius, 0.0)
	source_tower = new_source_tower
	stun_duration = maxf(new_stun_duration, 0.0)
	ground_hazard_duration = maxf(new_ground_hazard_duration, 0.0)
	ground_hazard_tick_interval = maxf(new_ground_hazard_tick_interval, 0.01)
	ground_hazard_damage = maxi(new_ground_hazard_damage, 0)
	ground_hazard_radius = maxf(new_ground_hazard_radius, 0.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _is_valid_target():
		queue_free()
		return
	var destination := target_position if uses_fixed_target else target.global_position
	var offset := destination - global_position
	var hit_radius := PROJECTILE_RADIUS
	if not uses_fixed_target and target.has_method("get_projectile_hit_radius"):
		hit_radius += float(target.get_projectile_hit_radius())
	var travel_distance := speed * delta
	if offset.length() <= hit_radius + travel_distance:
		_resolve_impact(destination)
		queue_free()
		return
	if not offset.is_zero_approx():
		var direction := offset.normalized()
		global_position += direction * travel_distance
		rotation = direction.angle()


func _resolve_impact(impact_position: Vector2) -> void:
	if splash_radius > 0.0:
		_apply_splash(impact_position)
	elif is_instance_valid(target) and target.has_method("apply_damage"):
		_report_damage(int(target.apply_damage(damage, &"ballistic", false, true)))
	_spawn_ground_hazard(impact_position)


func _apply_splash(impact_position: Vector2) -> void:
	var total_applied := 0
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_instance_valid(candidate) or bool(candidate.get("finished")):
			continue
		if candidate.global_position.distance_to(impact_position) <= splash_radius:
			total_applied += int(candidate.apply_damage(damage, &"explosive", false, true))
			if stun_duration > 0.0 and candidate.has_method("apply_stun"):
				candidate.apply_stun(stun_duration)
	_report_damage(total_applied)


func _spawn_ground_hazard(impact_position: Vector2) -> void:
	if ground_hazard_duration <= 0.0 or ground_hazard_damage <= 0:
		return
	var hazard := GroundHazardScript.new() as Node2D
	get_tree().current_scene.add_child(hazard)
	hazard.global_position = impact_position
	hazard.setup(
		ground_hazard_radius if ground_hazard_radius > 0.0 else splash_radius,
		ground_hazard_duration,
		ground_hazard_tick_interval,
		ground_hazard_damage,
		source_tower
	)


func _report_damage(amount: int) -> void:
	if amount > 0 and is_instance_valid(source_tower) and source_tower.has_method("record_damage"):
		source_tower.record_damage(amount)


func _is_valid_target() -> bool:
	if uses_fixed_target:
		return true
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
