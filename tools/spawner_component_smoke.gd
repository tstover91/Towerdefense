extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000
	var primary_path: Path2D
	var relics: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))

	func get_primary_enemy_path() -> Path2D:
		return primary_path


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	fake_main.primary_path = path
	var target_data := _add_mob(path, 450.0)
	var target_mob: Node2D = target_data["mob"]
	var target_follow: PathFollow2D = target_data["follow"]
	var nearby_data := _add_mob(path, 470.0)
	var nearby_mob: Node2D = nearby_data["mob"]

	var evolutions := GameStats.get_tower_evolutions(&"dronedepot")
	if not _check(evolutions.size() == 3, "Alien Factory should expose exactly three evolutions."):
		return
	if not _check(evolutions.has(&"drone_depot") and evolutions.has(&"mech_bay") and evolutions.has(&"sentry_array"), "Alien Factory evolution roster is incomplete."):
		return

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"dronedepot"
	tower.tower_level = 3
	tower.main = fake_main
	tower.position = Vector2(430.0, 40.0)
	add_child(tower)
	tower.confirm_placement()
	if not _check(tower.can_equip_item(&"patient_hunter"), "Spawner rejected Patient Hunter."):
		return
	if not _check(tower.equip_item(&"patient_hunter"), "Spawner could not equip Patient Hunter."):
		return
	var component := tower.attack_component as SpawnerAttackComponent
	if not _check(component != null, "Spawner attack component was not created."):
		return
	await get_tree().process_frame
	component.clear_units()

	# Base Factory deploys stationary technological Sentry Turrets.
	if not _check(component.spawned_unit_id == &"sentry_turret", "Base Factory did not load its Sentry Turret."):
		return
	if not _check(tower.equip_item(&"ricochet_module"), "Factory could not equip Ricochet Module."):
		return
	var ricochet_stats: Dictionary = tower.get_current_effective_stats()["unit_stats"]
	var level_1_unit_stats: Dictionary = GameStats.get_tower_xp_level_stats(&"dronedepot", 1)["unit_stats"]
	var level_20_unit_stats: Dictionary = GameStats.get_tower_xp_level_stats(&"dronedepot", 20)["unit_stats"]
	if not _check(is_equal_approx(float(level_1_unit_stats.get("aim_radius", 0.0)), 10.5), "Factory Sentry did not receive its intended starting range."):
		return
	if not _check(is_equal_approx(float(level_20_unit_stats.get("aim_radius", 0.0)), 14.7), "Factory Sentry range did not reach its intended level-20 coverage."):
		return
	if not _check(int(ricochet_stats.get("bounce_count", 0)) == 1, "Ricochet Module did not add a bounce to Factory sentries."):
		return
	if not _check(float(ricochet_stats.get("bounce_range", 0.0)) >= 5.0, "Ricochet Module did not give Factory sentries a bounce range."):
		return
	if not _check(is_equal_approx(float(ricochet_stats.get("bounce_damage_multiplier", 0.0)), 0.70), "Ricochet Module did not give Factory sentries bounce damage falloff."):
		return
	if not _check(not tower.has_bonus_tag(&"reveal") and not component.uses_drone_targeting(), "Base Factory inherited Drone-only behavior."):
		return
	component.spawn_unit()
	var sentry := component.active_units[0] as SpawnedUnit
	if not _check(sentry.movement_type == GameStats.MOVEMENT_STATIONARY and sentry.type_tags.has(&"technology"), "Factory Sentry is not a stationary technological unit."):
		return
	if not _check(sentry.bounce_count == 1 and sentry.bounce_range_pixels > 0.0, "Spawned Factory Sentry did not inherit Ricochet Module."):
		return
	sentry.critical_chance = 0.0
	sentry.patient_hunter_charge_seconds = 5.0
	sentry.begin_patient_hunter_attack()
	if not _check(sentry.roll_attack_damage() == sentry.damage * 2, "Spawned unit did not use its own full Patient Hunter charge."):
		return
	sentry.finish_patient_hunter_attack(true)
	if not _check(is_zero_approx(sentry.patient_hunter_charge_seconds), "Spawned unit did not consume Patient Hunter charge."):
		return
	if not _check(tower.unequip_item(0) == &"patient_hunter", "Could not remove Patient Hunter for item inheritance checks."):
		return
	if not _check(tower.equip_item(&"penetrator_rounds"), "Factory could not equip Penetrator Rounds."):
		return
	if not _check(tower.equip_item(&"split_chamber"), "Factory could not equip Split Chamber."):
		return
	if not _check(tower.equip_item(&"scanner_implant"), "Factory could not equip Scanner Implant."):
		return
	var inherited_stats: Dictionary = tower.get_current_effective_stats()["unit_stats"]
	if not _check(int(inherited_stats.get("pierce_count", 0)) == 1, "Factory units did not inherit Penetrator Rounds."):
		return
	if not _check(int(inherited_stats.get("damage", 0)) == roundi(float(ricochet_stats.get("damage", 0)) * 0.70), "Factory units did not inherit Split Chamber's damage penalty."):
		return
	if not _check(Array(inherited_stats.get("additional_bonus_tags", [])).has(&"reveal"), "Factory units did not inherit Scanner Implant's Reveal tag."):
		return
	if not _check(tower.item_controller.get_trigger_total(&"additional_projectiles") == 1.0, "Factory units did not expose Split Chamber's extra shot."):
		return

	# Drone Depot safely replaces Sentries with expendable mobile Drones.
	_load_path(tower, &"a")
	if not _check(component.active_units.is_empty(), "Changing unit archetypes did not clear old Sentries."):
		return
	if not _check(component.spawned_unit_id == &"drone" and component.uses_drone_targeting(), "Drone Depot did not load mobile Drones."):
		return
	if not _check(tower.has_bonus_tag(&"reveal") and not tower.has_damage_tag(&"explosive"), "Drone Depot's pre-capstone tags are wrong."):
		return
	component.spawn_unit()
	var drone := component.active_units[0] as SpawnedUnit
	if not _check(drone.die_on_damage_budget and not drone.explode_on_damage_budget and is_zero_approx(drone.recharge_duration), "Drone Depot still uses recharging or gained Final Payload early."):
		return
	drone.global_position = target_mob.global_position
	drone.damage_spent = maxi(drone.damage_budget - drone.damage, 0)
	drone.perform_attack(target_mob)
	if not _check(drone.is_queued_for_deletion(), "A depleted Drone did not destroy itself."):
		return
	await get_tree().process_frame
	component.prune_units()
	if not _check(component.active_units.is_empty(), "Destroyed Drone remained in the Depot's active roster."):
		return

	# Level 20 adds Final Payload without restoring the old recharge trip.
	var level_20_xp: float = tower.instance_progression.get_total_xp_required_for_level(20)
	tower.instance_progression.grant_xp(level_20_xp)
	_load_path(tower, &"a")
	if not _check(tower.has_damage_tag(&"explosive"), "Final Payload did not add Explosive at level 20."):
		return
	component.spawn_unit()
	drone = component.active_units[0] as SpawnedUnit
	if not _check(drone.die_on_damage_budget and drone.explode_on_damage_budget, "Final Payload behavior was not loaded."):
		return
	drone.global_position = nearby_mob.global_position
	drone.damage_spent = maxi(drone.damage_budget - drone.damage, 0)
	var nearby_health_before: int = nearby_mob.health
	drone.perform_attack(target_mob)
	if not _check(nearby_mob.health < nearby_health_before, "Final Payload did not damage nearby enemies."):
		return
	await get_tree().process_frame

	# Mech Bay uses one guard Mech tied to the Factory's range.
	_load_path(tower, &"b")
	if not _check(component.spawned_unit_id == &"mech" and component.spawn_limit == 1, "Mech Bay did not load its single heavy Mech."):
		return
	if not _check(tower.has_damage_tag(&"melee") and not tower.has_damage_tag(&"ballistic"), "Mech Bay's damage identity is wrong."):
		return
	component.spawn_unit()
	var mech := component.active_units[0] as SpawnedUnit
	if not _check(mech.movement_type == GameStats.MOVEMENT_GUARD and mech.use_parent_tower_range, "Mech did not load its Factory-range guard behavior."):
		return
	if not _check(is_equal_approx(mech.get_guard_acquisition_radius(), tower.range_radius_pixels), "Mech target acquisition is not using the Factory's range."):
		return
	var progress_before_hit := target_follow.progress
	mech.perform_attack(target_mob)
	if not _check(target_follow.progress < progress_before_hit, "Mech's heavy attack did not knock its target backward."):
		return

	# Its level-20 capstone is a separate periodic area attack, not a replacement attack.
	if not _check(mech.periodic_ground_slam and not mech.mech_area_slam, "Mech's periodic Ground Slam capstone was not loaded independently."):
		return
	mech.global_position = Vector2(460.0, 0.0)
	mech.ground_slam_remaining = 0.0
	nearby_mob.health = nearby_mob.max_health
	nearby_data["follow"].progress = 470.0
	var slam_health_before: int = nearby_mob.health
	var slam_progress_before: float = nearby_data["follow"].progress
	mech.process_periodic_ground_slam(0.0)
	if not _check(nearby_mob.health < slam_health_before and nearby_data["follow"].progress < slam_progress_before, "Periodic Ground Slam did not deal area damage and knockback."):
		return

	component.on_round_ended()
	if not _check(component.active_units.is_empty() and tower.damage_timer.is_stopped(), "Spawner wave cleanup failed."):
		return

	print("Spawner smoke test passed: Factory Sentries, expendable Drones/Final Payload, and guard Mech/Ground Slam.")
	get_tree().quit(0)


func _add_mob(path: Path2D, progress: float) -> Dictionary:
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"normal"
	follow.add_child(mob)
	mob.set_path_follow(follow, progress)
	mob.max_health = 1_000_000
	mob.health = mob.max_health
	return {"mob": mob, "follow": follow}


func _load_path(tower: BaseTower, path_id: StringName) -> void:
	tower.purchased_paths.assign([path_id])
	tower.load_base_tags()
	tower.load_level_stats()


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
