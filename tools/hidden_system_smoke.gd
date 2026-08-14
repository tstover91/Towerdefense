extends SceneTree

const MOB_SCENE = preload("res://mob.tscn")
const RelicEffects = preload("res://relic_combat.gd")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"hidden"
	root.add_child(mob)

	var starting_health: int = mob.health
	var direct_context := AttackContext.legacy(&"invader", &"direct")
	assert(mob.apply_damage_from_tower(
		10, &"ballistic", false, &"invader", direct_context
	) == 0)
	assert(mob.health == starting_health)

	var reveal_context := AttackContext.legacy(&"invader", &"direct")
	reveal_context.metadata["source_can_reveal"] = true
	assert(mob.apply_damage_from_tower(
		10, &"ballistic", false, &"invader", reveal_context
	) > 0)
	assert(mob.health < starting_health)

	mob.health = starting_health
	var area_context := RelicEffects.prepare_explosion_context(
		AttackContext.legacy(&"slinger", &"explosion"),
		self,
		mob.global_position,
		32.0
	)
	assert(RelicEffects.is_valid_explosion_target(mob, area_context))
	assert(mob.apply_damage_from_tower(
		10, &"explosive", false, &"slinger", area_context
	) > 0)
	assert(mob.health < starting_health)

	print("Hidden system smoke checks passed.")
	quit(0)
