extends Node

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

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0


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
	tower.tower_id = &"invader"
	tower.main = fake_main
	tower.position = Vector2(500.0, 0.0)
	add_child(tower)
	tower.confirm_placement()
	var starting_health: int = mob.health
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	assert(tower.mobs_in_range.has(mob))
	assert(mob.health < starting_health, "Invader must fire immediately on first target acquisition.")
	assert(tower.attack_on_cooldown)
	assert(not tower.damage_timer.is_stopped())
	var health_after_first_attack: int = mob.health

	# Losing and reacquiring the target must not reset or bypass the interval.
	tower._on_body_exited(mob)
	tower._on_body_entered(mob)
	await get_tree().process_frame
	assert(mob.health == health_after_first_attack, "Reacquisition during cooldown must not grant another attack.")
	tower._apply_damage()
	assert(mob.health == health_after_first_attack, "Direct attack requests must respect the active cooldown.")

	# Simulate the real timeout with no target, then reacquire while ready.
	tower._on_body_exited(mob)
	tower._on_attack_timer_timeout()
	assert(not tower.attack_on_cooldown)
	assert(tower.damage_timer.is_stopped())
	tower._on_body_entered(mob)
	await get_tree().process_frame
	assert(mob.health < health_after_first_attack, "A ready tower must fire immediately when a later target enters.")
	assert(tower.attack_on_cooldown)

	print("Target acquisition smoke test passed: immediate ready attacks and strict cooldown preservation.")
	get_tree().quit(0)
