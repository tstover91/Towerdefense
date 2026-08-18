class_name ReinforcementDrop
extends Node2D

const GameStats = preload("res://stat_database.gd")
const SPAWNED_UNIT_SCENE = preload("res://spawned_unit.tscn")
const RANGE_PIXELS_PER_UNIT := 12.9

var tower_id: StringName = &"reinforcements"
var elapsed := 0.0
var lifetime := 0.0
var command_radius_pixels := 1.0


func setup(option: Dictionary, wave_number: int) -> void:
	add_to_group("reinforcement_drops")
	var unit_id := StringName(option.get("unit_id", &"reinforcement_alien"))
	var unit_count := maxi(int(option.get("unit_count", 1)), 1)
	var deployment_spread := maxf(
		float(option.get("deployment_spread", 0.0)),
		0.0
	)
	command_radius_pixels = maxf(
		float(option.get("command_radius", 1.0)) * RANGE_PIXELS_PER_UNIT,
		1.0
	)
	var unit_stats: Dictionary = option.get("unit_stats", {}).duplicate(true)
	unit_stats["damage"] = maxi(
		roundi(
			float(unit_stats.get("damage", 1))
			+ float(unit_stats.get("damage_per_round", 0.0))
				* float(maxi(wave_number - 1, 0))
		),
		1
	)
	lifetime = maxf(float(unit_stats.get("lifetime", 0.0)), 0.1)

	for unit_index in unit_count:
		var angle := -PI * 0.5 + TAU * float(unit_index) / float(unit_count)
		var offset := (
			Vector2.ZERO
			if unit_count == 1
			else Vector2.from_angle(angle) * deployment_spread
		)
		var unit := SPAWNED_UNIT_SCENE.instantiate() as SpawnedUnit
		add_child(unit)
		unit.global_position = global_position + offset
		unit.setup(unit_id, unit_stats, self, null)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime + 0.25:
		queue_free()
		return
	queue_redraw()


func get_owned_relic_count(_relic_id: StringName) -> int:
	return 0


func get_attack_relic_metadata(
	_source_position: Vector2,
	_source_range: float,
	_source_type_tags: Array[StringName]
) -> Dictionary:
	return {}


func has_bonus_tag(_tag: StringName) -> bool:
	return false


func _draw() -> void:
	var remaining_ratio := clampf(
		(lifetime - elapsed) / minf(lifetime, 2.0),
		0.0,
		1.0
	)
	var ring_color := Color(0.4, 1.0, 0.55, 0.32 * remaining_ratio)
	draw_circle(
		Vector2.ZERO,
		command_radius_pixels,
		Color(0.2, 0.8, 0.4, 0.025 * remaining_ratio)
	)
	draw_arc(
		Vector2.ZERO,
		command_radius_pixels,
		0.0,
		TAU,
		64,
		ring_color,
		1.5,
		true
	)
	draw_circle(Vector2.ZERO, 4.0, Color(0.5, 1.0, 0.65, 0.65 * remaining_ratio))
