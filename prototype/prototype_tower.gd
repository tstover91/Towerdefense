class_name PrototypeTower
extends Node2D

signal damage_dealt(tower_type: StringName, tower_level: int, amount: int)

const ProjectileScript = preload("res://prototype/prototype_projectile.gd")

const TYPE_GUNSLINGER: StringName = &"gunslinger"
const TYPE_ANTI_MATERIEL: StringName = &"anti_materiel"
const TYPE_FLAMESPITTER: StringName = &"flamespitter"
const TYPE_BOMBARDMENT: StringName = &"bombardment"
const TYPE_ATOMIC_STRIKE: StringName = &"atomic_strike"

const TARGET_FIRST: StringName = &"first"
const TARGET_HIGHEST_HP: StringName = &"highest_hp"
const TARGET_DENSEST: StringName = &"densest"

const TARGET_SCAN_INTERVAL := 0.10
const PARTICIPATED_SELL_RATIO := 0.70
const PIERCE_DAMAGE_LOSS_PER_ENEMY := 0.30
const PIERCE_MINIMUM_DAMAGE_MULTIPLIER := 0.40
const PIERCE_LINE_HALF_WIDTH_CELLS := 0.08
const SHOT_TRACE_DURATION := 0.07
const BOMBARDMENT_SHELL_STAGGER := 0.22

const TYPE_DATA := {
	TYPE_GUNSLINGER: {
		"name": "GUNSLINGER",
		"cost": 150,
		"upgrade_costs": [50, 300, 900],
		"color": Color("e84f3d"),
		"target_mode": TARGET_FIRST,
		"locks_target": false,
		"ignores_armor": false,
		"stats": [
			{"damage": 8, "interval": 0.80, "range_cells": 2.5, "pierce": 0},
			{"damage": 8, "interval": 0.60, "range_cells": 2.6, "pierce": 0},
			{"damage": 18, "interval": 0.45, "range_cells": 2.8, "pierce": 1},
			{"damage": 36, "interval": 0.40, "range_cells": 3.1, "pierce": 1},
		],
	},
	TYPE_ANTI_MATERIEL: {
		"name": "ANTI-MATERIEL",
		"cost": 350,
		"upgrade_costs": [150, 600, 1800],
		"color": Color("efb83d"),
		"target_mode": TARGET_HIGHEST_HP,
		"locks_target": true,
		"ignores_armor": true,
		"stats": [
			{"damage": 28, "interval": 2.20, "range_cells": 3.3, "pierce": 1},
			{"damage": 36, "interval": 2.00, "range_cells": 3.4, "pierce": 1},
			{"damage": 75, "interval": 1.80, "range_cells": 3.6, "pierce": 1},
			{"damage": 180, "interval": 1.55, "range_cells": 4.0, "pierce": 1},
		],
	},
	TYPE_FLAMESPITTER: {
		"name": "FLAMESPITTER",
		"cost": 150,
		"upgrade_costs": [50, 300, 900],
		"color": Color("e85b2a"),
		"target_mode": TARGET_FIRST,
		"locks_target": false,
		"ignores_armor": false,
		"stats": [
			{"damage": 2, "interval": 1.20, "range_cells": 1.8, "pierce": 0, "cone_degrees": 60.0, "target_limit": 3, "spray_ticks": 3, "tick_interval": 0.18, "spray_gap": 0.84, "continuous": false},
			{"damage": 2, "interval": 0.86, "range_cells": 1.9, "pierce": 0, "cone_degrees": 65.0, "target_limit": 4, "spray_ticks": 3, "tick_interval": 0.18, "spray_gap": 0.50, "continuous": false},
			{"damage": 4, "interval": 0.85, "range_cells": 2.0, "pierce": 0, "cone_degrees": 82.0, "target_limit": 5, "spray_ticks": 4, "tick_interval": 0.15, "spray_gap": 0.40, "continuous": false},
			{"damage": 5, "interval": 0.12, "range_cells": 2.2, "pierce": 0, "cone_degrees": 90.0, "target_limit": 6, "spray_ticks": 0, "tick_interval": 0.12, "spray_gap": 0.0, "continuous": true},
		],
	},
	TYPE_BOMBARDMENT: {
		"name": "BOMBARDMENT",
		"cost": 350,
		"upgrade_costs": [150, 600, 1800],
		"color": Color("d83a26"),
		"target_mode": TARGET_DENSEST,
		"locks_target": false,
		"ignores_armor": false,
		"stats": [
			{"damage": 20, "interval": 2.00, "range_cells": 3.2, "pierce": 0, "splash_cells": 0.90, "shells": 1, "stun": 0.0},
			{"damage": 24, "interval": 1.80, "range_cells": 3.4, "pierce": 0, "splash_cells": 1.05, "shells": 1, "stun": 0.0},
			{"damage": 38, "interval": 2.10, "range_cells": 3.5, "pierce": 0, "splash_cells": 1.10, "shells": 2, "stun": 0.0},
			{"damage": 70, "interval": 2.40, "range_cells": 3.7, "pierce": 0, "splash_cells": 1.20, "shells": 3, "stun": 0.40},
		],
	},
	TYPE_ATOMIC_STRIKE: {
		"name": "ATOMIC STRIKE",
		"cost": 500,
		"upgrade_costs": [200, 800, 2400],
		"color": Color("f06a24"),
		"target_mode": TARGET_DENSEST,
		"locks_target": false,
		"ignores_armor": false,
		"stats": [
			{"damage": 40, "interval": 5.00, "range_cells": 3.4, "pierce": 0, "splash_cells": 1.10, "hazard_duration": 0.0, "hazard_tick": 0.5, "hazard_damage": 0},
			{"damage": 55, "interval": 4.80, "range_cells": 3.5, "pierce": 0, "splash_cells": 1.20, "hazard_duration": 0.0, "hazard_tick": 0.5, "hazard_damage": 0},
			{"damage": 120, "interval": 4.50, "range_cells": 3.7, "pierce": 0, "splash_cells": 1.35, "hazard_duration": 0.0, "hazard_tick": 0.5, "hazard_damage": 0},
			{"damage": 270, "interval": 4.20, "range_cells": 4.0, "pierce": 0, "splash_cells": 1.50, "hazard_duration": 3.0, "hazard_tick": 0.5, "hazard_damage": 4},
		],
	},
}

