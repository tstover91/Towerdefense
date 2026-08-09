class_name SpawnedUnit
extends Node2D

const GameStats = preload("res://stat_database.gd")
const PROJECTILE_SCENE = preload("res://projectile.tscn")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const ARRIVAL_DISTANCE := 6.0
const BEAM_HIT_HALF_WIDTH := 2.5
const DEFAULT_BEAM_TURN_SPEED_DEGREES := 720.0

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
var critical_chance := GameStats.DEFAULT_CRITICAL_CHANCE
var critical_multiplier := GameStats.DEFAULT_CRITICAL_MULTIPLIER
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range_pixels := 0.0
var attack_interval := 1.0
var aim_radius_pixels := 100.0
var move_speed := 0.0
var projectile_speed := 500.0
var projectile_count := 1
var volley_width_pixels := 0.0
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
var local_target: Node2D
var locally_acquired_target := false
var target_is_shared := false
var shared_spore_targeting := false
var continuous_beam := false
var infinite_pierce := false
var beam_aim_direction := Vector2.RIGHT
var beam_has_aim := false
var beam_turn_speed_radians := deg_to_rad(DEFAULT_BEAM_TURN_SPEED_DEGREES)
var explode_on_damage_budget := false
var budget_explosion_radius_pixels := 0.0
var budget_explosion_damage_multiplier := 1.0
var mech_area_slam := false
var mech_slam_radius_pixels := 0.0
var mech_hunter := false
var hunter_pursuit_radius_pixels := 0.0
var hunter_critical_chance := 0.30
var visual_scale := 1.0


