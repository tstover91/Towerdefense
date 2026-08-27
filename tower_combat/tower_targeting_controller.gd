class_name TowerTargetingController
extends Node

const GameStats = preload("res://stat_database.gd")
const DIRECTIONAL_LINE_HALF_WIDTH := 3.0

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


func process(delta: float) -> void:
	if (
		tower.relentless_target_instance_id > 0
		and (
			not is_valid_target(tower.target)
			or tower.target.get_instance_id()
				!= tower.relentless_target_instance_id
		)
	):
		tower.reset_relentless()
	if tower.attack_component != null:
		tower.attack_component.process_pre_targeting(delta)
	if tower.uses_continuous_beam():
		tower.queue_redraw()
	if not tower.is_placed:
		if tower.uses_directional_aim():
			tower.rotator.rotation = tower.aim_direction.angle()
		return
	if tower.uses_standard_spawner_system():
		return
	if (
		tower.attack_component != null
		and not tower.attack_component.uses_standard_targeting()
	):
		return
	if tower.uses_directional_aim():
		tower.rotator.rotation = tower.aim_direction.angle()
	if tower.uses_manual_ground_targeting():
		if (
			tower.attack_component != null
			and tower.attack_component.has_manual_target_position()
		):
			tower.rotator.rotation = (
				tower.attack_component.get_manual_target_position()
				- tower.rotator.global_position
			).angle()
		request_attack_if_ready()
		return
	if not is_instance_valid(tower.target):
		tower.target = null
	if (
		tower.uses_tracking_cone()
		and tower.attack_component != null
		and not tower.attack_component.is_target_in_tracking_cone(tower.target)
	):
		tower.target = null
	if not is_valid_target(tower.target):
		select_target()
	request_attack_if_ready()
	tower.process_continuous_beam_aim(delta)
	if tower.attack_component != null:
		tower.attack_component.process_attack(delta)
	if tower.uses_tracking_cone() and is_valid_target(tower.target):
		tower.rotator.rotation = (
			tower.target.global_position - tower.rotator.global_position
		).angle()
	if (
		is_valid_target(tower.target)
		and not tower.uses_directional_aim()
		and not tower.uses_continuous_beam()
	):
		var desired_angle := (
			tower.target.global_position - tower.rotator.global_position
		).angle()
		tower.rotator.rotation = lerp_angle(
			tower.rotator.rotation, desired_angle, 5.0 * delta
		)


func apply_damage() -> void:
	if not tower.uses_standard_spawner_system():
		tower.damage_timer.wait_time = tower.get_current_attack_interval()
	if not tower.is_placed:
		return
	if tower.uses_shared_attack_scheduler() and tower.attack_on_cooldown:
		return
	if (
		tower.attack_component != null
		and not tower.attack_component.uses_standard_targeting()
	):
		return
	if tower.uses_manual_ground_targeting():
		var attacked_ground := false
		if (
			tower.attack_component != null
			and tower.attack_component.has_manual_attack_opportunity()
		):
			tower.notify_attack_started()
			tower.attack_component.execute_manual_attack()
			attacked_ground = true
		complete_shared_attack_cycle(attacked_ground)
		return
	var sticky_health_mode := tower.target_mode in [
		BaseTower.TargetMode.LOWEST_HEALTH,
		BaseTower.TargetMode.HIGHEST_HEALTH,
	]
	if (
		not is_valid_target(tower.target)
		or not tower.mobs_in_range.has(tower.target)
		or (not tower.uses_continuous_beam() and not sticky_health_mode)
	):
		select_target()
	if tower.attack_component != null:
		tower.attack_component.on_target_updated()
	var did_attack := false
	if is_valid_target(tower.target):
		tower.notify_attack_started(tower.target)
		tower.attack(tower.target)
		did_attack = true
		# Projectile Melee attacks confirm Relentless only when the originally
		# selected primary enemy is physically hit.
		if not (
			tower.delivery_type == GameStats.DELIVERY_PROJECTILE
			and tower.has_damage_tag(BaseTower.DAMAGE_MELEE)
		):
			tower.register_relentless_primary_attack(tower.target)
	complete_shared_attack_cycle(did_attack)


func on_attack_timer_timeout() -> void:
	if tower.uses_shared_attack_scheduler():
		tower.attack_on_cooldown = false
	apply_damage()


func complete_shared_attack_cycle(did_attack: bool) -> void:
	if not tower.uses_shared_attack_scheduler():
		return
	if not did_attack:
		tower.attack_on_cooldown = false
		tower.damage_timer.stop()
		return
	tower.attack_on_cooldown = true
	tower.damage_timer.wait_time = tower.get_current_attack_interval()
	tower.damage_timer.start()


func request_attack_if_ready() -> void:
	if (
		not tower.uses_shared_attack_scheduler()
		or not tower.is_placed
		or tower.attack_on_cooldown
		or tower.immediate_attack_pending
	):
		return
	var has_attack_opportunity := is_valid_target(tower.target)
	if tower.uses_manual_ground_targeting():
		has_attack_opportunity = (
			tower.attack_component != null
			and tower.attack_component.has_manual_attack_opportunity()
		)
	if not has_attack_opportunity:
		return
	tower.immediate_attack_pending = true
	call_deferred("perform_pending_attack")


