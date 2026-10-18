extends SceneTree

const RunStatsScript = preload("res://prototype/prototype_run_stats.gd")
const BoardScript = preload("res://prototype/prototype_grid_board.gd")
const TowerScript = preload("res://prototype/prototype_tower.gd")
const EnemyScript = preload("res://prototype/prototype_enemy.gd")


func _init() -> void:
	var stats: RefCounted = RunStatsScript.new()
	stats.begin_wave(1, 500, 20)
	stats.record_spawn(&"soldier", 100, 1, 2.0)
	stats.record_spawn(&"soldier", 100, 1, 4.0)
	var board: Node2D = BoardScript.new()
	board.displayed_route.assign([
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
		Vector2i(8, 0), Vector2i(9, 0), Vector2i(10, 0),
	])
	board.tower_damage_recorded.connect(stats.record_damage)
	board._on_tower_damage_dealt(&"gunslinger", 1, 25, 2.0)
	var tower: Node2D = TowerScript.new()
	var enemy: Node2D = EnemyScript.new()
	enemy.route_progress = 6.0
	tower.damage_dealt.connect(board._on_tower_damage_dealt)
	tower.record_damage(50, enemy)
	stats.record_enemy_resolved(false, 0, 0.40)
	stats.record_enemy_resolved(false, 0, 0.80)
	var row: Dictionary = stats.finish_wave(
		1,
		10.0,
		{},
		{},
		{},
		20
	)
	assert(int(row["peak_active_enemies"]) == 2)
	assert(is_equal_approx(float(row["last_spawn_time_seconds"]), 4.0))
	assert(is_equal_approx(float(row["clear_after_last_spawn_seconds"]), 6.0))
	assert(int(row["damage_route_q1"]) == 25)
	assert(int(row["damage_route_q3"]) == 50)
	assert(int(row["defeated_route_q2"]) == 1)
	assert(int(row["defeated_route_q4"]) == 1)
	assert(is_equal_approx(float(row["average_death_progress_percent"]), 60.0))
	assert(is_equal_approx(float(row["median_death_progress_percent"]), 60.0))
	assert(is_equal_approx(float(row["p90_death_progress_percent"]), 76.0))
	assert(int(row["enemies_10_percent_beyond_median_death"]) == 1)
	var csv_report := FileAccess.get_file_as_string("user://prototype_run_stats.csv")
	assert(csv_report.contains("damage_route_q1"))
	assert(csv_report.contains("median_death_progress_percent"))
	assert(csv_report.contains("clear_after_last_spawn_seconds"))
	board.free()
	tower.free()
	enemy.free()
	print("SPATIAL_STATS_UNIT_SMOKE_OK")
	quit(0)
