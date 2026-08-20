extends SceneTree

const MOB_SCENE = preload("res://mob.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const GameStats = preload("res://stat_database.gd")
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
	relic_owner.relics[&"overcharged_capacitor"] = 2
	relic_owner.relics[&"static_discharge"] = 1
	relic_owner.relics[&"chain_lightning"] = 1
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
	assert(int(gauss_context.metadata.get("overcharged_capacitor", 0)) == 2)
	assert(int(gauss_context.metadata.get("static_discharge", 0)) == 1)
	assert(int(gauss_context.metadata.get("chain_lightning", 0)) == 1)
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
	root.add_child(depot)
	depot.is_placed = true
	for level in 4:
		var base_unit_stats: Dictionary = depot.get_effective_stats_for_level(level)["unit_stats"]
		var firing_duration := (
			float(base_unit_stats["damage_budget"])
			/ (float(base_unit_stats["damage"]) / float(base_unit_stats["attack_interval"]))
		)
		assert(firing_duration >= 4.0 and firing_duration <= 5.0)

	depot.purchased_paths.append(&"b")
	depot.load_base_tags()
	var payload_level_stats: Dictionary = depot.get_effective_stats_for_level(3)
	var payload_stats: Dictionary = payload_level_stats["unit_stats"]
	assert(int(payload_stats["damage_budget"]) == 7000)
	assert(is_equal_approx(float(payload_stats["budget_replacement_delay"]), 0.5))
	assert(is_equal_approx(float(payload_level_stats["spawn_interval"]), 0.5))
	var payload_duration := (
		float(payload_stats["damage_budget"])
		/ (float(payload_stats["damage"]) / float(payload_stats["attack_interval"]))
	)
	assert(payload_duration >= 4.0 and payload_duration <= 5.0)

	depot.purchased_paths.append(&"a")
	depot.load_base_tags()
	var dual_payload_stats: Dictionary = depot.get_effective_stats_for_level(3)["unit_stats"]
	assert(int(dual_payload_stats["damage_budget"]) == 8750)
	assert(int(dual_payload_stats["damage"]) == 425)
	var dual_payload_duration := (
		float(dual_payload_stats["damage_budget"])
		/ (float(dual_payload_stats["damage"]) / float(dual_payload_stats["attack_interval"]))
	)
	assert(dual_payload_duration >= 4.0 and dual_payload_duration <= 5.0)

	var drone := SPAWNED_UNIT_SCENE.instantiate()
	root.add_child(drone)
	drone.setup(&"drone", payload_stats, depot, null)
	assert(drone.movement_type == GameStats.MOVEMENT_DRONE)
	assert(not drone.has_bonus_tag(&"reveal"))
	assert(is_equal_approx(
		drone.get_effective_attack_radius(),
		2.5 * 12.9
	))
	mob.global_position = Vector2(100.0, 0.0)
	if not depot.mobs_in_range.has(mob):
		depot.mobs_in_range.append(mob)
	assert(drone.is_valid_target(mob))
	assert(drone.can_source_reveal())
	var drone_context: AttackContext = drone.create_attack_context(&"hitscan")
	assert(bool(drone_context.metadata["source_can_reveal"]))
	mob.global_position = Vector2(depot.get_drone_command_radius_pixels() + 1.0, 0.0)
	assert(not drone.is_valid_target(mob))

	armored.global_position = Vector2(100.0, 0.0)
	if not depot.mobs_in_range.has(armored):
		depot.mobs_in_range.append(armored)
	depot.drone_target_mode = depot.DroneTargetMode.FOCUS_MAX_HEALTH
	drone.target = armored
	drone.target_refresh_remaining = 1.0
	drone.global_position = Vector2.ZERO
	var armored_health_before_approach: int = armored.health
	drone.process_drone(0.1)
	assert(drone.global_position.x > 0.0)
	assert(armored.health == armored_health_before_approach)
	drone.global_position = armored.global_position - Vector2(20.0, 0.0)
	drone.attack_cooldown = 0.0
	drone.process_drone(0.01)
	assert(armored.health < armored_health_before_approach)

	print("Hidden system smoke checks passed.")
	quit(0)
