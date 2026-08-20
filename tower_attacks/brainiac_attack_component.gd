class_name BrainiacAttackComponent
extends TowerAttackComponent

const CONVERGING_BEAMS = preload("res://beholder_converging_beams.gd")

var damage_mark_enabled := false
var mark_duration := 3.0
var mark_damage_per_stack := 0.02
var mark_maximum_stacks := 10


func reset_path_behaviors() -> void:
	damage_mark_enabled = false
	mark_duration = 3.0
	mark_damage_per_stack = 0.02
	mark_maximum_stacks = 10


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if not flags.get("beholder_damage_mark", false):
		return
	damage_mark_enabled = true
	mark_duration = maxf(float(values.get("mark_duration", 3.0)), 0.01)
	mark_damage_per_stack = maxf(
		float(values.get("mark_damage_per_stack", 0.02)),
		0.0
	)
	mark_maximum_stacks = maxi(
		int(values.get("mark_maximum_stacks", 10)),
		1
	)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	var aim_offset := current_target.global_position - tower.global_position
	if aim_offset.is_zero_approx():
		return true
	var spread_ratios: Array[float] = []
	var volley_context := tower.create_attack_context(
		&"brainiac_volley", null, &"tower", null, false, true
	)
	for index in tower.projectile_count:
		var spread_ratio := 0.0
		if tower.projectile_count > 1:
			spread_ratio = (
				(float(index) / float(tower.projectile_count - 1) - 0.5)
				* 2.0
			)
		spread_ratios.append(spread_ratio)
	var fan_half_angle := atan2(
		tower.volley_width_pixels * 0.5,
		maxf(tower.range_radius_pixels, 1.0)
	)
	var beams := CONVERGING_BEAMS.new() as BeholderConvergingBeams
	tower.get_tree().current_scene.add_child(beams)
	beams.setup(
		tower,
		current_target,
		tower.muzzle.global_position,
		spread_ratios,
		fan_half_angle,
		attack_damage,
		volley_context,
		damage_mark_enabled,
		mark_duration,
		mark_damage_per_stack,
		mark_maximum_stacks
	)
	return true
