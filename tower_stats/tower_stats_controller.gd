class_name TowerStatsController
extends Node

const GameStats = preload("res://stat_database.gd")

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


func load_level_stats() -> void:
	var stats := get_current_effective_stats()
	var tower_data := GameStats.get_tower(tower.tower_id)
	var tower_texture := stats.get(
		"tower_texture", tower_data.get("texture")
	) as Texture2D
	if tower_texture != null:
		tower.visual_sprite.texture = tower_texture
	tower.footprint_size_pixels = (
		Vector2(tower_data.get("footprint_cells", Vector2i.ONE))
		* BaseTower.BUILD_CELL_SIZE
	)
	var click_shape := tower.get_node(
		"clickarea/CollisionShape2D"
	).shape.duplicate() as RectangleShape2D
	click_shape.size = tower.footprint_size_pixels
	tower.get_node("clickarea/CollisionShape2D").shape = click_shape
	tower.damage = stats["damage"]
	tower.critical_chance = clampf(
		float(stats.get("critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE)),
		0.0,
		1.0
	)
	tower.critical_multiplier = maxf(
		float(stats.get(
			"critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER
		)),
		1.0
	)
	tower.noncritical_damage_multiplier = clampf(
		float(stats.get("noncritical_damage_multiplier", 1.0)), 0.0, 1.0
	)
	tower.miss_chance = clampf(float(stats.get("miss_chance", 0.0)), 0.0, 1.0)
	tower.pierce_loses_no_power = bool(stats.get("pierce_loses_no_power", false))
	tower.slow_duration = maxf(float(stats.get("slow_duration", 0.0)), 0.0)
	tower.slow_speed_multiplier = clampf(
		1.0 - float(stats.get(
			"slow_strength", 1.0 - GameStats.SLOW_SPEED_MULTIPLIER
		)),
		0.0,
		1.0
	)
	tower.stun_duration = maxf(float(stats.get("stun_duration", 0.0)), 0.0)
	tower.stun_affects_bosses = bool(stats.get("stun_affects_bosses", false))
	tower.bounce_count = maxi(int(stats.get("bounce_count", 0)), 0)
	tower.bounce_range_pixels = (
		maxf(float(stats.get("bounce_range", 0.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	tower.projectile_count = maxi(int(stats.get("projectile_count", 1)), 1)
	tower.volley_width_pixels = (
		maxf(float(stats.get("volley_width", 0.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	tower.volley_stagger = maxf(float(stats.get("volley_stagger", 0.0)), 0.0)
	tower.damage_type = get_primary_damage_type()
	tower.beam_turn_speed_radians = deg_to_rad(maxf(
		float(stats.get(
			"beam_turn_speed_degrees",
			BaseTower.DEFAULT_BEAM_TURN_SPEED_DEGREES
		)),
		0.0
	))
	tower.beam_hit_half_width_pixels = maxf(
		float(stats.get("beam_half_width", BaseTower.BEAM_HIT_HALF_WIDTH)), 0.1
	)
	tower.base_beam_hit_half_width_pixels = tower.beam_hit_half_width_pixels
	tower.death_ray_overcharge_enabled = bool(
		stats.get("death_ray_overcharge", false)
	)
	tower.refresh_death_ray_overcharge_state()
	tower.projectile_speed = stats.get("projectile_speed", 600.0)
	tower.splash_radius_pixels = (
		float(stats.get("splash_radius", 0.0))
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	if tower.attack_component != null:
		tower.attack_component.load_level_stats(stats)
	load_path_behaviors()
	if not tower.uses_standard_spawner_system():
		tower.loaded_attack_interval = maxf(float(stats["firerate"]), 0.01)
		tower.damage_timer.wait_time = tower.loaded_attack_interval
	var range_shape := tower.get_node(
		"Tower/CollisionShape2D"
	).shape.duplicate() as CircleShape2D
	tower.range_radius_pixels = (
		float(stats.get("range", 0.0)) * BaseTower.RANGE_PIXELS_PER_UNIT
	)
	range_shape.radius = tower.range_radius_pixels
	tower.get_node("Tower/CollisionShape2D").shape = range_shape
	tower.refresh_reveal_coverage()
	tower.queue_redraw()


func get_effective_stats_for_level(level: int) -> Dictionary:
	var stats := GameStats.get_tower_level(tower.tower_id, level)
	return apply_effective_stat_modifiers(stats)


func get_effective_stats_for_xp_level(xp_level: int) -> Dictionary:
	var stats := GameStats.get_tower_xp_level_stats(tower.tower_id, xp_level)
	return apply_effective_stat_modifiers(stats)


func get_current_effective_stats() -> Dictionary:
	if tower.instance_progression == null:
		return get_effective_stats_for_level(tower.tower_level)
	var expected_rank := GameStats.get_stat_rank_for_xp_level(
		tower.instance_progression.level
	)
	# Preserve the legacy level API for focused tower tests and compatibility
	# callers that intentionally set tower_level directly.
	if tower.tower_level != expected_rank:
		return get_effective_stats_for_level(tower.tower_level)
	return get_effective_stats_for_xp_level(tower.instance_progression.level)


func apply_effective_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	stats = apply_path_stat_modifiers(stats)
	if tower.item_controller != null:
		stats = tower.item_controller.apply_stat_modifiers(stats)
	if tower.uses_standard_spawner_system():
		var unit_stats: Dictionary = stats["unit_stats"].duplicate(true)
		unit_stats["damage"] = roundi(
			float(unit_stats["damage"]) + get_main_bonus(&"tower_damage_flat")
		)
		unit_stats["attack_interval"] = maxf(
			float(unit_stats["attack_interval"])
				/ get_main_multiplier(&"tower_attack_speed"),
			0.01
		)
		unit_stats["aim_radius"] = (
			float(unit_stats["aim_radius"])
			* get_main_multiplier(&"tower_range")
		)
		unit_stats = apply_effect_combat_stat_modifiers(unit_stats, true)
		stats["unit_stats"] = unit_stats
		stats["damage"] = unit_stats["damage"]
		stats["firerate"] = unit_stats["attack_interval"]
		stats["range"] = (
			float(stats["deployment_radius"])
			* get_main_multiplier(&"tower_range")
		)
		return stats
	stats["damage"] = roundi(
		float(stats["damage"]) + get_main_bonus(&"tower_damage_flat")
	)
	stats["firerate"] = maxf(
		float(stats["firerate"])
			/ get_main_multiplier(&"tower_attack_speed"),
		0.01
	)
	if stats.has("range"):
		stats["range"] = (
			float(stats["range"]) * get_main_multiplier(&"tower_range")
		)
	return apply_effect_combat_stat_modifiers(stats, false)


func apply_effect_combat_stat_modifiers(
	base_stats: Dictionary,
	for_spawned_unit: bool
) -> Dictionary:
	var stats := base_stats.duplicate(true)
	var damage_key := "damage"
	var interval_key := "attack_interval" if for_spawned_unit else "firerate"
	var range_key := "aim_radius" if for_spawned_unit else "range"
	var primary_type := get_primary_damage_type()
	if (
		for_spawned_unit
		and tower.uses_standard_spawner_system()
		and get_effect_stack_count(&"trade_agreement") > 0
	):
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key])
				* GameStats.TRADE_AGREEMENT_UNIT_DAMAGE_MULTIPLIER
		), 1)
		for budget_key in ["damage_budget", "lifetime"]:
			if stats.has(budget_key) and float(stats[budget_key]) > 0.0:
				stats[budget_key] = (
					float(stats[budget_key])
					* GameStats.TRADE_AGREEMENT_UNIT_BUDGET_MULTIPLIER
				)
	if (
		tower.has_damage_tag(BaseTower.DAMAGE_MELEE)
		and get_effect_stack_count(&"relentless") > 0
	):
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key]) * GameStats.RELENTLESS_DAMAGE_MULTIPLIER
		), 1)
	if (
		tower.has_damage_tag(BaseTower.DAMAGE_MELEE)
		and get_effect_stack_count(&"lone_wolf") > 0
		and not has_other_placed_tower_with_same_id()
	):
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key]) * GameStats.LONE_WOLF_DAMAGE_MULTIPLIER
		), 1)
		stats[interval_key] = maxf(
			float(stats[interval_key])
				/ GameStats.LONE_WOLF_ATTACK_SPEED_MULTIPLIER,
			0.01
		)
		if stats.has(range_key):
			stats[range_key] = maxf(
				float(stats[range_key]) * GameStats.LONE_WOLF_RANGE_MULTIPLIER,
				0.1
			)
	if primary_type == BaseTower.DAMAGE_BEAM:
		var focused_count := get_effect_stack_count(&"focused_lens")
		var wide_count := get_effect_stack_count(&"wide_lens")
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key])
			* (1.0 + GameStats.FOCUSED_LENS_DAMAGE_PER_STACK * focused_count)
			* pow(GameStats.WIDE_LENS_DAMAGE_MULTIPLIER, wide_count)
		), 1)
		if stats.has(range_key):
			stats[range_key] = maxf(
				float(stats[range_key])
				* pow(GameStats.FOCUSED_LENS_RANGE_MULTIPLIER, focused_count)
				* (1.0 + GameStats.WIDE_LENS_RANGE_PER_STACK * wide_count),
				0.1
			)
		if get_effect_stack_count(&"death_ray") > 0:
			stats["death_ray_overcharge"] = true
	if primary_type == BaseTower.DAMAGE_BALLISTIC:
		var heavy_count := get_effect_stack_count(&"heavy_rounds")
		var lightweight_count := get_effect_stack_count(&"lightweight_ammo")
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key])
			* pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER, heavy_count)
			* pow(GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER, lightweight_count)
		), 1)
		stats[interval_key] = maxf(
			float(stats[interval_key])
			* pow(GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER, heavy_count)
			* pow(GameStats.LIGHTWEIGHT_AMMO_INTERVAL_MULTIPLIER, lightweight_count),
			0.01
		)
		if get_effect_stack_count(&"suppressive_fire") > 0:
			stats["slow_duration"] = maxf(
				float(stats.get("slow_duration", 0.0)),
				GameStats.SUPPRESSIVE_FIRE_DURATION
			)
	if primary_type == BaseTower.DAMAGE_EXPLOSIVE:
		stats[damage_key] = maxi(roundi(
			float(stats[damage_key]) * get_explosion_damage_multiplier()
		), 1)
		if stats.has("splash_radius"):
			stats["splash_radius"] = (
				float(stats["splash_radius"])
				* get_explosion_radius_multiplier()
			)
		stats[interval_key] = maxf(
			float(stats[interval_key]) * get_explosion_interval_multiplier(),
			0.01
		)
	if for_spawned_unit and bool(stats.get("explode_on_damage_budget", false)):
		stats["budget_explosion_radius"] = (
			float(stats.get("budget_explosion_radius", 0.0))
			* get_explosion_radius_multiplier()
		)
		stats["budget_explosion_damage_multiplier"] = (
			float(stats.get("budget_explosion_damage_multiplier", 1.0))
			* get_explosion_damage_multiplier()
		)
	var glass_cannon_count := get_effect_stack_count(&"glass_cannon")
	var deadeye_count := get_effect_stack_count(&"deadeye")
	var base_critical_multiplier := float(stats.get(
		"critical_multiplier", GameStats.DEFAULT_CRITICAL_MULTIPLIER
	))
	stats["critical_chance"] = clampf(
		float(stats.get("critical_chance", GameStats.DEFAULT_CRITICAL_CHANCE))
		+ GameStats.LUCKY_SHOT_CHANCE_PER_STACK
			* get_effect_stack_count(&"lucky_shot"),
		0.0,
		1.0
	)
	stats["critical_multiplier"] = maxf(
		base_critical_multiplier
		+ GameStats.GLASS_CANNON_CRITICAL_MULTIPLIER_BONUS
			* float(glass_cannon_count)
		+ GameStats.DEADEYE_CRITICAL_MULTIPLIER_BONUS
			* float(deadeye_count),
		1.0
	)
	if glass_cannon_count > 0:
		stats["noncritical_damage_multiplier"] = pow(
			GameStats.GLASS_CANNON_NONCRITICAL_MULTIPLIER,
			glass_cannon_count
		)
	if deadeye_count > 0:
		stats["miss_chance"] = 1.0 - pow(
			1.0 - GameStats.DEADEYE_MISS_CHANCE, deadeye_count
		)
	if tower.has_bonus_tag(BaseTower.BONUS_PIERCE):
		stats["pierce_count"] = tower.pierce_count
		stats["pierce_loses_no_power"] = (
			bool(stats.get("pierce_loses_no_power", false))
			or get_effect_stack_count(&"follow_through") > 0
		)
	if (
		tower.has_bonus_tag(BaseTower.BONUS_STUN)
		and get_effect_stack_count(&"youre_not_special") > 0
	):
		stats["stun_affects_bosses"] = true
	if for_spawned_unit:
		var inherited_bonus_tags: Array = stats.get(
			"additional_bonus_tags", []
		).duplicate()
		for inherited_tag in [
			BaseTower.BONUS_PIERCE,
			BaseTower.BONUS_STUN,
			BaseTower.BONUS_REVEAL,
		]:
			if (
				inherited_tag == BaseTower.BONUS_REVEAL
				and (
					tower.uses_drone_targeting()
					or bool(stats.get("reveal_via_parent_command_range", false))
				)
			):
				continue
			if tower.has_bonus_tag(inherited_tag) and not inherited_bonus_tags.has(inherited_tag):
				inherited_bonus_tags.append(inherited_tag)
		stats["additional_bonus_tags"] = inherited_bonus_tags
	return stats


