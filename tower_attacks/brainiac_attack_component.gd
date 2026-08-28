class_name BrainiacAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const TEMPORAL_EYE_BUBBLE = preload("res://temporal_eye_bubble.gd")

var psionic_link_enabled := false
var link_duration := 2.0
var link_cooldown := 6.0
var link_cooldown_remaining := 0.0
var link_radius_pixels := 0.0
var link_damage_share := 0.35
var previous_link_cooldown := 0.0
var ramping_beam_enabled := false
var beam_ramp_start_multiplier := 1.0
var beam_ramp_step_multiplier := 0.0
var beam_ramp_step_interval := 0.5
var beam_ramp_max_multiplier := 1.0
var beam_lock_elapsed := 0.0
var beam_lock_target_id := 0
var temporal_eye_enabled := false
var temporal_bubble_duration := 3.0
var temporal_bubble_radius_pixels := 0.0
var temporal_beam_tick_interval := 0.2
var temporal_beam_half_width_pixels := 0.0
var temporal_rotation_radians := PI * 0.5
var temporal_center_damage_multiplier := 1.0
var temporal_final_stun_duration := 0.0
var active_temporal_bubble: Node


func uses_continuous_beam() -> bool:
	return not temporal_eye_enabled


func get_continuous_beam_origin(_default_origin: Vector2) -> Vector2:
	return tower.global_position


