class_name SiegeAttacker
extends Node2D

signal attacker_died(attacker: Node)
signal structure_hit(attacker: Node, structure: Node, damage: float)

const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")
const RouterScript = preload("res://siege_prototype/siege_grid_router.gd")

const COLOR_RAIDER := Color("4ca66a")
const COLOR_BRUTE := Color("5878b8")
const COLOR_SAPPER := Color("d68637")
const COLOR_RANGER := Color("9b63b6")
const COLOR_BOMBER := Color("9b493d")
const COLOR_MAGE := Color("4d8ac8")
const COLOR_OUTLINE := Color("252522")
const COLOR_HEALTH := Color("62bd69")
const COLOR_HEALTH_BACK := Color("252522")
const COLOR_TARGET := Color("f3d166")
const TARGET_CANDIDATE_COUNT := 3

var attacker_id: int
var kind: StringName
var definition: Dictionary = {}
var board: Node2D
var grid_position := Vector2.ZERO
var max_health := 1.0
var health := 1.0
var damage := 1.0
var wall_damage := 1.0
var death_damage := 0.0
var death_wall_damage := 0.0
var death_damage_radius_cells := 0.0
var splash_radius_cells := 0.0
var attack_interval := 1.0
var move_speed_cells := 1.0
var attack_range_cells := 1.05
var preferred_target: StringName = &"any"
var movement_type: StringName = &"ground"
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
	death_damage = float(definition.get("death_damage", 0.0))
	death_wall_damage = float(definition.get("death_wall_damage", death_damage))
	death_damage_radius_cells = float(definition.get("death_damage_radius_cells", 0.0))
	splash_radius_cells = float(definition.get("splash_radius_cells", 0.0))
	attack_interval = maxf(float(definition.get("attack_interval", 1.0)), 0.05)
	move_speed_cells = maxf(float(definition.get("move_speed_cells", 1.0)), 0.05)
	attack_range_cells = maxf(float(definition.get("attack_range_cells", 1.05)), 0.1)
	preferred_target = StringName(definition.get("preferred_target", &"any"))
	movement_type = StringName(definition.get("movement_type", &"ground"))
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
	if intended_target == null or intended_target.destroyed:
		_refresh_plan(true)
		active_target = board.get_structure(active_target_id) if active_target_id != &"" else null
	elif plan_dirty or active_target == null or active_target.destroyed:
		_refresh_plan(false)
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


func _refresh_plan(force_retarget: bool) -> void:
	plan_dirty = false
	path.clear()
	path_index = 0
	var plan: Dictionary = {}
	var committed_target: Node2D = board.get_structure(intended_target_id) if intended_target_id != &"" else null
	if not force_retarget and committed_target != null and not committed_target.destroyed:
		plan = _build_plan_for_target(committed_target, _get_protective_wall_cells())
	if plan.is_empty():
		plan = _choose_target_plan()
	if plan.is_empty():
		intended_target_id = &""
		active_target_id = &""
		return
	var intended: Node2D = plan["target"]
	intended_target_id = intended.structure_id
	var active: Node2D = plan.get("active_target", intended)
	active_target_id = active.structure_id
	path.assign(plan.get("path", []))
	path_index = mini(1, path.size())


