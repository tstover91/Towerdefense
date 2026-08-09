class_name SaucerFlyer
extends Node2D

const RETURN_DISTANCE := 3.0

var parent_tower
var attack_cooldown := 0.0
var abduction_cooldown := 0.0
var target: Node2D
var abduction_flash_remaining := 0.0


func setup(tower: Node2D) -> void:
	parent_tower = tower
	global_position = tower.global_position
	abduction_cooldown = float(parent_tower.saucer_abduction_cooldown)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(parent_tower) or parent_tower.is_queued_for_deletion():
		queue_free()
		return

	abduction_flash_remaining = maxf(abduction_flash_remaining - delta, 0.0)
	if not parent_tower.is_saucer_combat_active():
		target = null
		attack_cooldown = 0.0
		abduction_cooldown = float(parent_tower.saucer_abduction_cooldown)
		move_toward_position(parent_tower.global_position, delta)
		queue_redraw()
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	abduction_cooldown = maxf(abduction_cooldown - delta, 0.0)
	target = parent_tower.get_saucer_target()
	if not is_valid_target(target):
		target = null
		move_toward_position(parent_tower.global_position, delta)
		queue_redraw()
		return

	var can_abduct: bool = (
		abduction_cooldown <= 0.0
		and parent_tower.saucer_can_abduct_target(target)
	)
	var desired_radius := float(parent_tower.saucer_attack_radius_pixels) * 0.8
	if can_abduct:
		desired_radius = float(parent_tower.saucer_abduction_radius_pixels) * 0.8
	var distance_to_target := global_position.distance_to(target.global_position)
	if distance_to_target > desired_radius:
		move_toward_position(target.global_position, delta)
		distance_to_target = global_position.distance_to(target.global_position)

	if (
		can_abduct
		and distance_to_target <= float(parent_tower.saucer_abduction_radius_pixels)
		and parent_tower.try_saucer_abduction(target, global_position)
	):
		abduction_cooldown = float(parent_tower.saucer_abduction_cooldown)
		abduction_flash_remaining = 0.28
		target = null
		queue_redraw()
		return

	if (
		attack_cooldown <= 0.0
		and distance_to_target <= float(parent_tower.saucer_attack_radius_pixels)
	):
		parent_tower.fire_saucer_rockets(global_position, target)
		attack_cooldown = float(parent_tower.damage_timer.wait_time)
	queue_redraw()


func move_toward_position(destination: Vector2, delta: float) -> void:
	var distance := global_position.distance_to(destination)
	if distance <= RETURN_DISTANCE:
		global_position = destination
		return
	global_position = global_position.move_toward(
		destination,
		float(parent_tower.saucer_flyer_move_speed) * delta
	)


func is_valid_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not bool(candidate.get("finished"))
	)


func _draw() -> void:
	if abduction_flash_remaining > 0.0:
		var flash_alpha := abduction_flash_remaining / 0.28
		draw_circle(Vector2.ZERO, 24.0, Color(0.35, 1.0, 0.62, 0.18 * flash_alpha))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, Color(0.45, 1.0, 0.72, flash_alpha), 2.0)
	var body_color := Color(0.58, 0.78, 0.92)
	draw_ellipse(Vector2.ZERO, 18.0, 7.0, body_color)
	draw_circle(Vector2(0.0, -4.0), 8.0, Color(0.32, 0.72, 0.94))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.82, 0.95, 1.0), 2.0)
	draw_circle(Vector2(-10.0, 2.0), 2.0, Color(1.0, 0.75, 0.22))
	draw_circle(Vector2(0.0, 4.0), 2.0, Color(1.0, 0.75, 0.22))
	draw_circle(Vector2(10.0, 2.0), 2.0, Color(1.0, 0.75, 0.22))