const BODY_DARK := Color("171717")
const BODY_LIGHT := Color("f1ead8")
const RANGE_COLOR := Color(0.91, 0.31, 0.24, 0.12)
const RANGE_EDGE_COLOR := Color(0.91, 0.31, 0.24, 0.45)

var grid_cell := Vector2i.ZERO
var tower_type: StringName = TYPE_GUNSLINGER
var level := 1
var selected := false
var cell_size_provider: Callable
var attack_cooldown := 0.0
var target_scan_remaining := 0.0
var target: Node2D
var aim_direction := Vector2.RIGHT
var total_investment := 0
var has_participated := false
var shot_trace_remaining := 0.0
var shot_trace_end := Vector2.ZERO
var flame_spray_active := false
var flame_ticks_remaining := 0
var flame_tick_remaining := 0.0
var bombardment_shells_remaining := 0
var bombardment_shell_timer := 0.0
var bombardment_impact_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


static func get_build_cost(type: StringName) -> int:
	return int(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUNSLINGER])["cost"])


static func get_type_name(type: StringName) -> String:
	return String(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUNSLINGER])["name"])


static func get_base_range(type: StringName) -> float:
	return float(TYPE_DATA.get(type, TYPE_DATA[TYPE_GUNSLINGER])["stats"][0]["range_cells"])


func configure(new_grid_cell: Vector2i, new_cell_size_provider: Callable, new_tower_type: StringName = TYPE_GUNSLINGER) -> void:
	grid_cell = new_grid_cell
	cell_size_provider = new_cell_size_provider
	tower_type = new_tower_type if TYPE_DATA.has(new_tower_type) else TYPE_GUNSLINGER
	total_investment = get_build_cost(tower_type)
	queue_redraw()


