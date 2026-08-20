extends Node

const MOB_SCENE = preload("res://mob.tscn")


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var shielded := spawn_test_mob(&"shielded", Vector2.ZERO)
	var shielded_health: int = shielded.health
	assert(shielded.ablative_shield_points == 5)
	for hit_index in 5:
		var damage_type: StringName = &"beam" if hit_index % 2 == 0 else &"explosive"
		assert(shielded.apply_damage(10_000, damage_type) == 0)
		assert(shielded.health == shielded_health)
		assert(shielded.ablative_shield_points == 4 - hit_index)
	assert(shielded.apply_damage(10, &"ballistic") == 10)
	assert(shielded.health == shielded_health - 10)

	var projector := spawn_test_mob(&"shield_projector", Vector2(300.0, 0.0))
	var protected := spawn_test_mob(&"normal", Vector2(350.0, 0.0))
	var outside := spawn_test_mob(&"normal", Vector2(500.0, 0.0))
	var protected_health: int = protected.health
	var outside_health: int = outside.health
	assert(projector.ablative_shield_points == 12)
	assert(protected.apply_damage(10_000, &"beam") == 0)
	assert(protected.health == protected_health)
	assert(projector.ablative_shield_points == 11)
	assert(projector.apply_damage(10_000, &"explosive") == 0)
	assert(projector.ablative_shield_points == 10)
	assert(outside.apply_damage(10, &"ballistic") == 10)
	assert(outside.health == outside_health - 10)
	assert(projector.ablative_shield_points == 10)

	# All remaining shared points are consumed by hits against the protected ally.
	for _hit_index in 10:
		assert(protected.apply_damage(10_000, &"electric") == 0)
	assert(projector.ablative_shield_points == 0)
	assert(protected.health == protected_health)
	assert(protected.apply_damage(10, &"beam") == 10)
	assert(protected.health == protected_health - 10)

	print("Shield enemy smoke test passed: self shields, shared projector pools, radius limits, and zero overflow.")
	get_tree().quit(0)


func spawn_test_mob(enemy_id: StringName, world_position: Vector2) -> Node2D:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = enemy_id
	add_child(mob)
	mob.global_position = world_position
	return mob
