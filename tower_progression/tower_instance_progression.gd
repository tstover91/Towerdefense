class_name TowerInstanceProgression
extends RefCounted

signal progression_changed
signal level_changed(new_level: int)

const MAX_LEVEL := 20
const TARGET_XP_AT_MAX_LEVEL := 1500.0
const RUNESCAPE_EXPONENT_LEVEL_SPAN := 7.0
const RUNESCAPE_EXPONENTIAL_BASE := 300.0

static var _next_instance_sequence := 1

var instance_uid: StringName
var tower_family_id: StringName
var level := 1
var xp := 0.0
var kills := 0
var actual_damage_dealt := 0.0
var control_credit := 0.0


func _init(family_id: StringName = &"") -> void:
	tower_family_id = family_id
	instance_uid = StringName("tower_%d" % _next_instance_sequence)
	_next_instance_sequence += 1


func record_damage(actual_damage: int, xp_award: float) -> void:
	if actual_damage <= 0:
		return
	actual_damage_dealt += float(actual_damage)
	grant_xp(xp_award)


func record_kill(xp_award: float) -> void:
	kills += 1
	grant_xp(xp_award)


func grant_xp(amount: float) -> void:
	var safe_amount := maxf(amount, 0.0)
	if safe_amount <= 0.0:
		return
	xp += safe_amount
	var previous_level := level
	level = get_level_for_total_xp(xp)
	progression_changed.emit()
	if level != previous_level:
		level_changed.emit(level)


func get_level_for_total_xp(total_xp: float) -> int:
	var resolved_level := 1
	while resolved_level < MAX_LEVEL:
		if total_xp < get_total_xp_required_for_level(resolved_level + 1):
			break
		resolved_level += 1
	return resolved_level


func get_xp_requirement_for_level(source_level: int = level) -> float:
	if source_level >= MAX_LEVEL:
		return 0.0
	return (
		get_total_xp_required_for_level(source_level + 1)
		- get_total_xp_required_for_level(source_level)
	)


func get_xp_at_level_start(source_level: int = level) -> float:
	return get_total_xp_required_for_level(source_level)


func get_total_xp_required_for_level(source_level: int) -> float:
	var safe_level := clampi(source_level, 1, MAX_LEVEL)
	var maximum_raw_xp := get_runescape_total_xp(MAX_LEVEL)
	if maximum_raw_xp <= 0:
		return 0.0
	return roundf(
		float(get_runescape_total_xp(safe_level))
		/ float(maximum_raw_xp)
		* TARGET_XP_AT_MAX_LEVEL
	)


func get_runescape_total_xp(source_level: int) -> int:
	var points := 0
	for rank in range(1, maxi(source_level, 1)):
		points += floori(
			float(rank)
			+ RUNESCAPE_EXPONENTIAL_BASE
			* pow(2.0, float(rank) / RUNESCAPE_EXPONENT_LEVEL_SPAN)
		)
	return floori(float(points) / 4.0)


func get_xp_into_current_level() -> float:
	return maxf(xp - get_xp_at_level_start(), 0.0)


func get_xp_to_next_level() -> float:
	return get_xp_requirement_for_level()


func get_progress_ratio() -> float:
	var requirement := get_xp_to_next_level()
	if requirement <= 0.0:
		return 1.0
	return clampf(get_xp_into_current_level() / requirement, 0.0, 1.0)
