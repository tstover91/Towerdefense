class_name SaucerAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const SAUCER_FLYER_SCENE = preload("res://saucer_flyer.tscn")

var twin_rockets_enabled := false
var rocket_damage_multiplier := 2.0
var rocket_interval := 3.0
var rocket_splash_radius_pixels := 0.0
var monster_drop_enabled := false
var flyer_move_speed := 165.0
var attack_radius_pixels := 0.0
var abduction_cooldown := 16.0
var abduction_radius_pixels := 0.0
var abduction_health_threshold := 0.35
var monster_stats: Dictionary = {}
var active_flyer: Node2D
var active_monster: Node


func uses_standard_targeting() -> bool:
	return false


func uses_shared_attack_scheduler() -> bool:
	return false


func shows_target_mode_control() -> bool:
	return false


func load_level_stats(stats: Dictionary) -> void:
	flyer_move_speed = maxf(float(stats.get("flyer_move_speed", 165.0)), 0.0)
	attack_radius_pixels = (
		maxf(float(stats.get("flyer_attack_radius", 5.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	abduction_cooldown = maxf(float(stats.get("abduction_cooldown", 16.0)), 0.1)
	abduction_radius_pixels = (
		maxf(float(stats.get("abduction_radius", 1.5)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	abduction_health_threshold = clampf(
		float(stats.get("abduction_health_threshold", 0.35)), 0.0, 1.0
	)
	monster_stats = stats.get("monster_stats", {}).duplicate(true)


func reset_path_behaviors() -> void:
	twin_rockets_enabled = false
	rocket_damage_multiplier = 2.0
	rocket_interval = 3.0
	rocket_splash_radius_pixels = 0.0
	monster_drop_enabled = false


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("saucer_twin_rockets", false):
		twin_rockets_enabled = true
		rocket_damage_multiplier = maxf(
			float(values.get("saucer_rocket_damage_multiplier", 2.0)), 0.0
		)
		rocket_interval = maxf(
			float(values.get("saucer_rocket_interval", 3.0)), 0.1
		)
		rocket_splash_radius_pixels = (
			maxf(float(values.get("saucer_rocket_splash_radius", 3.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
	if flags.get("saucer_monster_drop", false):
		monster_drop_enabled = true


func finalize_path_behaviors() -> void:
	if not twin_rockets_enabled or not tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		return
	if tower.get_primary_damage_type() != BaseTower.DAMAGE_EXPLOSIVE:
		rocket_damage_multiplier *= tower.get_explosion_damage_multiplier()
	rocket_splash_radius_pixels *= tower.get_explosion_radius_multiplier()
	rocket_interval *= tower.get_explosion_interval_multiplier()


func on_placement_confirmed() -> void:
	ensure_flyer()


func on_round_ended() -> void:
	clear_monster()


func _exit_tree() -> void:
	if is_instance_valid(active_flyer):
		active_flyer.queue_free()
	clear_monster()


func ensure_flyer() -> void:
	if not tower.is_placed or is_instance_valid(active_flyer):
		return
	if SAUCER_FLYER_SCENE == null or tower.get_tree().current_scene == null:
		return
	active_flyer = SAUCER_FLYER_SCENE.instantiate() as Node2D
	tower.get_tree().current_scene.add_child(active_flyer)
	active_flyer.global_position = tower.global_position
	active_flyer.setup(tower, self)


func is_combat_active() -> bool:
	return (
		tower.is_placed
		and tower.main != null
		and tower.main.round_active
		and not tower.is_queued_for_deletion()
	)


func get_target() -> Node2D:
	if not is_combat_active():
		return null
	tower.target_mode = BaseTower.TargetMode.FIRST
	tower._select_target()
	return tower.target if tower.is_valid_target(tower.target) else null


func can_abduct_target(candidate: Variant) -> bool:
	if not tower.is_valid_target(candidate):
		return false
	if candidate.traits.has(&"boss") or candidate.traits.has(&"elite"):
		return false
	if candidate.max_health <= 0:
		return false
	return (
		float(candidate.health) / float(candidate.max_health)
		<= abduction_health_threshold
	)


func get_abduction_target(saucer_position: Vector2) -> Node2D:
	if not is_combat_active():
		return null
	var selected_target: Node2D
	var selected_max_health := -1
	var selected_progress := -INF
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if not can_abduct_target(candidate):
			continue
		if saucer_position.distance_to(candidate.global_position) > abduction_radius_pixels:
			continue
		var candidate_max_health := int(candidate.max_health)
		var candidate_progress := -INF
		if is_instance_valid(candidate.path_follow):
			candidate_progress = float(candidate.path_follow.progress)
		if (
			candidate_max_health > selected_max_health
			or (
				candidate_max_health == selected_max_health
				and candidate_progress > selected_progress
			)
		):
			selected_max_health = candidate_max_health
			selected_progress = candidate_progress
			selected_target = candidate
	return selected_target


func get_rocket_target(saucer_position: Vector2, gun_target: Node2D) -> Node2D:
	if not is_combat_active():
		return null
	var selected_target: Node2D
	var selected_health := -1
	var selected_progress := -INF
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if candidate == gun_target or not tower.is_valid_target(candidate):
			continue
		if saucer_position.distance_to(candidate.global_position) > attack_radius_pixels:
			continue
		var candidate_health := int(candidate.health)
		var candidate_progress := -INF
		if is_instance_valid(candidate.path_follow):
			candidate_progress = float(candidate.path_follow.progress)
		if (
			candidate_health > selected_health
			or (
				candidate_health == selected_health
				and candidate_progress > selected_progress
			)
		):
			selected_health = candidate_health
			selected_progress = candidate_progress
			selected_target = candidate
	if selected_target != null:
		return selected_target
	if (
		tower.is_valid_target(gun_target)
		and saucer_position.distance_to(gun_target.global_position) <= attack_radius_pixels
	):
		return gun_target
	return null


func fire_weapon(launch_position: Vector2, current_target: Node2D) -> void:
	if not is_combat_active() or not tower.is_valid_target(current_target):
		return
	var attack_damage := tower.roll_attack_damage(current_target)
	var gun_context := tower.create_attack_context(
		&"electric_primary", null, &"tower", null, false, true
	)
	tower.spawn_hitscan_effect(
		launch_position, current_target.global_position, BaseTower.DAMAGE_ELECTRIC
	)
	tower.apply_control_effects(current_target, gun_context)
	tower.apply_tower_damage(
		current_target,
		attack_damage,
		BaseTower.DAMAGE_ELECTRIC,
		false,
		gun_context
	)


func fire_rockets(launch_position: Vector2, gun_target: Node2D) -> bool:
	if not twin_rockets_enabled:
		return false
	var rocket_target := get_rocket_target(launch_position, gun_target)
	if not tower.is_valid_target(rocket_target):
		return false
	var rocket_damage := maxi(
		roundi(float(tower.roll_attack_damage(rocket_target)) * rocket_damage_multiplier), 1
	)
	_fire_homing_rockets(launch_position, rocket_target, rocket_damage)
	return true


func _fire_homing_rockets(
	launch_position: Vector2,
	current_target: Node2D,
	rocket_damage: int
) -> void:
	if tower.projectile_scene == null or not tower.is_valid_target(current_target):
		return
	var aim_offset := current_target.global_position - launch_position
	var perpendicular := (
		aim_offset.normalized().orthogonal()
		if not aim_offset.is_zero_approx()
		else Vector2.UP
	)
	for rocket_index in 2:
		var lateral_offset := -7.0 if rocket_index == 0 else 7.0
		var rocket_origin := launch_position + perpendicular * lateral_offset
		var destination := current_target.global_position
		var projectile := tower.projectile_scene.instantiate() as TowerProjectile
		tower.get_tree().current_scene.add_child(projectile)
		projectile.global_position = rocket_origin
		projectile.setup(
			current_target,
			destination,
			tower.projectile_speed,
			maxf(tower.range_radius_pixels, rocket_origin.distance_to(destination) * 2.0),
			rocket_damage,
			BaseTower.DAMAGE_EXPLOSIVE,
			GameStats.IMPACT_PRIMARY,
			rocket_splash_radius_pixels,
			0,
			0.0,
			0.0,
			false,
			0,
			0.0,
			false,
			0.0,
			false,
			tower.has_bonus_tag(BaseTower.BONUS_REVEAL),
			tower.tower_id,
			true,
			false,
			1.0,
			tower.create_attack_context(
				&"homing_rocket", projectile, &"projectile", null, false, true
			)
		)


func try_abduction(current_target: Node2D, saucer_position: Vector2) -> bool:
	if (
		not is_combat_active()
		or not can_abduct_target(current_target)
		or saucer_position.distance_to(current_target.global_position)
			> abduction_radius_pixels
	):
		return false
	if current_target.has_method("abduct"):
		current_target.abduct(tower.create_attack_context(&"abduction"))
	else:
		current_target.queue_free()
	if monster_drop_enabled:
		_spawn_monster(saucer_position)
	if tower.target == current_target:
		tower.target = null
	return true


func _spawn_monster(spawn_position: Vector2) -> void:
	if not monster_drop_enabled or tower.main == null or not tower.main.round_active:
		return
	if is_instance_valid(active_monster) and not active_monster.is_queued_for_deletion():
		return
	var resolved_stats := monster_stats.duplicate(true)
	resolved_stats["damage"] = maxi(
		roundi(float(resolved_stats.get("damage", 1)) + tower.get_main_bonus(&"tower_damage_flat")), 1
	)
	resolved_stats["attack_interval"] = maxf(
		float(resolved_stats.get("attack_interval", 1.0))
			/ tower.get_main_multiplier(&"tower_attack_speed"),
		0.01
	)
	resolved_stats["aim_radius"] = (
		float(resolved_stats.get("aim_radius", 4.0))
		* tower.get_main_multiplier(&"tower_range")
	)
	resolved_stats["acquisition_radius"] = (
		float(resolved_stats.get("acquisition_radius", 8.0))
		* tower.get_main_multiplier(&"tower_range")
	)
	var monster := SPAWNED_UNIT_SCENE.instantiate()
	tower.get_tree().current_scene.add_child(monster)
	monster.global_position = spawn_position
	monster.setup(&"abducted_monster", resolved_stats, tower, null)
	active_monster = monster
	monster.tree_exiting.connect(_on_monster_exiting.bind(monster))


func _on_monster_exiting(monster: Node) -> void:
	if active_monster == monster:
		active_monster = null


func clear_monster() -> void:
	if is_instance_valid(active_monster):
		active_monster.queue_free()
	active_monster = null
