extends SceneTree

const GeneratorScript = preload("res://prototype/prototype_map_layout_generator.gd")
const QualityEvaluatorScript = preload("res://prototype/prototype_map_quality_evaluator.gd")
const GRID_SIZE := Vector2i(19, 10)
const SEED_COUNT := 200
const STATIC_OBJECTS: Array[Vector2i] = [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(7, 4), Vector2i(11, 5),
	Vector2i(12, 5), Vector2i(15, 7), Vector2i(4, 7), Vector2i(17, 8),
]


func _init() -> void:
	var generator: RefCounted = GeneratorScript.new()
	var evaluator: RefCounted = QualityEvaluatorScript.new()
	var samples: Array[Dictionary] = []
	for seed in range(1, SEED_COUNT + 1):
		var layout: Dictionary = generator.generate(seed, GRID_SIZE, STATIC_OBJECTS)
		if layout.is_empty():
			push_error("Map quality audit could not generate seed %d" % seed)
			quit(1)
			return
		var route: Array[Vector2i] = []
		route.assign(layout["route"])
		var waypoints: Array[Vector2i] = []
		waypoints.assign(layout["waypoints"])
		var metrics: Dictionary = evaluator.evaluate(
			GRID_SIZE,
			route,
			Vector2i(layout["entrance"]),
			waypoints,
			Vector2i(layout["exit_cell"]),
			STATIC_OBJECTS
		)
		if not evaluator.is_acceptable(metrics):
			push_error("Generated seed %d failed its map-quality safeguards: %s" % [seed, metrics])
			quit(1)
			return
		metrics["seed"] = seed
		samples.append(metrics)

	for metric_name in [
		"route_steps", "turns", "crossings", "close_revisits",
		"useful_build_cells", "best_coverage_steps", "best_coverage_ratio",
		"rows_used", "columns_used",
	]:
		print("%s %s" % [metric_name, _summarize(samples, metric_name)])
	print("PROTOTYPE_MAP_QUALITY_AUDIT_OK seeds=%d" % SEED_COUNT)
	quit(0)


func _summarize(samples: Array[Dictionary], metric_name: String) -> String:
	var minimum := INF
	var maximum := -INF
	var total := 0.0
	var minimum_seed := 0
	var maximum_seed := 0
	for sample in samples:
		var value := float(sample[metric_name])
		total += value
		if value < minimum:
			minimum = value
			minimum_seed = int(sample["seed"])
		if value > maximum:
			maximum = value
			maximum_seed = int(sample["seed"])
	return "min=%.3f(seed %d) avg=%.3f max=%.3f(seed %d)" % [
		minimum, minimum_seed, total / float(samples.size()), maximum, maximum_seed,
	]
