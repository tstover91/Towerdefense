class_name FishermanAttackComponent
extends TowerAttackComponent

const GameStats = preload("res://stat_database.gd")
const FISHERMAN_HOOK_EFFECT = preload("res://fisherman_hook_effect.gd")

var hook_tick_count := 4
var hook_duration := 1.2
var hook_pull_speed := 80.0
var hook_pull_immunity := 2.5
var electric_line_enabled := false
var harpoon_enabled := false
var harpoon_target_count := 3
var harpoon_line_half_width := 5.0
var harpoon_pull_speed_multiplier := 1.45


func load_level_stats(stats: Dictionary) -> void:
	hook_tick_count = maxi(int(stats.get("hook_tick_count", 4)), 1)
	hook_duration = maxf(float(stats.get("hook_duration", 1.2)), 0.01)
	hook_pull_speed = maxf(float(stats.get("hook_pull_speed", 80.0)), 0.0)
	hook_pull_immunity = maxf(float(stats.get("hook_pull_immunity", 2.5)), 0.0)


func reset_path_behaviors() -> void:
	electric_line_enabled = false
	harpoon_enabled = false
	harpoon_target_count = 3
	harpoon_line_half_width = 5.0
	harpoon_pull_speed_multiplier = 1.45


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("fisherman_electric_line", false):
		electric_line_enabled = true
	if not flags.get("fisherman_harpoon", false):
		return
	harpoon_enabled = true
	harpoon_target_count = maxi(
		int(values.get("harpoon_target_count", 3)),
		1
	)
	harpoon_line_half_width = maxf(
		float(values.get("harpoon_line_half_width", 5.0)),
		0.0
	)
	harpoon_pull_speed_multiplier = maxf(
		float(values.get("harpoon_pull_speed_multiplier", 1.45)),
		0.0
	)


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	var cast_targets: Array[Node2D] = [current_target]
	if harpoon_enabled:
		var cast_direction := current_target.global_position - tower.muzzle.global_position
		if not cast_direction.is_zero_approx():
			var cast_end := (
				tower.muzzle.global_position
				+ cast_direction.normalized() * tower.range_radius_pixels
			)
			var pierced_targets := tower.get_targets_along_line(
				tower.muzzle.global_position,
				cast_end,
				current_target,
				harpoon_line_half_width
			)
			pierced_targets.resize(mini(
				pierced_targets.size(),
				harpoon_target_count - 1
			))
			cast_targets.append_array(pierced_targets)

	var cast_context := tower.create_attack_context(
		&"fisherman_cast", tower, &"tower", null, false, true
	)
	for hit_index in cast_targets.size():
		var hooked_target := cast_targets[hit_index]
		if not tower.is_valid_target(hooked_target):
			continue
		var hooked_damage := attack_damage
		if harpoon_enabled:
			hooked_damage = GameStats.get_piercing_damage(
				attack_damage,
				hit_index,
				tower.pierce_loses_no_power
			)
		var hook_context := tower.create_attack_context(
			&"fisherman_hook",
			tower,
			&"tower",
			cast_context,
			hit_index > 0
		)
		tower.apply_control_effects(hooked_target, hook_context)
		var hook_effect := FISHERMAN_HOOK_EFFECT.new()
		tower.get_tree().current_scene.add_child(hook_effect)
		hook_effect.setup(
			tower,
			hooked_target,
			hooked_damage,
			tower.damage_type,
			harpoon_enabled,
			hook_tick_count,
			hook_duration,
			hook_pull_speed * (
				harpoon_pull_speed_multiplier if harpoon_enabled else 1.0
			),
			hook_pull_immunity,
			hit_index == 0,
			electric_line_enabled,
			harpoon_enabled,
			hook_context
		)
	return true
