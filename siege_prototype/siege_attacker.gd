class_name SiegeAttacker
extends Node2D

signal attacker_died(attacker: Node)
signal structure_hit(attacker: Node, structure: Node, damage: float)

const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const RouterScript = preload("res://siege_prototype/siege_grid_router.gd")

const COLOR_RAIDER := Color("4ca66a")
const COLOR_BRUTE := Color("5878b8")
const COLOR_SAPPER := Color("d68637")
const COLOR_OUTLINE := Color("252522")
const COLOR_HEALTH := Color("62bd69")
const COLOR_HEALTH_BACK := Color("252522")
const COLOR_TARGET := Color("f3d166")

var attacker_id: int
var kind: StringName
var definition: Dictionary = {}
var board: Node2D
var grid_position := Vector2.ZERO
var max_health := 1.0
var health := 1.0
var damage := 1.0
var wall_damage := 1.0
var attack_interval := 1.0
var move_speed_cells := 1.0
var attack_range_cells := 1.05
var preferred_target: StringName = &"any"
var self_destructs := false
var dead := false
var attack_cooldown := 0.0
var intended_target_id: StringName
var active_target_id: StringName
var path: Array[Vector2i] = []
var path_index := 0
var plan_dirty := true
var cell_size := 48.0


func configure(
	next_id: int,
	next_kind: StringName,
	next_definition: Dictionary,
	spawn_cell: Vector2i,
	next_board: Node2D
) -> void:
	attacker_id = next_id
	kind = next_kind
	definition = next_definition.duplicate(true)
	board = next_board
	grid_position = Vector2(spawn_cell)
	max_health = maxf(float(definition.get("max_health", 1.0)), 1.0)
	health = max_health
	damage = float(definition.get("damage", 1.0))
	wall_damage = float(definition.get("wall_damage", damage))
	attack_interval = maxf(float(definition.get("attack_interval", 1.0)), 0.05)
	move_speed_cells = maxf(float(definition.get("move_speed_cells", 1.0)), 0.05)
	attack_range_cells = maxf(float(definition.get("attack_range_cells", 1.05)), 0.1)
	preferred_target = StringName(definition.get("preferred_target", &"any"))
	self_destructs = bool(definition.get("self_destructs", false))
	name = "%s_%d" % [kind, attacker_id]
	set_layout_metrics(board.board_origin, board.cell_size)
	queue_redraw()


