class_name SiegeCombatController
extends Node2D

signal wave_started
signal wave_finished(result: StringName)
signal status_changed(text: String)

const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const AttackerScript = preload("res://siege_prototype/siege_attacker.gd")

const DEMO_WAVE: Array[Dictionary] = [
	{"kind": &"brute", "row": 5},
	{"kind": &"brute", "row": 6},
	{"kind": &"brute", "row": 10},
	{"kind": &"brute", "row": 11, "next_delay": 6.0},
	{"kind": &"sapper", "row": 6},
	{"kind": &"sapper", "row": 6},
	{"kind": &"sapper", "row": 8},
	{"kind": &"sapper", "row": 8},
	{"kind": &"sapper", "row": 10},
	{"kind": &"sapper", "row": 10},
	{"kind": &"raider", "row": 5},
	{"kind": &"raider", "row": 6},
	{"kind": &"raider", "row": 7},
	{"kind": &"raider", "row": 8},
	{"kind": &"raider", "row": 9},
	{"kind": &"raider", "row": 10},
	{"kind": &"sapper", "row": 11},
	{"kind": &"raider", "row": 11},
]

var board: Node2D
var attackers: Array[Node2D] = []
var pending_wave: Array[Dictionary] = []
var tower_cooldowns: Dictionary = {}
var tracers: Array[Dictionary] = []
var next_attacker_id := 1
var spawn_cooldown := 0.0
var spawn_interval := 0.62
var combat_speed := 1.0
var active := false
var result: StringName = &"idle"
var elapsed_time := 0.0


func _ready() -> void:
	board = get_node_or_null("../SiegeBoard")
	if board == null:
		return
	board.structure_topology_changed.connect(_on_structure_topology_changed)
	board.view_transform_changed.connect(_update_attacker_layout)
	get_viewport().size_changed.connect(_update_attacker_layout)
	set_physics_process(true)


func start_demo_wave() -> void:
	if board == null:
		return
	clear_attackers()
	board.reconstruct_blueprint()
	pending_wave = DEMO_WAVE.duplicate(true)
	tower_cooldowns.clear()
	tracers.clear()
	spawn_cooldown = 0.0
	elapsed_time = 0.0
	active = true
	result = &"running"
	status_changed.emit("Siege in progress · 18 attackers incoming")
	wave_started.emit()
	queue_redraw()


func reset_fortress() -> void:
	clear_attackers()
	pending_wave.clear()
	tracers.clear()
	active = false
	result = &"idle"
	elapsed_time = 0.0
	if board != null:
		board.reconstruct_blueprint()
	status_changed.emit("Fortress reconstructed · ready for attack")
	queue_redraw()


func clear_attackers() -> void:
	for attacker in attackers:
		if is_instance_valid(attacker):
			remove_child(attacker)
			attacker.queue_free()
	attackers.clear()