func get_explosion_damage_multiplier() -> float:
	return (
		pow(GameStats.HIGH_YIELD_DAMAGE_MULTIPLIER, get_effect_stack_count(&"high_yield"))
		* pow(GameStats.CONCENTRATED_CHARGE_DAMAGE_MULTIPLIER, get_effect_stack_count(&"concentrated_charge"))
	)


func get_explosion_radius_multiplier() -> float:
	return (
		pow(GameStats.HIGH_YIELD_RADIUS_MULTIPLIER, get_effect_stack_count(&"high_yield"))
		* pow(GameStats.CONCENTRATED_CHARGE_RADIUS_MULTIPLIER, get_effect_stack_count(&"concentrated_charge"))
		* pow(GameStats.BLAST_GEL_RADIUS_MULTIPLIER, get_effect_stack_count(&"blast_gel"))
	)


func get_explosion_interval_multiplier() -> float:
	return 1.0


func get_sidebar_stats() -> Dictionary:
	var tower_data := GameStats.get_tower(tower.tower_id)
	var levels: Array = tower_data["levels"]
	var next_level := tower.tower_level + 1
	var result := {
		"display_name": tower_data["display_name"],
		"is_placed": tower.is_placed,
		"level": tower.tower_level,
		"maximum_level": levels.size() - 1,
		"type_tags": tower.type_tags.duplicate(),
		"attack_tags": tower.damage_tags.duplicate(),
		"bonus_tags": tower.bonus_tags.duplicate(),
		"has_next_level": next_level < levels.size(),
		"show_upgrade_info": (
			tower.is_placed
			and tower.pending_action == BaseTower.MenuAction.UPGRADE
		),
		"path_status": tower.get_path_status_text(),
	}
	if tower.instance_progression != null:
		result["xp_level"] = tower.instance_progression.level
		result["xp"] = tower.instance_progression.xp
		result["xp_into_level"] = tower.instance_progression.get_xp_into_current_level()
		result["xp_to_next_level"] = tower.instance_progression.get_xp_to_next_level()
		result["xp_progress"] = tower.instance_progression.get_progress_ratio()
		result["tower_instance_uid"] = tower.instance_progression.instance_uid
		result["kills"] = tower.instance_progression.kills
		result["actual_damage_dealt"] = tower.instance_progression.actual_damage_dealt
		result["control_credit"] = tower.instance_progression.control_credit
		result["equipped_items"] = tower.get_equipped_item_ids()
		result["active_items"] = tower.item_controller.get_active_item_ids()
	if next_level < levels.size():
		result["next_level"] = next_level
	return result