func simulate(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	var active_target: Node2D = board.get_structure(active_target_id) if active_target_id != &"" else null
	var intended_target: Node2D = board.get_structure(intended_target_id) if intended_target_id != &"" else null
	if plan_dirty or intended_target == null or intended_target.destroyed or active_target == null or active_target.destroyed:
		_refresh_plan()
		active_target = board.get_structure(active_target_id) if active_target_id != &"" else null
	if active_target == null:
		return
	if _distance_to_structure(active_target) <= attack_range_cells:
		_try_attack(active_target)
		return
	_move_along_path(delta)


func mark_plan_dirty() -> void:
	plan_dirty = true


func apply_damage(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var previous := health
	health = maxf(health - amount, 0.0)
	queue_redraw()
	if health <= 0.0:
		_die()
	return previous - health


func set_layout_metrics(board_origin: Vector2, next_cell_size: float) -> void:
	cell_size = maxf(next_cell_size, 1.0)
	position = board_origin + (grid_position + Vector2(0.5, 0.5)) * cell_size
	queue_redraw()


func _refresh_plan() -> void:
	plan_dirty = false
	path.clear()
	path_index = 0
	var intended := _choose_intended_target()
	if intended == null:
		intended_target_id = &""
		active_target_id = &""
		return
	intended_target_id = intended.structure_id
	var start := _current_cell()
	var blocked: Array[Vector2i] = board.get_navigation_blocked_cells()
	var goals: Array[Vector2i] = RouterScript.get_adjacent_cells(intended.get_occupied_cells(), ArenaLayoutScript.GRID_SIZE)
	var direct_path: Array[Vector2i] = RouterScript.find_path(start, goals, blocked, ArenaLayoutScript.GRID_SIZE)
	if not direct_path.is_empty():
		active_target_id = intended_target_id
		path = direct_path
		path_index = mini(1, path.size())
		return

	var wall_plan := _choose_blocking_wall_plan(start, intended, blocked)
	if wall_plan.is_empty():
		active_target_id = intended_target_id
		return
	var wall: Node2D = wall_plan["wall"]
	active_target_id = wall.structure_id
	path = wall_plan["path"]
	path_index = mini(1, path.size())


func _choose_intended_target() -> Node2D:
	var candidates: Array[Node2D] = []
	if preferred_target == &"defenses":
		for structure in board.structures:
			if not structure.destroyed and (structure.kind == &"cannon" or structure.kind == &"mortar"):
				candidates.append(structure)
	if candidates.is_empty():
		for structure in board.structures:
			if not structure.destroyed and structure.counts_for_objective:
				candidates.append(structure)
	var best: Node2D
	var best_distance := INF
	for candidate in candidates:
		var candidate_distance := _distance_to_structure(candidate)
		if candidate_distance < best_distance:
			best = candidate
			best_distance = candidate_distance
	return best


func _choose_blocking_wall_plan(start: Vector2i, intended: Node2D, blocked: Array[Vector2i]) -> Dictionary:
	var best_plan: Dictionary = {}
	var best_score := 1_000_000
	for structure in board.structures:
		if structure.destroyed or structure.kind != &"wall":
			continue
		var wall_cells: Array[Vector2i] = structure.get_occupied_cells()
		var approach_cells: Array[Vector2i] = RouterScript.get_adjacent_cells(wall_cells, ArenaLayoutScript.GRID_SIZE)
		var wall_path: Array[Vector2i] = RouterScript.find_path(start, approach_cells, blocked, ArenaLayoutScript.GRID_SIZE)
		if wall_path.is_empty():
			continue
		var score := wall_path.size() + RouterScript.manhattan_to_cells(wall_cells[0], intended.get_occupied_cells())
		if score < best_score:
			best_score = score
			best_plan = {"wall": structure, "path": wall_path}
	return best_plan


func _move_along_path(delta: float) -> void:
	if path_index >= path.size():
		plan_dirty = true
		return
	var destination := Vector2(path[path_index])
	grid_position = grid_position.move_toward(destination, move_speed_cells * delta)
	if grid_position.distance_to(destination) <= 0.01:
		grid_position = destination
		path_index += 1
	set_layout_metrics(board.board_origin, board.cell_size)


func _try_attack(target: Node2D) -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = attack_interval
	var applied_damage := wall_damage if target.kind == &"wall" else damage
	target.apply_damage(applied_damage)
	structure_hit.emit(self, target, applied_damage)
	if self_destructs:
		_die()
	else:
		plan_dirty = target.destroyed


func _distance_to_structure(structure: Node2D) -> float:
	var best := INF
	for cell in structure.get_occupied_cells():
		best = minf(best, grid_position.distance_to(Vector2(cell)))
	return best


func _current_cell() -> Vector2i:
	return Vector2i(roundi(grid_position.x), roundi(grid_position.y))


func _die() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	queue_redraw()
	attacker_died.emit(self)


func _draw() -> void:
	var radius := cell_size * (0.32 if kind == &"brute" else 0.23)
	var body_color := COLOR_RAIDER
	if kind == &"brute":
		body_color = COLOR_BRUTE
	elif kind == &"sapper":
		body_color = COLOR_SAPPER
	if dead:
		body_color = body_color.darkened(0.65)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, COLOR_OUTLINE, maxf(cell_size * 0.045, 1.0), true)
	if kind == &"sapper":
		draw_line(Vector2(-radius * 0.55, 0.0), Vector2(radius * 0.55, 0.0), COLOR_TARGET, maxf(cell_size * 0.07, 2.0), true)
	if dead or health >= max_health:
		return
	var width := radius * 1.8
	var bar := Rect2(Vector2(-width * 0.5, -radius - cell_size * 0.13), Vector2(width, maxf(cell_size * 0.07, 3.0)))
	draw_rect(bar, COLOR_HEALTH_BACK, true)
	var fill := bar
	fill.size.x *= health / max_health
	draw_rect(fill, COLOR_HEALTH, true)
