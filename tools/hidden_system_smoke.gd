extends SceneTree

const MOB_SCENE = preload("res://mob.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const RelicEffects = preload("res://relic_combat.gd")


class RelicOwner extends Node:
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)

	var round_active := true
	var money := 999999
	var relics: Dictionary = {}

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var relic_owner := RelicOwner.new()
	relic_owner.relics[&"conductive"] = 1
	root.add_child(relic_owner)

	var gauss := TOWER_SCENE.instantiate()
	gauss.main = relic_owner
	gauss.tower_id = &"gauss_repeater"
	root.add_child(gauss)
	gauss.global_position = Vector2.ZERO

	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"hidden"
	root.add_child(mob)
	mob.global_position = Vector2(100.0, 0.0)

	gauss._select_directional_target()
	assert(gauss.target == null)
	gauss.target = mob
	var node_count_before_hidden_attack := root.get_child_count()
	gauss.attack(mob)
	assert(root.get_child_count() == node_count_before_hidden_attack)

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

	var armored := MOB_SCENE.instantiate()
	armored.enemy_id = &"armored"
	root.add_child(armored)
	assert(gauss.damage_type == &"electric")
	var gauss_context: AttackContext = gauss.create_attack_context(&"projectile")
	assert(int(gauss_context.metadata.get("conductive", 0)) == 1)
	assert(armored.apply_damage_from_tower(
		20, gauss.damage_type, false, gauss.tower_id, gauss_context
	) == 26)
	armored.health = armored.max_health
	assert(armored.apply_damage_from_tower(
		20, gauss.damage_type, true, gauss.tower_id, gauss_context
	) == 26)

	var depot := TOWER_SCENE.instantiate()
	depot.main = relic_owner
	depot.tower_id = &"dronedepot"
	depot.tower_level = 3
	depot.purchased_paths.append(&"b")
	root.add_child(depot)
	var payload_stats: Dictionary = depot.get_effective_stats_for_level(3)["unit_stats"]
	assert(int(payload_stats["damage_budget"]) == 6000)
	assert(
		float(payload_stats["damage_budget"])
		/ (float(payload_stats["damage"]) / float(payload_stats["attack_interval"]))
		>= 3.8
	)
	depot.purchased_paths.append(&"a")
	depot.load_base_tags()
	var dual_payload_stats: Dictionary = depot.get_effective_stats_for_level(3)["unit_stats"]
	assert(int(dual_payload_stats["damage_budget"]) == 9000)
	assert(int(dual_payload_stats["damage"]) == 425)

	print("Hidden system smoke checks passed.")
	quit(0)
