class_name PrototypeEnemy
extends "res://prototype/grid_route_follower.gd"

signal defeated(enemy: Node2D)
signal summon_requested(summoner: Node2D, enemy_type: StringName, count: int)

const TYPE_SOLDIER: StringName = &"soldier"
const TYPE_RUNNER: StringName = &"runner"
const TYPE_GIANT: StringName = &"giant"
const TYPE_CARRIER: StringName = &"carrier"
const TYPE_ARMORED: StringName = &"armored"
const TYPE_SHIELDED: StringName = &"shielded"
const TYPE_HEALER: StringName = &"healer"
const TYPE_WITCH: StringName = &"witch"
const TYPE_SWARMLING: StringName = &"swarmling"
const TYPE_GOLEM: StringName = &"golem"
const TYPE_GOLEMITE: StringName = &"golemite"
const STUN_FATIGUE_MULTIPLIERS := [1.0, 0.65, 0.40, 0.25, 0.10]
const STUN_FATIGUE_RECOVERY_INTERVAL := 5.0
const BOSS_STUN_DURATION_MULTIPLIER := 0.50
const TYPE_DATA := {
	TYPE_SOLDIER: {"health": 65, "speed": 0.90, "leak": 1, "radius": 0.17, "color": Color("2b2b29")},
	TYPE_RUNNER: {"health": 42, "speed": 1.20, "leak": 1, "radius": 0.14, "color": Color("d94f3d")},
	TYPE_GIANT: {"health": 480, "speed": 0.60, "leak": 3, "radius": 0.27, "color": Color("3c5264")},
	TYPE_CARRIER: {"health": 320, "speed": 0.68, "leak": 2, "radius": 0.24, "color": Color("75559a"), "releases": 4, "release_type": TYPE_SOLDIER},
	TYPE_ARMORED: {"health": 200, "speed": 0.72, "leak": 2, "radius": 0.21, "color": Color("68737c"), "armor": 5},
	TYPE_SHIELDED: {"health": 130, "speed": 0.78, "leak": 2, "radius": 0.20, "color": Color("397f91"), "shield_charges": 3},
	TYPE_HEALER: {"health": 420, "speed": 0.65, "leak": 2, "radius": 0.21, "color": Color("d8c764"), "healing_per_second": 40.0, "healing_range_cells": 2.25},
	TYPE_WITCH: {"health": 180, "speed": 0.60, "leak": 2, "radius": 0.21, "color": Color("79549a"), "summon_type": TYPE_SWARMLING, "summon_count": 2, "first_summon": 2.5, "summon_interval": 5.0, "summon_living_limit": 6, "summon_total_limit": 10},
	TYPE_SWARMLING: {"health": 18, "speed": 0.95, "leak": 1, "radius": 0.11, "color": Color("a784be")},
	TYPE_GOLEM: {"health": 3200, "speed": 0.45, "leak": 5, "radius": 0.34, "color": Color("55504b"), "releases": 2, "release_type": TYPE_GOLEMITE},
	TYPE_GOLEMITE: {"health": 640, "speed": 0.60, "leak": 1, "radius": 0.23, "color": Color("777068")},
}
const BODY_INSET := Color("ece8da")
const DAMAGE_FLASH_COLOR := Color("ef624d")
const HEALTH_BACKGROUND := Color("171717")
const HEALTH_COLOR := Color("e9b949")

var enemy_type: StringName = TYPE_SOLDIER
var traits: Array[StringName] = []
var finished := false
var health := 1
var max_health := 1
var route_progress := 0.0
var leak_damage := 1
var visual_radius := 10.0
var damage_flash_remaining := 0.0
var current_cell_size := 48.0
var base_speed_cells_per_second := 0.90
var current_speed_cells_per_second := 0.90
var formation_id := -1
var formation_index := 0
var released_children := false
var stun_remaining := 0.0
var stun_fatigue_tier := 0
var stun_fatigue_recovery_elapsed := 0.0
var armor := 0
var shield_charges := 0
var maximum_shield_charges := 0
var healing_tick_remaining := 0.0
var summon_remaining := 0.0
var summons_created := 0
var combat_scale := 1.0


