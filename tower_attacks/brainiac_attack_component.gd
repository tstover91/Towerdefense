class_name BrainiacAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const CONVERGENCE_RESOLVER = preload("res://brainiac_convergence_resolver.gd")

var convergence_explosion_enabled := false
var convergence_base_radius_pixels := 0.0
var convergence_radius_per_arrival_pixels := 0.0
var convergence_damage_per_arrival := 1.0
var psionic_link_enabled := false
var link_duration := 2.0
var link_cooldown := 6.0
var link_cooldown_remaining := 0.0
var link_radius_pixels := 0.0
var link_damage_share := 0.35
var previous_link_cooldown := 0.0


func reset_path_behaviors() -> void:
	previous_link_cooldown = link_cooldown_remaining
	convergence_explosion_enabled = false
	convergence_base_radius_pixels = 0.0
	convergence_radius_per_arrival_pixels = 0.0
	convergence_damage_per_arrival = 1.0
	psionic_link_enabled = false
	link_duration = 2.0
	link_cooldown = 6.0
	link_radius_pixels = 0.0
	link_damage_share = 0.35


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("brainiac_convergence_explosion", false):
		convergence_explosion_enabled = true
		convergence_base_radius_pixels = (
			maxf(float(values.get("convergence_base_radius", 1.5)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		convergence_radius_per_arrival_pixels = (
			maxf(float(values.get("convergence_radius_per_arrival", 0.65)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		convergence_damage_per_arrival = maxf(
			float(values.get("convergence_damage_per_arrival", 1.0)),
			0.0
		)
	if flags.get("brainiac_psionic_link", false):
		psionic_link_enabled = true
		link_duration = maxf(
			float(values.get("brainiac_link_duration", 2.0)),
			0.01
		)
		link_cooldown = maxf(
			float(values.get("brainiac_link_cooldown", 6.0)),
			0.01
		)
		link_radius_pixels = (
			maxf(float(values.get("brainiac_link_radius", 3.5)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		link_damage_share = maxf(
			float(values.get("brainiac_link_damage_share", 0.35)),
			0.0
		)


func finalize_path_behaviors() -> void:
	_apply_relic_modifiers()
	if psionic_link_enabled:
		link_cooldown_remaining = minf(
			previous_link_cooldown,
			link_cooldown
		)
	else:
		link_cooldown_remaining = 0.0
	previous_link_cooldown = 0.0


func _apply_relic_modifiers() -> void:
	if psionic_link_enabled:
		var lingering_count := tower.get_owned_relic_count(&"lingering_thoughts")
		var quick_count := tower.get_owned_relic_count(&"quick_thinking")
		link_duration *= (
			pow(GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER, lingering_count)
			* pow(GameStats.QUICK_THINKING_DURATION_MULTIPLIER, quick_count)
		)
		link_cooldown *= pow(
			GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER,
			quick_count
		)
	if convergence_explosion_enabled:
		var radius_multiplier := tower.get_explosion_radius_multiplier()
		if tower.get_primary_damage_type() != &"explosive":
			convergence_damage_per_arrival *= tower.get_explosion_damage_multiplier()
		convergence_base_radius_pixels *= radius_multiplier
		convergence_radius_per_arrival_pixels *= radius_multiplier


func on_round_started() -> void:
	link_cooldown_remaining = 0.0


func on_round_ended() -> void:
	link_cooldown_remaining = 0.0


func process_attack(delta: float) -> void:
	if tower.main != null and tower.main.round_active:
		link_cooldown_remaining = maxf(link_cooldown_remaining - delta, 0.0)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	_apply_link_if_ready(current_target)
	var aim_offset := current_target.global_position - tower.global_position
	if aim_offset.is_zero_approx():
		return true
	var direction := aim_offset.normalized()
	var perpendicular := direction.orthogonal()
	var convergence_point := (
		tower.global_position + direction * tower.range_radius_pixels
	)
	var maximum_flight_duration := 0.0
	var convergence_resolver: Node
	var volley_context := tower.create_attack_context(
		&"brainiac_volley", null, &"tower", null, false, true
	)
	if convergence_explosion_enabled:
		convergence_resolver = CONVERGENCE_RESOLVER.new()
		tower.get_tree().current_scene.add_child(convergence_resolver)
		convergence_resolver.setup(
			tower.main,
			tower.projectile_count,
			attack_damage,
			convergence_damage_per_arrival,
			convergence_base_radius_pixels,
			convergence_radius_per_arrival_pixels,
			convergence_point,
			tower.has_bonus_tag(BaseTower.BONUS_REVEAL),
			tower.create_attack_context(
				&"brainiac_convergence",
				tower,
				&"tower",
				volley_context,
				true
			)
		)
	for index in tower.projectile_count:
		var spread_ratio := 0.0
		if tower.projectile_count > 1:
			spread_ratio = (
				float(index) / float(tower.projectile_count - 1) - 0.5
			)
		var launch_position := (
			tower.muzzle.global_position
			+ perpendicular * tower.volley_width_pixels * spread_ratio
		)
		var flight_distance := launch_position.distance_to(convergence_point)
		maximum_flight_duration = maxf(
			maximum_flight_duration,
			flight_distance / maxf(tower.projectile_speed, 1.0)
		)
		var projectile := tower.launch_projectile_from_position(
			current_target,
			launch_position,
			convergence_point,
			flight_distance,
			attack_damage,
			0.0,
			tower.create_attack_context(
				&"brainiac_projectile",
				tower,
				&"tower",
				volley_context,
				false
			)
		)
		if convergence_resolver != null and projectile != null:
			convergence_resolver.track_projectile(projectile)
	if convergence_resolver != null:
		convergence_resolver.arm_timeout(maximum_flight_duration + 0.05)
	return true


func _apply_link_if_ready(current_target: Node2D) -> void:
	if (
		not psionic_link_enabled
		or link_cooldown_remaining > 0.0
		or not current_target.has_method("apply_brainiac_link")
	):
		return
	current_target.apply_brainiac_link(
		link_duration,
		link_radius_pixels,
		link_damage_share,
		tower.create_attack_context(&"brainiac_link")
	)
	link_cooldown_remaining = link_cooldown
