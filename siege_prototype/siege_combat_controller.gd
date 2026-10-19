class_name SiegeCombatController
extends Node2D

signal wave_started
signal wave_finished(result: StringName)
signal status_changed(text: String)

const AttackerCatalogScript = preload("res://siege_prototype/siege_attacker_catalog.gd")
const AttackerScript = preload("res://siege_prototype/siege_attacker.gd")
const ArenaLayoutScript = preload("res://siege_prototype/siege_arena_layout.gd")

const DEMO_ATTACKER_COUNT := 48

var board: Node2D
var attackers: Array[Node2D] = []
var pending_wave: Array[Dictionary] = []
var tower_cooldowns: Dictionary = {}
var tower_targets: Dictionary = {}
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
	start_wave(_build_demo_wave(), "TH6 benchmark")


func start_wave(wave: Array[Dictionary], wave_label := "Run attack") -> void:
	if board == null:
		return
	clear_attackers()
	board.reconstruct_blueprint()
	pending_wave = wave.duplicate(true)
	tower_cooldowns.clear()
	tower_targets.clear()
	tracers.clear()
	spawn_cooldown = 0.0
	elapsed_time = 0.0
	active = true
	result = &"running"
	status_changed.emit("%s · %d attackers incoming" % [wave_label, pending_wave.size()])
	wave_started.emit()
	queue_redraw()


func reset_fortress() -> void:
	clear_attackers()
	pending_wave.clear()
	tower_cooldowns.clear()
	tower_targets.clear()
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
	tower_targets.clear()


func _build_demo_wave() -> Array[Dictionary]:
	var wave: Array[Dictionary] = []
	# Giants lead and hold defensive fire while Wall Breakers approach. This
	# changes army composition only; every unit retains its exact TH6 stats.
	for index in 12:
		wave.append({"kind": &"brute", "row": 15 + index})
	wave[-1]["next_delay"] = 2.0
	for index in 12:
		wave.append({"kind": &"sapper", "row": 15 + index})
	for index in 24:
		wave.append({"kind": &"raider", "row": 15 + index % 12})
	return wave


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
	_apply_unit_separation()
	_update_towers(delta)
	_update_tracers(delta)
	_check_wave_end()


func _update_spawning(delta: float) -> void:
	spawn_cooldown -= delta
	while not pending_wave.is_empty() and spawn_cooldown <= 0.0:
		var entry: Dictionary = pending_wave.pop_front()
		_spawn_attacker(StringName(entry.get("kind", &"raider")), int(entry.get("row", 5)), int(entry.get("level", -1)))
		spawn_cooldown += float(entry.get("next_delay", spawn_interval))


func _spawn_attacker(kind: StringName, row: int, level := -1) -> Node2D:
	assert(AttackerCatalogScript.has_kind(kind), "Missing siege attacker definition for %s" % kind)
	var attacker: Node2D = AttackerScript.new()
	attacker.configure(next_attacker_id, kind, AttackerCatalogScript.get_definition(kind, level), Vector2i(0, clampi(row, 0, ArenaLayoutScript.GRID_SIZE.y - 1)), board)
	next_attacker_id += 1
	attacker.attacker_died.connect(_on_attacker_died)
	attacker.structure_hit.connect(_on_structure_hit)
	add_child(attacker)
	attackers.append(attacker)
	return attacker