func setup_combat(new_type: StringName, health_scale: float, cell_size_pixels: float, new_formation_id := -1, new_formation_index := 0) -> void:
	enemy_type = new_type if TYPE_DATA.has(new_type) else TYPE_SOLDIER
	var data: Dictionary = TYPE_DATA[enemy_type]
	combat_scale = maxf(health_scale, 0.1)
	max_health = maxi(roundi(float(data["health"]) * combat_scale), 1)
	health = max_health
	base_speed_cells_per_second = float(data["speed"])
	current_speed_cells_per_second = base_speed_cells_per_second
	leak_damage = int(data["leak"])
	formation_id = new_formation_id
	formation_index = new_formation_index
	current_cell_size = maxf(cell_size_pixels, 1.0)
	speed_pixels_per_second = base_speed_cells_per_second * current_cell_size
	visual_radius = maxf(current_cell_size * float(data["radius"]), 6.0)
	armor = maxi(int(data.get("armor", 0)), 0)
	maximum_shield_charges = maxi(int(data.get("shield_charges", 0)), 0)
	shield_charges = maximum_shield_charges
	healing_tick_remaining = 0.25
	summon_remaining = float(data.get("first_summon", 0.0))
	summons_created = 0
	stun_remaining = 0.0
	stun_fatigue_tier = 0
	stun_fatigue_recovery_elapsed = 0.0


func update_cell_scale(cell_size_pixels: float, _unused_speed := 0.0) -> void:
	current_cell_size = maxf(cell_size_pixels, 1.0)
	speed_pixels_per_second = current_speed_cells_per_second * current_cell_size
	visual_radius = maxf(current_cell_size * float(TYPE_DATA[enemy_type]["radius"]), 6.0)
	queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("mobs")
	queue_redraw()


func _process(delta: float) -> void:
	if finished:
		return
	_process_stun_effects(delta)
	if stun_remaining > 0.0:
		damage_flash_remaining = maxf(damage_flash_remaining - delta, 0.0)
		queue_redraw()
		return
	_process_healing(delta)
	_process_summoning(delta)
	_update_formation_speed()
	var previous_position := position
	super._process(delta)
	route_progress += previous_position.distance_to(position) / current_cell_size
	damage_flash_remaining = maxf(damage_flash_remaining - delta, 0.0)
	queue_redraw()


func _update_formation_speed() -> void:
	current_speed_cells_per_second = base_speed_cells_per_second
	if enemy_type == TYPE_RUNNER or formation_id < 0:
		speed_pixels_per_second = current_speed_cells_per_second * current_cell_size
		return
	var nearest_ahead: PrototypeEnemy
	var nearest_gap := INF
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if candidate == self or not candidate is PrototypeEnemy or candidate.finished:
			continue
		if candidate.formation_id != formation_id or candidate.formation_index >= formation_index:
			continue
		var gap: float = route_progress - candidate.route_progress
		if gap < 0.0:
			gap = -gap
		if gap < nearest_gap:
			nearest_ahead = candidate
			nearest_gap = gap
	if nearest_ahead != null:
		if nearest_gap < 0.48:
			current_speed_cells_per_second = minf(current_speed_cells_per_second, nearest_ahead.current_speed_cells_per_second * 0.35)
		elif nearest_gap < 0.85:
			current_speed_cells_per_second = minf(current_speed_cells_per_second, nearest_ahead.current_speed_cells_per_second)
	speed_pixels_per_second = maxf(current_speed_cells_per_second * current_cell_size, 1.0)