func _process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	target_scan_remaining = maxf(target_scan_remaining - delta, 0.0)
	shot_trace_remaining = maxf(shot_trace_remaining - delta, 0.0)
	_process_flame_spray(delta)
	_process_bombardment_salvo(delta)
	if not _is_valid_target(target) or not _is_target_in_range(target):
		_set_target(null)
	if target_scan_remaining <= 0.0 and (target == null or not _locks_target()):
		target_scan_remaining = TARGET_SCAN_INTERVAL
		_set_target(_select_target())
	if _is_valid_target(target):
		var offset := target.global_position - global_position
		if not offset.is_zero_approx():
			aim_direction = offset.normalized()
		if attack_cooldown <= 0.0 and not flame_spray_active and bombardment_shells_remaining <= 0:
			if not _locks_target():
				_set_target(_select_target())
			if _is_valid_target(target):
				_fire_at(target)
	queue_redraw()


func _set_target(new_target: Node2D) -> void:
	target = new_target


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func can_upgrade() -> bool:
	return level < _get_level_stats_array().size()


func get_next_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var upgrade_costs: Array = TYPE_DATA[tower_type]["upgrade_costs"]
	return int(upgrade_costs[level - 1])


func upgrade(paid_cost: int) -> bool:
	if not can_upgrade() or paid_cost != get_next_upgrade_cost():
		return false
	level += 1
	total_investment += paid_cost
	attack_cooldown = minf(attack_cooldown, get_attack_interval())
	flame_spray_active = false
	flame_ticks_remaining = 0
	bombardment_shells_remaining = 0
	queue_redraw()
	return true


func mark_participated() -> void:
	has_participated = true


func get_sell_refund() -> int:
	return total_investment if not has_participated else floori(float(total_investment) * PARTICIPATED_SELL_RATIO)


func _get_level_stats_array() -> Array:
	return TYPE_DATA[tower_type]["stats"]


func _get_stats() -> Dictionary:
	return _get_level_stats_array()[level - 1]


func get_damage() -> int:
	return int(_get_stats()["damage"])


func get_attack_interval() -> float:
	return float(_get_stats()["interval"])


func get_range_cells() -> float:
	return float(_get_stats()["range_cells"])


func get_pierce_count() -> int:
	return int(_get_stats().get("pierce", 0))


func get_splash_cells() -> float:
	return float(_get_stats().get("splash_cells", 0.0))


func get_cone_degrees() -> float:
	return float(_get_stats().get("cone_degrees", 0.0))


func get_target_limit() -> int:
	return int(_get_stats().get("target_limit", 1))


func get_shell_count() -> int:
	return int(_get_stats().get("shells", 1))


func get_range_pixels() -> float:
	return get_range_cells() * get_cell_size()


func get_cell_size() -> float:
	return maxf(float(cell_size_provider.call()), 1.0) if cell_size_provider.is_valid() else 48.0


func get_summary() -> String:
	var targeting := "FIRST"
	if _get_target_mode() == TARGET_HIGHEST_HP:
		targeting = "HIGHEST HP · LOCK"
	elif _get_target_mode() == TARGET_DENSEST:
		targeting = "DENSEST"
	var pierce_text := " · PIERCE %d" % get_pierce_count() if get_pierce_count() > 0 else ""
	var behavior_text := pierce_text
	if tower_type == TYPE_FLAMESPITTER:
		behavior_text = " · %.0f° CONE · HITS %d" % [get_cone_degrees(), get_target_limit()]
	elif tower_type == TYPE_BOMBARDMENT:
		behavior_text = " · %d SHELL%s" % [get_shell_count(), "S" if get_shell_count() != 1 else ""]
	elif tower_type == TYPE_ATOMIC_STRIKE:
		behavior_text = " · %.1f BLAST" % get_splash_cells()
		if float(_get_stats().get("hazard_duration", 0.0)) > 0.0:
			behavior_text += " · GROUND FIRE"
	return "%s L%d  ·  %d DMG  ·  %.2fs  ·  %.1f RANGE%s  ·  %s" % [
		get_type_name(tower_type), level, get_damage(), get_attack_interval(),
		get_range_cells(), behavior_text, targeting,
	]