func reset_path_behaviors() -> void:
	previous_link_cooldown = link_cooldown_remaining
	psionic_link_enabled = false
	link_duration = 2.0
	link_cooldown = 6.0
	link_radius_pixels = 0.0
	link_damage_share = 0.35
	ramping_beam_enabled = false
	beam_ramp_start_multiplier = 1.0
	beam_ramp_step_multiplier = 0.0
	beam_ramp_step_interval = 0.5
	beam_ramp_max_multiplier = 1.0
	temporal_eye_enabled = false
	temporal_bubble_duration = 3.0
	temporal_bubble_radius_pixels = 0.0
	temporal_beam_tick_interval = 0.2
	temporal_beam_half_width_pixels = 0.0
	temporal_rotation_radians = PI * 0.5
	temporal_center_damage_multiplier = 1.0
	temporal_final_stun_duration = 0.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("brainiac_psionic_link", false):
		psionic_link_enabled = true
		link_duration = maxf(float(values.get("brainiac_link_duration", 2.0)), 0.01)
		link_cooldown = maxf(float(values.get("brainiac_link_cooldown", 6.0)), 0.01)
		link_radius_pixels = (
			maxf(float(values.get("brainiac_link_radius", 3.5)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		link_damage_share = maxf(
			float(values.get("brainiac_link_damage_share", 0.35)),
			0.0
		)
	if flags.get("brainiac_ramping_beam", false):
		ramping_beam_enabled = true
		beam_ramp_start_multiplier = maxf(
			float(values.get("beam_ramp_start_multiplier", 0.5)), 0.0
		)
		beam_ramp_step_multiplier = maxf(
			float(values.get("beam_ramp_step_multiplier", 0.25)), 0.0
		)
		beam_ramp_step_interval = maxf(
			float(values.get("beam_ramp_step_interval", 0.5)), 0.01
		)
		beam_ramp_max_multiplier = maxf(
			float(values.get("beam_ramp_max_multiplier", 2.5)),
			beam_ramp_start_multiplier
		)
	if flags.get("psion_temporal_eye", false):
		temporal_eye_enabled = true
		temporal_bubble_duration = maxf(
			float(values.get("temporal_bubble_duration", 3.0)), 0.1
		)
		temporal_bubble_radius_pixels = maxf(
			float(values.get("temporal_bubble_radius", 3.0)), 0.1
		) * BaseTower.BUILD_CELL_SIZE
		temporal_beam_tick_interval = maxf(
			float(values.get("temporal_beam_tick_interval", 0.20)), 0.05
		)
		temporal_beam_half_width_pixels = maxf(
			float(values.get("temporal_beam_half_width", 0.30)), 0.05
		) * BaseTower.BUILD_CELL_SIZE
		temporal_rotation_radians = deg_to_rad(
			float(values.get("temporal_rotation_degrees", 90.0))
		)
		temporal_center_damage_multiplier = maxf(
			float(values.get("temporal_center_damage_multiplier", 1.0)), 0.0
		)
		temporal_final_stun_duration = maxf(
			float(values.get("temporal_final_stun_duration", 0.0)), 0.0
		)


func finalize_path_behaviors() -> void:
	_apply_item_effect_modifiers()
	if psionic_link_enabled:
		link_cooldown_remaining = minf(previous_link_cooldown, link_cooldown)
	else:
		link_cooldown_remaining = 0.0
	previous_link_cooldown = 0.0
	if not ramping_beam_enabled:
		beam_lock_elapsed = 0.0
		beam_lock_target_id = 0
	if not temporal_eye_enabled:
		clear_temporal_bubble()


func _apply_item_effect_modifiers() -> void:
	if not psionic_link_enabled:
		return
	var lingering_count := tower.get_effect_stack_count(&"lingering_thoughts")
	var quick_count := tower.get_effect_stack_count(&"quick_thinking")
	link_duration *= (
		pow(GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER, lingering_count)
		* pow(GameStats.QUICK_THINKING_DURATION_MULTIPLIER, quick_count)
	)
	link_cooldown *= pow(
		GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER,
		quick_count
	)


func on_round_started() -> void:
	link_cooldown_remaining = 0.0


func on_round_ended() -> void:
	link_cooldown_remaining = 0.0
	beam_lock_elapsed = 0.0
	beam_lock_target_id = 0
	clear_temporal_bubble()


func on_target_updated() -> void:
	_apply_link_if_ready()


func process_attack(delta: float) -> void:
	if tower.is_combat_active():
		link_cooldown_remaining = maxf(link_cooldown_remaining - delta, 0.0)
	_apply_link_if_ready()
	_process_beam_ramp(delta)


func get_continuous_beam_damage(base_damage: int) -> int:
	if not ramping_beam_enabled:
		return base_damage
	var completed_steps := floori(beam_lock_elapsed / beam_ramp_step_interval)
	var damage_multiplier := minf(
		beam_ramp_start_multiplier
			+ beam_ramp_step_multiplier * float(completed_steps),
		beam_ramp_max_multiplier
	)
	return maxi(roundi(float(base_damage) * damage_multiplier), 1)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	if not temporal_eye_enabled or not tower.is_valid_target(current_target):
		return false
	clear_temporal_bubble()
	var bubble := TEMPORAL_EYE_BUBBLE.new()
	tower.get_tree().current_scene.add_child(bubble)
	bubble.global_position = current_target.global_position
	bubble.setup(
		tower,
		attack_damage,
		temporal_bubble_duration,
		temporal_bubble_radius_pixels,
		temporal_beam_tick_interval,
		temporal_beam_half_width_pixels,
		temporal_rotation_radians,
		temporal_center_damage_multiplier,
		temporal_final_stun_duration,
		tower.create_attack_context(
			&"temporal_eye_bubble", bubble, &"persistent_effect", null, false, true
		)
	)
	active_temporal_bubble = bubble
	bubble.tree_exiting.connect(_on_temporal_bubble_exiting.bind(bubble))
	return true


func clear_temporal_bubble() -> void:
	if is_instance_valid(active_temporal_bubble):
		active_temporal_bubble.recycle_now()
	active_temporal_bubble = null


func _on_temporal_bubble_exiting(bubble: Node) -> void:
	if active_temporal_bubble == bubble:
		active_temporal_bubble = null


func _apply_link_if_ready() -> void:
	if (
		not psionic_link_enabled
		or link_cooldown_remaining > 0.0
		or not tower.is_combat_active()
		or not tower.is_valid_target(tower.target)
		or not tower.mobs_in_range.has(tower.target)
		or not tower.target.has_method("apply_brainiac_link")
	):
		return
	tower.target.apply_brainiac_link(
		link_duration,
		link_radius_pixels,
		link_damage_share,
		tower.create_attack_context(&"brainiac_link")
	)
	link_cooldown_remaining = link_cooldown


func _process_beam_ramp(delta: float) -> void:
	if not ramping_beam_enabled:
		beam_lock_elapsed = 0.0
		beam_lock_target_id = 0
		return
	if (
		not tower.is_combat_active()
		or not tower.is_valid_target(tower.target)
		or not tower.mobs_in_range.has(tower.target)
	):
		beam_lock_elapsed = 0.0
		beam_lock_target_id = 0
		return
	var current_target_id := tower.target.get_instance_id()
	if current_target_id != beam_lock_target_id:
		beam_lock_target_id = current_target_id
		beam_lock_elapsed = 0.0
		return
	beam_lock_elapsed += delta
