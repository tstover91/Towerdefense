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


class FakeMob:
	extends Node2D
	var traits: Array[StringName] = []
	var finished := false
	var damage_received := 0

	func get_projectile_hit_radius() -> float:
		return 12.0

	func apply_damage_from_tower(
		amount: int,
		_damage_type: StringName,
		_ignores_armor: bool,
		_source_tower_id: StringName,
		_attack_context: AttackContext = null
	) -> int:
		damage_received += amount
		return amount


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
	tower.tower_id = &"brainiac"
	tower.tower_level = 3
	tower.main = fake_main
	tower.position = Vector2(500.0, 50.0)
	add_child(tower)
	tower.confirm_placement()
	# Keep the shared acquisition scheduler from launching independently; this
	# test invokes the component once so projectile geometry is deterministic.
	tower.attack_on_cooldown = true
	var component := tower.attack_component as BrainiacAttackComponent
	assert(component != null)
	assert(tower.has_damage_tag(&"beam"))
	assert(not tower.has_damage_tag(&"ballistic"))
	assert(tower.get_primary_damage_type() == &"beam")
	assert(tower.delivery_type == GameStats.DELIVERY_HITSCAN)
	assert(tower.has_bonus_tag(&"reveal"))
	assert(GameStats.get_tower(&"brainiac")["paths"].has(&"b"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	mob.max_health = 100_000
	mob.health = 100_000
	mob.health_bar.max_value = mob.max_health
	mob.health_bar.value = mob.health
	component.execute_attack(mob, tower.damage)

	var projectiles := get_tree().get_nodes_in_group("tower_projectiles")
	assert(projectiles.is_empty(), "Beholder must no longer launch projectiles.")
	var active_beams := get_tree().get_nodes_in_group("beholder_converging_beams")
	assert(active_beams.size() == 1)
	var beams := active_beams[0] as BeholderConvergingBeams
	assert(beams.beam_origins.size() == 5)
	var distinct_launch_positions: Dictionary = {}
	for launch_position in beams.beam_origins:
		distinct_launch_positions[Vector2(
			snappedf(launch_position.x, 0.01),
			snappedf(launch_position.y, 0.01)
		)] = true
	assert(distinct_launch_positions.size() == 5, "Beholder beams must fan out at launch.")
	for endpoint in beams.beam_endpoints:
		assert(endpoint.is_equal_approx(mob.global_position))
	var blocker := FakeMob.new()
	add_child(blocker)
	blocker.add_to_group("mobs")
	blocker.global_position = beams.beam_origins[2].lerp(
		mob.global_position,
		0.5
	)
	beams._refresh_beam_endpoints()
	var center_hits := beams._get_beam_targets(
		tower,
		beams.beam_origins[2],
		mob.global_position
	)
	assert(center_hits.size() == 1)
	assert(center_hits[0] == blocker, "An intervening enemy must intercept the beam.")
	assert(beams.beam_endpoints[2].is_equal_approx(blocker.global_position))
	tower.pierce_count = 1
	center_hits = beams._get_beam_targets(
		tower,
		beams.beam_origins[2],
		mob.global_position
	)
	assert(center_hits.size() == 2)
	assert(center_hits[0] == blocker and center_hits[1] == mob)
	tower.pierce_count = 0
	var budgeted_damage := 0
	for tick in BeholderConvergingBeams.TICK_COUNT:
		budgeted_damage += BeholderConvergingBeams.get_budgeted_tick_damage(
			tower.damage,
			tick,
			BeholderConvergingBeams.TICK_COUNT
		)
	assert(budgeted_damage == tower.damage, "Beam ticks must preserve each former bolt's total damage.")
	beams._process(BeholderConvergingBeams.BEAM_DURATION)
	assert(beams.tick_index == BeholderConvergingBeams.TICK_COUNT)

	# Piercing Volley lets each beam continue into one additional intersected enemy.
	await get_tree().process_frame
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(tower.pierce_count == 1)
	assert(tower.has_damage_tag(&"beam"))
	assert(not tower.has_bonus_tag(&"psionic"))
	component.execute_attack(mob, tower.damage)
	active_beams = get_tree().get_nodes_in_group("beholder_converging_beams")
	assert(active_beams.size() == 1)
	beams = active_beams[0] as BeholderConvergingBeams
	assert(beams.beam_origins.size() == 5)
	beams.queue_free()
	await get_tree().process_frame

	# Withering Gaze marks each touched enemy once per tick, not once per beam.
	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(tower.pierce_count == 0)
	assert(component.damage_mark_enabled)
	assert(is_equal_approx(component.mark_damage_per_stack, 0.02))
	assert(component.mark_maximum_stacks == 10)
	component.execute_attack(mob, tower.damage)
	active_beams = get_tree().get_nodes_in_group("beholder_converging_beams")
	assert(active_beams.size() == 1)
	beams = active_beams[0] as BeholderConvergingBeams
	assert(mob.beholder_mark_stacks == 1)
	beams._process(BeholderConvergingBeams.BEAM_DURATION)
	assert(mob.beholder_mark_stacks == 10)
	assert(is_equal_approx(mob.get_beholder_mark_damage_multiplier(), 1.20))
	var health_before_marked_hit: int = mob.health
	mob.apply_damage(100, &"ballistic")
	assert(health_before_marked_hit - mob.health == 120)
	mob._process_beholder_damage_mark(component.mark_duration)
	assert(mob.beholder_mark_stacks == 0)
	assert(is_equal_approx(mob.get_beholder_mark_damage_multiplier(), 1.0))

	print("Beholder smoke test passed: converging beams, interception, Piercing Volley, base Reveal, and Withering Gaze.")
	get_tree().quit(0)