func get_next_upgrade_summary() -> String:
	if not can_upgrade():
		return "MAX LEVEL · %d DMG · %.2fs · %.1f RANGE" % [
			get_damage(), get_attack_interval(), get_range_cells(),
		]
	var current: Dictionary = _get_stats()
	var next: Dictionary = _get_level_stats_array()[level]
	var changes: Array[String] = []
	if int(next["damage"]) != int(current["damage"]):
		changes.append("DMG %d→%d" % [int(current["damage"]), int(next["damage"])])
	if not is_equal_approx(float(next["interval"]), float(current["interval"])):
		changes.append("RATE %.2f→%.2fs" % [float(current["interval"]), float(next["interval"])])
	if not is_equal_approx(float(next["range_cells"]), float(current["range_cells"])):
		changes.append("RANGE %.1f→%.1f" % [float(current["range_cells"]), float(next["range_cells"])])
	for key in ["pierce", "target_limit", "shells"]:
		if int(next.get(key, 0)) != int(current.get(key, 0)):
			changes.append("%s %d→%d" % [String(key).to_upper(), int(current.get(key, 0)), int(next.get(key, 0))])
	if float(next.get("stun", 0.0)) > float(current.get("stun", 0.0)):
		changes.append("STUN %.1fs" % float(next["stun"]))
	if float(next.get("hazard_duration", 0.0)) > float(current.get("hazard_duration", 0.0)):
		changes.append("GROUND FIRE")
	return "NEXT L%d · %s" % [level + 1, " · ".join(changes)]


func _get_target_mode() -> StringName:
	return StringName(TYPE_DATA[tower_type]["target_mode"])


func _locks_target() -> bool:
	return bool(TYPE_DATA[tower_type]["locks_target"])


func _select_target() -> Node2D:
	match _get_target_mode():
		TARGET_HIGHEST_HP:
			return _select_highest_hp_target()
		TARGET_DENSEST:
			return _select_best_cluster()
		_:
			return _select_first_target()


func _select_first_target() -> Node2D:
	var selected_target: Node2D
	var least_route_remaining := INF
	var closest_distance := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		var route_remaining := _get_route_remaining(candidate)
		if route_remaining < least_route_remaining - 0.01 or (is_equal_approx(route_remaining, least_route_remaining) and distance < closest_distance):
			selected_target = candidate
			least_route_remaining = route_remaining
			closest_distance = distance
	return selected_target


func _select_highest_hp_target() -> Node2D:
	var selected_target: Node2D
	var highest_health := -1
	var least_route_remaining := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var candidate_health := int(candidate.get("health"))
		var route_remaining := _get_route_remaining(candidate)
		if candidate_health > highest_health or (candidate_health == highest_health and route_remaining < least_route_remaining):
			selected_target = candidate
			highest_health = candidate_health
			least_route_remaining = route_remaining
	return selected_target


func _select_best_cluster() -> Node2D:
	var candidates: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if _is_valid_target(candidate) and _is_target_in_range(candidate):
			candidates.append(candidate as Node2D)
	var selected_target: Node2D
	var best_count := -1
	var least_route_remaining := INF
	var splash_range := get_splash_cells() * get_cell_size()
	for candidate in candidates:
		var nearby := 0
		for other in candidates:
			if candidate.global_position.distance_to(other.global_position) <= splash_range:
				nearby += 1
		var route_remaining := _get_route_remaining(candidate)
		if nearby > best_count or (nearby == best_count and route_remaining < least_route_remaining):
			selected_target = candidate
			best_count = nearby
			least_route_remaining = route_remaining
	return selected_target


func _get_route_remaining(candidate: Node2D) -> float:
	if bool(candidate.get("active")) and candidate.has_method("get_route_distance_remaining"):
		return float(candidate.get_route_distance_remaining())
	return -float(candidate.get("route_progress"))


func _is_valid_target(candidate) -> bool:
	return candidate != null and is_instance_valid(candidate) and not candidate.is_queued_for_deletion() and not bool(candidate.get("finished"))


