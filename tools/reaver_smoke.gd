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
	tower.critical_chance = 0.0
	var component := tower.attack_component as ReaverAttackComponent
	assert(component != null)
	assert(component.combo_hit_count == 3)
	assert(is_equal_approx(component.combo_stagger, 0.10 * 0.50 / 1.15))
	assert(component.assassinate_enabled)
	assert(not component.time_bubble_enabled)
	assert(component._get_combo_hit_damage(400, 0) == 100)
	assert(component._get_combo_hit_damage(400, 1) == 100)
	assert(component._get_combo_hit_damage(400, 2) == 200)
	var starting_health: int = mob.health
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.15).timeout
	assert(
		starting_health - mob.health == 600,
		"Assassinate must deal two 100-damage hits and one guaranteed 400-damage critical finisher."
	)
	assert(tower.last_attack_roll_was_critical)

	# Time Bubble owns its activation, repeated slow refresh, visuals, and state
	# preservation when stats are reloaded.
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.time_bubble_enabled)
	assert(not component.assassinate_enabled)
	component.time_bubble_cooldown_remaining = 0.0
	component.process_attack(0.01)
	assert(component.time_bubble_active_remaining > 0.0)
	assert(mob.slow_remaining > 0.0)
	component.time_bubble_active_remaining = 2.0
	tower.load_level_stats()
	assert(is_equal_approx(component.time_bubble_active_remaining, 2.0))

	# The Psionic relic modifiers moved with the bubble rather than remaining as
	# hidden Reaver branches in BaseTower.
	fake_main.relics[&"lingering_thoughts"] = 1
	fake_main.relics[&"quick_thinking"] = 1
	tower.load_level_stats()
	assert(is_equal_approx(
		component.time_bubble_active_duration,
		3.0
			* GameStats.LINGERING_THOUGHTS_DURATION_MULTIPLIER
			* GameStats.QUICK_THINKING_DURATION_MULTIPLIER
	))
	assert(is_equal_approx(
		component.time_bubble_cooldown,
		7.0 * GameStats.QUICK_THINKING_COOLDOWN_MULTIPLIER
	))
	component.on_round_ended()
	assert(is_zero_approx(component.time_bubble_active_remaining))
	assert(is_zero_approx(component.time_bubble_cooldown_remaining))

	print("Reaver smoke test passed: combo timing, Assassinate, Time Bubble, path state, visuals, and Psionic relics.")
	get_tree().quit(0)
