class_name TowerAttackDeliveryController
extends Node

const GameStats = preload("res://stat_database.gd")
const HITSCAN_EFFECT_SCENE = preload("res://hitscan_effect.tscn")

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


func attack(current_target: Node2D) -> void:
	# Revalidate at the firing boundary so losing reveal cannot produce a shot.
	if not tower.is_valid_target(current_target):
		return
	if tower.uses_continuous_beam():
		var beam_damage := tower.damage
		if tower.attack_component != null:
			beam_damage = tower.attack_component.get_continuous_beam_damage(
				beam_damage
			)
		apply_continuous_beam_tick(
			current_target,
			roll_critical_damage(beam_damage, current_target),
			0.0
		)
		return
	if (
		tower.attack_component != null
		and tower.attack_component.execute_raw_attack(
			current_target, tower.damage
		)
	):
		return
	var base_attack_damage := tower.damage
	if tower.attack_component != null:
		base_attack_damage = tower.attack_component.modify_base_attack_damage(
			current_target, base_attack_damage
		)
	var attack_damage := roll_critical_damage(base_attack_damage, current_target)
	if (
		tower.attack_component != null
		and tower.attack_component.execute_attack(current_target, attack_damage)
	):
		return
	if tower.delivery_type == GameStats.DELIVERY_PROJECTILE:
		launch_projectile(current_target, attack_damage)
	else:
		apply_hitscan_damage(current_target, attack_damage)


func apply_tower_damage(
	current_target: Node,
	attack_damage: int,
	attack_damage_type: StringName,
	ignores_armor: bool,
	attack_context: AttackContext = null
) -> void:
	var resolved_context := attack_context
	if resolved_context == null:
		resolved_context = create_attack_context(&"direct")
	if bool(resolved_context.metadata.get("shot_missed", false)):
		return
	if current_target.has_method("apply_damage_from_tower"):
		current_target.apply_damage_from_tower(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			tower.tower_id,
			resolved_context
		)
	else:
		current_target.apply_damage(
			attack_damage,
			attack_damage_type,
			ignores_armor,
			true,
			resolved_context
		)


func create_attack_context(
	attack_kind: StringName,
	immediate_source: Object = null,
	source_kind: StringName = &"tower",
	parent_context: AttackContext = null,
	secondary := false,
	include_critical_roll := false
) -> AttackContext:
	var source: Object = immediate_source if immediate_source != null else tower
	if parent_context != null:
		return parent_context.derive(
			source,
			source_kind,
			attack_kind,
			secondary,
			get_last_attack_roll_metadata()
				if include_critical_roll
				else {}
		)
	var metadata := get_attack_relic_metadata(
		tower.global_position,
		tower.range_radius_pixels,
		tower.type_tags
	)
	if include_critical_roll:
		metadata.merge(get_last_attack_roll_metadata(), true)
	return AttackContext.from_tower(
		tower,
		source,
		source_kind,
		attack_kind,
		metadata
	)


func register_relentless_primary_attack(current_target: Node2D) -> void:
	if (
		not tower.has_damage_tag(BaseTower.DAMAGE_MELEE)
		or tower.get_owned_relic_count(&"relentless") <= 0
		or not tower.is_valid_target(current_target)
	):
		reset_relentless()
		return
	var current_target_id := current_target.get_instance_id()
	if current_target_id != tower.relentless_target_instance_id:
		tower.relentless_target_instance_id = current_target_id
		tower.relentless_stacks = 1
	else:
		tower.relentless_stacks = mini(
			tower.relentless_stacks + 1,
			GameStats.RELENTLESS_MAXIMUM_STACKS
		)


func reset_relentless() -> void:
	tower.relentless_target_instance_id = 0
	tower.relentless_stacks = 0


