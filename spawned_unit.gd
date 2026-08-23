class_name SpawnedUnit
extends Node2D

const GameStats = preload("res://stat_database.gd")
const RelicEffects = preload("res://relic_combat.gd")
const PROJECTILE_SCENE = preload("res://projectile.tscn")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")
const HITSCAN_EFFECT_SCENE = preload("res://hitscan_effect.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9
const ARRIVAL_DISTANCE := 6.0
const BEAM_HIT_HALF_WIDTH := 2.5
const DEFAULT_BEAM_TURN_SPEED_DEGREES := 720.0
const MOBILE_TARGET_REFRESH_INTERVAL := 0.15
const DRONE_ATTACK_RADIUS_UNITS := 2.5
const DRONE_ASSIGNMENT_FRAME_META: StringName = &"drone_assignment_refresh_bucket"
const DRONE_ASSIGNMENT_CACHE_META: StringName = &"drone_assignment_cache"

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
var noncritical_damage_multiplier := 1.0
var last_attack_roll_was_critical := false
var last_attack_roll_missed := false
var miss_chance := 0.0
var relentless_target_instance_id := 0
var relentless_stacks := 0
var pierce_loses_no_power := false
var slow_duration := 0.0
var stun_duration := 0.0
var stun_affects_bosses := false
var bounce_count := 0
var bounce_range_pixels := 0.0
var attack_interval := 1.0
var aim_radius_pixels := 100.0
var acquisition_radius_pixels := 100.0
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
var target_refresh_remaining := 0.0
var path_progress := 0.0
var orbit_angle := 0.0
var home_position := Vector2.ZERO
var target: Node2D
var local_target: Node2D
var locally_acquired_target := false
var target_is_shared := false
var shared_spore_targeting := false
var continuous_beam := false
var infinite_pierce := false
var inherent_infinite_pierce := false
var beam_aim_direction := Vector2.RIGHT
var beam_has_aim := false
var beam_turn_speed_radians := deg_to_rad(DEFAULT_BEAM_TURN_SPEED_DEGREES)
var death_ray_overcharge_enabled := false
var death_ray_cycle_elapsed := 0.0
var death_ray_overcharge_active := false
var explode_on_damage_budget := false
var budget_explosion_radius_pixels := 0.0
var budget_explosion_damage_multiplier := 1.0
var budget_replacement_delay := 0.5
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
	if (
		death_ray_overcharge_enabled
		and parent_tower.has_method("get_death_ray_cycle_elapsed")
	):
		death_ray_cycle_elapsed = parent_tower.get_death_ray_cycle_elapsed()
	refresh_death_ray_overcharge_state()
	home_position = global_position
	target_refresh_remaining = get_initial_target_refresh_delay()
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
	pierce_count = maxi(int(unit_stats.get("pierce_count", pierce_count)), 0)
	if pierce_count > 0 and not bonus_tags.has(&"pierce"):
		bonus_tags.append(&"pierce")
	elif pierce_count < 1:
		bonus_tags.erase(&"pierce")
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
	noncritical_damage_multiplier = clampf(
		float(unit_stats.get("noncritical_damage_multiplier", 1.0)),
		0.0,
		1.0
	)
	miss_chance = clampf(float(unit_stats.get("miss_chance", 0.0)), 0.0, 1.0)
	pierce_loses_no_power = bool(
		unit_stats.get("pierce_loses_no_power", false)
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
	acquisition_radius_pixels = maxf(
		float(unit_stats.get("acquisition_radius", 1.0))
			* RANGE_PIXELS_PER_UNIT,
		aim_radius_pixels
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
	inherent_infinite_pierce = bool(unit_stats.get("infinite_pierce", false))
	death_ray_overcharge_enabled = bool(
		unit_stats.get("death_ray_overcharge", false)
	)
	refresh_death_ray_overcharge_state()
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
	budget_replacement_delay = maxf(
		float(unit_stats.get("budget_replacement_delay", 0.5)),
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
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(parent_tower) or parent_tower.is_queued_for_deletion():
		queue_free()
		return
	if lifetime > 0.0:
		age += delta
		if age >= lifetime:
			queue_free()
			return

	if death_ray_overcharge_enabled:
		process_death_ray_overcharge(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if (
		relentless_target_instance_id > 0
		and (
			not is_valid_target(target)
			or target.get_instance_id() != relentless_target_instance_id
		)
	):
		reset_relentless()
	target_refresh_remaining = maxf(target_refresh_remaining - delta, 0.0)
	if continuous_beam:
		update_continuous_beam_aim(delta)
	match movement_type:
		GameStats.MOVEMENT_DRONE:
			process_drone(delta)
		GameStats.MOVEMENT_PATH_ASSAULT:
			process_path_assault(delta)
		GameStats.MOVEMENT_GUARD:
			process_guard(delta)
		_:
			process_stationary()
	if continuous_beam:
		queue_redraw()


func process_stationary() -> void:
	if not is_valid_target(target):
		target = null
	if target_refresh_remaining <= 0.0:
		local_target = select_target(global_position, aim_radius_pixels)
		target_refresh_remaining = MOBILE_TARGET_REFRESH_INTERVAL
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
		target_refresh_remaining = 0.0
		move_toward_position(parent_tower.global_position, delta)
		if global_position.distance_squared_to(parent_tower.global_position) <= ARRIVAL_DISTANCE * ARRIVAL_DISTANCE:
			global_position = parent_tower.global_position
			returning_to_base = false
			recharge_remaining = recharge_duration
		return

	if recharge_remaining > 0.0:
		target = null
		target_refresh_remaining = 0.0
		global_position = parent_tower.global_position
		recharge_remaining = maxf(recharge_remaining - delta, 0.0)
		if recharge_remaining <= 0.0:
			damage_spent = 0
		return

	var drone_target_eligible := is_valid_target(target)
	if target_refresh_remaining <= 0.0:
		target = select_drone_command_target()
		target_refresh_remaining = MOBILE_TARGET_REFRESH_INTERVAL
	elif not drone_target_eligible:
		target = null
	if is_valid_target(target):
		var desired_distance := get_effective_attack_radius() * 0.9
		if global_position.distance_squared_to(target.global_position) > desired_distance * desired_distance:
			move_toward_position(target.global_position, delta)
		try_attack_target()
		return

	orbit_angle = fmod(orbit_angle + delta * 0.9, TAU)
	var orbit_radius := minf(get_drone_command_radius_pixels() * 0.35, 64.0)
	var orbit_position := (
		parent_tower.global_position
		+ Vector2.from_angle(orbit_angle) * orbit_radius
	)
	move_toward_position(orbit_position, delta)


func select_drone_command_target() -> Node2D:
	if not is_instance_valid(parent_tower):
		return null
	if (
		parent_tower.has_method("get_drone_target_mode")
		and int(parent_tower.get_drone_target_mode()) == 1
	):
		return select_highest_max_health_drone_target()
	return select_distributed_drone_target()


func select_highest_max_health_drone_target() -> Node2D:
	var candidates := get_sorted_drone_targets()
	return candidates[0] if not candidates.is_empty() else null


func select_distributed_drone_target() -> Node2D:
	var current_frame := floori(
		float(Time.get_ticks_msec())
		/ (MOBILE_TARGET_REFRESH_INTERVAL * 1000.0)
	)
	if int(get_tree().get_meta(DRONE_ASSIGNMENT_FRAME_META, -1)) == current_frame:
		var cached_assignments: Dictionary = get_tree().get_meta(
			DRONE_ASSIGNMENT_CACHE_META,
			{}
		)
		return cached_assignments.get(get_instance_id()) as Node2D

	var available_drones: Array[Node] = []
	var reserved_targets: Dictionary = {}
	var target_lists_by_drone: Dictionary = {}
	var target_lists_by_tower: Dictionary = {}
	for candidate in get_tree().get_nodes_in_group("spawned_units"):
		if not is_available_combat_drone(candidate):
			continue
		var tower_id: int = candidate.parent_tower.get_instance_id()
		var candidate_targets: Array[Node2D] = []
		if target_lists_by_tower.has(tower_id):
			candidate_targets.assign(target_lists_by_tower[tower_id])
		else:
			candidate_targets = candidate.get_sorted_drone_targets()
			target_lists_by_tower[tower_id] = candidate_targets
		target_lists_by_drone[candidate.get_instance_id()] = candidate_targets
		if candidate.is_focus_max_health_drone():
			var focused_target: Node2D = (
				candidate_targets[0] if not candidate_targets.is_empty() else null
			)
			if is_instance_valid(focused_target):
				reserved_targets[focused_target.get_instance_id()] = true
		else:
			available_drones.append(candidate)
	available_drones.sort_custom(
		func(a: Node, b: Node) -> bool:
			var a_choice_count: int = (
				target_lists_by_drone[a.get_instance_id()] as Array
			).size()
			var b_choice_count: int = (
				target_lists_by_drone[b.get_instance_id()] as Array
			).size()
			if a_choice_count != b_choice_count:
				return a_choice_count < b_choice_count
			return a.get_instance_id() < b.get_instance_id()
	)

	var assignments: Dictionary = {}
	for drone in available_drones:
		var candidates: Array[Node2D] = []
		candidates.assign(target_lists_by_drone[drone.get_instance_id()])
		var chosen_target: Node2D
		for candidate in candidates:
			if not reserved_targets.has(candidate.get_instance_id()):
				chosen_target = candidate
				break
		# Once every valid enemy is occupied, sharing is allowed.
		if chosen_target == null and not candidates.is_empty():
			chosen_target = candidates[0]
		if is_instance_valid(chosen_target):
			assignments[drone.get_instance_id()] = chosen_target
			reserved_targets[chosen_target.get_instance_id()] = true
	get_tree().set_meta(DRONE_ASSIGNMENT_FRAME_META, current_frame)
	get_tree().set_meta(DRONE_ASSIGNMENT_CACHE_META, assignments)
	return assignments.get(get_instance_id()) as Node2D


func is_available_combat_drone(candidate: Node) -> bool:
	return (
		is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate.get("unit_id") == &"drone"
		and is_instance_valid(candidate.get("parent_tower"))
		and not bool(candidate.get("returning_to_base"))
		and float(candidate.get("recharge_remaining")) <= 0.0
		and candidate.has_method("get_sorted_drone_targets")
	)


func is_focus_max_health_drone() -> bool:
	return (
		unit_id == &"drone"
		and is_instance_valid(parent_tower)
		and parent_tower.has_method("get_drone_target_mode")
		and int(parent_tower.get_drone_target_mode()) == 1
	)


func get_sorted_drone_targets() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if not is_instance_valid(parent_tower):
		return candidates
	if parent_tower.has_method("get_drone_command_targets"):
		candidates.assign(parent_tower.get_drone_command_targets())
	candidates.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			if a.max_health != b.max_health:
				return a.max_health > b.max_health
			var a_progress := float(a.path_follow.progress)
			var b_progress := float(b.path_follow.progress)
			if not is_equal_approx(a_progress, b_progress):
				return a_progress > b_progress
			return a.get_instance_id() < b.get_instance_id()
	)
	return candidates


func process_guard(delta: float) -> void:
	var guard_target_eligible := (
		is_valid_target(target)
		and home_position.distance_squared_to(target.global_position)
			<= acquisition_radius_pixels * acquisition_radius_pixels
	)
	if target_refresh_remaining <= 0.0:
		target = select_guard_target()
		target_refresh_remaining = MOBILE_TARGET_REFRESH_INTERVAL
	elif not guard_target_eligible:
		target = null
	if is_valid_target(target):
		if global_position.distance_squared_to(target.global_position) > aim_radius_pixels * aim_radius_pixels:
			move_toward_position(target.global_position, delta)
			return
		try_attack_target()
		return
	target = null
	move_toward_position(home_position, delta)


func select_guard_target() -> Node2D:
	var candidates: Array[Node2D] = []
	var acquisition_radius_squared := acquisition_radius_pixels * acquisition_radius_pixels
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if (
			is_valid_target(candidate)
			and home_position.distance_squared_to(candidate.global_position)
				<= acquisition_radius_squared
		):
			candidates.append(candidate)
	candidates.sort_custom(
		func(a: Node2D, b: Node2D) -> bool:
			return get_target_progress(a) > get_target_progress(b)
	)
	if candidates.is_empty():
		return null

	var claimed_targets: Dictionary = {}
	if unit_id == &"reinforcement_alien" and is_instance_valid(parent_tower):
		for sibling in get_tree().get_nodes_in_group("spawned_units"):
			if (
				sibling == self
				or sibling.get("unit_id") != &"reinforcement_alien"
				or sibling.get("parent_tower") != parent_tower
				or not is_valid_target(sibling.get("target"))
			):
				continue
			claimed_targets[sibling.target.get_instance_id()] = true
		for candidate in candidates:
			if not claimed_targets.has(candidate.get_instance_id()):
				return candidate
	return candidates[0]


func process_path_assault(delta: float) -> void:
	if path_node == null or path_node.curve == null:
		queue_free()
		return
	if mech_hunter:
		process_hunter_mech(delta)
		return
	var attack_radius := get_effective_attack_radius()
	var assault_target_eligible := (
		is_valid_target(target)
		and global_position.distance_squared_to(target.global_position)
			<= attack_radius * attack_radius
	)
	if target_refresh_remaining <= 0.0:
		target = select_target(global_position, attack_radius)
		target_refresh_remaining = MOBILE_TARGET_REFRESH_INTERVAL
	elif not assault_target_eligible:
		target = null
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
	var hunter_target_eligible := (
		is_valid_target(target)
		and is_instance_valid(target.path_follow)
		and absf(float(target.path_follow.progress) - path_progress)
			<= hunter_pursuit_radius_pixels
	)
	if target_refresh_remaining <= 0.0:
		target = select_hunter_target()
		target_refresh_remaining = MOBILE_TARGET_REFRESH_INTERVAL
	elif not hunter_target_eligible:
		target = null
	if is_valid_target(target):
		var attack_radius := get_effective_attack_radius()
		if global_position.distance_squared_to(target.global_position) <= attack_radius * attack_radius:
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
	var attack_radius := get_effective_attack_radius()
	if (
		not target_is_shared
		and global_position.distance_squared_to(target.global_position)
			> attack_radius * attack_radius
	):
		return
	perform_attack(target)
	register_relentless_primary_attack(target)
	attack_cooldown = get_current_attack_interval()


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
				if (
					is_instance_valid(parent_tower)
					and parent_tower.has_method("schedule_spawned_unit_replacement")
				):
					parent_tower.schedule_spawned_unit_replacement(
						budget_replacement_delay
					)
				queue_free()
				return
			returning_to_base = true


func get_effective_attack_radius() -> float:
	if movement_type == GameStats.MOVEMENT_DRONE:
		return DRONE_ATTACK_RADIUS_UNITS * RANGE_PIXELS_PER_UNIT
	if mech_area_slam and mech_slam_radius_pixels > 0.0:
		return mech_slam_radius_pixels
	return aim_radius_pixels


func get_current_attack_interval() -> float:
	var interval := attack_interval
	if (
		has_damage_tag(&"melee")
		and is_instance_valid(parent_tower)
		and parent_tower.has_method("get_owned_relic_count")
	):
		var frenzy_stacks := int(parent_tower.get_owned_relic_count(&"frenzy"))
		if frenzy_stacks > 0:
			var enemy_count := 0
			var attack_radius := get_effective_attack_radius()
			var attack_radius_squared := attack_radius * attack_radius
			for mob in get_tree().get_nodes_in_group("mobs"):
				if (
					is_valid_target(mob)
					and global_position.distance_squared_to(mob.global_position)
						<= attack_radius_squared
				):
					enemy_count += 1
			enemy_count = mini(
				enemy_count,
				GameStats.FRENZY_MAXIMUM_ENEMY_COUNT
			)
			interval /= (
				1.0
				+ GameStats.FRENZY_SPEED_PER_ENEMY_PER_STACK
					* float(enemy_count)
					* float(frenzy_stacks)
			)
	if (
		has_damage_tag(&"melee")
		and is_instance_valid(parent_tower)
		and parent_tower.has_method("get_owned_relic_count")
		and int(parent_tower.get_owned_relic_count(&"relentless")) > 0
		and relentless_stacks > 0
	):
		interval /= (
			1.0 + GameStats.RELENTLESS_SPEED_PER_STACK * float(relentless_stacks)
		)
	return maxf(interval, 0.01)


func register_relentless_primary_attack(current_target: Node2D) -> void:
	if (
		not has_damage_tag(&"melee")
		or not is_instance_valid(parent_tower)
		or not parent_tower.has_method("get_owned_relic_count")
		or int(parent_tower.get_owned_relic_count(&"relentless")) <= 0
		or not is_valid_target(current_target)
	):
		reset_relentless()
		return
	var current_target_id := current_target.get_instance_id()
	if current_target_id != relentless_target_instance_id:
		relentless_target_instance_id = current_target_id
		relentless_stacks = 1
	else:
		relentless_stacks = mini(
			relentless_stacks + 1,
			GameStats.RELENTLESS_MAXIMUM_STACKS
		)


func reset_relentless() -> void:
	relentless_target_instance_id = 0
	relentless_stacks = 0


func create_attack_context(
	attack_kind: StringName,
	parent_context: AttackContext = null,
	secondary := false,
	include_critical_roll := false
) -> AttackContext:
	if parent_context != null:
		return parent_context.derive(
			self,
			&"spawned_unit",
			attack_kind,
			secondary,
			get_last_attack_roll_metadata()
				if include_critical_roll
				else {}
		)
	var metadata := {"spawned_unit_id": unit_id}
	if (
		is_instance_valid(parent_tower)
		and parent_tower.has_method("get_attack_relic_metadata")
	):
		metadata.merge(
			parent_tower.get_attack_relic_metadata(
				global_position,
				get_effective_attack_radius(),
				type_tags,
				damage_tags
			),
			true
		)
		metadata["source_can_reveal"] = can_source_reveal()
	if include_critical_roll:
		metadata.merge(get_last_attack_roll_metadata(), true)
	return AttackContext.from_tower(
		parent_tower,
		self,
		&"spawned_unit",
		attack_kind,
		metadata
	)


func apply_owned_damage(
	mob: Node,
	attack_damage: int,
	attack_damage_type: StringName,
	ignores_armor: bool,
	attack_context: AttackContext
) -> void:
	var source_tower_id := StringName(parent_tower.get("tower_id"))
	if mob.has_method("apply_damage_from_tower"):
		mob.apply_damage_from_tower(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			source_tower_id,
			attack_context
		)
	else:
		mob.apply_damage(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			true,
			attack_context
		)


func perform_mech_area_slam() -> void:
	if mech_slam_radius_pixels <= 0.0:
		return
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		if get_tree().current_scene.has_method("spawn_explosion_visual"):
			get_tree().current_scene.spawn_explosion_visual(
				global_position, mech_slam_radius_pixels
			)
		else:
			var slam_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
			get_tree().current_scene.add_child(slam_zone)
			slam_zone.global_position = global_position
			slam_zone.setup(mech_slam_radius_pixels)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_area_target(mob):
			continue
		var distance_to_slam: float = global_position.distance_to(mob.global_position)
		if distance_to_slam > mech_slam_radius_pixels:
			continue
		var rolled_damage := roll_attack_damage(mob)
		var slam_context := create_attack_context(
			&"mech_slam", null, false, true
		)
		slam_context.metadata["area_damage"] = true
		var slam_damage := GameStats.get_explosion_damage(
			rolled_damage,
			distance_to_slam,
			mech_slam_radius_pixels
		)
		apply_control_effects(mob)
		apply_owned_damage(mob, slam_damage, &"melee", false, slam_context)


func trigger_budget_explosion() -> void:
	if budget_explosion_radius_pixels <= 0.0:
		return
	if EXPLOSION_ZONE_SCENE != null and get_tree().current_scene != null:
		if get_tree().current_scene.has_method("spawn_explosion_visual"):
			get_tree().current_scene.spawn_explosion_visual(
				global_position, budget_explosion_radius_pixels
			)
		else:
			var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
			get_tree().current_scene.add_child(explosion_zone)
			explosion_zone.global_position = global_position
			explosion_zone.setup(budget_explosion_radius_pixels)
	var explosion_damage := maxi(
		roundi(float(damage) * budget_explosion_damage_multiplier),
		1
	)
	var explosion_context := RelicEffects.prepare_explosion_context(
		create_attack_context(&"drone_payload_explosion"),
		get_tree(),
		global_position,
		budget_explosion_radius_pixels
	)
	for mob in get_tree().get_nodes_in_group("mobs"):
		if not RelicEffects.is_valid_explosion_target(mob, explosion_context):
			continue
		var distance_to_blast: float = global_position.distance_to(mob.global_position)
		if distance_to_blast > budget_explosion_radius_pixels:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage,
			distance_to_blast,
			budget_explosion_radius_pixels
		)
		apply_owned_damage(
			mob,
			dealt_damage,
			&"explosive",
			false,
			explosion_context
		)


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
		# Multi-projectile volleys share one muzzle and spread toward separate
		# endpoints. Their separation therefore grows throughout the flight
		# instead of starting wide and converging on the selected target.
		var launch_position := global_position
		var destination := (
			current_target.global_position
			+ perpendicular * volley_width_pixels * spread_ratio
		)
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
			has_bonus_tag(&"reveal"),
			StringName(parent_tower.get("tower_id")),
			false,
			pierce_loses_no_power,
			1.0,
			create_attack_context(
				&"spawned_projectile", null, false, true
			).derive(
				projectile,
				&"projectile",
				&"spawned_projectile",
				false
			)
		)


func perform_hitscan_attack(
	current_target: Node2D,
	attack_damage: int,
	damage_type: StringName
) -> void:
	spawn_hitscan_effect(global_position, current_target.global_position, damage_type)
	var attack_context := create_attack_context(
		&"spawned_hitscan", null, false, true
	)
	apply_control_effects(current_target, attack_context)
	apply_owned_damage(
		current_target,
		attack_damage,
		damage_type,
		pierce_count > 0,
		attack_context
	)
	var hit_target_ids: Dictionary = {current_target.get_instance_id(): true}
	var bounce_result := perform_hitscan_bounces(
		current_target,
		global_position,
		attack_damage,
		damage_type,
		attack_context,
		hit_target_ids
	)
	var last_hit_target: Node2D = bounce_result["target"]
	var final_leg_origin: Vector2 = bounce_result["origin"]
	var final_leg_distance: float = bounce_result["maximum_distance"]
	var final_aim_offset := last_hit_target.global_position - final_leg_origin
	if pierce_count > 0 and not final_aim_offset.is_zero_approx():
		var direction := final_aim_offset.normalized()
		var line_origin := last_hit_target.global_position + direction * 0.01
		var line_end := final_leg_origin + direction * final_leg_distance
		spawn_hitscan_effect(last_hit_target.global_position, line_end, damage_type)
		var targets := get_hitscan_pierce_targets(
			line_origin,
			line_end,
			last_hit_target
		)
		var pierced_hits := 0
		for pierced_target: Node2D in targets:
			if hit_target_ids.has(pierced_target.get_instance_id()):
				continue
			if pierced_hits >= pierce_count:
				break
			hit_target_ids[pierced_target.get_instance_id()] = true
			var pierce_context := create_attack_context(
				&"spawned_pierce", attack_context, true
			)
			apply_control_effects(pierced_target, pierce_context)
			var pierced_damage := GameStats.get_piercing_damage(
				attack_damage,
				pierced_hits + 1,
				pierce_loses_no_power
			)
			apply_owned_damage(
				pierced_target,
				pierced_damage,
				damage_type,
				true,
				pierce_context
			)
			pierced_hits += 1
func perform_hitscan_bounces(
	starting_target: Node2D,
	starting_origin: Vector2,
	attack_damage: int,
	attack_damage_type: StringName,
	parent_context: AttackContext,
	hit_target_ids: Dictionary
) -> Dictionary:
	var result := {
		"target": starting_target,
		"origin": starting_origin,
		"maximum_distance": aim_radius_pixels,
	}
	if bounce_count < 1 or bounce_range_pixels <= 0.0:
		return result
	var bounce_source := starting_target
	for _bounce_index in bounce_count:
		var bounce_target := get_nearest_hitscan_bounce_target(
			bounce_source.global_position,
			hit_target_ids
		)
		if bounce_target == null:
			break
		var bounce_context := create_attack_context(
			&"spawned_bounce", parent_context, true
		)
		spawn_hitscan_effect(
			bounce_source.global_position,
			bounce_target.global_position,
			attack_damage_type
		)
		apply_control_effects(bounce_target, bounce_context)
		apply_owned_damage(
			bounce_target,
			attack_damage,
			attack_damage_type,
			pierce_count > 0 or infinite_pierce,
			bounce_context
		)
		hit_target_ids[bounce_target.get_instance_id()] = true
		result["origin"] = bounce_source.global_position
		result["maximum_distance"] = bounce_range_pixels
		bounce_source = bounce_target
		result["target"] = bounce_source
	return result


func get_nearest_hitscan_bounce_target(
	origin: Vector2,
	excluded_target_ids: Dictionary
) -> Node2D:
	var selected_target: Node2D
	var selected_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		if excluded_target_ids.has(candidate.get_instance_id()):
			continue
		var candidate_distance := origin.distance_to(candidate.global_position)
		if candidate_distance > bounce_range_pixels:
			continue
		if candidate_distance < selected_distance:
			selected_distance = candidate_distance
			selected_target = candidate
	return selected_target


func spawn_hitscan_effect(
	start_position: Vector2,
	end_position: Vector2,
	attack_type: StringName
) -> void:
	if HITSCAN_EFFECT_SCENE == null or get_tree().current_scene == null:
		return
	if get_tree().current_scene.has_method("spawn_hitscan_visual"):
		get_tree().current_scene.spawn_hitscan_visual(
			start_position, end_position, attack_type
		)
		return
	var effect := HITSCAN_EFFECT_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(effect)
	effect.setup(start_position, end_position, attack_type)


func perform_continuous_beam_attack(
	current_target: Node2D,
	attack_damage: int,
	damage_type: StringName
) -> bool:
	ensure_continuous_beam_aim(current_target)
	if not beam_has_aim:
		return false
	var line_origin := global_position
	var beam_length := get_continuous_beam_length(current_target)
	var line_end := line_origin + beam_aim_direction * beam_length
	var beam_context := create_attack_context(
		&"spawned_beam_tick", null, false, true
	)
	if pierce_count < 1 and not infinite_pierce:
		if not is_target_intersecting_beam(current_target, line_origin, line_end):
			return false
		apply_control_effects(current_target, beam_context)
		apply_owned_damage(
			current_target,
			attack_damage,
			damage_type,
			false,
			beam_context
		)
		return true

	var targets := get_hitscan_pierce_targets(line_origin, line_end, null, true)
	var maximum_hits := targets.size()
	if not infinite_pierce:
		maximum_hits = mini(maximum_hits, 1 + pierce_count)
	for index in maximum_hits:
		apply_control_effects(targets[index])
		apply_owned_damage(
			targets[index],
			GameStats.get_piercing_damage(
				attack_damage,
				index,
				pierce_loses_no_power
			),
			damage_type,
			true,
			create_attack_context(
				&"spawned_beam_pierce",
				beam_context,
				index > 0
			)
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
	var turn_angle := beam_aim_direction.angle_to(desired_direction)
	var maximum_turn := beam_turn_speed_radians * delta
	beam_aim_direction = beam_aim_direction.rotated(
		clampf(turn_angle, -maximum_turn, maximum_turn)
	).normalized()


func get_continuous_beam_length(current_target: Node2D) -> float:
	if (
		pierce_count < 1
		and not infinite_pierce
		and is_valid_target(current_target)
	):
		return global_position.distance_to(current_target.global_position)
	return aim_radius_pixels


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
		<= hit_radius + get_current_beam_half_width()
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
		var line_half_width := (
			get_current_beam_half_width() if use_beam_width else 0.0
		)
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
	last_attack_roll_was_critical = false
	last_attack_roll_missed = false
	if miss_chance > 0.0 and randf() < miss_chance:
		last_attack_roll_missed = true
		return 0
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
		last_attack_roll_was_critical = true
		return maxi(roundi(
			float(damage)
			* critical_multiplier
			* get_death_ray_damage_multiplier()
		), 1)
	return maxi(roundi(
		float(damage)
		* noncritical_damage_multiplier
		* get_death_ray_damage_multiplier()
	), 1)


func process_death_ray_overcharge(delta: float) -> void:
	if death_ray_overcharge_enabled and is_combat_active():
		death_ray_cycle_elapsed = fmod(
			death_ray_cycle_elapsed + delta,
			GameStats.DEATH_RAY_CYCLE_DURATION
		)
	refresh_death_ray_overcharge_state()


func refresh_death_ray_overcharge_state() -> void:
	var was_active := death_ray_overcharge_active
	death_ray_overcharge_active = (
		death_ray_overcharge_enabled
		and is_combat_active()
		and death_ray_cycle_elapsed < GameStats.DEATH_RAY_OVERCHARGE_DURATION
	)
	infinite_pierce = inherent_infinite_pierce or death_ray_overcharge_active
	if death_ray_overcharge_active != was_active:
		queue_redraw()


func get_death_ray_damage_multiplier() -> float:
	return (
		GameStats.DEATH_RAY_DAMAGE_MULTIPLIER
		if death_ray_overcharge_active
		else 1.0
	)


func get_current_beam_half_width() -> float:
	return BEAM_HIT_HALF_WIDTH * (
		GameStats.DEATH_RAY_WIDTH_MULTIPLIER
		if death_ray_overcharge_active
		else 1.0
	)


func is_combat_active() -> bool:
	return (
		is_instance_valid(parent_tower)
		and parent_tower.has_method("is_combat_active")
		and parent_tower.is_combat_active()
	)


func get_last_attack_roll_metadata() -> Dictionary:
	return {
		"was_critical": last_attack_roll_was_critical,
		"shot_missed": last_attack_roll_missed,
	}


func apply_control_effects(
	current_target: Node,
	attack_context: AttackContext = null
) -> void:
	if (
		attack_context != null
		and bool(attack_context.metadata.get("shot_missed", false))
	):
		return
	var resolved_context := attack_context
	if resolved_context == null:
		resolved_context = create_attack_context(&"spawned_status_effect")
	if slow_duration > 0.0 and current_target.has_method("apply_slow"):
		current_target.apply_slow(slow_duration, resolved_context)
	if stun_duration > 0.0 and current_target.has_method("apply_stun"):
		current_target.apply_stun(
			stun_duration,
			stun_affects_bosses,
			resolved_context
		)


func select_target(origin: Vector2, maximum_distance: float) -> Node2D:
	var selected_target: Node2D
	var selected_progress := -INF
	var maximum_distance_squared := maximum_distance * maximum_distance
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		if origin.distance_squared_to(candidate.global_position) > maximum_distance_squared:
			continue
		var progress := float(candidate.path_follow.progress)
		if progress > selected_progress:
			selected_progress = progress
			selected_target = candidate
	return selected_target


func get_initial_target_refresh_delay() -> float:
	var phase := float(get_instance_id() % 997) / 997.0
	return phase * MOBILE_TARGET_REFRESH_INTERVAL


func is_valid_target(candidate: Variant) -> bool:
	if not is_valid_area_target(candidate):
		return false
	if (
		movement_type == GameStats.MOVEMENT_DRONE
		and is_instance_valid(parent_tower)
		and parent_tower.has_method("is_valid_drone_command_target")
	):
		return parent_tower.is_valid_drone_command_target(candidate)
	if candidate.traits.has(&"hidden"):
		return (
			has_bonus_tag(&"reveal")
			or (
				candidate.has_method("is_revealed_for_all")
				and candidate.is_revealed_for_all()
			)
		)
	return true


func can_source_reveal() -> bool:
	if (
		movement_type == GameStats.MOVEMENT_DRONE
		and is_instance_valid(parent_tower)
		and parent_tower.has_method("has_bonus_tag")
	):
		return parent_tower.has_bonus_tag(&"reveal")
	return has_bonus_tag(&"reveal")


func get_drone_command_radius_pixels() -> float:
	if (
		is_instance_valid(parent_tower)
		and parent_tower.has_method("get_drone_command_radius_pixels")
	):
		return maxf(float(parent_tower.get_drone_command_radius_pixels()), 1.0)
	return maxf(leash_radius_pixels, 1.0)


func is_valid_area_target(candidate: Variant) -> bool:
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
	if (
		continuous_beam
		and beam_has_aim
		and not returning_to_base
		and recharge_remaining <= 0.0
		and is_valid_target(target)
		and global_position.distance_to(target.global_position) <= aim_radius_pixels
	):
		var beam_end := (
			global_position
			+ beam_aim_direction * get_continuous_beam_length(target)
		)
		draw_line(
			Vector2.ZERO,
			to_local(beam_end),
			Color(0.25, 0.85, 1.0, 0.9),
			get_current_beam_half_width(),
			true
		)
		draw_circle(Vector2.ZERO, 3.5, Color(0.55, 0.95, 1.0, 0.9))
	if death_ray_overcharge_active:
		draw_arc(
			Vector2.ZERO,
			13.0,
			0.0,
			TAU,
			24,
			Color(0.35, 0.9, 1.0, 0.95),
			2.5,
			true
		)
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
		&"reinforcement_alien":
			var body_color := Color(0.38, 0.9, 0.48)
			draw_circle(Vector2(0.0, -3.0), 8.0, body_color)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-7.0, 3.0),
					Vector2(7.0, 3.0),
					Vector2(5.0, 12.0),
					Vector2(-5.0, 12.0),
				]),
				body_color.darkened(0.18)
			)
			draw_circle(Vector2(-3.0, -4.0), 1.8, Color(0.08, 0.12, 0.1))
			draw_circle(Vector2(3.0, -4.0), 1.8, Color(0.08, 0.12, 0.1))
			draw_line(Vector2(-7.0, 5.0), Vector2(-12.0, 9.0), body_color, 3.0, true)
			draw_line(Vector2(7.0, 5.0), Vector2(12.0, 9.0), body_color, 3.0, true)
		_:
			draw_circle(Vector2.ZERO, 8.0, Color.WHITE)
