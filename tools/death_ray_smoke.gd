extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics := {&"death_ray": 1}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var brainiac := TOWER_SCENE.instantiate() as BaseTower
	brainiac.tower_id = &"brainiac"
	brainiac.main = fake_main
	add_child(brainiac)
	brainiac.confirm_placement()
	brainiac.process_death_ray_overcharge(0.0)
	assert(brainiac.death_ray_overcharge_enabled)
	assert(brainiac.death_ray_overcharge_active)
	assert(brainiac.infinite_pierce)
	assert(is_equal_approx(
		rad_to_deg(brainiac.beam_turn_speed_radians),
		480.0
	))
	assert(is_equal_approx(
		brainiac.beam_hit_half_width_pixels,
		brainiac.base_beam_hit_half_width_pixels * 2.0
	))
	assert(brainiac.roll_attack_damage() == brainiac.damage * 2)

	brainiac.process_death_ray_overcharge(2.01)
	assert(not brainiac.death_ray_overcharge_active)
	assert(not brainiac.infinite_pierce)
	assert(is_equal_approx(
		brainiac.beam_hit_half_width_pixels,
		brainiac.base_beam_hit_half_width_pixels
	))
	assert(brainiac.roll_attack_damage() == brainiac.damage)
	brainiac.process_death_ray_overcharge(3.99)
	assert(brainiac.death_ray_overcharge_active)
	assert(brainiac.infinite_pierce)

	var depot := TOWER_SCENE.instantiate() as BaseTower
	depot.tower_id = &"dronedepot"
	depot.tower_level = 3
	depot.purchased_paths.assign([&"a"])
	depot.main = fake_main
	add_child(depot)
	depot.confirm_placement()
	depot.process_death_ray_overcharge(0.0)
	var unit_stats: Dictionary = depot.get_effective_stats_for_level(3)["unit_stats"]
	assert(bool(unit_stats["death_ray_overcharge"]))
	assert(not bool(unit_stats.get("infinite_pierce", false)))

	var drone := SPAWNED_UNIT_SCENE.instantiate() as SpawnedUnit
	add_child(drone)
	drone.setup(&"drone", unit_stats, depot, null)
	assert(drone.death_ray_overcharge_active)
	assert(drone.infinite_pierce)
	assert(is_equal_approx(
		drone.get_current_beam_half_width(),
		SpawnedUnit.BEAM_HIT_HALF_WIDTH * 2.0
	))
	assert(drone.roll_attack_damage() == drone.damage * 2)

	depot.death_ray_cycle_elapsed = 3.0
	depot.refresh_death_ray_overcharge_state()
	var inactive_drone := SPAWNED_UNIT_SCENE.instantiate() as SpawnedUnit
	add_child(inactive_drone)
	inactive_drone.setup(&"drone", unit_stats, depot, null)
	assert(not inactive_drone.death_ray_overcharge_active)
	assert(not inactive_drone.infinite_pierce)
	assert(inactive_drone.roll_attack_damage() == inactive_drone.damage)

	print("Death Ray smoke test passed: synchronized 2-second overcharge, double damage and width, infinite Pierce, and native tracking speed.")
	get_tree().quit(0)
