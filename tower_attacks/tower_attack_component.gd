class_name TowerAttackComponent
extends Node

## Extension point for tower-specific attack execution and cooldown behavior.
## BaseTower continues to own targeting, stats shared by every tower, and damage
## helpers. Components own only mechanics that are unique to one attack family.

var tower: BaseTower


func setup(owner_tower: BaseTower) -> void:
	tower = owner_tower


func load_level_stats(_stats: Dictionary) -> void:
	pass


func reset_path_behaviors() -> void:
	pass


func apply_path_behavior(_flags: Dictionary, _values: Dictionary) -> void:
	pass


func finalize_path_behaviors() -> void:
	pass


func process_attack(_delta: float) -> void:
	pass


func process_pre_targeting(_delta: float) -> void:
	pass


func uses_directional_aim() -> bool:
	return false


func uses_manual_ground_targeting() -> bool:
	return false


func uses_continuous_beam() -> bool:
	return false


func locks_aim_during_attack() -> bool:
	return false


func get_continuous_beam_origin(default_origin: Vector2) -> Vector2:
	return default_origin


func uses_standard_targeting() -> bool:
	return true


func uses_shared_attack_scheduler() -> bool:
	return true


func uses_standard_spawner_system() -> bool:
	return false


func uses_drone_targeting() -> bool:
	return false


func shows_target_mode_control() -> bool:
	return true


func draw_attack_visuals() -> void:
	pass


func on_round_started() -> void:
	pass


func on_round_ended() -> void:
	pass


func on_placement_confirmed() -> void:
	pass


func on_aim_direction_changed() -> void:
	pass


func on_target_updated() -> void:
	pass


func on_enemy_killed(_enemy: Node, _attack_context: AttackContext) -> void:
	pass


func modify_base_attack_damage(_current_target: Node2D, base_damage: int) -> int:
	return base_damage


func modify_attack_interval(base_interval: float) -> float:
	return base_interval


func get_continuous_beam_damage(base_damage: int) -> int:
	return base_damage


func uses_tracking_cone() -> bool:
	return false


func uses_finite_directional_range() -> bool:
	return false


func get_tracking_cone_degrees() -> float:
	return 0.0


func is_target_in_tracking_cone(_candidate: Variant) -> bool:
	return true


func select_directional_target() -> Node2D:
	return null


func begin_manual_targeting() -> void:
	pass


func cancel_manual_targeting() -> void:
	pass


func confirm_manual_target_position(_world_position: Vector2) -> bool:
	return false


func is_manual_targeting_active() -> bool:
	return false


func has_manual_target_position() -> bool:
	return false


func get_manual_target_position() -> Vector2:
	return Vector2.ZERO


func restore_manual_target_position(_world_position: Vector2) -> void:
	pass


func is_valid_manual_target_position(_world_position: Vector2) -> bool:
	return false


func has_manual_attack_opportunity() -> bool:
	return false


func execute_manual_attack() -> void:
	pass


func projectile_contact_explosions_enabled() -> bool:
	return false


func projectile_contact_explosion_radius() -> float:
	return 0.0


func projectile_contact_explosion_damage_multiplier() -> float:
	return 1.0


func spawn_unit() -> void:
	pass


func schedule_unit_replacement(_delay: float) -> void:
	pass


func get_drone_target_mode() -> int:
	return 0


func set_drone_target_mode(_mode: int) -> void:
	pass


func get_drone_command_targets() -> Array[Node2D]:
	return []


func execute_raw_attack(_current_target: Node2D, _base_damage: int) -> bool:
	return false


func execute_attack(_current_target: Node2D, _attack_damage: int) -> bool:
	return false