func _choose_target_plan() -> Dictionary:
	var candidates: Array[Node2D] = []
	if preferred_target == &"defenses":
		for structure in board.structures:
			if not structure.destroyed and bool(structure.definition.get("is_defense", false)):
				candidates.append(structure)
	if candidates.is_empty():
		for structure in board.structures:
			if not structure.destroyed and structure.counts_for_objective:
				candidates.append(structure)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool: return _distance_to_structure(a) < _distance_to_structure(b))
	var considered_plans: Array[Dictionary] = []
	var sapper_wall_fallbacks: Array[Dictionary] = []
	var sapper_building_fallbacks: Array[Dictionary] = []
	var protective_wall_cells := _get_protective_wall_cells()
	# Normal troops use Clash's rule of three literally: route only among the
	# three closest eligible buildings. Wall Breakers instead keep looking for
	# the nearest building protected by a meaningful connected wall group.
	var candidate_limit := candidates.size() if kind == &"sapper" else mini(TARGET_CANDIDATE_COUNT, candidates.size())
	for index in candidate_limit:
		var candidate := candidates[index]
		var plan := _build_plan_for_target(candidate, protective_wall_cells)
		if plan.is_empty():
			continue
		if kind == &"sapper":
			if bool(plan.get("crosses_protective_wall", false)):
				considered_plans.append(plan)
				if considered_plans.size() >= TARGET_CANDIDATE_COUNT:
					break
			elif bool(plan.get("crosses_wall", false)):
				sapper_wall_fallbacks.append(plan)
			else:
				sapper_building_fallbacks.append(plan)
			continue
		considered_plans.append(plan)
	if considered_plans.is_empty() and kind == &"sapper":
		# Ignore isolated decoy pieces while a three-piece wall group protects a
		# building. If no such group exists, retain fallbacks so no-timer rounds
		# can always resolve instead of leaving a Wall Breaker permanently idle.
		considered_plans = sapper_wall_fallbacks if not sapper_wall_fallbacks.is_empty() else sapper_building_fallbacks
	var best_plan: Dictionary = {}
	var best_cost := INF
	for plan in considered_plans:
		var plan_cost := float(plan.get("cost", INF))
		if plan_cost < best_cost:
			best_cost = plan_cost
			best_plan = plan
	return best_plan


func _build_plan_for_target(target: Node2D, protective_wall_cells: Dictionary = {}) -> Dictionary:
	if target == null or target.destroyed:
		return {}
	var hard_blocked: Array[Vector2i] = []
	var wall_costs: Dictionary = {}
	var wall_by_cell: Dictionary = {}
	if movement_type == &"air":
		# Flying troops cross Walls, terrain, and other structures. The intended
		# target footprint alone stays closed so they stop at its attack perimeter.
		hard_blocked.append_array(target.get_occupied_cells())
	else:
		for structure in board.structures:
			if structure.destroyed or not structure.blocks_movement:
				continue
			if structure.kind == &"wall":
				var wall_equivalent_cost := _wall_break_cost_in_tiles(structure.health)
				for cell in structure.get_occupied_cells():
					wall_costs[cell] = wall_equivalent_cost
					wall_by_cell[cell] = structure
			else:
				hard_blocked.append_array(structure.get_occupied_cells())
		for terrain_cell in ArenaLayoutScript.STATIC_TERRAIN:
			if not hard_blocked.has(terrain_cell):
				hard_blocked.append(terrain_cell)
	var goals := _get_attack_goal_cells(target, hard_blocked, wall_costs)
	var route := RouterScript.find_weighted_path(_current_cell(), goals, hard_blocked, wall_costs, ArenaLayoutScript.GRID_SIZE)
	if route.is_empty():
		return {}
	var full_path: Array[Vector2i] = []
	full_path.assign(route.get("path", []))
	var crossed_walls: Array[Vector2i] = []
	crossed_walls.assign(route.get("crossed_walls", []))
	var active_target: Node2D = target
	var movement_path: Array[Vector2i] = full_path
	var crosses_protective_wall := false
	for crossed_cell in crossed_walls:
		if protective_wall_cells.has(crossed_cell):
			crosses_protective_wall = true
			break
	if not crossed_walls.is_empty():
		active_target = wall_by_cell.get(crossed_walls[0])
		movement_path = []
		for cell in full_path:
			if cell == crossed_walls[0]:
				break
			movement_path.append(cell)
	return {
		"target": target,
		"active_target": active_target,
		"path": movement_path,
		"cost": float(route.get("cost", INF)),
		"crosses_wall": not crossed_walls.is_empty(),
		"crosses_protective_wall": crosses_protective_wall,
	}


