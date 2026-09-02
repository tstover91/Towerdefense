extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const MOB_SCENE = preload("res://mob.tscn")

const DEFAULT_ENEMY_STAGES: Array[int] = [1, 30, 60, 90]
const DEFAULT_STAGE_DURATION := 8.0
const WARMUP_DURATION := 2.0
const CLEANUP_DURATION := 8.0
const PATH_LENGTH := 2400.0
const COMBAT_CENTER := Vector2(1200.0, 360.0)
const TOWER_ROSTER: Array[StringName] = [
	&"saucer", &"saucer",
	&"energycore", &"energycore", &"energycore",
	&"fisherman", &"fisherman", &"fisherman", &"fisherman",
	&"orbitalcannon", &"orbitalcannon", &"orbitalcannon",
	&"voidcaller", &"voidcaller",
	&"dronedepot",
]


class StressMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var sandbox_mode := true
	var money := 1_000_000_000
	var primary_path: Path2D

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func get_primary_enemy_path() -> Path2D:
		return primary_path

	func get_path_cell_positions_near(center: Vector2, _radius: float) -> Array[Vector2]:
		return [Vector2(center.x - 24.0, 360.0), Vector2(center.x + 24.0, 360.0)]

	func is_world_position_in_playable_area(_position: Vector2) -> bool:
		return true

	func get_shared_spore_target(_requesting_tower: Node) -> Node2D:
		return null


var stage_duration := DEFAULT_STAGE_DURATION
var enemy_stages: Array[int] = DEFAULT_ENEMY_STAGES.duplicate()
var output_path := "user://performance_stress.csv"
var stress_main: StressMain
var enemy_path: Path2D
var towers: Array[BaseTower] = []
var rows: Array[String] = []


func _ready() -> void:
	_parse_arguments()
	call_deferred("run_benchmark")


func run_benchmark() -> void:
	_build_arena()
	await get_tree().create_timer(WARMUP_DURATION).timeout
	for enemy_count in enemy_stages:
		_set_enemy_count(enemy_count)
		await get_tree().physics_frame
		await get_tree().physics_frame
		await _sample_stage("enemies_%d" % enemy_count, stage_duration)

	stress_main.round_active = false
	stress_main.round_ended.emit(24)
	_clear_enemies()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _sample_stage("cleanup", CLEANUP_DURATION)
	_write_report()
	print("Performance stress report: ", ProjectSettings.globalize_path(output_path))
	get_tree().quit(0)


func _build_arena() -> void:
	stress_main = StressMain.new()
	add_child(stress_main)
	enemy_path = Path2D.new()
	var curve := Curve2D.new()
	curve.add_point(Vector2(0.0, COMBAT_CENTER.y))
	curve.add_point(Vector2(PATH_LENGTH, COMBAT_CENTER.y))
	enemy_path.curve = curve
	add_child(enemy_path)
	stress_main.primary_path = enemy_path

	for tower_index in TOWER_ROSTER.size():
		var angle := TAU * float(tower_index) / float(TOWER_ROSTER.size())
		var ring := 82.0 + float(tower_index % 3) * 34.0
		var tower := TOWER_SCENE.instantiate() as BaseTower
		tower.tower_id = TOWER_ROSTER[tower_index]
		tower.main = stress_main
		tower.position = COMBAT_CENTER + Vector2(cos(angle), sin(angle)) * ring
		add_child(tower)
		tower.confirm_placement()
		tower.instance_progression.set_level_for_sandbox(20)
		towers.append(tower)
		_configure_manual_target(tower)


func _configure_manual_target(tower: BaseTower) -> void:
	if tower.attack_component == null or not tower.uses_manual_ground_targeting():
		return
	tower.attack_component.set("target_position", COMBAT_CENTER)
	tower.attack_component.set("has_target_position", true)


func _set_enemy_count(target_count: int) -> void:
	var current := get_tree().get_node_count_in_group(&"mobs")
	while current < target_count:
		_add_enemy(current, target_count)
		current += 1
	while current > target_count:
		var enemies := get_tree().get_nodes_in_group(&"mobs")
		if enemies.is_empty():
			break
		var enemy: Node = enemies.back()
		var follow := enemy.get_parent()
		follow.queue_free()
		current -= 1


func _add_enemy(index: int, total: int) -> void:
	var follow := PathFollow2D.new()
	enemy_path.add_child(follow)
	follow.loop = false
	var enemy = MOB_SCENE.instantiate()
	enemy.enemy_id = &"brute" if index % 10 == 0 else &"normal"
	follow.add_child(enemy)
	var spread := minf(float(total) * 7.0, 700.0)
	var progress := COMBAT_CENTER.x - spread * 0.5
	if total > 1:
		progress += spread * float(index) / float(total - 1)
	enemy.set_path_follow(follow, progress)
	# Keep the workload stable: towers continue hitting targets without killing
	# them or allowing them to leave the benchmark arena.
	enemy.max_health = 1_000_000_000
	enemy.health = enemy.max_health
	enemy.speed = 0.0
	if enemy.has_node("HealthBarAnchor/HealthBar"):
		var health_bar: ProgressBar = enemy.get_node("HealthBarAnchor/HealthBar")
		health_bar.max_value = enemy.max_health
		health_bar.value = enemy.health