func _update_towers(delta: float) -> void:
	for structure in board.structures:
		if structure.destroyed or not bool(structure.definition.get("can_attack", structure.definition.get("is_defense", false))):
			continue
		if StringName(structure.definition.get("target_type", &"ground")) == &"air":
			continue
		if float(structure.definition.get("attack_damage", 0.0)) <= 0.0:
			continue
		var cooldown := maxf(float(tower_cooldowns.get(structure.structure_id, 0.0)) - delta, 0.0)
		if cooldown > 0.0:
			tower_cooldowns[structure.structure_id] = cooldown
			continue
		# Cache stable attacker IDs, never Node references. A killed attacker can be
		# queued for deletion between physics frames; assigning that freed Object
		# from a Dictionary to a typed Node2D caused the Android battle freeze.
		var cached_attacker_id := int(tower_targets.get(structure.structure_id, -1))
		var target: Node2D = _get_living_attacker(cached_attacker_id)
		if not _tower_target_is_valid(structure, target):
			target = _choose_tower_target(structure)
			if target == null:
				tower_targets.erase(structure.structure_id)
			else:
				tower_targets[structure.structure_id] = target.attacker_id
		if target == null:
			tower_cooldowns[structure.structure_id] = 0.0
			continue
		_apply_tower_damage(structure, target)
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
	var minimum_range := float(tower.definition.get("minimum_range_cells", 0.0))
	var best: Node2D
	var best_distance := INF
	for attacker in attackers:
		if not is_instance_valid(attacker) or attacker.dead:
			continue
		var distance := tower_center.distance_to(attacker.grid_position)
		if distance >= minimum_range and distance <= range_cells and distance < best_distance:
			best = attacker
			best_distance = distance
	return best


func _tower_target_is_valid(tower: Node2D, target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or target.dead:
		return false
	var distance := _structure_center_grid(tower).distance_to(target.grid_position)
	var range_cells := float(tower.definition.get("attack_range_cells", 0.0))
	var minimum_range := float(tower.definition.get("minimum_range_cells", 0.0))
	return distance >= minimum_range and distance <= range_cells


func _get_living_attacker(attacker_id: int) -> Node2D:
	if attacker_id < 0:
		return null
	for attacker in attackers:
		if is_instance_valid(attacker) and not attacker.dead and attacker.attacker_id == attacker_id:
			return attacker
	return null


func _apply_unit_separation() -> void:
	var living: Array[Node2D] = []
	for attacker in attackers:
		if is_instance_valid(attacker) and not attacker.dead:
			living.append(attacker)
	var blocked: Array[Vector2i] = board.get_navigation_blocked_cells()
	for first_index in living.size():
		for second_index in range(first_index + 1, living.size()):
			var first := living[first_index]
			var second := living[second_index]
			var offset: Vector2 = second.grid_position - first.grid_position
			var distance := offset.length()
			var minimum_distance := 0.52 if first.kind == &"brute" or second.kind == &"brute" else 0.40
			if distance >= minimum_distance:
				continue
			var direction := offset / distance if distance > 0.001 else Vector2.UP.rotated(float(first.attacker_id % 8) * PI / 4.0)
			var correction := direction * (minimum_distance - distance) * 0.28
			_try_nudge_attacker(first, -correction, blocked)
			_try_nudge_attacker(second, correction, blocked)


func _try_nudge_attacker(attacker: Node2D, offset: Vector2, blocked: Array[Vector2i]) -> void:
	var candidate: Vector2 = attacker.grid_position + offset
	candidate.x = clampf(candidate.x, 0.0, float(ArenaLayoutScript.GRID_SIZE.x - 1))
	candidate.y = clampf(candidate.y, 0.0, float(ArenaLayoutScript.GRID_SIZE.y - 1))
	var candidate_cell := Vector2i(roundi(candidate.x), roundi(candidate.y))
	if blocked.has(candidate_cell):
		return
	attacker.grid_position = candidate
	attacker.set_layout_metrics(board.board_origin, board.cell_size)


func _apply_tower_damage(tower: Node2D, primary_target: Node2D) -> void:
	var damage := float(tower.definition.get("attack_damage", 0.0))
	var splash_radius := float(tower.definition.get("splash_radius_cells", 0.0))
	if splash_radius <= 0.0:
		primary_target.apply_damage(damage)
		return
	var impact_position: Vector2 = primary_target.grid_position
	for attacker in attackers.duplicate():
		if is_instance_valid(attacker) and not attacker.dead and attacker.grid_position.distance_to(impact_position) <= splash_radius:
			attacker.apply_damage(damage)


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
	for tower_id in tower_targets.keys():
		if int(tower_targets.get(tower_id, -1)) == attacker.attacker_id:
			tower_targets.erase(tower_id)
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