func _get_attack_goal_cells(target: Node2D, hard_blocked: Array[Vector2i], wall_costs: Dictionary) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	occupied.assign(target.get_occupied_cells())
	var min_cell: Vector2i = occupied[0]
	var max_cell: Vector2i = occupied[0]
	for cell in occupied:
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	var margin := ceili(attack_range_cells + 1.0)
	var goals: Array[Vector2i] = []
	for x in range(maxi(0, min_cell.x - margin), mini(ArenaLayoutScript.GRID_SIZE.x - 1, max_cell.x + margin) + 1):
		for y in range(maxi(0, min_cell.y - margin), mini(ArenaLayoutScript.GRID_SIZE.y - 1, max_cell.y + margin) + 1):
			var candidate := Vector2i(x, y)
			if hard_blocked.has(candidate):
				continue
			if _distance_from_position_to_structure(Vector2(candidate), target) > attack_range_cells + 0.001:
				continue
			# Ranged units can fire over Walls. Melee units must either stand on the
			# blocking Wall cell (and breach it) or have a clear contact line.
			if attack_range_cells <= 1.05 and not wall_costs.has(candidate):
				var has_clear_contact := false
				for target_cell in occupied:
					if _edge_distance_between_cells(candidate, target_cell) <= attack_range_cells + 0.001 and not _wall_between_cells(candidate, target_cell, wall_costs):
						has_clear_contact = true
						break
				if not has_clear_contact:
					continue
			goals.append(candidate)
	return goals


func _wall_between_cells(from_cell: Vector2i, to_cell: Vector2i, wall_costs: Dictionary) -> bool:
	var delta := to_cell - from_cell
	var steps := maxi(absi(delta.x), absi(delta.y))
	if steps <= 1:
		return false
	for step in range(1, steps):
		var progress := float(step) / float(steps)
		var sample := Vector2i(Vector2(from_cell).lerp(Vector2(to_cell), progress).round())
		if wall_costs.has(sample):
			return true
	return false


func _edge_distance_between_cells(first: Vector2i, second: Vector2i) -> float:
	var delta := (Vector2(first) - Vector2(second)).abs()
	return Vector2(maxf(delta.x - 1.0, 0.0), maxf(delta.y - 1.0, 0.0)).length()


func _get_protective_wall_cells() -> Dictionary:
	var unvisited: Dictionary = {}
	for structure in board.structures:
		if structure.destroyed or structure.kind != &"wall":
			continue
		for cell in structure.get_occupied_cells():
			unvisited[cell] = true
	var protective: Dictionary = {}
	while not unvisited.is_empty():
		var seed := Vector2i(unvisited.keys()[0])
		var frontier: Array[Vector2i] = [seed]
		var component: Array[Vector2i] = []
		unvisited.erase(seed)
		while not frontier.is_empty():
			var current: Vector2i = frontier.pop_back()
			component.append(current)
			for direction in RouterScript.CARDINAL_DIRECTIONS:
				var neighbor: Vector2i = current + direction
				if unvisited.has(neighbor):
					unvisited.erase(neighbor)
					frontier.append(neighbor)
		if component.size() >= 3:
			for cell in component:
				protective[cell] = true
	return protective


func _wall_break_cost_in_tiles(wall_health: float) -> float:
	var wall_dps := wall_damage / attack_interval
	if wall_dps <= 0.0:
		return 1_000_000.0
	return maxf(wall_health, 0.0) / wall_dps * move_speed_cells


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
	_apply_attack_damage(target, applied_damage)
	structure_hit.emit(self, target, applied_damage)
	if self_destructs:
		_die()
	else:
		plan_dirty = target.destroyed