func _clear_enemies() -> void:
	for child in enemy_path.get_children():
		child.queue_free()


func _sample_stage(stage_name: String, duration: float) -> void:
	var elapsed := 0.0
	var frame_count := 0
	var total_frame_ms := 0.0
	var worst_frame_ms := 0.0
	var frames_over_33_ms := 0
	var total_process_ms := 0.0
	var total_physics_ms := 0.0
	var peak_process_ms := 0.0
	var peak_physics_ms := 0.0
	while elapsed < duration:
		var start_usec := Time.get_ticks_usec()
		await get_tree().process_frame
		var frame_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
		elapsed += frame_ms / 1000.0
		frame_count += 1
		total_frame_ms += frame_ms
		worst_frame_ms = maxf(worst_frame_ms, frame_ms)
		if frame_ms > 33.333:
			frames_over_33_ms += 1
		var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		total_process_ms += process_ms
		total_physics_ms += physics_ms
		peak_process_ms = maxf(peak_process_ms, process_ms)
		peak_physics_ms = maxf(peak_physics_ms, physics_ms)
	var average_ms := total_frame_ms / maxf(float(frame_count), 1.0)
	var average_fps := 1000.0 / maxf(average_ms, 0.001)
	var average_process_ms := total_process_ms / maxf(float(frame_count), 1.0)
	var average_physics_ms := total_physics_ms / maxf(float(frame_count), 1.0)
	rows.append(",".join(PackedStringArray([
		stage_name,
		str(get_tree().get_node_count_in_group(&"mobs")),
		str(towers.size()),
		str(frame_count),
		"%.3f" % average_ms,
		"%.2f" % average_fps,
		"%.3f" % worst_frame_ms,
		str(frames_over_33_ms),
		"%.3f" % average_process_ms,
		"%.3f" % peak_process_ms,
		"%.3f" % average_physics_ms,
		"%.3f" % peak_physics_ms,
		str(get_tree().get_node_count_in_group(&"tower_projectiles")),
		str(get_tree().get_node_count_in_group(&"spawned_units")),
		str(get_tree().get_node_count_in_group(&"tower_attack_visuals")),
		str(_count_active_group_nodes(&"tower_attack_visuals")),
		str(get_tree().get_node_count_in_group(&"tower_attack_resolvers")),
		str(get_tree().get_node_count_in_group(&"fisherman_hooks")),
		str(get_tree().get_node_count_in_group(&"saucer_flyers")),
		str(get_tree().get_node_count()),
		_get_group_type_summary(&"tower_attack_visuals"),
	])))
	print("%-12s avg %7.3f ms  %6.1f FPS  worst %7.3f ms  nodes %d" % [
		stage_name, average_ms, average_fps, worst_frame_ms, get_tree().get_node_count()
	])


func _write_report() -> void:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write performance report: %s" % output_path)
		return
	file.store_line("stage,enemies,towers,frames,average_frame_ms,average_fps,worst_frame_ms,frames_over_33ms,average_process_ms,peak_process_ms,average_physics_ms,peak_physics_ms,projectiles,spawned_units,visual_effect_nodes,active_visual_effects,attack_resolvers,fisherman_hooks,saucer_flyers,total_nodes,visual_effect_types")
	for row in rows:
		file.store_line(row)


func _count_active_group_nodes(group_name: StringName) -> int:
	var active := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if node.process_mode != Node.PROCESS_MODE_DISABLED and (
			not node is CanvasItem or node.visible
		):
			active += 1
	return active


func _get_group_type_summary(group_name: StringName) -> String:
	var counts: Dictionary = {}
	for node in get_tree().get_nodes_in_group(group_name):
		var type_name := node.get_class()
		if node.get_script() != null:
			type_name = node.get_script().resource_path.get_file().get_basename()
		counts[type_name] = int(counts.get(type_name, 0)) + 1
	var labels: Array[String] = []
	for type_name in counts:
		labels.append("%s:%d" % [type_name, counts[type_name]])
	labels.sort()
	return ";".join(labels)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--duration="):
			stage_duration = maxf(float(argument.trim_prefix("--duration=")), 1.0)
		elif argument.begins_with("--enemies="):
			enemy_stages.clear()
			for value in argument.trim_prefix("--enemies=").split(",", false):
				enemy_stages.append(maxi(int(value), 1))
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
