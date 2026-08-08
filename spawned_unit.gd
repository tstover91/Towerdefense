class_name SpawnedUnit
extends Node2D

const GameStats = preload("res://stat_database.gd")
const PROJECTILE_SCENE = preload("res://projectile.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const ARRIVAL_DISTANCE := 6.0

var unit_id: StringName = &""
var parent_tower: Node2D
var path_node: Path2D
var type_tags: Array[StringName] = []
var damage_tags: Array[StringName] = []
var bonus_tags: Array[StringName] = []
var movement_type: StringName = GameStats.MOVEMENT_STATIONARY
var delivery_type: StringName = GameStats.DELIVERY_HITSCAN
var impact_mode: StringName = GameStats.IMPACT_PRIMARY
var pierce_count := 0
var damage := 1
var attack_interval := 1.0
var aim_radius_pixels := 100.0
var move_speed := 0.0
var projectile_speed := 500.0
var splash_radius_pixels := 0.0
var leash_radius_pixels := 150.0
var damage_budget := 0
var recharge_duration := 0.0
var lifetime := 0.0
var age := 0.0
var damage_spent := 0
var recharge_remaining := 0.0
var returning_to_base := false
var attack_cooldown := 0.0
var path_progress := 0.0
var orbit_angle := 0.0
var target: Node2D


func setup(
	spawned_unit_id: StringName,
	unit_stats: Dictionary,
	spawner: Node2D,
	map_path: Path2D
) -> void:
	unit_id = spawned_unit_id
	parent_tower = spawner
	path_node = map_path
	load_definition()
	apply_stats(unit_stats)
	if movement_type == GameStats.MOVEMENT_PATH_ASSAULT:
		initialize_path_position()
	queue_redraw()


func load_definition() -> void:
	var definition := GameStats.get_spawned_unit(unit_id)
	type_tags.assign(definition.get("type_tags", []))
	damage_tags.assign(definition.get("damage_tags", []))
	bonus_tags.assign(definition.get("bonus_tags", []))
	movement_type = definition.get(
		"movement_type",
		GameStats.MOVEMENT_STATIONARY
	)
	delivery_type = definition.get(
		"delivery_type",
		GameStats.DELIVERY_HITSCAN
	)
	impact_mode = definition.get("impact_mode", GameStats.IMPACT_PRIMARY)
	pierce_count = maxi(int(definition.get("pierce_count", 0)), 0)


func apply_stats(unit_stats: Dictionary) -> void:
	damage = maxi(int(unit_stats.get("damage", damage)), 1)
	attack_interval = maxf(
		float(unit_stats.get("attack_interval", attack_interval)),
		0.01
	)
	aim_radius_pixels = maxf(
		float(unit_stats.get("aim_radius", 1.0)) * RANGE_PIXELS_PER_UNIT,
		1.0
	)
	move_speed = maxf(float(unit_stats.get("move_speed", move_speed)), 0.0)
	projectile_speed = maxf(
		float(unit_stats.get("projectile_speed", projectile_speed)),
		1.0
	)
	splash_radius_pixels = maxf(
		float(unit_stats.get("splash_radius", 0.0)) * RANGE_PIXELS_PER_UNIT,
		0.0
	)
	leash_radius_pixels = maxf(
		float(unit_stats.get("leash_radius", 1.0)) * RANGE_PIXELS_PER_UNIT,
		aim_radius_pixels
	)
	damage_budget = maxi(int(unit_stats.get("damage_budget", damage_budget)), 0)
	recharge_duration = maxf(
		float(unit_stats.get("recharge_duration", recharge_duration)),
		0.0
	)
	lifetime = maxf(float(unit_stats.get("lifetime", lifetime)), 0.0)
	attack_cooldown = minf(attack_cooldown, attack_interval)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(parent_tower) or parent_tower.is_queued_for_deletion():
		queue_free()
		return
	if movement_type == GameStats.MOVEMENT_STATIONARY and lifetime > 0.0:
		age += delta
		if age >= lifetime:
			queue_free()
			return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	match movement_type:
		GameStats.MOVEMENT_DRONE:
			process_drone(delta)
		GameStats.MOVEMENT_PATH_ASSAULT:
			process_path_assault(delta)
		_:
			process_stationary()


func process_stationary() -> void:
	target = select_target(global_position, aim_radius_pixels)
	try_attack_target()


func process_drone(delta: float) -> void:
	if returning_to_base:
		target = null
		move_toward_position(parent_tower.global_position, delta)
		if global_position.distance_to(parent_tower.global_position) <= ARRIVAL_DISTANCE:
			global_position = parent_tower.global_position
			returning_to_base = false
			recharge_remaining = recharge_duration
		return

	if recharge_remaining > 0.0:
		target = null
		global_position = parent_tower.global_position
		recharge_remaining = maxf(recharge_remaining - delta, 0.0)
		if recharge_remaining <= 0.0:
			damage_spent = 0
		return

	target = select_target(parent_tower.global_position, leash_radius_pixels)
	if is_valid_target(target):
		var distance_to_target := global_position.distance_to(target.global_position)
		if distance_to_target > aim_radius_pixels * 0.8:
			move_toward_position(target.global_position, delta)
		try_attack_target()
		return

	orbit_angle = fmod(orbit_angle + delta * 0.9, TAU)
	var orbit_radius := minf(leash_radius_pixels * 0.35, 64.0)
	var orbit_position := (
		parent_tower.global_position
		+ Vector2.from_angle(orbit_angle) * orbit_radius
	)
	move_toward_position(orbit_position, delta)


func process_path_assault(delta: float) -> void:
	if path_node == null or path_node.curve == null:
		queue_free()
		return
	target = select_target(global_position, aim_radius_pixels)
	if is_valid_target(target):
		try_attack_target()
		return
	path_progress = maxf(path_progress - move_speed * delta, 0.0)
	global_position = path_node.to_global(
		path_node.curve.sample_baked(path_progress, true)
	)
	if path_progress <= 0.0:
		queue_free()


func initialize_path_position() -> void:
	if path_node == null or path_node.curve == null:
		return
	path_progress = path_node.curve.get_closest_offset(
		path_node.to_local(global_position)
	)
	global_position = path_node.to_global(
		path_node.curve.sample_baked(path_progress, true)
	)


func move_toward_position(destination: Vector2, delta: float) -> void:
	if move_speed <= 0.0:
		return
	global_position = global_position.move_toward(destination, move_speed * delta)


func try_attack_target() -> void:
	if attack_cooldown > 0.0 or not is_valid_target(target):
		return
	if global_position.distance_to(target.global_position) > aim_radius_pixels:
		return
	perform_attack(target)
	attack_cooldown = attack_interval


func perform_attack(current_target: Node2D) -> void:
	var damage_type := get_damage_type()
	if delivery_type == GameStats.DELIVERY_PROJECTILE:
		var projectile := PROJECTILE_SCENE.instantiate() as TowerProjectile
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		projectile.setup(
			current_target,
			current_target.global_position,
			projectile_speed,
			aim_radius_pixels,
			damage,
			damage_type,
			impact_mode,
			splash_radius_pixels,
			pierce_count
		)
	else:
		current_target.apply_damage(damage, damage_type, pierce_count > 0)

	if movement_type == GameStats.MOVEMENT_DRONE and damage_budget > 0:
		damage_spent += damage
		if damage_spent >= damage_budget:
			returning_to_base = true


func select_target(origin: Vector2, maximum_distance: float) -> Node2D:
	var selected_target: Node2D
	var selected_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		if origin.distance_to(candidate.global_position) > maximum_distance:
			continue
		var progress := float(candidate.path_follow.progress)
		if progress > selected_progress:
			selected_progress = progress
			selected_target = candidate
	return selected_target


func is_valid_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)


func get_damage_type() -> StringName:
	if damage_tags.is_empty():
		return &"ballistic"
	return damage_tags[0]


func has_type_tag(tag: StringName) -> bool:
	return type_tags.has(tag)


func has_damage_tag(tag: StringName) -> bool:
	return damage_tags.has(tag)


func has_bonus_tag(tag: StringName) -> bool:
	return bonus_tags.has(tag)


func _draw() -> void:
	match unit_id:
		&"spore_turret":
			draw_circle(Vector2.ZERO, 9.0, Color(0.3, 0.9, 0.3))
			draw_circle(Vector2.ZERO, 4.0, Color(0.1, 0.35, 0.12))
		&"drone":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(11.0, 0.0),
					Vector2(-8.0, -7.0),
					Vector2(-5.0, 0.0),
					Vector2(-8.0, 7.0),
				]),
				Color(0.25, 0.75, 1.0)
			)
		&"mech":
			draw_rect(Rect2(-9.0, -9.0, 18.0, 18.0), Color(0.95, 0.55, 0.18))
			draw_rect(Rect2(-4.0, -13.0, 8.0, 7.0), Color(0.45, 0.22, 0.08))
		_:
			draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
