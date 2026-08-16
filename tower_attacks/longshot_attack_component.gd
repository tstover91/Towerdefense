class_name LongshotAttackComponent
extends TowerAttackComponent

const LONGSHOT_MINE_SCENE = preload("res://longshot_mine.tscn")

var distance_damage_enabled := false
var distance_minimum_multiplier := 1.0
var distance_midpoint_multiplier := 1.0
var distance_maximum_multiplier := 1.0
var mines_enabled := false
var mine_interval := 6.0
var mine_remaining := 0.0
var mine_maximum_count := 3
var mine_placement_radius_pixels := 0.0
var mine_trigger_radius_pixels := 0.0
var mine_explosion_radius_pixels := 0.0
var mine_damage_multiplier := 1.0
var active_mines: Array[Node] = []
var previous_mine_remaining := 0.0


func reset_path_behaviors() -> void:
	previous_mine_remaining = mine_remaining
	distance_damage_enabled = false
	distance_minimum_multiplier = 1.0
	distance_midpoint_multiplier = 1.0
	distance_maximum_multiplier = 1.0
	mines_enabled = false
	mine_interval = 6.0
	mine_maximum_count = 3
	mine_placement_radius_pixels = 0.0
	mine_trigger_radius_pixels = 0.0
	mine_explosion_radius_pixels = 0.0
	mine_damage_multiplier = 1.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("longshot_distance_damage", false):
		distance_damage_enabled = true
		distance_minimum_multiplier = maxf(
			float(values.get("distance_minimum_multiplier", 1.0)), 0.0
		)
		distance_midpoint_multiplier = clampf(
			float(values.get("distance_midpoint_multiplier", 1.0)),
			distance_minimum_multiplier,
			float(values.get("distance_maximum_multiplier", 2.0))
		)
		distance_maximum_multiplier = maxf(
			float(values.get("distance_maximum_multiplier", 2.0)),
			distance_midpoint_multiplier
		)
	if flags.get("longshot_mines", false):
		mines_enabled = true
		mine_interval = maxf(float(values.get("mine_interval", 6.0)), 0.1)
		mine_maximum_count = maxi(int(values.get("mine_maximum_count", 3)), 1)
		mine_placement_radius_pixels = (
			maxf(float(values.get("mine_placement_radius", 6.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		mine_trigger_radius_pixels = (
			maxf(float(values.get("mine_trigger_radius", 1.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		mine_explosion_radius_pixels = (
			maxf(float(values.get("mine_explosion_radius", 2.5)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		mine_damage_multiplier = maxf(
			float(values.get("mine_damage_multiplier", 1.25)), 0.0
		)


func finalize_path_behaviors() -> void:
	if mines_enabled and tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		if tower.get_primary_damage_type() != BaseTower.DAMAGE_EXPLOSIVE:
			mine_damage_multiplier *= tower.get_explosion_damage_multiplier()
		mine_explosion_radius_pixels *= tower.get_explosion_radius_multiplier()
		mine_interval *= tower.get_explosion_interval_multiplier()
	if mines_enabled:
		mine_remaining = (
			minf(previous_mine_remaining, mine_interval)
			if previous_mine_remaining > 0.0
			else mine_interval
		)
	else:
		mine_remaining = 0.0
	previous_mine_remaining = 0.0


func on_round_started() -> void:
	if mines_enabled:
		mine_remaining = mine_interval


func on_round_ended() -> void:
	clear_mines()
	mine_remaining = mine_interval


func _exit_tree() -> void:
	clear_mines()


func modify_base_attack_damage(current_target: Node2D, base_damage: int) -> int:
	if not distance_damage_enabled:
		return base_damage
	if not is_instance_valid(current_target) or tower.range_radius_pixels <= 0.0:
		return base_damage
	var distance_ratio := clampf(
		tower.global_position.distance_to(current_target.global_position)
			/ tower.range_radius_pixels,
		0.0,
		1.0
	)
	var damage_multiplier := distance_midpoint_multiplier
	if distance_ratio <= 0.5:
		damage_multiplier = lerpf(
			distance_minimum_multiplier,
			distance_midpoint_multiplier,
			distance_ratio * 2.0
		)
	else:
		damage_multiplier = lerpf(
			distance_midpoint_multiplier,
			distance_maximum_multiplier,
			(distance_ratio - 0.5) * 2.0
		)
	return maxi(roundi(float(base_damage) * damage_multiplier), 1)


func process_attack(delta: float) -> void:
	if not mines_enabled or not tower.is_placed:
		return
	if tower.main == null or not tower.main.round_active:
		return
	prune_mines()
	if active_mines.size() >= mine_maximum_count:
		return
	mine_remaining = maxf(mine_remaining - delta, 0.0)
	if mine_remaining > 0.0:
		return
	mine_remaining = mine_interval
	place_mine()


func place_mine() -> void:
	if (
		tower.main == null
		or not tower.main.has_method("get_path_cell_positions_near")
		or LONGSHOT_MINE_SCENE == null
		or tower.get_tree().current_scene == null
	):
		return
	var candidates: Array = tower.main.get_path_cell_positions_near(
		tower.global_position, mine_placement_radius_pixels
	)
	for mine in active_mines:
		if not is_instance_valid(mine):
			continue
		candidates = candidates.filter(
			func(candidate_position: Vector2) -> bool:
				return candidate_position.distance_to(mine.global_position) > 1.0
		)
	if candidates.is_empty():
		return
	var mine_position: Vector2 = candidates[
		tower.spawn_rng.randi_range(0, candidates.size() - 1)
	]
	var mine := LONGSHOT_MINE_SCENE.instantiate() as Node2D
	tower.get_tree().current_scene.add_child(mine)
	mine.global_position = mine_position
	mine.setup(
		tower.main,
		maxi(roundi(float(tower.damage) * mine_damage_multiplier), 1),
		mine_trigger_radius_pixels,
		mine_explosion_radius_pixels,
		tower.create_attack_context(&"mine_explosion", mine, &"mine")
	)
	mine.detonated.connect(_on_mine_detonated)
	active_mines.append(mine)


func _on_mine_detonated(mine: Node2D) -> void:
	active_mines.erase(mine)
	mine_remaining = mine_interval


func prune_mines() -> void:
	active_mines = active_mines.filter(
		func(mine: Node) -> bool:
			return is_instance_valid(mine) and not mine.is_queued_for_deletion()
	)


func clear_mines() -> void:
	for mine in active_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	active_mines.clear()
