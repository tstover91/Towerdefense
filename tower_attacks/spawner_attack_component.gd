class_name SpawnerAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")

var spawned_unit_id: StringName = &""
var spawn_limit := 0
var deployment_radius_pixels := 0.0
var active_units: Array[Node] = []
var drone_target_mode := 0


func uses_standard_targeting() -> bool:
	return false


func uses_shared_attack_scheduler() -> bool:
	return false


func uses_standard_spawner_system() -> bool:
	return true


func uses_drone_targeting() -> bool:
	return spawned_unit_id == &"drone"


func load_level_stats(stats: Dictionary) -> void:
	var tower_data := GameStats.get_tower(tower.tower_id)
	spawned_unit_id = tower_data.get("spawned_unit_id", &"")
	spawn_limit = maxi(int(stats.get("spawn_limit", 1)), 1)
	if tower.get_owned_relic_count(&"trade_agreement") > 0:
		spawn_limit *= GameStats.TRADE_AGREEMENT_SPAWN_LIMIT_MULTIPLIER
	deployment_radius_pixels = (
		float(stats.get("deployment_radius", 1.0))
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	var spawn_interval := float(stats.get("spawn_interval", 1.0))
	if tower.get_owned_relic_count(&"trade_agreement") > 0:
		spawn_interval *= GameStats.TRADE_AGREEMENT_SPAWN_INTERVAL_MULTIPLIER
	tower.damage_timer.wait_time = maxf(spawn_interval, 0.1)
	_refresh_unit_stats(stats.get("unit_stats", {}))


func on_round_ended() -> void:
	tower.damage_timer.stop()
	clear_units()


func _exit_tree() -> void:
	clear_units()


func spawn_unit() -> void:
	if not tower.is_placed or spawned_unit_id.is_empty():
		return
	if tower.main == null or not tower.main.round_active:
		tower.damage_timer.stop()
		return
	prune_units()
	if active_units.size() >= spawn_limit:
		return
	var spawned_unit: Node = SPAWNED_UNIT_SCENE.instantiate()
	tower.get_tree().current_scene.add_child(spawned_unit)
	spawned_unit.global_position = _get_spawned_unit_position()
	var map_path: Path2D
	if tower.main.has_method("get_primary_enemy_path"):
		map_path = tower.main.get_primary_enemy_path()
	spawned_unit.setup(
		spawned_unit_id,
		tower.get_effective_stats_for_level(tower.tower_level)["unit_stats"],
		tower,
		map_path
	)
	active_units.append(spawned_unit)
	spawned_unit.tree_exiting.connect(_on_unit_exiting.bind(spawned_unit))


func _get_spawned_unit_position() -> Vector2:
	var definition := GameStats.get_spawned_unit(spawned_unit_id)
	if definition["movement_type"] != GameStats.MOVEMENT_STATIONARY:
		return tower.global_position
	var angle := tower.spawn_rng.randf_range(0.0, TAU)
	var distance := sqrt(tower.spawn_rng.randf()) * deployment_radius_pixels
	var spawn_position := tower.global_position + Vector2.from_angle(angle) * distance
	var viewport_size := tower.get_viewport_rect().size
	var playable_right_edge := viewport_size.x
	if tower.main != null and tower.main.has_method("get_playable_right_edge"):
		playable_right_edge = minf(
			playable_right_edge, float(tower.main.get_playable_right_edge())
		)
	spawn_position.x = clampf(spawn_position.x, 8.0, playable_right_edge - 8.0)
	spawn_position.y = clampf(spawn_position.y, 8.0, viewport_size.y - 8.0)
	return spawn_position


func _refresh_unit_stats(unit_stats: Dictionary) -> void:
	prune_units()
	for spawned_unit in active_units:
		if is_instance_valid(spawned_unit):
			spawned_unit.apply_stats(unit_stats)


func prune_units() -> void:
	active_units = active_units.filter(
		func(spawned_unit: Node) -> bool:
			return (
				is_instance_valid(spawned_unit)
				and not spawned_unit.is_queued_for_deletion()
			)
	)


func _on_unit_exiting(spawned_unit: Node) -> void:
	active_units.erase(spawned_unit)


func schedule_unit_replacement(delay: float) -> void:
	if not tower.is_placed:
		return
	tower.get_tree().create_timer(maxf(delay, 0.0), false).timeout.connect(
		_spawn_scheduled_replacement
	)


func _spawn_scheduled_replacement() -> void:
	if (
		not tower.is_placed
		or tower.main == null
		or not tower.main.round_active
	):
		return
	prune_units()
	if active_units.size() < spawn_limit:
		spawn_unit()


func clear_units() -> void:
	for spawned_unit in active_units:
		if is_instance_valid(spawned_unit):
			spawned_unit.queue_free()
	active_units.clear()


func get_drone_target_mode() -> int:
	return drone_target_mode


func set_drone_target_mode(mode: int) -> void:
	drone_target_mode = clampi(mode, 0, 1)


func get_drone_command_targets() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if not uses_drone_targeting():
		return candidates
	for candidate in tower.mobs_in_range:
		if (
			tower.is_valid_target(candidate)
			and tower.global_position.distance_to(candidate.global_position)
				<= tower.range_radius_pixels
		):
			candidates.append(candidate)
	return candidates