func get_attack_relic_metadata(
	source_position: Vector2,
	source_range: float,
	source_type_tags: Array
) -> Dictionary:
	return {
		"source_position": source_position,
		"source_range": maxf(source_range, 0.0),
		"source_type_tags": source_type_tags.duplicate(),
		"source_can_reveal": tower.has_bonus_tag(BaseTower.BONUS_REVEAL),
		"enemies_in_range": count_valid_enemies_near(
			source_position, source_range
		),
		"nearby_melee_towers": mini(
			tower.stats_controller.get_nearby_tower_count(
				BaseTower.DAMAGE_MELEE, 1.5 * BaseTower.BUILD_CELL_SIZE
			),
			GameStats.STRENGTH_IN_NUMBERS_MAXIMUM_NEIGHBORS
		),
		"pack_hunter": tower.get_owned_relic_count(&"pack_hunter"),
		"predatory_instinct": tower.get_owned_relic_count(&"predatory_instinct"),
		"interference_beam": tower.get_owned_relic_count(&"interference_beam"),
		"microwave": tower.get_owned_relic_count(&"microwave"),
		"hollow_point": tower.get_owned_relic_count(&"hollow_point"),
		"long_barrel": tower.get_owned_relic_count(&"long_barrel"),
		"point_blank": tower.get_owned_relic_count(&"point_blank"),
		"giant_killer": tower.get_owned_relic_count(&"giant_killer"),
		"duelist": tower.get_owned_relic_count(&"duelist"),
		"strength_in_numbers": tower.get_owned_relic_count(&"strength_in_numbers"),
		"crowd_pleaser": tower.get_owned_relic_count(&"crowd_pleaser"),
		"direct_hit": tower.get_owned_relic_count(&"direct_hit"),
		"thermite_bombs": tower.get_owned_relic_count(&"thermite_bombs"),
		"charred_clothes": tower.get_owned_relic_count(&"charred_clothes"),
		"conductive": tower.get_owned_relic_count(&"conductive"),
		"overcharged_capacitor": tower.get_owned_relic_count(&"overcharged_capacitor"),
		"static_discharge": tower.get_owned_relic_count(&"static_discharge"),
		"chain_lightning": tower.get_owned_relic_count(&"chain_lightning"),
		"pressure_point": tower.get_owned_relic_count(&"pressure_point"),
		"big_game_control": tower.get_owned_relic_count(&"big_game_control"),
		"emergency_brake": tower.get_owned_relic_count(&"emergency_brake"),
	}


func count_valid_enemies_near(origin: Vector2, radius: float) -> int:
	var count := 0
	for mob in tower.get_tree().get_nodes_in_group("mobs"):
		if (
			tower.is_valid_target(mob)
			and origin.distance_to(mob.global_position) <= radius
		):
			count += 1
	return count


func roll_attack_damage(current_target: Node2D = null) -> int:
	return roll_critical_damage(tower.damage, current_target)


func roll_critical_damage(base_damage: int, _current_target: Node2D = null) -> int:
	tower.last_attack_roll_was_critical = false
	tower.last_attack_roll_missed = false
	if tower.miss_chance > 0.0 and tower.spawn_rng.randf() < tower.miss_chance:
		tower.last_attack_roll_missed = true
		return 0
	if (
		tower.has_bonus_tag(BaseTower.BONUS_CRITICAL)
		and tower.spawn_rng.randf() < tower.critical_chance
	):
		tower.last_attack_roll_was_critical = true
		return maxi(roundi(float(base_damage) * tower.critical_multiplier), 1)
	return maxi(
		roundi(float(base_damage) * tower.noncritical_damage_multiplier), 1
	)


func roll_guaranteed_critical_damage(base_damage: int) -> int:
	tower.last_attack_roll_was_critical = false
	tower.last_attack_roll_missed = false
	if tower.miss_chance > 0.0 and tower.spawn_rng.randf() < tower.miss_chance:
		tower.last_attack_roll_missed = true
		return 0
	tower.last_attack_roll_was_critical = true
	return maxi(roundi(float(base_damage) * tower.critical_multiplier), 1)


func get_last_attack_roll_metadata() -> Dictionary:
	return {
		"was_critical": tower.last_attack_roll_was_critical,
		"shot_missed": tower.last_attack_roll_missed,
	}


