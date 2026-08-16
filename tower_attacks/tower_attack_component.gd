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


func execute_attack(_current_target: Node2D, _attack_damage: int) -> bool:
	return false