func _is_target_in_range(candidate: Node2D) -> bool:
	return global_position.distance_squared_to(candidate.global_position) <= pow(get_range_pixels(), 2.0)


func _fire_at(current_target: Node2D) -> void:
	if not _is_valid_target(current_target):
		return
	mark_participated()
	if tower_type == TYPE_FLAMESPITTER:
		_start_flame_spray()
		return
	if tower_type == TYPE_BOMBARDMENT:
		_start_bombardment_salvo(current_target.global_position)
		return
	if tower_type == TYPE_ATOMIC_STRIKE:
		_start_atomic_strike(current_target.global_position)
		return
	attack_cooldown = get_attack_interval()
	var target_position := current_target.global_position
	var pierce_targets := _find_pierce_targets_after(current_target, target_position)
	var total_applied := _apply_hit(current_target, get_damage())
	for hit_index in mini(get_pierce_count(), pierce_targets.size()):
		var pierce_target: Node2D = pierce_targets[hit_index]
		total_applied += _apply_hit(pierce_target, get_piercing_damage(get_damage(), hit_index + 1))
	record_damage(total_applied)
	shot_trace_end = target_position
	if not pierce_targets.is_empty() and get_pierce_count() > 0:
		shot_trace_end = pierce_targets[mini(get_pierce_count(), pierce_targets.size()) - 1].global_position
	shot_trace_remaining = SHOT_TRACE_DURATION


func _start_flame_spray() -> void:
	flame_spray_active = true
	flame_ticks_remaining = int(_get_stats().get("spray_ticks", 1))
	_apply_flame_tick()
	if bool(_get_stats().get("continuous", false)):
		flame_tick_remaining = float(_get_stats().get("tick_interval", 0.2))
		return
	flame_ticks_remaining -= 1
	if flame_ticks_remaining > 0:
		flame_tick_remaining = float(_get_stats().get("tick_interval", 0.2))
	else:
		_finish_flame_spray()


func _process_flame_spray(delta: float) -> void:
	if tower_type != TYPE_FLAMESPITTER or not flame_spray_active:
		return
	if not _is_valid_target(target) or not _is_target_in_range(target):
		flame_spray_active = false
		flame_ticks_remaining = 0
		return
	flame_tick_remaining -= delta
	if flame_tick_remaining > 0.0:
		return
	_set_target(_select_first_target())
	if not _is_valid_target(target):
		flame_spray_active = false
		flame_ticks_remaining = 0
		return
	var offset := target.global_position - global_position
	if not offset.is_zero_approx():
		aim_direction = offset.normalized()
	_apply_flame_tick()
	if bool(_get_stats().get("continuous", false)):
		flame_tick_remaining += float(_get_stats().get("tick_interval", 0.2))
		return
	flame_ticks_remaining -= 1
	if flame_ticks_remaining <= 0:
		_finish_flame_spray()
	else:
		flame_tick_remaining += float(_get_stats().get("tick_interval", 0.2))


func _finish_flame_spray() -> void:
	flame_spray_active = false
	flame_ticks_remaining = 0
	attack_cooldown = float(_get_stats().get("spray_gap", 0.0))


func _apply_flame_tick() -> void:
	var total_applied := 0
	var minimum_dot := cos(deg_to_rad(get_cone_degrees() * 0.5))
	var cone_targets: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var offset: Vector2 = candidate.global_position - global_position
		if offset.is_zero_approx() or aim_direction.dot(offset.normalized()) >= minimum_dot:
			cone_targets.append(candidate as Node2D)
	cone_targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var a_distance := global_position.distance_squared_to(a.global_position)
		var b_distance := global_position.distance_squared_to(b.global_position)
		if not is_equal_approx(a_distance, b_distance):
			return a_distance < b_distance
		return a.get_instance_id() < b.get_instance_id()
	)
	for hit_index in mini(get_target_limit(), cone_targets.size()):
		total_applied += int(cone_targets[hit_index].apply_damage(get_damage(), &"fire", false, true))
	record_damage(total_applied)