func apply_damage(requested_damage: int, _damage_type: StringName = &"ballistic", ignores_armor := false, _from_tower := true, _attack_context = null) -> int:
	if finished or requested_damage <= 0:
		return 0
	if shield_charges > 0:
		shield_charges -= 1
		damage_flash_remaining = 0.08
		queue_redraw()
		return 0
	var reduced_damage := requested_damage if ignores_armor else maxi(requested_damage - armor, 1)
	var applied_damage := mini(reduced_damage, health)
	health -= applied_damage
	damage_flash_remaining = 0.08
	if health <= 0:
		finished = true
		active = false
		defeated.emit(self)
	queue_redraw()
	return applied_damage


func _process_healing(delta: float) -> void:
	var data: Dictionary = TYPE_DATA[enemy_type]
	var healing_per_second := float(data.get("healing_per_second", 0.0)) * combat_scale
	if healing_per_second <= 0.0:
		return
	healing_tick_remaining -= delta
	if healing_tick_remaining > 0.0:
		return
	var elapsed := 0.25 - healing_tick_remaining
	healing_tick_remaining = 0.25
	var target: PrototypeEnemy
	var lowest_health_ratio := 2.0
	var healing_range := float(data.get("healing_range_cells", 0.0)) * current_cell_size
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if candidate == self or not candidate is PrototypeEnemy or candidate.finished:
			continue
		if candidate.formation_id != formation_id or candidate.enemy_type == TYPE_SWARMLING:
			continue
		if global_position.distance_to(candidate.global_position) > healing_range:
			continue
		var health_ratio: float = float(candidate.health) / float(maxi(candidate.max_health, 1))
		if candidate.health < candidate.max_health and health_ratio < lowest_health_ratio:
			target = candidate
			lowest_health_ratio = health_ratio
	if target != null:
		target.health = mini(target.health + maxi(roundi(healing_per_second * elapsed), 1), target.max_health)
		target.queue_redraw()


func _process_summoning(delta: float) -> void:
	var data: Dictionary = TYPE_DATA[enemy_type]
	var summon_type := StringName(data.get("summon_type", &""))
	if summon_type.is_empty() or summons_created >= int(data.get("summon_total_limit", 0)):
		return
	summon_remaining -= delta
	if summon_remaining > 0.0:
		return
	var living_summons := 0
	for candidate in get_tree().get_nodes_in_group("mobs"):
		if (
			candidate is PrototypeEnemy
			and not candidate.finished
			and int(candidate.get_meta("summoner_id", 0)) == get_instance_id()
		):
			living_summons += 1
	var living_limit := int(data.get("summon_living_limit", 0))
	var summon_count := mini(
		int(data.get("summon_count", 0)),
		mini(living_limit - living_summons, int(data.get("summon_total_limit", 0)) - summons_created)
	)
	if summon_count > 0:
		summons_created += summon_count
		summon_requested.emit(self, summon_type, summon_count)
	summon_remaining = float(data.get("summon_interval", 5.0))


func apply_damage_from_tower(requested_damage: int, damage_type: StringName, ignores_armor: bool, _source_tower_id: StringName, attack_context = null) -> int:
	return apply_damage(requested_damage, damage_type, ignores_armor, true, attack_context)


func _process_stun_effects(delta: float) -> void:
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	if stun_fatigue_tier <= 0:
		stun_fatigue_recovery_elapsed = 0.0
		return
	stun_fatigue_recovery_elapsed += delta
	while stun_fatigue_tier > 0 and stun_fatigue_recovery_elapsed >= STUN_FATIGUE_RECOVERY_INTERVAL:
		stun_fatigue_recovery_elapsed -= STUN_FATIGUE_RECOVERY_INTERVAL
		stun_fatigue_tier -= 1
	if stun_fatigue_tier <= 0:
		stun_fatigue_recovery_elapsed = 0.0


