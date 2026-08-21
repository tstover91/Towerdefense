class_name ReaverAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")

var combo_hit_count := 1
var combo_stagger := 0.0
var active_combo_sequence := 0
var time_bubble_enabled := false
var time_bubble_active_duration := 3.0
var time_bubble_cooldown := 7.0
var time_bubble_active_remaining := 0.0
var time_bubble_cooldown_remaining := 0.0
var time_bubble_refresh_interval := 0.2
var time_bubble_slow_duration := 0.3
var time_bubble_refresh_remaining := 0.0
var assassinate_enabled := false
var previous_bubble_active := 0.0
var previous_bubble_cooldown := 0.0


func load_level_stats(stats: Dictionary) -> void:
	combo_hit_count = maxi(int(stats.get("combo_hit_count", 1)), 1)
	combo_stagger = maxf(float(stats.get("combo_stagger", 0.0)), 0.0)
	var tower_data := GameStats.get_tower(tower.tower_id)
	var base_level: Dictionary = tower_data["levels"][0]
	var base_attack_interval := maxf(float(base_level["firerate"]), 0.01)
	combo_stagger *= float(stats["firerate"]) / base_attack_interval


func reset_path_behaviors() -> void:
	previous_bubble_active = time_bubble_active_remaining
	previous_bubble_cooldown = time_bubble_cooldown_remaining
	time_bubble_enabled = false
	time_bubble_active_duration = 3.0
	time_bubble_cooldown = 7.0
	time_bubble_refresh_interval = 0.2
	time_bubble_slow_duration = 0.3
	assassinate_enabled = false


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("reaver_time_bubble", false):
		time_bubble_enabled = true
		time_bubble_active_duration = maxf(float(values.get("time_bubble_active_duration", 3.0)), 0.01)
		time_bubble_cooldown = maxf(float(values.get("time_bubble_cooldown", 7.0)), 0.0)
		time_bubble_refresh_interval = maxf(float(values.get("time_bubble_refresh_interval", 0.2)), 0.05)
		time_bubble_slow_duration = maxf(float(values.get("time_bubble_slow_duration", 0.3)), 0.01)
	if flags.get("reaver_assassinate", false):
		assassinate_enabled = true


func finalize_path_behaviors() -> void:
	_apply_psionic_relic_modifiers()
	if time_bubble_enabled:
		if previous_bubble_active > 0.0:
			time_bubble_active_remaining = minf(previous_bubble_active, time_bubble_active_duration)
			time_bubble_cooldown_remaining = 0.0
		elif previous_bubble_cooldown > 0.0:
			time_bubble_active_remaining = 0.0
			time_bubble_cooldown_remaining = minf(previous_bubble_cooldown, time_bubble_cooldown)
		else:
			time_bubble_active_remaining = 0.0
			time_bubble_cooldown_remaining = 0.0
	else:
		time_bubble_active_remaining = 0.0
		time_bubble_cooldown_remaining = 0.0
		time_bubble_refresh_remaining = 0.0
	previous_bubble_active = 0.0
	previous_bubble_cooldown = 0.0


func _apply_psionic_relic_modifiers() -> void:
	if not time_bubble_enabled:
		return
	var lingering_count := tower.get_owned_relic_count(&"lingering_thoughts")
	var quick_count := tower.get_owned_relic_count(&"quick_thinking")
	time_bubble_active_duration *= (
		pow(GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER, lingering_count)
		* pow(GameStats.QUICK_THINKING_DURATION_MULTIPLIER, quick_count)
	)
	time_bubble_cooldown *= pow(GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER, quick_count)


func on_round_started() -> void:
	if time_bubble_enabled:
		_reset_time_bubble()


func on_round_ended() -> void:
	_reset_time_bubble()
	tower.queue_redraw()


func _reset_time_bubble() -> void:
	time_bubble_active_remaining = 0.0
	time_bubble_cooldown_remaining = 0.0
	time_bubble_refresh_remaining = 0.0