func launch_projectile(current_target: Node2D, attack_damage: int) -> void:
	if tower.projectile_scene == null:
		push_error("Projectile tower %s has no projectile scene." % tower.tower_id)
		return
	if not tower.is_valid_target(current_target):
		return
	var impact_radius := (
		tower.splash_radius_pixels
		if tower.damage_type == BaseTower.DAMAGE_EXPLOSIVE
		else 0.0
	)
	var projectile_target_position := current_target.global_position
	var maximum_projectile_distance := tower.range_radius_pixels
	if (
		tower.infinite_pierce
		and tower.impact_mode == GameStats.IMPACT_FIRST_CONTACT
	):
		var shot_direction := (
			current_target.global_position - tower.muzzle.global_position
		).normalized()
		projectile_target_position = (
			tower.muzzle.global_position
			+ shot_direction * maximum_projectile_distance
		)
	launch_projectile_from_position(
		current_target,
		tower.muzzle.global_position,
		projectile_target_position,
		maximum_projectile_distance,
		attack_damage,
		impact_radius
	)


func launch_projectile_from_position(
	current_target: Node2D,
	launch_position: Vector2,
	destination: Vector2,
	maximum_projectile_distance: float,
	attack_damage: int,
	impact_radius: float,
	attack_ownership_context: AttackContext = null
) -> TowerProjectile:
	if tower.projectile_scene == null:
		return null
	var projectile := tower.projectile_scene.instantiate() as TowerProjectile
	tower.get_tree().current_scene.add_child(projectile)
	projectile.global_position = launch_position
	var resolved_context := attack_ownership_context
	if resolved_context == null:
		resolved_context = create_attack_context(
			&"projectile", projectile, &"projectile", null, false, true
		)
	elif resolved_context.get_immediate_source() != projectile:
		resolved_context = resolved_context.derive(
			projectile,
			&"projectile",
			resolved_context.attack_kind,
			resolved_context.is_secondary
		)
	projectile.setup(
		current_target,
		destination,
		tower.projectile_speed,
		maximum_projectile_distance,
		attack_damage,
		tower.damage_type,
		tower.impact_mode,
		impact_radius,
		tower.pierce_count,
		tower.slow_duration,
		tower.stun_duration,
		tower.stun_affects_bosses,
		tower.bounce_count,
		tower.bounce_range_pixels,
		tower.attack_component != null
			and tower.attack_component.projectile_contact_explosions_enabled(),
		tower.attack_component.projectile_contact_explosion_radius()
			if tower.attack_component != null
			else 0.0,
		tower.infinite_pierce,
		tower.has_bonus_tag(BaseTower.BONUS_REVEAL),
		tower.tower_id,
		false,
		tower.pierce_loses_no_power,
		tower.attack_component.projectile_contact_explosion_damage_multiplier()
			if tower.attack_component != null
			else 1.0,
		resolved_context
	)
	return projectile


func apply_hitscan_damage(
	current_target: Node2D,
	attack_damage: int,
	provided_context: AttackContext = null
) -> void:
	var origin := tower.muzzle.global_position
	var primary_position := current_target.global_position
	spawn_hitscan_effect(origin, primary_position, tower.damage_type)
	var attack_context := provided_context
	if attack_context == null:
		attack_context = create_attack_context(
			&"hitscan", null, &"tower", null, false, true
		)
	apply_control_effects(current_target, attack_context)
	apply_tower_damage(
		current_target,
		attack_damage,
		tower.damage_type,
		tower.pierce_count > 0,
		attack_context
	)
	var hit_target_ids: Dictionary = {current_target.get_instance_id(): true}
	var bounce_result := apply_hitscan_bounces(
		current_target,
		origin,
		attack_damage,
		attack_context,
		hit_target_ids
	)
	var last_hit_target: Node2D = bounce_result["target"]
	var final_leg_origin: Vector2 = bounce_result["origin"]
	var final_leg_distance: float = bounce_result["maximum_distance"]
	var final_aim_offset := last_hit_target.global_position - final_leg_origin
	if tower.pierce_count > 0 and not final_aim_offset.is_zero_approx():
		var direction := final_aim_offset.normalized()
		var pierce_origin := last_hit_target.global_position + direction * 0.01
		var end := final_leg_origin + direction * final_leg_distance
		spawn_hitscan_effect(
			last_hit_target.global_position, end, tower.damage_type
		)
		var targets := get_targets_along_line(
			pierce_origin, end, last_hit_target
		)
		var pierced_hits := 0
		for pierced_target: Node2D in targets:
			if hit_target_ids.has(pierced_target.get_instance_id()):
				continue
			if pierced_hits >= tower.pierce_count:
				break
			hit_target_ids[pierced_target.get_instance_id()] = true
			var pierce_context := create_attack_context(
				&"pierce", tower, &"tower", attack_context, true
			)
			apply_control_effects(pierced_target, pierce_context)
			var pierced_damage := GameStats.get_piercing_damage(
				attack_damage,
				pierced_hits + 1,
				tower.pierce_loses_no_power
			)
			apply_tower_damage(
				pierced_target,
				pierced_damage,
				tower.damage_type,
				true,
				pierce_context
			)
			pierced_hits += 1


