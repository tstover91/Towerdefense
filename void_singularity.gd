class_name VoidSingularity
extends Node2D

const GameStats = preload("res://stat_database.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const VOID_CALLER_TOWER_ID: StringName = &"voidcaller"

signal finished(singularity: Node2D)

var main: Node
var center_path_progress := 0.0
var pull_duration := 1.0
var pull_radius := 64.5
var pull_speed := 160.0
var explosion_radius := 58.05
var explosion_damage := 1
var elapsed := 0.0
var resolving := false


func setup(
	game_main: Node,
	path_progress: float,
	duration: float,
	radius: float,
	path_pull_speed: float,
	final_explosion_radius: float,
	final_explosion_damage: int
) -> void:
	main = game_main
	center_path_progress = maxf(path_progress, 0.0)
	pull_duration = maxf(duration, 0.01)
	pull_radius = maxf(radius, 1.0)
	pull_speed = maxf(path_pull_speed, 0.0)
	explosion_radius = maxf(final_explosion_radius, 1.0)
	explosion_damage = maxi(final_explosion_damage, 1)
	queue_redraw()


func _draw() -> void:
	var progress_ratio := clampf(elapsed / pull_duration, 0.0, 1.0)
	var pulse_radius := lerpf(pull_radius, pull_radius * 0.3, progress_ratio)
	draw_circle(Vector2.ZERO, pulse_radius, Color(0.22, 0.02, 0.32, 0.28))
	draw_arc(
		Vector2.ZERO,
		pull_radius,
		0.0,
		TAU,
		64,
		Color(0.7, 0.2, 1.0, 0.7),
		2.0,
		true
	)
	draw_circle(Vector2.ZERO, 6.0, Color(0.8, 0.35, 1.0, 0.95))


func _process(delta: float) -> void:
	if resolving:
		return
	if main == null or not main.round_active:
		cancel()
		return
	elapsed += delta
	pull_nearby_mobs(delta)
	queue_redraw()
	if elapsed >= pull_duration:
		explode()


func pull_nearby_mobs(delta: float) -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_mob(mob):
			continue
		if global_position.distance_to(mob.global_position) > pull_radius:
			continue
		if not is_nearest_singularity_for(mob):
			continue
		if not is_instance_valid(mob.path_follow):
			continue
		mob.path_follow.progress = move_toward(
			mob.path_follow.progress,
			center_path_progress,
			pull_speed * delta
		)


func is_nearest_singularity_for(mob: Node2D) -> bool:
	var own_distance := global_position.distance_to(mob.global_position)
	var own_id := get_instance_id()
	for candidate in get_tree().get_nodes_in_group("void_singularities"):
		if candidate == self or not is_valid_singularity(candidate):
			continue
		var candidate_distance: float = candidate.global_position.distance_to(
			mob.global_position
		)
		if candidate_distance > candidate.pull_radius:
			continue
		if candidate_distance < own_distance:
			return false
		if is_equal_approx(candidate_distance, own_distance):
			if candidate.get_instance_id() < own_id:
				return false
	return true


func is_valid_singularity(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.resolving
	)


func explode() -> void:
	if resolving:
		return
	resolving = true
	spawn_explosion_zone()
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_mob(mob):
			continue
		var distance_from_center: float = global_position.distance_to(mob.global_position)
		if distance_from_center > explosion_radius:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_from_center,
			explosion_radius
		)
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				dealt_damage,
				&"explosive",
				false,
				VOID_CALLER_TOWER_ID
			)
		else:
			mob.apply_damage(dealt_damage, &"explosive", false)
	finished.emit(self)
	queue_free()


func cancel() -> void:
	if resolving:
		return
	resolving = true
	finished.emit(self)
	queue_free()


func spawn_explosion_zone() -> void:
	if EXPLOSION_ZONE_SCENE == null or get_tree().current_scene == null:
		return
	var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(explosion_zone)
	explosion_zone.global_position = global_position
	explosion_zone.setup(explosion_radius)


func is_valid_mob(candidate: Variant) -> bool:
	var valid_mob: bool = (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
	return valid_mob and not candidate.traits.has(&"hidden")