func set_combat_speed(multiplier: float) -> void:
	combat_speed = clampf(multiplier, 0.25, 4.0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	simulate_step(delta * combat_speed)


func simulate_step(delta: float) -> void:
	if not active or board == null or delta <= 0.0:
		return
	elapsed_time += delta
	_update_spawning(delta)
	for attacker in attackers.duplicate():
		if is_instance_valid(attacker) and not attacker.dead:
			attacker.simulate(delta)
	_update_towers(delta)
	_update_tracers(delta)
	_check_wave_end()


func _update_spawning(delta: float) -> void:
	spawn_cooldown -= delta
	while not pending_wave.is_empty() and spawn_cooldown <= 0.0:
		var entry: Dictionary = pending_wave.pop_front()
		_spawn_attacker(StringName(entry.get("kind", &"raider")), int(entry.get("row", 5)))
		spawn_cooldown += float(entry.get("next_delay", spawn_interval))


func _spawn_attacker(kind: StringName, row: int) -> Node2D:
	assert(AttackerCatalogScript.has_kind(kind), "Missing siege attacker definition for %s" % kind)
	var attacker: Node2D = AttackerScript.new()
	attacker.configure(next_attacker_id, kind, AttackerCatalogScript.get_definition(kind), Vector2i(0, clampi(row, 0, 9)), board)
	next_attacker_id += 1
	attacker.attacker_died.connect(_on_attacker_died)
	attacker.structure_hit.connect(_on_structure_hit)
	add_child(attacker)
	attackers.append(attacker)
	return attacker


func _update_towers(delta: float) -> void:
	for structure in board.structures:
		if structure.destroyed or structure.kind != &"cannon":
			continue
		var cooldown := maxf(float(tower_cooldowns.get(structure.structure_id, 0.0)) - delta, 0.0)
		if cooldown > 0.0:
			tower_cooldowns[structure.structure_id] = cooldown
			continue
		var target := _choose_tower_target(structure)
		if target == null:
			tower_cooldowns[structure.structure_id] = 0.0
			continue
		var tower_damage := float(structure.definition.get("attack_damage", 0.0))
		target.apply_damage(tower_damage)
		tower_cooldowns[structure.structure_id] = float(structure.definition.get("attack_interval", 1.0))
		tracers.append({
			"from": _structure_center_screen(structure),
			"to": target.position,
			"life": 0.11,
		})
		queue_redraw()


func _choose_tower_target(tower: Node2D) -> Node2D:
	var tower_center := _structure_center_grid(tower)
	var range_cells := float(tower.definition.get("attack_range_cells", 0.0))
	var best: Node2D
	var best_distance := INF
	for attacker in attackers:
		if not is_instance_valid(attacker) or attacker.dead:
			continue
		var distance := tower_center.distance_to(attacker.grid_position)
		if distance <= range_cells and distance < best_distance:
			best = attacker
			best_distance = distance
	return best


func _update_tracers(delta: float) -> void:
	for index in range(tracers.size() - 1, -1, -1):
		tracers[index]["life"] = float(tracers[index]["life"]) - delta
		if float(tracers[index]["life"]) <= 0.0:
			tracers.remove_at(index)
	if not tracers.is_empty():
		queue_redraw()


func _check_wave_end() -> void:
	if board.get_remaining_integrity() <= 0:
		_finish_wave(&"attackers")
	elif pending_wave.is_empty() and attackers.is_empty():
		_finish_wave(&"defenders")
	elif elapsed_time >= 45.0:
		_finish_wave(&"defenders")


func _finish_wave(winner: StringName) -> void:
	if not active:
		return
	active = false
	result = winner
	if winner == &"attackers":
		status_changed.emit("Fortress breached · attackers destroyed every objective")
	else:
		status_changed.emit("Fortress held · reconstruct to run the siege again")
	wave_finished.emit(winner)


func _on_attacker_died(attacker: Node2D) -> void:
	attackers.erase(attacker)
	if is_instance_valid(attacker):
		attacker.queue_free()


func _on_structure_hit(attacker: Node2D, structure: Node2D, _damage: float) -> void:
	tracers.append({
		"from": attacker.position,
		"to": _structure_center_screen(structure),
		"life": 0.09,
	})
	queue_redraw()


func _on_structure_topology_changed() -> void:
	for attacker in attackers:
		if is_instance_valid(attacker):
			attacker.mark_plan_dirty()


func _update_attacker_layout() -> void:
	if board == null:
		return
	for attacker in attackers:
		if is_instance_valid(attacker):
			attacker.set_layout_metrics(board.board_origin, board.cell_size)


func _structure_center_grid(structure: Node2D) -> Vector2:
	return Vector2(structure.grid_cell) + Vector2(structure.footprint) * 0.5 - Vector2(0.5, 0.5)


func _structure_center_screen(structure: Node2D) -> Vector2:
	return board.board_origin + (_structure_center_grid(structure) + Vector2(0.5, 0.5)) * board.cell_size


func _draw() -> void:
	for tracer in tracers:
		var alpha := clampf(float(tracer.get("life", 0.0)) / 0.11, 0.0, 1.0)
		draw_line(Vector2(tracer["from"]), Vector2(tracer["to"]), Color(1.0, 0.82, 0.34, alpha), 3.0, true)