func apply_hitscan_bounces(
	starting_target: Node2D,
	starting_origin: Vector2,
	attack_damage: int,
	parent_context: AttackContext,
	hit_target_ids: Dictionary
) -> Dictionary:
	var result := {
		"target": starting_target,
		"origin": starting_origin,
		"maximum_distance": tower.range_radius_pixels,
	}
	if tower.bounce_count < 1 or tower.bounce_range_pixels <= 0.0:
		return result
	var bounce_source := starting_target
	for _bounce_index in tower.bounce_count:
		var bounce_target := get_nearest_bounce_target(
			bounce_source.global_position, hit_target_ids
		)
		if bounce_target == null:
			break
		var bounce_context := create_attack_context(
			&"bounce", tower, &"tower", parent_context, true
		)
		spawn_hitscan_effect(
			bounce_source.global_position,
			bounce_target.global_position,
			tower.damage_type
		)
		apply_control_effects(bounce_target, bounce_context)
		apply_tower_damage(
			bounce_target,
			attack_damage,
			tower.damage_type,
			tower.pierce_count > 0 or tower.infinite_pierce,
			bounce_context
		)
		hit_target_ids[bounce_target.get_instance_id()] = true
		result["origin"] = bounce_source.global_position
		result["maximum_distance"] = tower.bounce_range_pixels
		bounce_source = bounce_target
		result["target"] = bounce_source
	return result


func get_nearest_bounce_target(
	origin: Vector2,
	excluded_target_ids: Dictionary
) -> Node2D:
	var selected_target: Node2D
	var selected_distance := INF
	for candidate in tower.get_tree().get_nodes_in_group("mobs"):
		if not tower.is_valid_target(candidate):
			continue
		if excluded_target_ids.has(candidate.get_instance_id()):
			continue
		var candidate_distance := origin.distance_to(candidate.global_position)
		if candidate_distance > tower.bounce_range_pixels:
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
	var current_scene := tower.get_tree().current_scene
	if HITSCAN_EFFECT_SCENE == null or current_scene == null:
		return
	if current_scene.has_method("spawn_hitscan_visual"):
		current_scene.spawn_hitscan_visual(
			start_position, end_position, attack_type
		)
		return
	var effect := HITSCAN_EFFECT_SCENE.instantiate() as Node2D
	current_scene.add_child(effect)
	effect.setup(start_position, end_position, attack_type)


func apply_continuous_beam_tick(
	current_target: Node2D,
	attack_damage: int,
	beam_offset := 0.0
) -> void:
	ensure_continuous_beam_aim(current_target)
	if not tower.beam_has_aim:
		return
	var direction := tower.beam_aim_direction.normalized()
	var perpendicular := direction.orthogonal()
	var line_origin := get_continuous_beam_origin() + perpendicular * beam_offset
	var beam_length := get_continuous_beam_length(current_target, line_origin)
	var line_end := line_origin + direction * beam_length
	var beam_context := create_attack_context(
		&"beam_tick", null, &"tower", null, false, true
	)
	if tower.pierce_count < 1 and not tower.infinite_pierce:
		if not is_target_intersecting_line(
			current_target,
			line_origin,
			line_end,
			tower.beam_hit_half_width_pixels
		):
			return
		apply_control_effects(current_target, beam_context)
		apply_tower_damage(
			current_target,
			attack_damage,
			tower.damage_type,
			false,
			beam_context
		)
		return
	var intersected_targets := get_targets_along_line(
		line_origin,
		line_end,
		null,
		tower.beam_hit_half_width_pixels
	)
	var maximum_hits := intersected_targets.size()
	if not tower.infinite_pierce:
		maximum_hits = mini(maximum_hits, 1 + tower.pierce_count)
	for index in maximum_hits:
		var hit_target := intersected_targets[index]
		apply_control_effects(hit_target)
		apply_tower_damage(
			hit_target,
			GameStats.get_piercing_damage(
				attack_damage,
				index,
				tower.pierce_loses_no_power
			),
			tower.damage_type,
			true,
			create_attack_context(
				&"beam_pierce",
				tower,
				&"tower",
				beam_context,
				index > 0
			)
		)


