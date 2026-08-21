class_name OrbitalCannonAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const SOLAR_LANCE_SCENE = preload("res://solar_lance.tscn")

var minimum_range_pixels := 0.0
var has_target_position := false
var target_position := Vector2.ZERO
var targeting_active := false
var preview_position := Vector2.ZERO
var preview_valid := false
var solar_lance_enabled := false
var solar_lance_duration := 1.5
var solar_lance_tick_interval := 0.2
var solar_lance_tick_damage_multiplier := 0.25
var solar_lance_tick_end_damage_multiplier := 0.50
var solar_lance_dual_tick_damage_multiplier := 0.10
var bombardment_enabled := false
var bombardment_strike_count := 5
var bombardment_stagger := 0.15
var bombardment_spread_radius_pixels := 0.0
var bombardment_damage_multiplier := 0.38
var bombardment_radius_multiplier := 0.70
var active_solar_lances: Array[Node] = []


func uses_manual_ground_targeting() -> bool:
	return true


func load_level_stats(_stats: Dictionary) -> void:
	var tower_data := GameStats.get_tower(tower.tower_id)
	minimum_range_pixels = (
		maxf(float(tower_data.get("minimum_range", 0.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)


func reset_path_behaviors() -> void:
	solar_lance_enabled = false
	solar_lance_duration = 1.5
	solar_lance_tick_interval = 0.2
	solar_lance_tick_damage_multiplier = 0.25
	solar_lance_tick_end_damage_multiplier = 0.50
	solar_lance_dual_tick_damage_multiplier = 0.10
	bombardment_enabled = false
	bombardment_strike_count = 5
	bombardment_stagger = 0.15
	bombardment_spread_radius_pixels = 0.0
	bombardment_damage_multiplier = 0.38
	bombardment_radius_multiplier = 0.70


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("orbital_solar_lance", false):
		solar_lance_enabled = true
		solar_lance_duration = maxf(
			float(values.get("solar_lance_duration", 1.5)), 0.01
		)
		solar_lance_tick_interval = maxf(
			float(values.get("solar_lance_tick_interval", 0.2)), 0.01
		)
		solar_lance_tick_damage_multiplier = maxf(
			float(values.get("solar_lance_tick_damage_multiplier", 0.25)), 0.0
		)
		solar_lance_tick_end_damage_multiplier = maxf(
			float(values.get("solar_lance_tick_end_damage_multiplier", 0.50)), 0.0
		)
		solar_lance_dual_tick_damage_multiplier = maxf(
			float(values.get("solar_lance_dual_tick_damage_multiplier", 0.10)), 0.0
		)
	if flags.get("orbital_bombardment", false):
		bombardment_enabled = true
		bombardment_strike_count = maxi(
			int(values.get("bombardment_strike_count", 5)), 1
		)
		bombardment_stagger = maxf(
			float(values.get("bombardment_stagger", 0.15)), 0.0
		)
		bombardment_spread_radius_pixels = (
			maxf(float(values.get("bombardment_spread_radius", 3.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		bombardment_damage_multiplier = maxf(
			float(values.get("bombardment_damage_multiplier", 0.38)), 0.0
		)
		bombardment_radius_multiplier = maxf(
			float(values.get("bombardment_radius_multiplier", 0.70)), 0.0
		)


func process_pre_targeting(_delta: float) -> void:
	if not targeting_active:
		return
	preview_position = tower.get_global_mouse_position()
	preview_valid = is_valid_manual_target_position(preview_position)
	tower.queue_redraw()


func draw_attack_visuals() -> void:
	if not tower.is_placed:
		return
	if tower.range_preview_visible and minimum_range_pixels > 0.0:
		tower.draw_circle(
			Vector2.ZERO, minimum_range_pixels, Color(1.0, 0.12, 0.12, 0.18)
		)
		tower.draw_arc(
			Vector2.ZERO,
			minimum_range_pixels,
			0.0,
			TAU,
			64,
			Color(1.0, 0.25, 0.2, 0.9),
			2.0,
			true
		)
	if has_target_position:
		_draw_target_symbol(
			tower.to_local(target_position), Color(1.0, 0.45, 0.15, 0.75)
		)
	if targeting_active:
		_draw_target_symbol(
			tower.to_local(preview_position),
			Color(0.25, 1.0, 0.35, 0.95)
				if preview_valid
				else Color(1.0, 0.15, 0.15, 0.95)
		)


func _draw_target_symbol(local_position: Vector2, color: Color) -> void:
	tower.draw_arc(local_position, 12.0, 0.0, TAU, 32, color, 2.0, true)
	tower.draw_line(
		local_position + Vector2(-18.0, 0.0),
		local_position + Vector2(18.0, 0.0),
		color,
		2.0,
		true
	)
	tower.draw_line(
		local_position + Vector2(0.0, -18.0),
		local_position + Vector2(0.0, 18.0),
		color,
		2.0,
		true
	)


func begin_manual_targeting() -> void:
	if tower.main == null:
		return
	targeting_active = true
	preview_position = tower.get_global_mouse_position()
	preview_valid = is_valid_manual_target_position(preview_position)
	tower.hide_action_menus()
	tower.show_current_range_preview()
	tower.main.begin_manual_tower_targeting(tower)
	tower.queue_redraw()


func cancel_manual_targeting() -> void:
	targeting_active = false
	tower.queue_redraw()
	tower.set_selected(false)


func confirm_manual_target_position(world_position: Vector2) -> bool:
	if not targeting_active or not is_valid_manual_target_position(world_position):
		return false
	target_position = world_position
	has_target_position = true
	targeting_active = false
	tower.queue_redraw()
	tower.set_selected(false)
	return true


func is_manual_targeting_active() -> bool:
	return targeting_active


func has_manual_target_position() -> bool:
	return has_target_position


func get_manual_target_position() -> Vector2:
	return target_position


func is_valid_manual_target_position(world_position: Vector2) -> bool:
	var distance_from_tower := tower.global_position.distance_to(world_position)
	if (
		distance_from_tower < minimum_range_pixels
		or distance_from_tower > tower.range_radius_pixels
	):
		return false
	return (
		tower.main == null
		or not tower.main.has_method("is_world_position_in_playable_area")
		or tower.main.is_world_position_in_playable_area(world_position)
	)


func has_manual_attack_opportunity() -> bool:
	if not tower.is_combat_active() or not has_target_position:
		return false
	var activation_radius := tower.splash_radius_pixels
	if solar_lance_enabled:
		activation_radius = BaseTower.BUILD_CELL_SIZE
	if bombardment_enabled:
		activation_radius = (
			bombardment_spread_radius_pixels
			+ (
				BaseTower.BUILD_CELL_SIZE
				if solar_lance_enabled
				else tower.splash_radius_pixels * bombardment_radius_multiplier
			)
		)
	for mob in tower.get_tree().get_nodes_in_group("mobs"):
		if not tower.is_valid_target(mob):
			continue
		if mob.global_position.distance_to(target_position) <= activation_radius:
			return true
	return false


func execute_manual_attack() -> void:
	var strike_count := bombardment_strike_count if bombardment_enabled else 1
	var strike_damage := tower.roll_attack_damage()
	var strike_radius := tower.splash_radius_pixels
	if bombardment_enabled:
		strike_damage = maxi(
			roundi(float(strike_damage) * bombardment_damage_multiplier), 1
		)
		strike_radius *= bombardment_radius_multiplier
	for strike_index in strike_count:
		var strike_position := target_position
		if strike_index > 0:
			var offset_angle := tower.spawn_rng.randf_range(0.0, TAU)
			var offset_distance := (
				sqrt(tower.spawn_rng.randf()) * bombardment_spread_radius_pixels
			)
			strike_position += Vector2.from_angle(offset_angle) * offset_distance
		var strike_delay := bombardment_stagger * float(strike_index)
		if strike_delay <= 0.0:
			_resolve_strike(strike_position, strike_damage, strike_radius)
		else:
			tower.get_tree().create_timer(strike_delay, false).timeout.connect(
				_resolve_strike.bind(strike_position, strike_damage, strike_radius)
			)


func _resolve_strike(
	strike_position: Vector2,
	strike_damage: int,
	strike_radius: float
) -> void:
	if not tower.is_placed or not tower.is_combat_active():
		return
	if solar_lance_enabled:
		_spawn_solar_lance(strike_position, strike_damage)
		return
	tower.launch_projectile_from_position(
		null,
		tower.muzzle.global_position,
		strike_position,
		tower.muzzle.global_position.distance_to(strike_position),
		strike_damage,
		strike_radius
	)


func _spawn_solar_lance(strike_position: Vector2, strike_damage: int) -> void:
	if SOLAR_LANCE_SCENE == null or tower.get_tree().current_scene == null:
		return
	var tick_start_multiplier := solar_lance_tick_damage_multiplier
	var tick_end_multiplier := solar_lance_tick_end_damage_multiplier
	if bombardment_enabled:
		tick_start_multiplier = solar_lance_dual_tick_damage_multiplier
		tick_end_multiplier = solar_lance_dual_tick_damage_multiplier
	var lance := SOLAR_LANCE_SCENE.instantiate() as Node2D
	tower.get_tree().current_scene.add_child(lance)
	lance.global_position = strike_position
	lance.setup(
		tower.main,
		BaseTower.BUILD_CELL_SIZE,
		maxi(roundi(float(strike_damage) * tick_start_multiplier), 1),
		maxi(roundi(float(strike_damage) * tick_end_multiplier), 1),
		solar_lance_duration,
		solar_lance_tick_interval,
		tower.create_attack_context(
			&"solar_lance", lance, &"persistent_effect", null, false, true
		)
	)
	lance.finished.connect(_on_solar_lance_finished)
	active_solar_lances.append(lance)


func _on_solar_lance_finished(lance: Node2D) -> void:
	active_solar_lances.erase(lance)


func on_round_ended() -> void:
	clear_solar_lances()


func _exit_tree() -> void:
	clear_solar_lances()


func clear_solar_lances() -> void:
	for lance in active_solar_lances:
		if is_instance_valid(lance):
			lance.queue_free()
	active_solar_lances.clear()
