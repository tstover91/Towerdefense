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

	var gun: Node2D = TowerScript.new()
	board.add_child(gun)
	gun.position = Vector2(300.0, 300.0)
	gun.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_GUN)
	var near_enemy: Node2D = _make_enemy(board, Vector2(340.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var far_enemy: Node2D = _make_enemy(board, Vector2(400.0, 300.0), EnemyScript.TYPE_SOLDIER)
	gun._process(0.11)
	_assert(gun.target == near_enemy, "gun acquires the closest enemy")
	far_enemy.position = Vector2(320.0, 300.0)
	gun._process(0.11)
	_assert(gun.target == near_enemy, "gun stays locked while its target remains valid")
	near_enemy.position = Vector2(1000.0, 300.0)
	gun._process(0.11)
	_assert(gun.target == far_enemy, "gun retargets after its locked target leaves range")

	var beam: Node2D = TowerScript.new()
	board.add_child(beam)
	beam.position = Vector2(500.0, 300.0)
	beam.configure(Vector2i.ZERO, Callable(board, "get_cell_size"), TowerScript.TYPE_BEAM)
	var beam_target: Node2D = _make_enemy(board, Vector2(540.0, 300.0), EnemyScript.TYPE_GIANT)
	var health_before: int = beam_target.health
	beam.target_lock_time = 2.5
	beam._fire_at(beam_target)
	_assert(health_before - beam_target.health == 8, "level-one beam ramps from 2 to 8 damage while locked")

	var splash_a: Node2D = _make_enemy(board, Vector2(700.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var splash_b: Node2D = _make_enemy(board, Vector2(730.0, 300.0), EnemyScript.TYPE_SOLDIER)
	var splash_projectile: Node2D = ProjectileScript.new()
	board.add_child(splash_projectile)
	splash_projectile.damage = 7
	splash_projectile.splash_radius = 50.0
	splash_projectile._apply_splash(splash_a.global_position)
	_assert(splash_a.health == 58 and splash_b.health == 58, "mortar splash damages a nearby group")

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
