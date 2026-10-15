class_name PrototypeGridRouteFollower
extends Node2D

signal reached_exit(follower: Node2D)

const BODY_COLOR := Color("f7f0df")
const BODY_OUTLINE := Color("17131b")
const DIRECTION_COLOR := Color("ef624d")

var router = null
var cell_center_provider: Callable
var world_to_cell_provider: Callable
var route: Array[Vector2i] = []
var route_index := 0
var next_checkpoint_index := 0
var speed_pixels_per_second := 115.0
var active := false
var travel_direction := Vector2.RIGHT
var traversed_edges: Dictionary = {}
var last_reached_cell := Vector2i(-1, -1)


func configure(
	new_router,
	new_cell_center_provider: Callable,
	new_world_to_cell_provider: Callable,
	new_speed_pixels_per_second := 115.0
) -> void:
	router = new_router
	cell_center_provider = new_cell_center_provider
	world_to_cell_provider = new_world_to_cell_provider
	speed_pixels_per_second = new_speed_pixels_per_second


func begin() -> bool:
	if router == null or not cell_center_provider.is_valid():
		return false
	next_checkpoint_index = 0
	position = cell_center_provider.call(router.entrance)
	active = true
	route.clear()
	route_index = 0
	traversed_edges.clear()
	last_reached_cell = router.entrance
	return reroute()


func begin_from_state(world_position: Vector2, route_state: Dictionary) -> bool:
	if router == null or not cell_center_provider.is_valid():
		return false
	position = world_position
	next_checkpoint_index = int(route_state.get("next_checkpoint_index", 0))
	traversed_edges = Dictionary(route_state.get("used_edges", {})).duplicate()
	last_reached_cell = Vector2i(route_state.get("cell", router.entrance))
	active = true
	route.clear()
	route_index = 0
	return reroute()


func reroute() -> bool:
	if not active or router == null:
		return false
	var anchor_cell := get_route_anchor_cell()
	var unavailable_edges := _get_used_edges_with_active_step(anchor_cell)
	var new_route: Array[Vector2i] = router.find_complete_route(
		anchor_cell,
		next_checkpoint_index,
		{},
		unavailable_edges
	)
	if new_route.is_empty():
		active = false
		return false
	route.assign(new_route)
	route_index = 0
	queue_redraw()
	return true


func get_route_state() -> Dictionary:
	var current_cell: Vector2i = Vector2i(
		world_to_cell_provider.call(position)
		if world_to_cell_provider.is_valid()
		else get_route_anchor_cell()
	)
	var occupied_cells: Array[Vector2i] = [current_cell]
	var anchor_cell := get_route_anchor_cell()
	if not occupied_cells.has(anchor_cell):
		occupied_cells.append(anchor_cell)
	return {
		"cell": anchor_cell,
		"occupied_cells": occupied_cells,
		"next_checkpoint_index": next_checkpoint_index,
		"used_edges": _get_used_edges_with_active_step(anchor_cell),
	}


func get_route_anchor_cell() -> Vector2i:
	if route_index >= 0 and route_index < route.size():
		return route[route_index]
	if world_to_cell_provider.is_valid():
		return world_to_cell_provider.call(position)
	return router.entrance if router != null else Vector2i.ZERO


func remap_layout(
	old_origin: Vector2,
	old_cell_size: float,
	new_origin: Vector2,
	new_cell_size: float
) -> void:
	if not active or old_cell_size <= 0.0 or new_cell_size <= 0.0:
		return
	var grid_position := (position - old_origin) / old_cell_size
	position = new_origin + grid_position * new_cell_size


func _process(delta: float) -> void:
	if not active or route_index >= route.size():
		return
	var movement_remaining := speed_pixels_per_second * maxf(delta, 0.0)
	while active and route_index < route.size():
		var target_position: Vector2 = cell_center_provider.call(route[route_index])
		var offset := target_position - position
		var distance := offset.length()
		if distance > 0.01:
			travel_direction = offset / distance
			var travel_distance := minf(distance, movement_remaining)
			position += travel_direction * travel_distance
			movement_remaining -= travel_distance
			if travel_distance + 0.01 < distance:
				break
		position = target_position
		var arrived_cell := route[route_index]
		if last_reached_cell.x >= 0 and last_reached_cell != arrived_cell:
			traversed_edges[router.get_edge_key(last_reached_cell, arrived_cell)] = true
		last_reached_cell = arrived_cell
		route_index += 1
		while (
			next_checkpoint_index < router.get_checkpoint_count()
			and arrived_cell == router.get_checkpoint(next_checkpoint_index)
		):
			next_checkpoint_index += 1
		if next_checkpoint_index >= router.get_checkpoint_count():
			active = false
			reached_exit.emit(self)
			break
		if movement_remaining <= 0.0:
			break
	queue_redraw()


func _get_used_edges_with_active_step(anchor_cell: Vector2i) -> Dictionary:
	var used_edges := traversed_edges.duplicate()
	if last_reached_cell.x >= 0 and last_reached_cell != anchor_cell:
		used_edges[router.get_edge_key(last_reached_cell, anchor_cell)] = true
	return used_edges


func _draw() -> void:
	var radius := 9.0
	draw_circle(Vector2.ZERO, radius + 3.0, BODY_OUTLINE)
	draw_circle(Vector2.ZERO, radius, BODY_COLOR)
	draw_line(
		Vector2.ZERO,
		travel_direction * (radius + 5.0),
		DIRECTION_COLOR,
		4.0,
		true
	)
