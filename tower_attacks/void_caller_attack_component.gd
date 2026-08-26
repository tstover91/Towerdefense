class_name VoidCallerAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const VOID_SINGULARITY_SCENE = preload("res://void_singularity.tscn")

var singularity_enabled := false
var singularity_cooldown := 10.0
var singularity_remaining := 0.0
var singularity_pull_duration := 1.0
var singularity_pull_radius_pixels := 0.0
var singularity_pull_speed := 80.0
var singularity_explosion_radius_pixels := 0.0
var singularity_damage_multiplier := 1.0
var active_singularities: Array[Node] = []
var previous_singularity_remaining := 0.0


func reset_path_behaviors() -> void:
	previous_singularity_remaining = singularity_remaining
	singularity_enabled = false
	singularity_cooldown = 10.0
	singularity_pull_duration = 1.0
	singularity_pull_radius_pixels = 0.0
	singularity_pull_speed = 80.0
	singularity_explosion_radius_pixels = 0.0
	singularity_damage_multiplier = 1.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if not flags.get("void_singularity", false):
		return
	singularity_enabled = true
	singularity_cooldown = maxf(
		float(values.get("singularity_cooldown", 10.0)),
		0.1
	)
	singularity_pull_duration = maxf(
		float(values.get("singularity_pull_duration", 1.0)),
		0.01
	)
	singularity_pull_radius_pixels = (
		maxf(float(values.get("singularity_pull_radius", 7.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	singularity_pull_speed = maxf(
		float(values.get("singularity_pull_speed", 80.0)),
		0.0
	)
	singularity_explosion_radius_pixels = (
		maxf(float(values.get("singularity_explosion_radius", 5.0)), 0.0)
		* BaseTower.RANGE_PIXELS_PER_UNIT
	)
	singularity_damage_multiplier = maxf(
		float(values.get("singularity_damage_multiplier", 3.0)),
		0.0
	)


func finalize_path_behaviors() -> void:
	_apply_relic_modifiers()
	if singularity_enabled:
		singularity_remaining = (
			minf(previous_singularity_remaining, singularity_cooldown)
			if previous_singularity_remaining > 0.0
			else singularity_cooldown
		)
	else:
		singularity_remaining = 0.0
	previous_singularity_remaining = 0.0


func _apply_relic_modifiers() -> void:
	if not singularity_enabled:
		return
	if tower.has_bonus_tag(BaseTower.BONUS_PSIONIC):
		var lingering_count := tower.get_effect_stack_count(&"lingering_thoughts")
		var quick_count := tower.get_effect_stack_count(&"quick_thinking")
		singularity_pull_duration *= (
			pow(GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER, lingering_count)
			* pow(GameStats.QUICK_THINKING_DURATION_MULTIPLIER, quick_count)
		)
		singularity_cooldown *= pow(
			GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER,
			quick_count
		)
	if tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		singularity_explosion_radius_pixels *= tower.get_explosion_radius_multiplier()
		singularity_cooldown *= tower.get_explosion_interval_multiplier()


func on_round_started() -> void:
	if singularity_enabled:
		singularity_remaining = singularity_cooldown


func on_round_ended() -> void:
	clear_singularities()
	singularity_remaining = singularity_cooldown


func _exit_tree() -> void:
	clear_singularities()


func process_attack(delta: float) -> void:
	if not singularity_enabled or not tower.is_placed:
		return
	if not tower.is_combat_active():
		return
	prune_singularities()
	singularity_remaining = maxf(singularity_remaining - delta, 0.0)
	if singularity_remaining > 0.0:
		return
	var singularity_target := tower.select_standard_target()
	if (
		not tower.is_valid_target(singularity_target)
		or not is_instance_valid(singularity_target.path_follow)
	):
		return
	singularity_remaining = singularity_cooldown
	spawn_singularity(singularity_target)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	var volley_center := current_target.global_position
	var aim_offset := volley_center - tower.muzzle.global_position
	if aim_offset.is_zero_approx():
		return true
	var perpendicular := aim_offset.normalized().orthogonal()
	var target_reference: WeakRef = weakref(current_target)
	var volley_context := tower.create_attack_context(
		&"void_caller_volley", null, &"tower", null, false, true
	)
	for index in tower.projectile_count:
		var spread_ratio := 0.0
		if tower.projectile_count > 1:
			spread_ratio = (
				float(index) / float(tower.projectile_count - 1) - 0.5
			)
		var destination := (
			volley_center
			+ perpendicular * tower.volley_width_pixels * spread_ratio
		)
		var release_delay := tower.volley_stagger * float(index)
		if release_delay <= 0.0:
			_launch_delayed_volley_projectile(
				target_reference,
				destination,
				attack_damage,
				volley_context
			)
		else:
			tower.get_tree().create_timer(release_delay, false).timeout.connect(
				_launch_delayed_volley_projectile.bind(
					target_reference,
					destination,
					attack_damage,
					volley_context
				)
			)
	return true


func _launch_delayed_volley_projectile(
	target_reference: WeakRef,
	destination: Vector2,
	attack_damage: int,
	volley_context: AttackContext
) -> void:
	if not tower.is_placed or not tower.is_combat_active():
		return
	var current_target: Node2D
	var referenced_target: Variant = target_reference.get_ref()
	if is_instance_valid(referenced_target):
		current_target = referenced_target as Node2D
	var launch_position := tower.muzzle.global_position
	tower.launch_projectile_from_position(
		current_target,
		launch_position,
		destination,
		launch_position.distance_to(destination),
		attack_damage,
		tower.splash_radius_pixels,
		tower.create_attack_context(
			&"void_caller_projectile",
			tower,
			&"tower",
			volley_context,
			false
		)
	)


func spawn_singularity(current_target: Node2D) -> void:
	if VOID_SINGULARITY_SCENE == null or tower.get_tree().current_scene == null:
		return
	var singularity := VOID_SINGULARITY_SCENE.instantiate() as Node2D
	tower.get_tree().current_scene.add_child(singularity)
	singularity.global_position = current_target.global_position
	singularity.setup(
		tower.main,
		current_target.path_follow.progress,
		singularity_pull_duration,
		singularity_pull_radius_pixels,
		singularity_pull_speed,
		singularity_explosion_radius_pixels,
		maxi(roundi(float(tower.damage) * singularity_damage_multiplier), 1),
		tower.create_attack_context(
			&"void_singularity",
			singularity,
			&"persistent_effect"
		)
	)
	singularity.finished.connect(_on_singularity_finished)
	active_singularities.append(singularity)


func _on_singularity_finished(singularity: Node2D) -> void:
	active_singularities.erase(singularity)


func prune_singularities() -> void:
	active_singularities = active_singularities.filter(
		func(singularity: Node) -> bool:
			return (
				is_instance_valid(singularity)
				and not singularity.is_queued_for_deletion()
			)
	)


func clear_singularities() -> void:
	for singularity in active_singularities:
		if is_instance_valid(singularity):
			singularity.queue_free()
	active_singularities.clear()