func _start_bombardment_salvo(impact_position: Vector2) -> void:
	attack_cooldown = get_attack_interval()
	bombardment_impact_position = impact_position
	bombardment_shells_remaining = get_shell_count()
	_launch_bombardment_shell()


func _process_bombardment_salvo(delta: float) -> void:
	if tower_type != TYPE_BOMBARDMENT or bombardment_shells_remaining <= 0:
		return
	bombardment_shell_timer -= delta
	if bombardment_shell_timer <= 0.0:
		_launch_bombardment_shell()


func _launch_bombardment_shell() -> void:
	if bombardment_shells_remaining <= 0:
		return
	var projectile := ProjectileScript.new() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + aim_direction * get_cell_size() * 0.18
	var is_final_shell := bombardment_shells_remaining == 1
	var stun_duration := float(_get_stats().get("stun", 0.0)) if is_final_shell else 0.0
	projectile.setup_position(
		bombardment_impact_position,
		maxf(get_cell_size() * 7.0, 300.0),
		get_damage(),
		get_splash_cells() * get_cell_size(),
		self,
		stun_duration
	)
	bombardment_shells_remaining -= 1
	bombardment_shell_timer = BOMBARDMENT_SHELL_STAGGER


func _start_atomic_strike(impact_position: Vector2) -> void:
	attack_cooldown = get_attack_interval()
	var projectile := ProjectileScript.new() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + aim_direction * get_cell_size() * 0.18
	projectile.setup_position(
		impact_position,
		maxf(get_cell_size() * 4.0, 190.0),
		get_damage(),
		get_splash_cells() * get_cell_size(),
		self,
		0.0,
		float(_get_stats().get("hazard_duration", 0.0)),
		float(_get_stats().get("hazard_tick", 0.5)),
		int(_get_stats().get("hazard_damage", 0)),
		get_splash_cells() * get_cell_size()
	)


func _apply_hit(enemy: Node2D, damage: int) -> int:
	if not _is_valid_target(enemy) or not enemy.has_method("apply_damage"):
		return 0
	return int(enemy.apply_damage(
		damage,
		&"ballistic",
		bool(TYPE_DATA[tower_type]["ignores_armor"]) or get_pierce_count() > 0,
		true
	))


func _find_pierce_targets_after(primary_target: Node2D, primary_position: Vector2) -> Array[Node2D]:
	var results: Array[Node2D] = []
	if get_pierce_count() <= 0:
		return results
	var shot_offset := primary_position - global_position
	if shot_offset.is_zero_approx():
		return results
	var shot_direction := shot_offset.normalized()
	var primary_distance := shot_offset.length()
	var candidates: Array[Dictionary] = []
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if candidate == primary_target or not _is_valid_target(candidate) or not _is_target_in_range(candidate):
			continue
		var candidate_offset: Vector2 = candidate.global_position - global_position
		var distance_along_line := candidate_offset.dot(shot_direction)
		if distance_along_line <= primary_distance + 0.01:
			continue
		var closest_point := global_position + shot_direction * distance_along_line
		var hit_radius := get_cell_size() * PIERCE_LINE_HALF_WIDTH_CELLS
		if candidate.has_method("get_projectile_hit_radius"):
			hit_radius += float(candidate.get_projectile_hit_radius())
		if candidate.global_position.distance_to(closest_point) <= hit_radius:
			candidates.append({"enemy": candidate, "distance": distance_along_line})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	for candidate_data in candidates:
		results.append(candidate_data["enemy"] as Node2D)
	return results


static func get_piercing_damage(base_damage: int, hit_number: int) -> int:
	var multiplier := maxf(
		1.0 - PIERCE_DAMAGE_LOSS_PER_ENEMY * float(maxi(hit_number, 0)),
		PIERCE_MINIMUM_DAMAGE_MULTIPLIER
	)
	return maxi(roundi(float(base_damage) * multiplier), 1)


func record_damage(amount: int) -> void:
	if amount > 0:
		damage_dealt.emit(tower_type, level, amount)