func apply_stun(duration: float, affects_bosses := false, _attack_context = null) -> void:
	if finished or duration <= 0.0:
		return
	var is_boss := traits.has(&"boss")
	if is_boss and not affects_bosses:
		return
	# Any eligible stun hit delays fatigue recovery, including one that is too
	# short to extend the stun already affecting this enemy.
	stun_fatigue_recovery_elapsed = 0.0
	var multiplier_index := mini(stun_fatigue_tier, STUN_FATIGUE_MULTIPLIERS.size() - 1)
	var boss_multiplier := BOSS_STUN_DURATION_MULTIPLIER if is_boss else 1.0
	var effective_duration: float = duration * boss_multiplier * STUN_FATIGUE_MULTIPLIERS[multiplier_index]
	if effective_duration <= stun_remaining:
		return
	stun_remaining = effective_duration
	stun_fatigue_tier = mini(stun_fatigue_tier + 1, STUN_FATIGUE_MULTIPLIERS.size() - 1)
	queue_redraw()


func mark_leaked() -> void:
	finished = true
	active = false


func get_projectile_hit_radius() -> float:
	return visual_radius


func get_route_progress() -> float:
	return route_progress


func get_release_count() -> int:
	if released_children:
		return 0
	released_children = true
	return int(TYPE_DATA[enemy_type].get("releases", 0))


func get_release_type() -> StringName:
	return StringName(TYPE_DATA[enemy_type].get("release_type", TYPE_SOLDIER))


func _draw() -> void:
	var body_color: Color = DAMAGE_FLASH_COLOR if damage_flash_remaining > 0.0 else TYPE_DATA[enemy_type]["color"]
	if enemy_type in [TYPE_GIANT, TYPE_GOLEM, TYPE_GOLEMITE]:
		draw_circle(Vector2.ZERO, visual_radius, body_color)
		draw_arc(Vector2.ZERO, visual_radius, 0.0, TAU, 24, Color("111111"), 3.0, true)
		draw_rect(Rect2(Vector2(-visual_radius * 0.58, -visual_radius * 0.28), Vector2(visual_radius * 1.16, visual_radius * 0.56)), BODY_INSET, true)
	elif enemy_type in [TYPE_CARRIER, TYPE_HEALER, TYPE_WITCH]:
		var rect := Rect2(Vector2.ONE * -visual_radius, Vector2.ONE * visual_radius * 2.0)
		draw_rect(rect, body_color, true)
		draw_rect(rect, Color("111111"), false, 3.0)
		for offset in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)]:
			draw_circle(offset * visual_radius, visual_radius * 0.16, BODY_INSET)
	else:
		var points := PackedVector2Array([Vector2(0.0, -visual_radius), Vector2(visual_radius, 0.0), Vector2(0.0, visual_radius), Vector2(-visual_radius, 0.0)])
		draw_colored_polygon(points, body_color)
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("111111"), 3.0, true)
		draw_circle(Vector2.ZERO, visual_radius * (0.25 if enemy_type == TYPE_RUNNER else 0.36), BODY_INSET)
	var health_ratio := clampf(float(health) / float(max_health), 0.0, 1.0)
	if stun_remaining > 0.0:
		draw_arc(Vector2.ZERO, visual_radius * 1.22, 0.0, TAU, 16, BODY_INSET, 2.0, true)
	if shield_charges > 0:
		draw_arc(Vector2.ZERO, visual_radius * 1.30, 0.0, TAU, 20, Color("63d5df"), 2.5, true)
	if armor > 0:
		draw_arc(Vector2.ZERO, visual_radius * 1.15, PI * 0.15, PI * 0.85, 8, Color("c2c7c9"), 3.0, true)
	var bar_size := Vector2(visual_radius * 2.4, 4.0)
	var bar_position := Vector2(-bar_size.x * 0.5, -visual_radius - 9.0)
	draw_rect(Rect2(bar_position, bar_size), HEALTH_BACKGROUND, true)
	draw_rect(Rect2(bar_position, Vector2(bar_size.x * health_ratio, bar_size.y)), HEALTH_COLOR, true)
