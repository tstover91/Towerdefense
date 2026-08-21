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
	var sandbox_mode := false
	var money := 1_000_000_000

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func get_path_cell_positions_near(
		_center: Vector2,
		_radius: float
	) -> Array[Vector2]:
		return [Vector2(475.0, 0.0), Vector2(525.0, 0.0)]


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var tower_data := GameStats.get_tower(&"fisherman")
	assert(int(tower_data["placement_cost"]) == 167)
	assert(tower_data["levels"].size() == 4)
	assert(int(tower_data["levels"][0]["damage"]) == 150)
	assert(float(tower_data["levels"][0]["firerate"]) == 2.0)
	assert(int(tower_data["levels"][3]["damage"]) == 600)
	assert(float(tower_data["levels"][3]["firerate"]) == 1.75)
	assert(float(tower_data["levels"][0]["range"]) == 12.75)
	assert(float(tower_data["levels"][3]["range"]) == 16.5)
	assert(int(tower_data["paths"]["a"]["cost"]) == 3000)
	assert(int(tower_data["paths"]["b"]["cost"]) == 3500)
	assert(tower_data["paths"]["b"]["display_name"] == "Minefield")
	assert(tower_data["type_tags"].has(&"biological"))
	assert(tower_data["damage_tags"].has(&"melee"))
	assert(not tower_data["damage_tags"].has(&"ballistic"))

	var fake_main := FakeMain.new()
	fake_main.round_active = false
	fake_main.sandbox_mode = true
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
	# Leave enough forward distance for all three overlapping towers to acquire
	# before the stronger hook finishes reeling the target backward.
	mob.set_path_follow(follow, 540.0)
	var starting_health: int = mob.health
	var cast_start_progress: float = follow.progress

	var towers: Array[BaseTower] = []
	for y_offset in [-20.0, 0.0, 20.0]:
		var placed_tower := TOWER_SCENE.instantiate() as BaseTower
		placed_tower.tower_id = &"fisherman"
		placed_tower.main = fake_main
		placed_tower.position = Vector2(400.0, y_offset)
		add_child(placed_tower)
		placed_tower.confirm_placement()
		var component := placed_tower.attack_component as FishermanAttackComponent
		assert(component != null)
		towers.append(placed_tower)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var unpulled_progress: float = (
		cast_start_progress + mob.get_effective_speed() * 1.3
	)
	for placed_tower in towers:
		var fisherman_component := (
			placed_tower.attack_component as FishermanAttackComponent
		)
		assert(fisherman_component != null)
		assert(placed_tower.uses_directional_aim())
		assert(placed_tower.uses_tracking_cone())
		assert(placed_tower.uses_finite_directional_range())
		assert(is_equal_approx(placed_tower.get_tracking_cone_degrees(), 60.0))
		assert(placed_tower.mobs_in_range.has(mob), "Every overlapping sandbox Fisherman must acquire the enemy.")
		assert(placed_tower.attack_on_cooldown, "Every Fisherman must start cooldown after its immediate cast.")
	assert(mob.health == starting_health - 114, "Every Fisherman must immediately land its first damage tick on acquisition.")
	assert(not mob.try_begin_fisherman_pull(2.5), "A second fisherman must not reclaim the pull during immunity.")
	var active_hooks: Array[FishermanHookEffect] = []
	for child in get_tree().current_scene.get_children():
		if child is FishermanHookEffect:
			active_hooks.append(child)
	assert(active_hooks.size() == 3, "Every Fisherman must create its own visible hook effect.")
	var pulling_hook_count := 0
	for hook in active_hooks:
		if hook.can_pull:
			pulling_hook_count += 1
	assert(pulling_hook_count == 1, "Overlapping hooks must share one pull claim while all remain visible.")
	await get_tree().create_timer(1.3).timeout
	assert(mob.health == starting_health - 450, "All three casts must deal their exact four-tick totals.")
	assert(follow.progress < cast_start_progress, "The claimed hook must visibly reel the enemy backward past its cast position.")
	assert(mob.fisherman_minimum_progress < cast_start_progress, "The active hook floor must allow its configured backward reel distance.")
	assert(not mob.fisherman_pull_active, "The pull claim must end when its line releases.")
	assert(mob.fisherman_pull_immunity_remaining > 2.3, "The full pull immunity must begin after the line releases.")
	assert(not mob.try_begin_fisherman_pull(2.5), "No Fisherman may pull during the post-release immunity window.")
	follow.progress = 400.0
	mob.fisherman_minimum_progress = 0.0
	mob.apply_fisherman_pull_toward(Vector2(700.0, 0.0), 25.0)
	assert(is_equal_approx(follow.progress, 400.0), "A tower ahead must never accelerate the enemy along the path.")
	mob.apply_fisherman_pull_toward(Vector2(300.0, 0.0), 25.0)
	assert(is_equal_approx(follow.progress, 375.0), "A tower behind must pull the enemy backward along the path.")
	follow.progress = 400.0
	mob.fisherman_minimum_progress = 390.0
	mob.apply_fisherman_pull_toward(Vector2.ZERO, 1000.0)
	assert(is_equal_approx(follow.progress, 390.0), "Pulls must never cross the guaranteed progress floor.")

	mob._process_control_effects(2.5)
	follow.progress += 20.0
	var banked_progress: float = follow.progress
	assert(mob.try_begin_fisherman_pull(2.5), "Pull immunity must expire after 2.5 seconds.")
	assert(is_equal_approx(mob.fisherman_minimum_progress, banked_progress), "A new hook must bank all progress gained during immunity.")
	mob.end_fisherman_pull(2.5)
	var tower := towers[0]
	var fisherman_component := tower.attack_component as FishermanAttackComponent
	var health_before_reacquisition: int = mob.health
	tower._on_body_exited(mob)
	follow.progress = 300.0
	tower._on_attack_timer_timeout()
	assert(not tower.attack_on_cooldown, "An idle cooldown timeout must leave Fisherman ready.")
	assert(tower.damage_timer.is_stopped(), "An idle Fisherman must not cycle its attack timer.")
	# Put the later group clearly in front of the tower's tracking cone.
	follow.progress = 500.0
	tower._on_body_entered(mob)
	await get_tree().process_frame
	assert(tower.attack_on_cooldown, "Fisherman must cast immediately when a later group enters.")
	assert(mob.health == health_before_reacquisition - 38, "Later target acquisition must immediately deal the first tick.")

	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(tower.damage == 840)
	assert(tower.damage_type == &"electric")
	assert(tower.has_type_tag(&"biological"))
	assert(tower.has_damage_tag(&"melee"))
	assert(tower.has_damage_tag(&"electric"))
	assert(fisherman_component.electric_line_enabled)

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(tower.pierce_count == 0)
	assert(tower.damage_type == &"melee")
	assert(tower.has_type_tag(&"biological"))
	assert(tower.has_damage_tag(&"melee"))
	assert(tower.has_damage_tag(&"explosive"))
	assert(not tower.has_damage_tag(&"electric"))
	assert(fisherman_component.mines_enabled)
	assert(fisherman_component.mine_maximum_count == 3)
	fisherman_component.process_attack(fisherman_component.mine_interval)
	assert(fisherman_component.active_mines.size() == 1)
	var mine := fisherman_component.active_mines[0] as FishermanMine
	assert(mine != null)
	assert(mine.damage == 750)
	mine._process(0.16)
	assert(is_zero_approx(mine.arm_remaining), "Mine arming must advance while Sandbox has no formal round active.")
	assert(is_equal_approx(
		mine.explosion_radius,
		2.5 * BaseTower.RANGE_PIXELS_PER_UNIT
	))

	# A lethal first tick used to remove the target and hook before the line's
	# first draw. Successful casts now retain cached endpoints for a brief flash.
	var lethal_follow := PathFollow2D.new()
	path.add_child(lethal_follow)
	var lethal_mob := MOB_SCENE.instantiate()
	lethal_mob.enemy_id = &"brute"
	lethal_follow.add_child(lethal_mob)
	lethal_mob.set_path_follow(lethal_follow, 500.0)
	lethal_mob.health = 1
	lethal_mob.max_health = 1
	fisherman_component.execute_attack(lethal_mob, tower.damage)
	var lethal_hook: FishermanHookEffect
	for child in get_tree().current_scene.get_children():
		if child is FishermanHookEffect and child.hooked_target == lethal_mob:
			lethal_hook = child
			break
	assert(lethal_hook != null, "A lethal Fisherman cast must still create its line effect.")
	assert(lethal_hook.has_cached_line, "The lethal cast must cache its line endpoints before damage.")
	await get_tree().create_timer(0.05).timeout
	assert(is_instance_valid(lethal_hook), "A lethal line must survive long enough to be rendered.")
	assert(not lethal_hook.is_queued_for_deletion(), "A lethal line must remain visible for its minimum flash.")
	await get_tree().create_timer(0.15).timeout
	await get_tree().process_frame
	assert(not is_instance_valid(lethal_hook), "The lethal line flash must clean itself up.")
	fisherman_component.clear_mines()
	print("Fisherman smoke test passed: forward cone, four ticks, pull immunity, lethal line flashes, Live Wire, and Minefield.")
	get_tree().quit()