func ensure_continuous_beam_aim(current_target: Node2D) -> void:
	if tower.beam_has_aim or not tower.is_valid_target(current_target):
		return
	var target_offset := (
		current_target.global_position - get_continuous_beam_origin()
	)
	if target_offset.is_zero_approx():
		return
	tower.beam_aim_direction = target_offset.normalized()
	tower.beam_has_aim = true


func process_continuous_beam_aim(delta: float) -> void:
	if not tower.uses_continuous_beam() or not tower.is_valid_target(tower.target):
		return
	var target_offset := (
		tower.target.global_position - get_continuous_beam_origin()
	)
	if target_offset.is_zero_approx():
		return
	var desired_direction := target_offset.normalized()
	if not tower.beam_has_aim:
		tower.beam_aim_direction = desired_direction
		tower.beam_has_aim = true
	else:
		var turn_angle := tower.beam_aim_direction.angle_to(desired_direction)
		var maximum_turn := tower.beam_turn_speed_radians * delta
		tower.beam_aim_direction = tower.beam_aim_direction.rotated(
			clampf(turn_angle, -maximum_turn, maximum_turn)
		).normalized()
	tower.rotator.rotation = tower.beam_aim_direction.angle()


func get_continuous_beam_origin() -> Vector2:
	var default_origin := tower.muzzle.global_position
	return (
		tower.attack_component.get_continuous_beam_origin(default_origin)
		if tower.attack_component != null
		else default_origin
	)


func get_continuous_beam_length(
	current_target: Node2D,
	beam_origin: Vector2
) -> float:
	if (
		tower.pierce_count < 1
		and not tower.infinite_pierce
		and tower.is_valid_target(current_target)
	):
		return beam_origin.distance_to(current_target.global_position)
	return tower.range_radius_pixels


func is_target_intersecting_line(
	candidate: Node2D,
	line_origin: Vector2,
	line_end: Vector2,
	line_half_width := 0.0
) -> bool:
	if not tower.is_valid_target(candidate):
		return false
	var closest_point := Geometry2D.get_closest_point_to_segment(
		candidate.global_position, line_origin, line_end
	)
	var hit_radius := 12.0
	if candidate.has_method("get_projectile_hit_radius"):
		hit_radius = candidate.get_projectile_hit_radius()
	return (
		candidate.global_position.distance_to(closest_point)
		<= hit_radius + line_half_width
	)


func apply_control_effects(
	current_target: Node,
	attack_context: AttackContext = null
) -> void:
	var resolved_context := attack_context
	if resolved_context == null:
		resolved_context = create_attack_context(&"status_effect")
	if bool(resolved_context.metadata.get("shot_missed", false)):
		return
	if tower.slow_duration > 0.0 and current_target.has_method("apply_slow"):
		current_target.apply_slow(tower.slow_duration, resolved_context)
	if tower.stun_duration > 0.0 and current_target.has_method("apply_stun"):
		current_target.apply_stun(
			tower.stun_duration,
			tower.stun_affects_bosses,
			resolved_context
		)


func get_targets_along_line(
	origin: Vector2,
	end: Vector2,
	excluded_target: Node = null,
	line_half_width := 0.0
) -> Array[Node2D]:
	var candidates: Array[Dictionary] = []
	var segment := end - origin
	var segment_length := segment.length()
	if segment_length <= 0.0:
		return []
	var direction := segment / segment_length
	for mob in tower.get_tree().get_nodes_in_group("mobs"):
		if mob == excluded_target or not tower.is_valid_target(mob):
			continue
		var distance_along_line: float = (mob.global_position - origin).dot(
			direction
		)
		if distance_along_line < 0.0 or distance_along_line > segment_length:
			continue
		var closest_point := Geometry2D.get_closest_point_to_segment(
			mob.global_position, origin, end
		)
		var hit_radius := 12.0
		if mob.has_method("get_projectile_hit_radius"):
			hit_radius = mob.get_projectile_hit_radius()
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
