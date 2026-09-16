class_name SaucerAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const AreaDamage = preload("res://area_damage_helper.gd")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const SAUCER_FLYER_SCENE = preload("res://saucer_flyer.tscn")

var twin_rockets_enabled := false
var rocket_damage_multiplier := 2.0
var rocket_interval := 3.0
var rocket_splash_radius_pixels := 0.0
var rocket_count := 2
var rocket_damage_type: StringName = BaseTower.DAMAGE_EXPLOSIVE
var monster_drop_enabled := false
var hunt_abductions_enabled := false
var maximum_monsters := 1
var monster_damage_multiplier := 1.0
var elite_abduction_threshold := 0.0
var vulnerability_field_enabled := false
var vulnerability_field_radius_pixels := 0.0
var vulnerability_field_bonus := 0.0
var vulnerability_field_refresh_interval := 0.2
var vulnerability_field_refresh_remaining := 0.0
var field_revealed_mobs: Array[Node] = []
var flyer_move_speed := 165.0
var attack_radius_pixels := 0.0
var abduction_cooldown := 16.0
var abduction_radius_pixels := 0.0
var abduction_health_threshold := 0.35
var monster_stats: Dictionary = {}
var active_flyer: Node2D
var active_monster: Node
var active_monsters: Array[Node] = []


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
	rocket_count = 2
	rocket_damage_type = BaseTower.DAMAGE_EXPLOSIVE
	monster_drop_enabled = false
	hunt_abductions_enabled = false
	maximum_monsters = 1
	monster_damage_multiplier = 1.0
	elite_abduction_threshold = 0.0
	vulnerability_field_enabled = false
	vulnerability_field_radius_pixels = 0.0
	vulnerability_field_bonus = 0.0
	vulnerability_field_refresh_interval = 0.2


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
		rocket_count = maxi(int(values.get("saucer_rocket_count", 2)), 1)
		rocket_damage_type = StringName(values.get(
			"saucer_rocket_damage_type", BaseTower.DAMAGE_EXPLOSIVE
		))
	if flags.get("saucer_monster_drop", false):
		monster_drop_enabled = true
		maximum_monsters = maxi(int(values.get("saucer_maximum_monsters", 1)), 1)
		monster_damage_multiplier = maxf(
			float(values.get("saucer_monster_damage_multiplier", 1.0)), 0.0
		)
		elite_abduction_threshold = clampf(
			float(values.get("saucer_elite_abduction_threshold", 0.0)), 0.0, 1.0
		)
	if flags.get("saucer_hunt_abductions", false):
		hunt_abductions_enabled = true
	if flags.get("saucer_vulnerability_field", false):
		vulnerability_field_enabled = true
		vulnerability_field_radius_pixels = maxf(
			float(values.get("saucer_field_radius", 3.5)), 0.0
		) * BaseTower.BUILD_CELL_SIZE
		vulnerability_field_bonus = maxf(
			float(values.get("saucer_field_vulnerability", 0.15)), 0.0
		)
		vulnerability_field_refresh_interval = maxf(
			float(values.get("saucer_field_refresh_interval", 0.20)), 0.05
		)


func finalize_path_behaviors() -> void:
	if not vulnerability_field_enabled:
		clear_field_reveals()
	if not twin_rockets_enabled or not tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		return
	if tower.get_primary_damage_type() != BaseTower.DAMAGE_EXPLOSIVE:
		rocket_damage_multiplier *= tower.get_explosion_damage_multiplier()
	rocket_splash_radius_pixels *= tower.get_explosion_radius_multiplier()
	rocket_interval *= tower.get_explosion_interval_multiplier()


func on_placement_confirmed() -> void:
	ensure_flyer()


func on_round_ended() -> void:
	clear_monsters()
	clear_field_reveals()


func _exit_tree() -> void:
	if is_instance_valid(active_flyer):
		active_flyer.queue_free()
	clear_monsters()
	clear_field_reveals()


func process_attack(delta: float) -> void:
	if not vulnerability_field_enabled or not is_instance_valid(active_flyer):
		return
	if not is_combat_active():
		clear_field_reveals()
		return
	vulnerability_field_refresh_remaining = maxf(
		vulnerability_field_refresh_remaining - delta, 0.0
	)
	if vulnerability_field_refresh_remaining > 0.0:
		return
	vulnerability_field_refresh_remaining = vulnerability_field_refresh_interval
	refresh_vulnerability_field()


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
		and tower.is_combat_active()
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
	if candidate.traits.has(&"boss"):
		return false
	if candidate.max_health <= 0:
		return false
	var health_ratio := float(candidate.health) / float(candidate.max_health)
	if candidate.traits.has(&"elite"):
		return elite_abduction_threshold > 0.0 and health_ratio <= elite_abduction_threshold
	return (
		health_ratio <= abduction_health_threshold
	)


