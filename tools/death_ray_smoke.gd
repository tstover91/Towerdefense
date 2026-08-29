extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics: Dictionary = {}

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
	assert(brainiac.equip_item(&"death_ray"))
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
		brainiac.base_beam_hit_half_width_pixels
			* GameStats.DEATH_RAY_WIDTH_MULTIPLIER
	))
	assert(brainiac.roll_attack_damage() == roundi(
		float(brainiac.damage) * GameStats.DEATH_RAY_DAMAGE_MULTIPLIER
	))

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

	print("Death Ray smoke test passed: equipped overcharge, configured damage/width bonuses, infinite Pierce, and native tracking speed.")
	get_tree().quit(0)
