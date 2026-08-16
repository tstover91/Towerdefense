class_name BeholderAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const RelicEffects = preload("res://relic_combat.gd")
const EXPLOSION_ZONE_SCENE = preload("res://explosion_zone.tscn")

var death_explosion_enabled := false
var death_explosion_radius_pixels := 0.0
var death_explosion_damage_multiplier := 1.0
var ramping_beam_enabled := false
var beam_ramp_start_multiplier := 1.0
var beam_ramp_step_multiplier := 0.0
var beam_ramp_step_interval := 0.5
var beam_ramp_max_multiplier := 1.0
var beam_lock_elapsed := 0.0
var beam_lock_target_id := 0
var observed_target: Node2D


func uses_continuous_beam() -> bool:
	return true


func get_continuous_beam_origin(_default_origin: Vector2) -> Vector2:
	return tower.global_position


func reset_path_behaviors() -> void:
	death_explosion_enabled = false
	death_explosion_radius_pixels = 0.0
	death_explosion_damage_multiplier = 1.0
	ramping_beam_enabled = false
	beam_ramp_start_multiplier = 1.0
	beam_ramp_step_multiplier = 0.0
	beam_ramp_step_interval = 0.5
	beam_ramp_max_multiplier = 1.0


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("beholder_death_explosion", false):
		death_explosion_enabled = true
		death_explosion_radius_pixels = (
			maxf(float(values.get("death_explosion_radius", 3.0)), 0.0)
			* BaseTower.RANGE_PIXELS_PER_UNIT
		)
		death_explosion_damage_multiplier = maxf(
			float(values.get("death_explosion_damage_multiplier", 1.0)), 0.0
		)
	if flags.get("beholder_ramping_beam", false):
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


func finalize_path_behaviors() -> void:
	if death_explosion_enabled and tower.has_damage_tag(BaseTower.DAMAGE_EXPLOSIVE):
		if tower.get_primary_damage_type() != BaseTower.DAMAGE_EXPLOSIVE:
			death_explosion_damage_multiplier *= tower.get_explosion_damage_multiplier()
		death_explosion_radius_pixels *= tower.get_explosion_radius_multiplier()
	if not death_explosion_enabled:
		disconnect_target_observer()
	if not ramping_beam_enabled:
		beam_lock_elapsed = 0.0
		beam_lock_target_id = 0


func _exit_tree() -> void:
	disconnect_target_observer()


func on_round_ended() -> void:
	disconnect_target_observer()
	beam_lock_elapsed = 0.0
	beam_lock_target_id = 0


func on_target_updated() -> void:
	_update_target_observer()


func process_attack(delta: float) -> void:
	_update_target_observer()
	_process_beam_ramp(delta)


func get_continuous_beam_damage(base_damage: int) -> int:
	if not ramping_beam_enabled:
		return base_damage
	var previous_level := maxi(tower.tower_level - 1, 0)
	var previous_level_damage := int(
		tower.get_effective_stats_for_level(previous_level)["damage"]
	)
	var completed_steps := floori(beam_lock_elapsed / beam_ramp_step_interval)
	var damage_multiplier := minf(
		beam_ramp_start_multiplier
			+ beam_ramp_step_multiplier * float(completed_steps),
		beam_ramp_max_multiplier
	)
	return maxi(roundi(float(previous_level_damage) * damage_multiplier), 1)


func _process_beam_ramp(delta: float) -> void:
	if not ramping_beam_enabled:
		beam_lock_elapsed = 0.0
		beam_lock_target_id = 0
		return
	if (
		tower.main == null
		or not tower.main.round_active
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


func _update_target_observer() -> void:
	var desired_target: Node2D
	if death_explosion_enabled and tower.is_valid_target(tower.target):
		desired_target = tower.target
	if desired_target == observed_target:
		return
	disconnect_target_observer()
	observed_target = desired_target
	if (
		is_instance_valid(observed_target)
		and observed_target.has_signal("mob_died")
	):
		observed_target.mob_died.connect(_on_target_died)


func disconnect_target_observer() -> void:
	if (
		is_instance_valid(observed_target)
		and observed_target.has_signal("mob_died")
		and observed_target.mob_died.is_connected(_on_target_died)
	):
		observed_target.mob_died.disconnect(_on_target_died)
	observed_target = null


func _on_target_died(killed_mob: Node2D) -> void:
	if not death_explosion_enabled or tower.target != killed_mob:
		return
	if killed_mob.get_meta("beholder_death_explosion_triggered", false):
		return
	killed_mob.set_meta("beholder_death_explosion_triggered", true)
	var explosion_damage := maxi(
		roundi(float(tower.damage) * death_explosion_damage_multiplier), 1
	)
	disconnect_target_observer()
	trigger_death_explosion(killed_mob.global_position, explosion_damage)


func trigger_death_explosion(center: Vector2, explosion_damage: int) -> void:
	var explosion_context := RelicEffects.prepare_explosion_context(
		tower.create_attack_context(&"beholder_death_explosion"),
		tower.get_tree(),
		center,
		death_explosion_radius_pixels
	)
	if EXPLOSION_ZONE_SCENE != null and tower.get_tree().current_scene != null:
		if tower.get_tree().current_scene.has_method("spawn_explosion_visual"):
			tower.get_tree().current_scene.spawn_explosion_visual(
				center, death_explosion_radius_pixels
			)
		else:
			var explosion_zone := EXPLOSION_ZONE_SCENE.instantiate() as Node2D
			tower.get_tree().current_scene.add_child(explosion_zone)
			explosion_zone.global_position = center
			explosion_zone.setup(death_explosion_radius_pixels)
	for mob in tower.get_tree().get_nodes_in_group("mobs"):
		if not RelicEffects.is_valid_explosion_target(mob, explosion_context):
			continue
		var distance_from_center: float = mob.global_position.distance_to(center)
		if distance_from_center > death_explosion_radius_pixels:
			continue
		var dealt_damage := GameStats.get_explosion_damage(
			explosion_damage, distance_from_center, death_explosion_radius_pixels
		)
		tower.apply_tower_damage(
			mob,
			dealt_damage,
			BaseTower.DAMAGE_EXPLOSIVE,
			false,
			explosion_context
		)