func setup(
	spawned_unit_id: StringName,
	unit_stats: Dictionary,
	spawner: Node2D,
	map_path: Path2D
) -> void:
	unit_id = spawned_unit_id
	parent_tower = spawner
	path_node = map_path
	add_to_group("spawned_units")
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
	if unit_stats.has("damage_tags"):
		damage_tags.assign(unit_stats["damage_tags"])
	for tag in unit_stats.get("additional_damage_tags", []):
		var damage_tag := StringName(tag)
		if not damage_tags.has(damage_tag):
			damage_tags.append(damage_tag)
	for tag in unit_stats.get("additional_bonus_tags", []):
		var bonus_tag := StringName(tag)
		if not bonus_tags.has(bonus_tag):
			bonus_tags.append(bonus_tag)
	damage = maxi(int(unit_stats.get("damage", damage)), 1)
	critical_chance = clampf(
		float(unit_stats.get(
			"critical_chance",
			GameStats.DEFAULT_CRITICAL_CHANCE
		)),
		0.0,
		1.0
	)
	critical_multiplier = maxf(
		float(unit_stats.get(
			"critical_multiplier",
			GameStats.DEFAULT_CRITICAL_MULTIPLIER
		)),
		1.0
	)
	slow_duration = maxf(float(unit_stats.get("slow_duration", 0.0)), 0.0)
	stun_duration = maxf(float(unit_stats.get("stun_duration", 0.0)), 0.0)
	stun_affects_bosses = bool(
		unit_stats.get("stun_affects_bosses", false)
	)
	bounce_count = maxi(int(unit_stats.get("bounce_count", 0)), 0)
	bounce_range_pixels = (
		maxf(float(unit_stats.get("bounce_range", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
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
	projectile_count = maxi(int(unit_stats.get("projectile_count", 1)), 1)
	volley_width_pixels = (
		maxf(float(unit_stats.get("volley_width", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	shared_spore_targeting = bool(
		unit_stats.get("shared_spore_targeting", false)
	)
	continuous_beam = bool(unit_stats.get("continuous_beam", false))
	infinite_pierce = bool(unit_stats.get("infinite_pierce", false))
	beam_turn_speed_radians = deg_to_rad(maxf(
		float(unit_stats.get(
			"beam_turn_speed_degrees",
			DEFAULT_BEAM_TURN_SPEED_DEGREES
		)),
		0.0
	))
	explode_on_damage_budget = bool(
		unit_stats.get("explode_on_damage_budget", false)
	)
	budget_explosion_radius_pixels = (
		maxf(float(unit_stats.get("budget_explosion_radius", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	budget_explosion_damage_multiplier = maxf(
		float(unit_stats.get("budget_explosion_damage_multiplier", 1.0)),
		0.0
	)
	mech_area_slam = bool(unit_stats.get("mech_area_slam", false))
	mech_slam_radius_pixels = (
		maxf(float(unit_stats.get("mech_slam_radius", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	mech_hunter = bool(unit_stats.get("mech_hunter", false))
	hunter_pursuit_radius_pixels = (
		maxf(float(unit_stats.get("hunter_pursuit_radius", 0.0)), 0.0)
		* RANGE_PIXELS_PER_UNIT
	)
	hunter_critical_chance = clampf(
		float(unit_stats.get("hunter_critical_chance", 0.30)),
		0.0,
		1.0
	)
	visual_scale = maxf(float(unit_stats.get("visual_scale", 1.0)), 0.1)
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
	update_continuous_beam_aim(delta)
	match movement_type:
		GameStats.MOVEMENT_DRONE:
			process_drone(delta)
		GameStats.MOVEMENT_PATH_ASSAULT:
			process_path_assault(delta)
		_:
			process_stationary()
	if continuous_beam:
		queue_redraw()


func process_stationary() -> void:
	local_target = select_target(global_position, aim_radius_pixels)
	target = local_target
	locally_acquired_target = is_valid_target(local_target)
	target_is_shared = false
	if unit_id == &"spore_turret" and shared_spore_targeting:
		var shared_target := select_shared_spore_target()
		if (
			is_valid_target(shared_target)
			and (
				not is_valid_target(target)
				or get_target_progress(shared_target) > get_target_progress(target)
			)
		):
			target = shared_target
			target_is_shared = true
	try_attack_target()


func select_shared_spore_target() -> Node2D:
	if (
		not is_instance_valid(parent_tower)
		or parent_tower.main == null
		or not parent_tower.main.has_method("get_shared_spore_target")
	):
		return null
	return parent_tower.main.get_shared_spore_target(parent_tower)


func get_target_progress(candidate: Node2D) -> float:
	if not is_valid_target(candidate) or not is_instance_valid(candidate.path_follow):
		return -INF
	return float(candidate.path_follow.progress)


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
	if mech_hunter:
		process_hunter_mech(delta)
		return
	target = select_target(global_position, get_effective_attack_radius())
	if is_valid_target(target):
		try_attack_target()
		return
	path_progress = maxf(path_progress - move_speed * delta, 0.0)
	global_position = path_node.to_global(
		path_node.curve.sample_baked(path_progress, true)
	)
	if path_progress <= 0.0:
		queue_free()


func process_hunter_mech(delta: float) -> void:
	target = select_hunter_target()
	if is_valid_target(target):
		if global_position.distance_to(target.global_position) <= get_effective_attack_radius():
			try_attack_target()
			return
		var target_progress := float(target.path_follow.progress)
		path_progress = move_toward(
			path_progress,
			target_progress,
			move_speed * delta
		)
		update_path_assault_position()
		return
	path_progress = maxf(path_progress - move_speed * delta, 0.0)
	update_path_assault_position()
	if path_progress <= 0.0:
		queue_free()


func select_hunter_target() -> Node2D:
	var selected_target: Node2D
	var selected_priority := -1
	var selected_health := -1
	var selected_progress := -INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate) or not is_instance_valid(candidate.path_follow):
			continue
		var candidate_progress := float(candidate.path_follow.progress)
		if absf(candidate_progress - path_progress) > hunter_pursuit_radius_pixels:
			continue
		var priority := 0
		if candidate.traits.has(&"boss"):
			priority = 2
		elif candidate.traits.has(&"elite"):
			priority = 1
		var candidate_health := int(candidate.health)
		if (
			priority > selected_priority
			or (
				priority == selected_priority
				and candidate_health > selected_health
			)
			or (
				priority == selected_priority
				and candidate_health == selected_health
				and candidate_progress > selected_progress
			)
		):
			selected_priority = priority
			selected_health = candidate_health
			selected_progress = candidate_progress
			selected_target = candidate
	return selected_target


func update_path_assault_position() -> void:
	global_position = path_node.to_global(
		path_node.curve.sample_baked(path_progress, true)
	)


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
	if (
		not target_is_shared
		and global_position.distance_to(target.global_position) > get_effective_attack_radius()
	):
		return
	perform_attack(target)
	attack_cooldown = attack_interval


func perform_attack(current_target: Node2D) -> void:
	var damage_type := get_damage_type()
	if mech_area_slam:
		perform_mech_area_slam()
		return
	var attack_damage := roll_attack_damage(current_target)
	var attack_landed := true
	if continuous_beam:
		attack_landed = perform_continuous_beam_attack(
			current_target,
			attack_damage,
			damage_type
		)
	elif delivery_type == GameStats.DELIVERY_PROJECTILE:
		launch_projectile_volley(current_target, attack_damage, damage_type)
	else:
		perform_hitscan_attack(current_target, attack_damage, damage_type)

	if (
		attack_landed
		and movement_type == GameStats.MOVEMENT_DRONE
		and damage_budget > 0
	):
		damage_spent += attack_damage
		if damage_spent >= damage_budget:
			if explode_on_damage_budget:
				trigger_budget_explosion()
				queue_free()
				return
			returning_to_base = true


func get_effective_attack_radius() -> float:
	if mech_area_slam and mech_slam_radius_pixels > 0.0:
		return mech_slam_radius_pixels
	return aim_radius_pixels


func perform_mech_area_slam() -> void:
	if mech_slam_radius_pixels <= 0.0:
		return
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		var slam_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(slam_zone)
		slam_zone.global_position = global_position
		slam_zone.setup(mech_slam_radius_pixels)
	var source_tower_id := StringName(parent_tower.get("tower_id"))
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob):
			continue
		var distance_to_slam: float = global_position.distance_to(mob.global_position)
		if distance_to_slam > mech_slam_radius_pixels:
			continue
		var slam_damage := GameStats.get_explosion_damage(
			roll_attack_damage(mob),
			distance_to_slam,
			mech_slam_radius_pixels
		)
		apply_control_effects(mob)
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				slam_damage,
				&"melee",
				false,
				source_tower_id
			)
		else:
			mob.apply_damage(slam_damage, &"melee", false)


func trigger_budget_explosion() -> void:
	if budget_explosion_radius_pixels <= 0.0:
		return
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
		get_tree().current_scene.add_child(explosion_zone)
		explosion_zone.global_position = global_position
		explosion_zone.setup(budget_explosion_radius_pixels)
	var explosion_damage := maxi(
		roundi(float(damage) * budget_explosion_damage_multiplier),
		1
	)
	var source_tower_id := StringName(parent_tower.get("tower_id"))
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(mob):
			continue
		var distance_to_blast: float = global_position.distance_to(mob.global_position)
		if distance_to_blast > budget_explosion_radius_pixels:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_to_blast,
			budget_explosion_radius_pixels
		)
		if mob.has_method("apply_damage_from_tower"):
			mob.apply_damage_from_tower(
				dealt_damage,
				&"explosive",
				false,
				source_tower_id
			)
		else:
			mob.apply_damage(dealt_damage, &"explosive", false)


func launch_projectile_volley(
	current_target: Node2D,
	attack_damage: int,
	damage_type: StringName
) -> void:
	var aim_offset := current_target.global_position - global_position
	var perpendicular := Vector2.UP
	if not aim_offset.is_zero_approx():
		perpendicular = aim_offset.normalized().orthogonal()
	for projectile_index in projectile_count:
		var spread_ratio := 0.0
		if projectile_count > 1:
			spread_ratio = (
				float(projectile_index) / float(projectile_count - 1) - 0.5
			)
		var launch_position := (
			global_position
			+ perpendicular * volley_width_pixels * spread_ratio
		)
		var destination := current_target.global_position
		var projectile := PROJECTILE_SCENE.instantiate() as TowerProjectile
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = launch_position
		projectile.setup(
			current_target,
			destination,
			projectile_speed,
			maxf(aim_radius_pixels, launch_position.distance_to(destination)),
			attack_damage,
			damage_type,
			impact_mode,
			splash_radius_pixels,
			pierce_count,
			slow_duration,
			stun_duration,
			stun_affects_bosses,
			bounce_count,
			bounce_range_pixels,
			false,
			0.0,
			false,
			has_bonus_tag(&"reveal")
		)


func perform_hitscan_attack(
	current_target: Node2D,
	attack_damage: int,
	damage_type: StringName
) -> void:
	apply_control_effects(current_target)
	current_target.apply_damage(
		attack_damage,
		damage_type,
		pierce_count > 0
	)
	if pierce_count < 1:
		return
	var aim_offset := current_target.global_position - global_position
	if aim_offset.is_zero_approx():
		return
	var direction := aim_offset.normalized()
	var line_origin := current_target.global_position + direction * 0.01
	var line_end := global_position + direction * aim_radius_pixels
	var targets := get_hitscan_pierce_targets(
		line_origin,
		line_end,
		current_target
	)
	for index in mini(targets.size(), pierce_count):
		apply_control_effects(targets[index])
		var pierced_damage := GameStats.get_piercing_damage(
			attack_damage,
			index + 1
		)
		targets[index].apply_damage(pierced_damage, damage_type, true)


func perform_continuous_beam_attack(
	current_target: Node2D,
	attack_damage: int,
	damage_type: StringName
) -> bool:
	ensure_continuous_beam_aim(current_target)
	if not beam_has_aim:
		return false
	var line_origin := global_position
	var line_end := line_origin + beam_aim_direction * aim_radius_pixels
	if pierce_count < 1 and not infinite_pierce:
		if not is_target_intersecting_beam(current_target, line_origin, line_end):
			return false
		apply_control_effects(current_target)
		current_target.apply_damage(attack_damage, damage_type, false)
		return true

	var targets := get_hitscan_pierce_targets(line_origin, line_end, null, true)
	var maximum_hits := targets.size()
	if not infinite_pierce:
		maximum_hits = mini(maximum_hits, 1 + pierce_count)
	for index in maximum_hits:
		apply_control_effects(targets[index])
		targets[index].apply_damage(
			GameStats.get_piercing_damage(attack_damage, index),
			damage_type,
			true
		)
	return maximum_hits > 0


func ensure_continuous_beam_aim(current_target: Node2D) -> void:
	if beam_has_aim or not is_valid_target(current_target):
		return
	var target_offset := current_target.global_position - global_position
	if target_offset.is_zero_approx():
		return
	beam_aim_direction = target_offset.normalized()
	beam_has_aim = true


func update_continuous_beam_aim(delta: float) -> void:
	if not continuous_beam or not is_valid_target(target):
		return
	var target_offset := target.global_position - global_position
	if target_offset.is_zero_approx():
		return
	var desired_direction := target_offset.normalized()
	if not beam_has_aim:
		beam_aim_direction = desired_direction
		beam_has_aim = true
		return
	var angle_difference := beam_aim_direction.angle_to(desired_direction)
	var maximum_turn := beam_turn_speed_radians * delta
	beam_aim_direction = beam_aim_direction.rotated(
		clampf(angle_difference, -maximum_turn, maximum_turn)
	).normalized()


func is_target_intersecting_beam(
	candidate: Node2D,
	line_origin: Vector2,
	line_end: Vector2
) -> bool:
	if not is_valid_target(candidate):
		return false
	var closest_point := Geometry2D.get_closest_point_to_segment(
		candidate.global_position,
		line_origin,
		line_end
	)
	var hit_radius := 12.0
	if candidate.has_method("get_projectile_hit_radius"):
		hit_radius = candidate.get_projectile_hit_radius()
	return (
		candidate.global_position.distance_to(closest_point)
		<= hit_radius + BEAM_HIT_HALF_WIDTH
	)


func get_hitscan_pierce_targets(
	line_origin: Vector2,
	line_end: Vector2,
	excluded_target: Node,
	use_beam_width := false
) -> Array[Node2D]:
	var candidates: Array[Dictionary] = []
	var segment := line_end - line_origin
	var segment_length := segment.length()
	if segment_length <= 0.0:
		return []
	var direction := segment / segment_length
	for mob in get_tree().get_nodes_in_group("mobs"):
		if mob == excluded_target or not is_valid_target(mob):
			continue
		var distance_along_line: float = (
			mob.global_position - line_origin
		).dot(direction)
		if distance_along_line < 0.0 or distance_along_line > segment_length:
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(
			mob.global_position,
			line_origin,
			line_end
		)
		var hit_radius := 12.0
		if mob.has_method("get_projectile_hit_radius"):
			hit_radius = mob.get_projectile_hit_radius()
		var line_half_width := BEAM_HIT_HALF_WIDTH if use_beam_width else 0.0
		if (
			mob.global_position.distance_to(closest_point)
			> hit_radius + line_half_width
		):
			continue
		candidates.append({
			"mob": mob,
			"distance": distance_along_line,
		})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[Node2D] = []
	for candidate in candidates:
		result.append(candidate["mob"])
	return result


func roll_attack_damage(current_target: Node2D = null) -> int:
	var current_critical_chance := critical_chance
	if (
		mech_hunter
		and is_valid_target(current_target)
		and (
			current_target.traits.has(&"elite")
			or current_target.traits.has(&"boss")
		)
	):
		current_critical_chance = maxf(
			current_critical_chance,
			hunter_critical_chance
		)
	if has_bonus_tag(&"critical") and randf() < current_critical_chance:
		return maxi(roundi(float(damage) * critical_multiplier), 1)
	return damage


func apply_control_effects(current_target: Node) -> void:
	if slow_duration > 0.0 and current_target.has_method("apply_slow"):
		current_target.apply_slow(slow_duration)
	if stun_duration > 0.0 and current_target.has_method("apply_stun"):
		current_target.apply_stun(stun_duration, stun_affects_bosses)


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
	var valid_target: bool = (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)
	if not valid_target:
		return false
	if candidate.traits.has(&"hidden"):
		return has_bonus_tag(&"reveal")
	return true


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
	if (
		continuous_beam
		and beam_has_aim
		and not returning_to_base
		and recharge_remaining <= 0.0
		and is_valid_target(target)
		and global_position.distance_to(target.global_position) <= aim_radius_pixels
	):
		var beam_end := global_position + beam_aim_direction * aim_radius_pixels
		draw_line(
			Vector2.ZERO,
			to_local(beam_end),
			Color(0.25, 0.85, 1.0, 0.9),
			2.5,
			true
		)
		draw_circle(Vector2.ZERO, 3.5, Color(0.55, 0.95, 1.0, 0.9))
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
			var body_size := Vector2(18.0, 18.0) * visual_scale
			draw_rect(Rect2(-body_size * 0.5, body_size), Color(0.95, 0.55, 0.18))
			draw_rect(
				Rect2(
					Vector2(-4.0, -13.0) * visual_scale,
					Vector2(8.0, 7.0) * visual_scale
				),
				Color(0.45, 0.22, 0.08)
			)
		&"abducted_monster":
			draw_circle(Vector2.ZERO, 12.0, Color(0.48, 0.9, 0.28))
			draw_circle(Vector2(-4.0, -2.0), 2.5, Color(0.08, 0.12, 0.06))
			draw_circle(Vector2(4.0, -2.0), 2.5, Color(0.08, 0.12, 0.06))
			draw_arc(Vector2(0.0, 2.0), 5.0, 0.2, PI - 0.2, 12, Color(0.12, 0.22, 0.08), 2.0)
		_:
			draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
