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
	var path := Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(1000.0, 0.0))
	path.curve = curve
	add_child(path)
	var follow := PathFollow2D.new()
	path.add_child(follow)
	var mob := MOB_SCENE.instantiate()
	mob.enemy_id = &"brute"
	follow.add_child(mob)
	mob.set_path_follow(follow, 500.0)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"reaver"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"b"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 0.0)
	add_child(tower)
	tower.confirm_placement()
	var reaver_levels: Array = GameStats.get_tower(&"reaver")["levels"]
	var expected_ranges := [9.0, 9.5, 10.0, 11.0]
	for level_index in reaver_levels.size():
		assert(is_equal_approx(
			float(reaver_levels[level_index]["range"]),
			expected_ranges[level_index]
		))
	assert(is_equal_approx(
		tower.range_radius_pixels,
		11.0 * BaseTower.RANGE_PIXELS_PER_UNIT
	))
	# Exercise the combo directly. Automatic acquisition is covered by the
	# targeting smoke and made this test dependent on physics callback ordering.
	tower.attack_on_cooldown = true
	tower.damage_timer.stop()
	tower.critical_chance = 0.0
	var component := tower.attack_component as ReaverAttackComponent
	if not _check(component != null, "Reaver attack component was not created."):
		return
	if not _check(component.combo_hit_count == 3, "Expected a three-hit combo."):
		return
	if not _check(
		is_equal_approx(component.combo_stagger, 0.10 * 0.50 / 1.15),
		"Combo stagger did not receive the expected attack-speed scaling."
	):
		return
	if not _check(component.assassinate_enabled, "Assassinate was not enabled."):
		return
	if not _check(not component.time_bubble_enabled, "Wrong Reaver path enabled."):
		return
	if not _check(component._get_combo_hit_damage(400, 0) == 100, "Wrong first-hit damage."):
		return
	if not _check(component._get_combo_hit_damage(400, 1) == 100, "Wrong second-hit damage."):
		return
	if not _check(component._get_combo_hit_damage(400, 2) == 200, "Wrong finisher base damage."):
		return
	var starting_health: int = mob.health
	component.execute_raw_attack(mob, 400)
	var combo_completed := await _wait_for_health_loss(mob, starting_health, 600)
	if not _check(
		combo_completed and starting_health - mob.health == 600,
		"Assassinate must deal two 100-damage hits and one guaranteed 400-damage critical finisher."
	):
		return
	if not _check(tower.last_attack_roll_was_critical, "Finisher was not marked critical."):
		return

	# Time Bubble owns its activation, repeated slow refresh, visuals, and state
	# preservation when stats are reloaded.
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	if not _check(component.time_bubble_enabled, "Time Bubble was not enabled."):
		return
	if not _check(not component.assassinate_enabled, "Assassinate remained enabled."):
		return
	component.time_bubble_cooldown_remaining = 0.0
	component.process_attack(0.01)
	if not _check(component.time_bubble_active_remaining > 0.0, "Time Bubble did not activate."):
		return
	if not _check(mob.slow_remaining > 0.0, "Time Bubble did not slow its target."):
		return
	component.time_bubble_active_remaining = 2.0
	tower.load_level_stats()
	if not _check(
		is_equal_approx(component.time_bubble_active_remaining, 2.0),
		"Stat reload did not preserve active Time Bubble duration."
	):
		return

	# The Psionic relic modifiers moved with the bubble rather than remaining as
	# hidden Reaver branches in BaseTower.
	fake_main.relics[&"lingering_thoughts"] = 1
	fake_main.relics[&"quick_thinking"] = 1
	tower.load_level_stats()
	if not _check(
		is_equal_approx(
			component.time_bubble_active_duration,
			3.0
				* GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER
				* GameStats.QUICK_THINKING_DURATION_MULTIPLIER
		),
		"Psionic relics produced the wrong Time Bubble duration."
	):
		return
	if not _check(
		is_equal_approx(
			component.time_bubble_cooldown,
			7.0 * GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER
		),
		"Psionic relics produced the wrong Time Bubble cooldown."
	):
		return
	component.on_round_ended()
	if not _check(
		is_zero_approx(component.time_bubble_active_remaining),
		"Time Bubble remained active after the round ended."
	):
		return
	if not _check(
		is_zero_approx(component.time_bubble_cooldown_remaining),
		"Time Bubble cooldown remained after the round ended."
	):
		return

	print("Reaver smoke test passed: combo timing, Assassinate, Time Bubble, path state, visuals, and Psionic relics.")
	get_tree().quit(0)


func _wait_for_health_loss(
	mob: Node,
	starting_health: int,
	expected_loss: int
) -> bool:
	var deadline := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < deadline:
		if starting_health - int(mob.health) >= expected_loss:
			return true
		await get_tree().process_frame
	return false


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
