class_name PrototypeMapQualityEvaluator
extends RefCounted

const COVERAGE_RANGE_CELLS := 2.5
const MIN_TURNS := 5
const MAX_CROSSINGS := 4
const MAX_CLOSE_REVISITS := 28
const MIN_USEFUL_BUILD_CELLS := 125
const MAX_BEST_COVERAGE_RATIO := 0.33
const MIN_ROWS_USED := 6


func evaluate(
	grid_size: Vector2i,
	route: Array[Vector2i],
	entrance: Vector2i,
	waypoints: Array[Vector2i],
	exit_cell: Vector2i,
	static_objects: Array[Vector2i]
) -> Dictionary:
	var route_steps := maxi(route.size() - 1, 0)
	var unique_route_cells: Dictionary = {}
	var occupied: Dictionary = {}
	for cell in static_objects:
		occupied[cell] = true
	occupied[entrance] = true
	occupied[exit_cell] = true
	for waypoint in waypoints:
		occupied[waypoint] = true
	for cell in route:
		unique_route_cells[cell] = true

	var turns := 0
	for index in range(2, route.size()):
		if route[index] - route[index - 1] != route[index - 1] - route[index - 2]:
			turns += 1

	var close_revisits := 0
	for first_index in route.size():
		for second_index in range(first_index + 3, route.size()):
			if _manhattan(route[first_index], route[second_index]) <= 1:
				close_revisits += 1

	var best_coverage_steps := 0
	var useful_build_cells := 0
	for y in grid_size.y:
		for x in grid_size.x:
			var build_cell := Vector2i(x, y)
			if occupied.has(build_cell):
				continue
			var covered_steps := 0
			for route_cell in route:
				if Vector2(build_cell).distance_to(Vector2(route_cell)) <= COVERAGE_RANGE_CELLS:
					covered_steps += 1
			if covered_steps > 0:
				useful_build_cells += 1
			best_coverage_steps = maxi(best_coverage_steps, covered_steps)

	var occupied_rows: Dictionary = {}
	var occupied_columns: Dictionary = {}
	for cell in unique_route_cells:
		occupied_rows[cell.y] = true
		occupied_columns[cell.x] = true

	return {
		"route_steps": route_steps,
		"turns": turns,
		"crossings": route.size() - unique_route_cells.size(),
		"close_revisits": close_revisits,
		"useful_build_cells": useful_build_cells,
		"best_coverage_steps": best_coverage_steps,
		"best_coverage_ratio": (
			float(best_coverage_steps) / float(route.size())
			if not route.is_empty()
			else 0.0
		),
		"rows_used": occupied_rows.size(),
		"columns_used": occupied_columns.size(),
	}


func is_acceptable(metrics: Dictionary) -> bool:
	return (
		int(metrics.get("turns", 0)) >= MIN_TURNS
		and int(metrics.get("crossings", 0)) <= MAX_CROSSINGS
		and int(metrics.get("close_revisits", 0)) <= MAX_CLOSE_REVISITS
		and int(metrics.get("useful_build_cells", 0)) >= MIN_USEFUL_BUILD_CELLS
		and float(metrics.get("best_coverage_ratio", 1.0)) <= MAX_BEST_COVERAGE_RATIO
		and int(metrics.get("rows_used", 0)) >= MIN_ROWS_USED
	)


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)