func get_navigation_target(
	saucer_position: Vector2,
	abduction_is_ready: bool
) -> Node2D:
	if hunt_abductions_enabled and abduction_is_ready:
		var hunted_target := get_abduction_hunt_target(saucer_position)
		if hunted_target != null:
			return hunted_target
	return get_target()


func get_abduction_hunt_target(_saucer_position: Vector2) -> Node2D:
	if not is_combat_active():
		return null
	var selected_target: Node2D
	var selected_max_health := -1
	var selected_progress := -INF
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), tower.global_position, tower.range_radius_pixels
	):
		if not can_abduct_target(candidate):
			continue
		if tower.global_position.distance_to(candidate.global_position) > tower.range_radius_pixels:
			continue
		var candidate_max_health := int(candidate.max_health)
		var candidate_progress := (
			float(candidate.path_follow.progress)
			if is_instance_valid(candidate.path_follow)
			else -INF
		)
		if candidate_max_health > selected_max_health or (
			candidate_max_health == selected_max_health
			and candidate_progress > selected_progress
		):
			selected_target = candidate
			selected_max_health = candidate_max_health
			selected_progress = candidate_progress
	return selected_target


func get_abduction_target(saucer_position: Vector2) -> Node2D:
	if not is_combat_active():
		return null
	var selected_target: Node2D
	var selected_max_health := -1
	var selected_progress := -INF
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), saucer_position, abduction_radius_pixels
	):
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
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), saucer_position, attack_radius_pixels
	):
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
	for rocket_index in rocket_count:
		var centered_index := float(rocket_index) - float(rocket_count - 1) * 0.5
		var lateral_offset := centered_index * 7.0
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
			rocket_damage_type,
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
	if not monster_drop_enabled or not tower.is_combat_active():
		return
	prune_monsters()
	if active_monsters.size() >= maximum_monsters:
		return
	var resolved_stats := monster_stats.duplicate(true)
	resolved_stats["damage"] = maxi(
		roundi(
			float(resolved_stats.get("damage", 1)) * monster_damage_multiplier
			+ tower.get_main_bonus(&"tower_damage_flat")
		), 1
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
	active_monsters.append(monster)
	monster.tree_exiting.connect(_on_monster_exiting.bind(monster))


func _on_monster_exiting(monster: Node) -> void:
	active_monsters.erase(monster)
	if active_monster == monster:
		active_monster = active_monsters[0] if not active_monsters.is_empty() else null


func clear_monster() -> void:
	clear_monsters()


func clear_monsters() -> void:
	for monster in active_monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	active_monsters.clear()
	active_monster = null


func prune_monsters() -> void:
	active_monsters = active_monsters.filter(
		func(monster: Node) -> bool:
			return is_instance_valid(monster) and not monster.is_queued_for_deletion()
	)
	active_monster = active_monsters[0] if not active_monsters.is_empty() else null


func refresh_vulnerability_field() -> void:
	if not vulnerability_field_enabled or not is_instance_valid(active_flyer):
		clear_field_reveals()
		return
	var field_context := tower.create_attack_context(&"mothership_vulnerability_field")
	var current_mobs: Array[Node] = []
	for candidate in AreaDamage.get_targets_near(
		tower.get_tree(), active_flyer.global_position,
		vulnerability_field_radius_pixels
	):
		if not tower.is_valid_target(candidate):
			continue
		if active_flyer.global_position.distance_to(candidate.global_position) > vulnerability_field_radius_pixels:
			continue
		current_mobs.append(candidate)
		if candidate.has_method("apply_external_vulnerability"):
			candidate.apply_external_vulnerability(
				vulnerability_field_refresh_interval * 2.5,
				vulnerability_field_bonus,
				field_context
			)
		if candidate.has_method("add_global_reveal_source"):
			candidate.add_global_reveal_source(active_flyer, field_context)
	for previous_mob in field_revealed_mobs:
		if (
			is_instance_valid(previous_mob)
			and not current_mobs.has(previous_mob)
			and previous_mob.has_method("remove_global_reveal_source")
		):
			previous_mob.remove_global_reveal_source(active_flyer)
	field_revealed_mobs = current_mobs


func clear_field_reveals() -> void:
	if is_instance_valid(active_flyer):
		for mob in field_revealed_mobs:
			if is_instance_valid(mob) and mob.has_method("remove_global_reveal_source"):
				mob.remove_global_reveal_source(active_flyer)
	field_revealed_mobs.clear()
