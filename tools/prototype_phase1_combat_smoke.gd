extends SceneTree

const PrototypeScene = preload("res://prototype/prototype_main.tscn")
const TowerScript = preload("res://prototype/prototype_tower.gd")
const EnemyScript = preload("res://prototype/prototype_enemy.gd")
const ProjectileScript = preload("res://prototype/prototype_projectile.gd")

var failure_count := 0
var released_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	get_root().size = Vector2i(1152, 648)
	var game: Node = PrototypeScene.instantiate()
	get_root().add_child(game)
	current_scene = game
	await process_frame
	var board: Node2D = game.get_node("GridBoard")
	board.enemies_added.connect(func(count: int) -> void: released_count += count)

	var gunslinger: Node2D = TowerScript.new()
	board.add_child(gunslinger)
	gunslinger.position = Vector2(300.0, 300.0)
	gunslinger.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_GUNSLINGER)
	var near_enemy: Node2D = _make_enemy(board, Vector2(340.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var far_enemy: Node2D = _make_enemy(board, Vector2(400.0, 300.0), EnemyScript.TYPE_SOLDIER)
	near_enemy.route_progress = 2.0
	far_enemy.route_progress = 5.0
	gunslinger._process(0.11)
	_assert(gunslinger.target == far_enemy, "Gunslinger uses its fixed First targeting")
	near_enemy.route_progress = 7.0
	gunslinger._process(0.11)
	_assert(gunslinger.target == near_enemy, "Gunslinger refreshes First instead of locking its old target")
	far_enemy.position = Vector2(1000.0, 300.0)
	gunslinger._process(0.11)
	_assert(gunslinger.target == near_enemy, "Gunslinger keeps the current First enemy when it remains first")

	var anti_materiel: Node2D = TowerScript.new()
	board.add_child(anti_materiel)
	anti_materiel.position = Vector2(500.0, 500.0)
	anti_materiel.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_ANTI_MATERIEL)
	var before_primary: Node2D = _make_enemy(board, Vector2(550.0, 500.0), EnemyScript.TYPE_SOLDIER)
	var primary: Node2D = _make_enemy(board, Vector2(600.0, 500.0), EnemyScript.TYPE_GIANT)
	var after_primary: Node2D = _make_enemy(board, Vector2(650.0, 500.0), EnemyScript.TYPE_SOLDIER)
	anti_materiel._process(0.11)
	_assert(anti_materiel.target == primary, "Anti-Materiel acquires the highest-HP enemy")
	_assert(primary.health == 452, "Anti-Materiel deals full damage to its selected primary target")
	_assert(before_primary.health == 65, "an enemy before the selected target cannot steal its primary hit")
	_assert(after_primary.health == 45, "Anti-Materiel pierces only the next enemy after its target at shared falloff")
	var new_highest_hp: Node2D = _make_enemy(board, Vector2(570.0, 530.0), EnemyScript.TYPE_GIANT)
	anti_materiel._process(0.11)
	_assert(anti_materiel.target == primary, "Anti-Materiel stays locked while its target remains alive and in range")
	primary.position = Vector2(1000.0, 500.0)
	anti_materiel._process(0.11)
	_assert(anti_materiel.target == new_highest_hp, "Anti-Materiel reacquires after its lock leaves range")

	var piercing_gunslinger: Node2D = TowerScript.new()
	board.add_child(piercing_gunslinger)
	piercing_gunslinger.position = Vector2(300.0, 400.0)
	piercing_gunslinger.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_GUNSLINGER)
	piercing_gunslinger.upgrade(piercing_gunslinger.get_next_upgrade_cost())
	piercing_gunslinger.upgrade(piercing_gunslinger.get_next_upgrade_cost())
	var gunslinger_before: Node2D = _make_enemy(board, Vector2(330.0, 400.0), EnemyScript.TYPE_SOLDIER)
	var gunslinger_primary: Node2D = _make_enemy(board, Vector2(360.0, 400.0), EnemyScript.TYPE_SOLDIER)
	var gunslinger_after: Node2D = _make_enemy(board, Vector2(390.0, 400.0), EnemyScript.TYPE_SOLDIER)
	piercing_gunslinger._fire_at(gunslinger_primary)
	_assert(gunslinger_primary.health == 47, "Gunslinger deals full damage to its selected primary target")
	_assert(gunslinger_before.health == 65, "Gunslinger primary-impact pierce ignores enemies before its target")
	_assert(gunslinger_after.health == 52, "Gunslinger pierces the next enemy after its target")

	var flamespitter: Node2D = TowerScript.new()
	board.add_child(flamespitter)
	flamespitter.position = Vector2(700.0, 500.0)
	flamespitter.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_FLAMESPITTER)
	flamespitter.aim_direction = Vector2.RIGHT
	var flame_near: Node2D = _make_enemy(board, Vector2(720.0, 500.0), EnemyScript.TYPE_SOLDIER)
	var flame_middle: Node2D = _make_enemy(board, Vector2(730.0, 500.0), EnemyScript.TYPE_SOLDIER)
	var flame_far: Node2D = _make_enemy(board, Vector2(740.0, 500.0), EnemyScript.TYPE_SOLDIER)
	var flame_over_limit: Node2D = _make_enemy(board, Vector2(750.0, 500.0), EnemyScript.TYPE_SOLDIER)
	var flame_outside: Node2D = _make_enemy(board, Vector2(740.0, 560.0), EnemyScript.TYPE_SOLDIER)
	var flame_behind: Node2D = _make_enemy(board, Vector2(660.0, 500.0), EnemyScript.TYPE_SOLDIER)
	flamespitter._apply_flame_tick()
	_assert(flame_near.health == 63 and flame_middle.health == 63 and flame_far.health == 63, "Flamespitter damages the nearest enemies inside its cone")
	_assert(flame_over_limit.health == 65, "Flamespitter stops after its level-one target limit")
	_assert(flame_outside.health == 65, "Flamespitter does not hit enemies outside its cone")
	_assert(flame_behind.health == 65, "Flamespitter cone does not damage enemies behind it")

	var splash_a: Node2D = _make_enemy(board, Vector2(700.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var splash_b: Node2D = _make_enemy(board, Vector2(730.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var splash_projectile: Node2D = ProjectileScript.new()
	board.add_child(splash_projectile)
	splash_projectile.damage = 7
	splash_projectile.splash_radius = 50.0
	splash_projectile.stun_duration = 0.4
	splash_projectile._apply_splash(splash_a.global_position)
	_assert(splash_a.health == 58 and splash_b.health == 58, "Bombardment splash damages a nearby group")
	_assert(splash_a.stun_remaining == 0.4 and splash_b.stun_remaining == 0.4, "Bombardment's final shell applies its short stun to the blast")

	var bombardment: Node2D = TowerScript.new()
	board.add_child(bombardment)
	bombardment.position = Vector2(850.0, 450.0)
	bombardment.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_BOMBARDMENT)
	for upgrade_index in 3:
		bombardment.upgrade(bombardment.get_next_upgrade_cost())
	bombardment._start_bombardment_salvo(Vector2(900.0, 450.0))
	bombardment._launch_bombardment_shell()
	bombardment._launch_bombardment_shell()
	var barrage_projectiles: Array[Node2D] = []
	for child in game.get_children():
		if child.get_script() == ProjectileScript:
			barrage_projectiles.append(child as Node2D)
	_assert(barrage_projectiles.size() == 3, "level-four Bombardment launches a three-shell barrage")
	if barrage_projectiles.size() == 3:
		_assert(barrage_projectiles[0].stun_duration == 0.0 and barrage_projectiles[1].stun_duration == 0.0, "the first two barrage shells do not stun")
		_assert(barrage_projectiles[2].stun_duration == 0.4, "only the final barrage shell carries the level-four stun")
	for barrage_projectile in barrage_projectiles:
		barrage_projectile.queue_free()

	var leader: Node2D = _make_enemy(board, Vector2(800.0, 300.0), EnemyScript.TYPE_GIANT, 44, 0)
	var follower: Node2D = _make_enemy(board, Vector2(780.0, 300.0), EnemyScript.TYPE_SOLDIER, 44, 1)
	_assert(leader.max_health >= follower.max_health * 7, "giants have tank-scale survivability")
	_assert(is_equal_approx(leader.base_speed_cells_per_second / follower.base_speed_cells_per_second, 2.0 / 3.0), "giants move at two-thirds soldier speed")
	leader.route_progress = 3.0
	follower.route_progress = 2.6
	follower._update_formation_speed()
	_assert(follower.current_speed_cells_per_second <= leader.current_speed_cells_per_second, "soldiers hold formation behind a giant")
	var runner: Node2D = _make_enemy(board, Vector2(780.0, 340.0), EnemyScript.TYPE_RUNNER, 44, 2)
	runner.route_progress = 2.7
	runner._update_formation_speed()
	_assert(is_equal_approx(runner.current_speed_cells_per_second, runner.base_speed_cells_per_second), "runners break formation at full speed")

	board.spawn_enemy({"enemy_type": EnemyScript.TYPE_CARRIER, "health": 1, "health_scale": 1.0, "group_index": 90})
	var carrier: Node2D = board.active_followers[-1]
	carrier._process(0.37)
	var release_position := carrier.position
	var release_route: Array[Vector2i] = carrier.route.duplicate()
	var release_route_index: int = carrier.route_index
	carrier.apply_damage(1)
	_assert(released_count == 4, "carrier defeat registers four released soldiers")
	var released_soldiers := 0
	for enemy in board.active_followers:
		if is_instance_valid(enemy) and enemy.enemy_type == EnemyScript.TYPE_SOLDIER and enemy.formation_id == 90:
			released_soldiers += 1
			_assert(enemy.position.is_equal_approx(release_position), "released soldiers begin at the carrier's exact position")
			_assert(enemy.route == release_route and enemy.route_index == release_route_index, "released soldiers inherit the carrier's remaining route")
	_assert(released_soldiers == 4, "carrier releases four active soldiers at its position")
	await process_frame

	_finish()


func _make_enemy(board: Node2D, world_position: Vector2, type: StringName, formation := -1, index := 0) -> Node2D:
	var enemy: Node2D = EnemyScript.new()
	board.add_child(enemy)
	enemy.position = world_position
	enemy.setup_combat(type, 1.0, board.get_cell_size(), formation, index)
	return enemy


func _assert(condition: bool, description: String) -> void:
	if condition:
		return
	push_error("Prototype phase-one combat smoke failed: %s" % description)
	failure_count += 1


func _finish() -> void:
	if failure_count > 0:
		quit(1)
		return
	print("PROTOTYPE_PHASE1_COMBAT_SMOKE_OK")
	quit(0)