func perform_pending_attack() -> void:
	tower.immediate_attack_pending = false
	if tower.attack_on_cooldown or not tower.is_placed:
		return
	if not tower.uses_manual_ground_targeting():
		if (
			not is_valid_target(tower.target)
			or not tower.mobs_in_range.has(tower.target)
		):
			select_target()
		if not is_valid_target(tower.target):
			return
	apply_damage()


func on_body_entered(body: Node2D) -> void:
	if body.is_in_group("mobs") and not tower.mobs_in_range.has(body):
		tower.mobs_in_range.append(body)
		apply_reveal_relics_to_mob(body)
		if not is_valid_target(tower.target):
			select_target()
		request_attack_if_ready()


func on_body_exited(body: Node2D) -> void:
	tower.mobs_in_range.erase(body)
	if body.has_method("remove_global_reveal_source"):
		body.remove_global_reveal_source(tower)
	if body == tower.target:
		tower.target = null


func is_valid_target(candidate: Variant) -> bool:
	if not is_valid_area_target(candidate):
		return false
	if candidate.traits.has(&"hidden"):
		return (
			tower.has_bonus_tag(BaseTower.BONUS_REVEAL)
			or (
				candidate.has_method("is_revealed_for_all")
				and candidate.is_revealed_for_all()
			)
		)
	return true


func is_valid_area_target(candidate: Variant) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and not candidate.finished
	)


func refresh_reveal_relic_coverage() -> void:
	remove_reveal_source_from_all_mobs()
	if not tower.is_placed or not tower.has_bonus_tag(BaseTower.BONUS_REVEAL):
		return
	for mob in tower.mobs_in_range:
		if (
			is_instance_valid(mob)
			and not mob.is_queued_for_deletion()
			and tower.global_position.distance_to(mob.global_position)
				<= tower.range_radius_pixels
		):
			apply_reveal_relics_to_mob(mob)


func apply_reveal_relics_to_mob(mob: Node) -> void:
	if (
		not is_instance_valid(mob)
		or not tower.has_bonus_tag(BaseTower.BONUS_REVEAL)
		or not mob.get("traits").has(&"hidden")
	):
		return
	if tower.get_effect_stack_count(&"perfect_intelligence") > 0:
		if mob.has_method("remove_hidden_trait"):
			mob.remove_hidden_trait(tower.create_attack_context(&"reveal"))
		else:
			mob.get("traits").erase(&"hidden")
		return
	if (
		tower.get_owned_relic_count(&"spotter") > 0
		and mob.has_method("add_global_reveal_source")
	):
		mob.add_global_reveal_source(
			tower, tower.create_attack_context(&"reveal")
		)


func remove_reveal_source_from_all_mobs() -> void:
	if not tower.is_inside_tree():
		return
	var scene_tree := tower.get_tree()
	if scene_tree == null:
		return
	for mob in scene_tree.get_nodes_in_group("mobs"):
		if is_instance_valid(mob) and mob.has_method("remove_global_reveal_source"):
			mob.remove_global_reveal_source(tower)


func select_target() -> void:
	if tower.uses_directional_aim():
		select_directional_target()
		return
	tower.target = select_standard_target()


func select_standard_target() -> Node2D:
	tower.mobs_in_range = tower.mobs_in_range.filter(
		func(mob):
			return (
				mob != null
				and is_instance_valid(mob)
				and not mob.is_queued_for_deletion()
				and not mob.finished
			)
	)
	var targetable_mobs := tower.mobs_in_range.filter(
		func(mob):
			return is_valid_target(mob)
	)
	if targetable_mobs.is_empty():
		return null
	var selected_target: Node2D = targetable_mobs[0]
	for candidate in targetable_mobs:
		match tower.target_mode:
			BaseTower.TargetMode.FIRST:
				if candidate.path_follow.progress > selected_target.path_follow.progress:
					selected_target = candidate
			BaseTower.TargetMode.LAST:
				if candidate.path_follow.progress < selected_target.path_follow.progress:
					selected_target = candidate
			BaseTower.TargetMode.LOWEST_HEALTH:
				if candidate.health < selected_target.health:
					selected_target = candidate
			BaseTower.TargetMode.HIGHEST_HEALTH:
				if candidate.health > selected_target.health:
					selected_target = candidate
	return selected_target


func select_directional_target() -> void:
	tower.target = null
	if tower.uses_tracking_cone() and tower.attack_component != null:
		tower.target = tower.attack_component.select_directional_target()
		return
	var closest_distance := INF
	var origin := tower.muzzle.global_position
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not is_valid_target(candidate):
			continue
		var offset: Vector2 = candidate.global_position - origin
		var distance_along_line: float = offset.dot(tower.aim_direction)
		if distance_along_line <= 0.0:
			continue
		var hit_radius := 12.0
		if candidate.has_method("get_projectile_hit_radius"):
			hit_radius = candidate.get_projectile_hit_radius()
		var distance_from_line: float = absf(tower.aim_direction.cross(offset))
		if distance_from_line > hit_radius + DIRECTIONAL_LINE_HALF_WIDTH:
			continue
		if distance_along_line < closest_distance:
			closest_distance = distance_along_line
			tower.target = candidate
