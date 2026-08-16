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

	var mobs: Array[Node2D] = []
	for progress in [480.0, 500.0, 520.0, 540.0]:
		var follow := PathFollow2D.new()
		path.add_child(follow)
		var mob := MOB_SCENE.instantiate()
		mob.enemy_id = &"brute"
		follow.add_child(mob)
		mob.set_path_follow(follow, progress)
		mobs.append(mob)

	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"energycore"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"b"])
	tower.main = fake_main
	tower.position = Vector2(500.0, 0.0)
	add_child(tower)
	tower.confirm_placement()
	var component := tower.attack_component as EnergyCoreAttackComponent
	assert(component != null)
	assert(component.branching_current_enabled)
	assert(component.branch_additional_targets == 2)
	assert(not component.shockwave_enabled)
	var starting_health: Array[int] = []
	for mob in mobs:
		starting_health.append(int(mob.health))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	for mob_index in mobs.size():
		assert(
			mobs[mob_index].health < starting_health[mob_index],
			"Three primary bolts plus nearby branches must damage the clustered enemies."
		)
	assert(component.branch_visual_segments.size() >= 3)
	assert(component.branch_visual_remaining > 0.0)

	# Reconfigure the same component to ensure path state resets cleanly and the
	# autonomous shockwave still uses the normal tower damage/context pipeline.
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.shockwave_enabled)
	assert(not component.branching_current_enabled)
	assert(is_equal_approx(component.shockwave_cooldown, 5.0))
	assert(is_equal_approx(component.shockwave_remaining, 5.0))
	var health_before_shockwave: Array[int] = []
	for mob in mobs:
		health_before_shockwave.append(int(mob.health))
	component.shockwave_remaining = 0.0
	component.process_attack(0.0)
	for mob_index in mobs.size():
		assert(
			mobs[mob_index].health < health_before_shockwave[mob_index],
			"Shockwave must damage every enemy in Energy Core range."
		)
	assert(component.shockwave_visual_remaining > 0.0)
	assert(is_equal_approx(
		component.shockwave_remaining,
		component.shockwave_cooldown
	))

	print("Energy Core smoke test passed: multi-primary strikes, branches, shockwave, path reset, and visuals.")
	get_tree().quit(0)