func _draw() -> void:
	var cell_size := get_cell_size()
	if selected:
		draw_circle(Vector2.ZERO, get_range_pixels(), RANGE_COLOR)
		draw_arc(Vector2.ZERO, get_range_pixels(), 0.0, TAU, 96, RANGE_EDGE_COLOR, 2.0, true)
	if tower_type == TYPE_FLAMESPITTER and flame_spray_active:
		_draw_flame_cone()
	var body_size := cell_size * 0.76
	var body_rect := Rect2(Vector2.ONE * -body_size * 0.5, Vector2.ONE * body_size)
	var body_color: Color = TYPE_DATA[tower_type]["color"]
	draw_rect(body_rect, body_color, true)
	draw_rect(body_rect, BODY_DARK, false, maxf(cell_size * 0.055, 2.0))
	if tower_type == TYPE_ANTI_MATERIEL:
		draw_rect(Rect2(Vector2(-cell_size * 0.20, -cell_size * 0.15), Vector2(cell_size * 0.40, cell_size * 0.30)), BODY_LIGHT, true)
		draw_line(Vector2.ZERO, aim_direction * cell_size * 0.50, BODY_DARK, maxf(cell_size * 0.12, 4.0), true)
		draw_circle(aim_direction * cell_size * 0.10, cell_size * 0.065, body_color.darkened(0.35))
	elif tower_type == TYPE_FLAMESPITTER:
		draw_circle(Vector2.ZERO, cell_size * 0.20, BODY_DARK)
		draw_colored_polygon(PackedVector2Array([
			aim_direction * cell_size * 0.43,
			aim_direction.rotated(0.45) * cell_size * 0.12,
			aim_direction.rotated(-0.45) * cell_size * 0.12,
		]), BODY_LIGHT)
	elif tower_type == TYPE_BOMBARDMENT:
		draw_circle(Vector2.ZERO, cell_size * 0.23, BODY_DARK)
		draw_circle(Vector2.ZERO, cell_size * 0.14, BODY_LIGHT)
		draw_line(Vector2.ZERO, aim_direction * cell_size * 0.38, BODY_DARK, maxf(cell_size * 0.13, 4.0), true)
	elif tower_type == TYPE_ATOMIC_STRIKE:
		draw_circle(Vector2.ZERO, cell_size * 0.23, BODY_DARK)
		draw_circle(Vector2.ZERO, cell_size * 0.13, body_color.lightened(0.35))
		draw_line(Vector2.ZERO, aim_direction * cell_size * 0.42, BODY_LIGHT, maxf(cell_size * 0.11, 4.0), true)
		draw_circle(aim_direction * cell_size * 0.38, cell_size * 0.07, BODY_DARK)
	else:
		draw_circle(Vector2.ZERO, cell_size * 0.20, BODY_LIGHT)
		var side := aim_direction.orthogonal() * cell_size * 0.09
		draw_line(side, side + aim_direction * cell_size * 0.34, BODY_DARK, maxf(cell_size * 0.07, 3.0), true)
		draw_line(-side, -side + aim_direction * cell_size * 0.34, BODY_DARK, maxf(cell_size * 0.07, 3.0), true)
	if shot_trace_remaining > 0.0:
		draw_line(Vector2.ZERO, to_local(shot_trace_end), BODY_LIGHT, maxf(cell_size * 0.035, 2.0), true)
	for pip_index in level:
		var pip_x := (float(pip_index) - float(level - 1) * 0.5) * cell_size * 0.13
		draw_circle(Vector2(pip_x, body_size * 0.39), maxf(cell_size * 0.025, 1.5), BODY_DARK)


func _draw_flame_cone() -> void:
	var half_angle := deg_to_rad(get_cone_degrees() * 0.5)
	var point_count := 14
	var points := PackedVector2Array([Vector2.ZERO])
	for point_index in point_count + 1:
		var angle := lerpf(-half_angle, half_angle, float(point_index) / float(point_count))
		points.append(aim_direction.rotated(angle) * get_range_pixels())
	draw_colored_polygon(points, Color(1.0, 0.27, 0.06, 0.28))