func apply_path_stat_modifiers(base_stats: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	for path_id in tower.purchased_paths:
		var path := GameStats.get_tower_path(tower.tower_id, path_id)
		_apply_path_stat_definition(stats, path)
		if _is_level_20_capstone_active():
			_apply_path_stat_definition(stats, path.get("level_20", {}))
	return stats


func _apply_path_stat_definition(stats: Dictionary, definition: Dictionary) -> void:
	apply_numeric_modifiers(stats, definition.get("stat_multipliers", {}), true)
	apply_numeric_modifiers(stats, definition.get("stat_additions", {}), false)
	for conditional in definition.get("conditional_stat_multipliers", []):
		var absent_path := StringName(conditional.get("unless_path", &""))
		if not absent_path.is_empty() and tower.purchased_paths.has(absent_path):
			continue
		apply_numeric_modifiers(stats, conditional.get("values", {}), true)
	for key in definition.get("stat_overrides", {}):
		stats[key] = definition["stat_overrides"][key]
	for conditional in definition.get("conditional_stat_overrides", []):
		var absent_path := StringName(conditional.get("unless_path", &""))
		if not absent_path.is_empty() and tower.purchased_paths.has(absent_path):
			continue
		for key in conditional.get("values", {}):
			stats[key] = conditional["values"][key]
	if stats.has("unit_stats"):
		var unit_stats: Dictionary = stats["unit_stats"]
		apply_numeric_modifiers(
			unit_stats, definition.get("unit_stat_multipliers", {}), true
		)
		apply_numeric_modifiers(
			unit_stats, definition.get("unit_stat_additions", {}), false
		)
		for key in definition.get("unit_stat_overrides", {}):
			unit_stats[key] = definition["unit_stat_overrides"][key]
		stats["unit_stats"] = unit_stats


func _is_level_20_capstone_active() -> bool:
	return (
		tower.instance_progression != null
		and tower.instance_progression.level >= GameStats.TOWER_XP_MAX_LEVEL
	)


func apply_numeric_modifiers(stats: Dictionary, modifiers: Dictionary, is_multiplier: bool) -> void:
	for key in modifiers:
		if not stats.has(key):
			continue
		var original: Variant = stats[key]
		if original is int:
			stats[key] = roundi(float(original) * float(modifiers[key])) if is_multiplier else int(original) + roundi(float(modifiers[key]))
		elif original is float:
			stats[key] = float(original) * float(modifiers[key]) if is_multiplier else float(original) + float(modifiers[key])


func get_main_bonus(effect: StringName) -> float:
	if tower.main == null:
		return 0.0
	return tower.main.get_run_bonus(effect)


func get_main_multiplier(effect: StringName) -> float:
	return 1.0 + get_main_bonus(effect)


func get_effect_stack_count(effect_id: StringName) -> int:
	if tower.item_controller == null:
		return 0
	return tower.item_controller.get_item_effect_count(effect_id)


func get_current_attack_interval() -> float:
	var interval := tower.loaded_attack_interval
	if tower.attack_component != null:
		interval = tower.attack_component.modify_attack_interval(interval)
	var frenzy_stacks := get_effect_stack_count(&"frenzy")
	if tower.has_damage_tag(BaseTower.DAMAGE_MELEE) and frenzy_stacks > 0:
		var enemy_count := mini(
			tower.count_valid_enemies_near(
				tower.global_position, tower.range_radius_pixels
			),
			GameStats.FRENZY_MAXIMUM_ENEMY_COUNT
		)
		var speed_bonus := (
			GameStats.FRENZY_SPEED_PER_ENEMY_PER_STACK
			* float(enemy_count)
			* float(frenzy_stacks)
		)
		interval /= 1.0 + speed_bonus
	if (
		tower.has_damage_tag(BaseTower.DAMAGE_MELEE)
		and get_effect_stack_count(&"relentless") > 0
		and tower.relentless_stacks > 0
	):
		interval /= 1.0 + GameStats.RELENTLESS_SPEED_PER_STACK * float(tower.relentless_stacks)
	return maxf(interval, 0.01)


func add_type_tag(tag: StringName) -> void:
	if not tower.type_tags.has(tag):
		tower.type_tags.append(tag)


func add_damage_tag(tag: StringName) -> void:
	if not tower.damage_tags.has(tag):
		tower.damage_tags.append(tag)


func add_bonus_tag(tag: StringName) -> void:
	if not tower.bonus_tags.has(tag):
		tower.bonus_tags.append(tag)
	if tag == BaseTower.BONUS_PIERCE and tower.pierce_count < 1:
		tower.pierce_count = 1


func remove_type_tag(tag: StringName) -> void:
	tower.type_tags.erase(tag)


func remove_damage_tag(tag: StringName) -> void:
	tower.damage_tags.erase(tag)


func remove_bonus_tag(tag: StringName) -> void:
	tower.bonus_tags.erase(tag)
	if tag == BaseTower.BONUS_PIERCE:
		tower.pierce_count = 0


func set_pierce_count(value: int) -> void:
	tower.pierce_count = maxi(value, 0)
	if tower.pierce_count < 1:
		tower.bonus_tags.erase(BaseTower.BONUS_PIERCE)
	elif not tower.bonus_tags.has(BaseTower.BONUS_PIERCE):
		tower.bonus_tags.append(BaseTower.BONUS_PIERCE)


func load_path_behaviors() -> void:
	tower.inherent_infinite_pierce = false
	tower.continuous_beam_enabled = false
	if tower.attack_component != null:
		tower.attack_component.reset_path_behaviors()
	for path_id in tower.purchased_paths:
		var path := GameStats.get_tower_path(tower.tower_id, path_id)
		_apply_path_behavior_definition(path)
		if _is_level_20_capstone_active():
			_apply_path_behavior_definition(path.get("level_20", {}))
	tower.refresh_death_ray_overcharge_state()
	if tower.attack_component != null:
		tower.attack_component.finalize_path_behaviors()


func _apply_path_behavior_definition(definition: Dictionary) -> void:
	var flags: Dictionary = definition.get("behavior_flags", {})
	var values: Dictionary = definition.get("behavior_values", {})
	if tower.attack_component != null:
		tower.attack_component.apply_path_behavior(flags, values)
	if flags.get("infinite_pierce", false):
		tower.inherent_infinite_pierce = true
	if flags.get("continuous_beam", false):
		tower.continuous_beam_enabled = true


func load_base_tags() -> void:
	var tower_data: Dictionary = GameStats.get_tower(tower.tower_id)
	tower.type_tags.clear()
	tower.damage_tags.clear()
	tower.bonus_tags.clear()
	for tag in tower_data.get("type_tags", []):
		tower.type_tags.append(tag)
	for tag in tower_data.get("damage_tags", []):
		tower.damage_tags.append(tag)
	for tag in tower_data.get("bonus_tags", []):
		tower.bonus_tags.append(tag)
	var levels: Array = tower_data.get("levels", [])
	for level_index in range(0, mini(tower.tower_level + 1, levels.size())):
		var level_data: Dictionary = levels[level_index]
		_apply_tag_changes(level_data)
	var loaded_pierce_count := int(tower_data.get(
		"pierce_count",
		1 if tower.bonus_tags.has(BaseTower.BONUS_PIERCE) else 0
	))
	tower.delivery_type = tower_data.get(
		"delivery_type", GameStats.DELIVERY_HITSCAN
	)
	tower.impact_mode = tower_data.get("impact_mode", GameStats.IMPACT_PRIMARY)
	for path_id in tower.purchased_paths:
		var path := GameStats.get_tower_path(tower.tower_id, path_id)
		_apply_tag_changes(path)
		if _is_level_20_capstone_active():
			_apply_tag_changes(path.get("level_20", {}))
		loaded_pierce_count += int(path.get("pierce_count_add", 0))
		if path.has("delivery_type"):
			tower.delivery_type = path["delivery_type"]
		if path.has("impact_mode"):
			tower.impact_mode = path["impact_mode"]
	if tower.item_controller != null:
		loaded_pierce_count += tower.item_controller.apply_tag_changes()
	set_pierce_count(loaded_pierce_count)
func _apply_tag_changes(definition: Dictionary) -> void:
	for tag in definition.get("add_type_tags", []):
		add_type_tag(tag)
	for tag in definition.get("add_damage_tags", []):
		add_damage_tag(tag)
	for tag in definition.get("add_bonus_tags", []):
		add_bonus_tag(tag)
	for tag in definition.get("remove_type_tags", []):
		remove_type_tag(tag)
	for tag in definition.get("remove_damage_tags", []):
		remove_damage_tag(tag)
	for tag in definition.get("remove_bonus_tags", []):
		remove_bonus_tag(tag)


func get_primary_damage_type() -> StringName:
	var tower_data := GameStats.get_tower(tower.tower_id)
	var primary_type := StringName(
		tower_data.get("primary_damage_type", tower.damage_tags[0])
	)
	for path_id in tower.purchased_paths:
		var path := GameStats.get_tower_path(tower.tower_id, path_id)
		if path.has("primary_damage_type"):
			primary_type = StringName(path["primary_damage_type"])
	assert(
		tower.damage_tags.has(primary_type),
		"Tower %s primary damage type must be one of its active tags." % tower.tower_id
	)
	return primary_type


func get_nearby_type_tower_count(
	required_type_tag: StringName,
	maximum_footprint_gap: float
) -> int:
	var count := 0
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if not is_valid_neighbor_tower(candidate):
			continue
		if not candidate.has_type_tag(required_type_tag):
			continue
		var candidate_footprint := Vector2(
			candidate.get("footprint_size_pixels")
		)
		var combined_half_extents := (
			tower.footprint_size_pixels + candidate_footprint
		) * 0.5
		var center_offset: Vector2 = (
			candidate.global_position - tower.global_position
		).abs()
		var footprint_gap := Vector2(
			maxf(center_offset.x - combined_half_extents.x, 0.0),
			maxf(center_offset.y - combined_half_extents.y, 0.0)
		)
		if footprint_gap.length() <= maximum_footprint_gap + 1.0:
			count += 1
	return count


func get_nearby_tower_count(
	required_damage_tag: StringName,
	radius: float
) -> int:
	var count := 0
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if not is_valid_neighbor_tower(candidate):
			continue
		if not candidate.has_damage_tag(required_damage_tag):
			continue
		if tower.global_position.distance_to(candidate.global_position) <= radius:
			count += 1
	return count


func has_nearby_other_tower(radius: float) -> bool:
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if (
			is_valid_neighbor_tower(candidate)
			and tower.global_position.distance_to(candidate.global_position) <= radius
		):
			return true
	return false


func has_other_placed_tower_with_same_id() -> bool:
	for candidate in tower.get_tree().get_nodes_in_group("towers"):
		if (
			is_valid_neighbor_tower(candidate)
			and StringName(candidate.get("tower_id")) == tower.tower_id
		):
			return true
	return false


func is_valid_neighbor_tower(candidate: Variant) -> bool:
	return (
		candidate != null
		and candidate != tower
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and bool(candidate.get("is_placed"))
	)
