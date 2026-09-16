class_name LongshotAttackComponent
extends TowerAttackComponent

var kill_chain_enabled := false
var kill_reload_remaining_multiplier := 0.50
var critical_kill_reload_remaining_multiplier := 0.10
var radiation_chain_enabled := false
var radiation_chain_base_damage_multiplier := 0.08
var radiation_chain_damage_per_kill := 0.02
var radiation_chain_maximum_bonus := 0.08
var radiation_chain_kills := 0
var kill_registered_this_attack := false


func reset_path_behaviors() -> void:
	kill_chain_enabled = false
	kill_reload_remaining_multiplier = 0.50
	critical_kill_reload_remaining_multiplier = 0.10
	radiation_chain_enabled = false
	radiation_chain_base_damage_multiplier = 0.08
	radiation_chain_damage_per_kill = 0.02
	radiation_chain_maximum_bonus = 0.08


func apply_path_behavior(flags: Dictionary, values: Dictionary) -> void:
	if flags.get("longshot_radiation_chain", false):
		radiation_chain_enabled = true
		radiation_chain_base_damage_multiplier = maxf(float(values.get("radiation_chain_base_damage_multiplier", 0.08)), 0.0)
		radiation_chain_damage_per_kill = maxf(float(values.get("radiation_chain_damage_per_kill", 0.02)), 0.0)
		radiation_chain_maximum_bonus = maxf(float(values.get("radiation_chain_maximum_bonus", 0.08)), 0.0)
	if flags.get("longshot_kill_chain", false):
		kill_chain_enabled = true
		kill_reload_remaining_multiplier = clampf(
			float(values.get("kill_reload_remaining_multiplier", 0.50)),
			0.0,
			1.0
		)
		critical_kill_reload_remaining_multiplier = clampf(
			float(values.get(
				"critical_kill_reload_remaining_multiplier", 0.10
			)),
			0.0,
			kill_reload_remaining_multiplier
		)


func on_enemy_killed(_enemy: Node, attack_context: AttackContext) -> void:
	if not kill_chain_enabled:
		return
	kill_registered_this_attack = true
	radiation_chain_kills += 1
	var was_critical := (
		attack_context != null
		and bool(attack_context.metadata.get("was_critical", false))
	)
	var remaining_multiplier := (
		critical_kill_reload_remaining_multiplier
		if was_critical
		else kill_reload_remaining_multiplier
	)
	# Hitscan damage resolves before the shared attack cycle starts its timer.
	# Deferring makes both hitscan and projectile kills reduce the active reload.
	call_deferred("_apply_kill_chain_reload_reduction", remaining_multiplier)


func on_round_started() -> void:
	radiation_chain_kills = 0
	kill_registered_this_attack = false


func on_round_ended() -> void:
	radiation_chain_kills = 0
	kill_registered_this_attack = false


func execute_attack(current_target: Node2D, attack_damage: int) -> bool:
	if not radiation_chain_enabled or not tower.is_valid_target(current_target):
		return false
	kill_registered_this_attack = false
	var bonus_multiplier := minf(
		float(radiation_chain_kills) * radiation_chain_damage_per_kill,
		radiation_chain_maximum_bonus
	)
	var context := tower.create_attack_context(&"kill_chain_shot")
	if current_target.has_method("apply_radiation"):
		current_target.apply_radiation(
			1,
			maxi(roundi(float(attack_damage) * (
				radiation_chain_base_damage_multiplier + bonus_multiplier
			)), 1),
			context,
			1.0
		)
	tower.apply_hitscan_damage(current_target, attack_damage, context)
	if not kill_registered_this_attack:
		radiation_chain_kills = 0
	return true


func _apply_kill_chain_reload_reduction(remaining_multiplier: float) -> void:
	if not is_instance_valid(tower) or not tower.is_inside_tree():
		return
	if not tower.attack_on_cooldown or tower.damage_timer.is_stopped():
		tower.request_attack_if_ready()
		return
	var reduced_reload := maxf(
		tower.damage_timer.time_left * clampf(remaining_multiplier, 0.0, 1.0),
		0.01
	)
	tower.damage_timer.start(reduced_reload)