func _apply_attack_damage(primary_target: Node2D, primary_damage: float) -> void:
	primary_target.apply_damage(primary_damage)
	if splash_radius_cells <= 0.0:
		return
	var impact_position := Vector2(primary_target.grid_cell) + Vector2(primary_target.footprint) * 0.5 - Vector2(0.5, 0.5)
	for structure in board.structures:
		if structure == primary_target or structure.destroyed:
			continue
		if _distance_from_position_to_structure(impact_position, structure) > splash_radius_cells:
			continue
		structure.apply_damage(wall_damage if structure.kind == &"wall" else damage)


func _distance_to_structure(structure: Node2D) -> float:
	return _distance_from_position_to_structure(grid_position, structure)


func _distance_from_position_to_structure(from_position: Vector2, structure: Node2D) -> float:
	var best := INF
	for cell in structure.get_occupied_cells():
		# Measure between tile edges rather than centers. This makes cardinal and
		# diagonal contact both zero-distance and lets ranged units stop at their
		# real firing perimeter instead of routing all the way to the building.
		var delta := (from_position - Vector2(cell)).abs()
		var edge_delta := Vector2(maxf(delta.x - 1.0, 0.0), maxf(delta.y - 1.0, 0.0))
		best = minf(best, edge_delta.length())
	return best


func _current_cell() -> Vector2i:
	return Vector2i(roundi(grid_position.x), roundi(grid_position.y))


func _die() -> void:
	if dead:
		return
	_apply_death_damage()
	dead = true
	health = 0.0
	queue_redraw()
	attacker_died.emit(self)


func _apply_death_damage() -> void:
	if death_damage_radius_cells <= 0.0 or board == null:
		return
	for structure in board.structures:
		if structure.destroyed:
			continue
		var distance := INF
		for cell in structure.get_occupied_cells():
			distance = minf(distance, grid_position.distance_to(Vector2(cell)))
		if distance > death_damage_radius_cells:
			continue
		var explosion_damage := death_wall_damage if structure.kind == &"wall" else death_damage
		structure.apply_damage(explosion_damage)


func _draw() -> void:
	var radius := cell_size * (0.32 if kind == &"brute" or kind == &"bomber" else 0.23)
	var body_color := COLOR_RAIDER
	if kind == &"brute":
		body_color = COLOR_BRUTE
	elif kind == &"sapper":
		body_color = COLOR_SAPPER
	elif kind == &"ranger":
		body_color = COLOR_RANGER
	elif kind == &"bomber":
		body_color = COLOR_BOMBER
	elif kind == &"mage":
		body_color = COLOR_MAGE
	if dead:
		body_color = body_color.darkened(0.65)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, COLOR_OUTLINE, maxf(cell_size * 0.045, 1.0), true)
	if kind == &"sapper":
		draw_line(Vector2(-radius * 0.55, 0.0), Vector2(radius * 0.55, 0.0), COLOR_TARGET, maxf(cell_size * 0.07, 2.0), true)
	elif kind == &"ranger":
		draw_arc(Vector2.ZERO, radius * 0.65, -PI * 0.6, PI * 0.6, 10, COLOR_TARGET, maxf(cell_size * 0.05, 1.0), true)
	elif kind == &"bomber":
		draw_line(Vector2(-radius * 0.65, radius * 0.15), Vector2(radius * 0.65, radius * 0.15), COLOR_TARGET, maxf(cell_size * 0.06, 1.0), true)
		draw_circle(Vector2(0.0, -radius * 0.35), radius * 0.22, COLOR_TARGET)
	elif kind == &"mage":
		draw_circle(Vector2.ZERO, radius * 0.34, COLOR_TARGET)
	if dead or health >= max_health:
		return
	var width := radius * 1.8
	var bar := Rect2(Vector2(-width * 0.5, -radius - cell_size * 0.13), Vector2(width, maxf(cell_size * 0.07, 3.0)))
	draw_rect(bar, COLOR_HEALTH_BACK, true)
	var fill := bar
	fill.size.x *= health / max_health
	draw_rect(fill, COLOR_HEALTH, true)