func process_attack(delta: float) -> void:
	if not time_bubble_enabled or not tower.is_placed:
		return
	if not tower.is_combat_active():
		_reset_time_bubble()
		return
	if time_bubble_active_remaining <= 0.0:
		time_bubble_cooldown_remaining = maxf(time_bubble_cooldown_remaining - delta, 0.0)
		if time_bubble_cooldown_remaining > 0.0:
			return
		if not _has_valid_enemy_in_bubble():
			return
		time_bubble_active_remaining = time_bubble_active_duration
		time_bubble_refresh_remaining = 0.0
	time_bubble_active_remaining = maxf(time_bubble_active_remaining - delta, 0.0)
	tower.queue_redraw()
	if time_bubble_active_remaining <= 0.0:
		time_bubble_cooldown_remaining = time_bubble_cooldown
		return
	time_bubble_refresh_remaining -= delta
	if time_bubble_refresh_remaining > 0.0:
		return
	time_bubble_refresh_remaining = time_bubble_refresh_interval
	var bubble_context := tower.create_attack_context(&"reaver_time_bubble")
	for mob in tower.tower_area.get_overlapping_bodies():
		if not tower.is_valid_target(mob) or not mob.has_method("apply_slow"):
			continue
		mob.apply_slow(time_bubble_slow_duration, bubble_context)


func _has_valid_enemy_in_bubble() -> bool:
	for mob in tower.tower_area.get_overlapping_bodies():
		if tower.is_valid_target(mob):
			return true
	return false


func draw_attack_visuals() -> void:
	if not time_bubble_enabled or not tower.is_placed or time_bubble_active_remaining <= 0.0:
		return
	if not tower.is_combat_active():
		return
	tower.draw_circle(Vector2.ZERO, tower.range_radius_pixels, Color(0.20, 0.55, 1.0, 0.10))
	tower.draw_arc(
		Vector2.ZERO,
		tower.range_radius_pixels,
		0.0,
		TAU,
		96,
		Color(0.45, 0.78, 1.0, 0.55),
		1.5,
		true
	)


func execute_raw_attack(current_target: Node2D, base_damage: int) -> bool:
	active_combo_sequence += 1
	var combo_sequence := active_combo_sequence
	var target_reference: WeakRef = weakref(current_target)
	for hit_index in combo_hit_count:
		var hit_damage := _get_combo_hit_damage(base_damage, hit_index)
		if assassinate_enabled and hit_index == combo_hit_count - 1:
			hit_damage = tower.roll_guaranteed_critical_damage(hit_damage)
		else:
			hit_damage = tower.roll_critical_damage(hit_damage, current_target)
		var hit_context := tower.create_attack_context(
			&"reaver_combo_hit", null, &"tower", null, false, true
		)
		var hit_delay := combo_stagger * float(hit_index)
		if hit_delay <= 0.0:
			_apply_combo_hit(target_reference, hit_damage, combo_sequence, hit_context)
		else:
			tower.get_tree().create_timer(hit_delay, false).timeout.connect(
				_apply_combo_hit.bind(target_reference, hit_damage, combo_sequence, hit_context)
			)
	return true


func _get_combo_hit_damage(total_damage: int, hit_index: int) -> int:
	if combo_hit_count <= 1:
		return total_damage
	var light_hit_damage := maxi(roundi(float(total_damage) * 0.25), 1)
	if hit_index < combo_hit_count - 1:
		return light_hit_damage
	return maxi(total_damage - light_hit_damage * (combo_hit_count - 1), 1)


func _apply_combo_hit(
	target_reference: WeakRef,
	hit_damage: int,
	combo_sequence: int,
	hit_context: AttackContext
) -> void:
	if combo_sequence != active_combo_sequence:
		return
	if not tower.is_placed or not tower.is_combat_active():
		active_combo_sequence += 1
		return
	var referenced_target: Variant = target_reference.get_ref()
	if not tower.is_valid_target(referenced_target):
		active_combo_sequence += 1
		return
	var combo_target := referenced_target as Node2D
	if tower.global_position.distance_to(combo_target.global_position) > tower.range_radius_pixels:
		active_combo_sequence += 1
		return
	tower.apply_hitscan_damage(combo_target, hit_damage, hit_context)
