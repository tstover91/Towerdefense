class_name RoundController
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const ROUND_STANDARD: StringName = &"standard"
const ROUND_HORDE: StringName = &"horde"
const ROUND_ELITE: StringName = &"elite"
const ROUND_GAUNTLET: StringName = &"gauntlet"
const ROUND_PAYDAY: StringName = &"payday"

const PHASE_BUILD: StringName = &"build"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_DRAFT: StringName = &"draft"
const PHASE_COMPLETE: StringName = &"complete"

const POST_ROUND_BUILD: StringName = &"build"
const POST_ROUND_ITEM_SHOP: StringName = &"item_shop"
const POST_ROUND_TOWER_DRAFT: StringName = &"tower_draft"
const POST_ROUND_REINFORCEMENT_DRAFT: StringName = &"reinforcement_draft"
const POST_ROUND_VICTORY: StringName = &"victory"

var rng: RandomNumberGenerator
var phase: StringName = PHASE_BUILD
var round_number := 0
var max_rounds := 0
var current_round_type: StringName = ROUND_STANDARD
var round_eight_type: StringName = ROUND_HORDE
var round_sixteen_type: StringName = ROUND_ELITE
var round_time_remaining := 0.0
var round_duration := 0.0
var round_elapsed := 0.0
var round_active := false
var game_ended := false


func _init(random_source: RandomNumberGenerator = null) -> void:
	rng = random_source if random_source != null else RandomNumberGenerator.new()


func configure(maximum_rounds: int) -> void:
	max_rounds = maximum_rounds


func roll_challenge_round_order() -> void:
	if rng.randf() < 0.5:
		round_eight_type = ROUND_HORDE
		round_sixteen_type = ROUND_ELITE
	else:
		round_eight_type = ROUND_ELITE
		round_sixteen_type = ROUND_HORDE


func get_round_type(wave: int) -> StringName:
	match wave:
		8:
			return round_eight_type
		16:
			return round_sixteen_type
		_:
			return ROUND_STANDARD


func can_start_round(blocked_by_gameplay: bool = false) -> bool:
	return (
		not game_ended
		and not round_active
		and round_number < max_rounds
		and not blocked_by_gameplay
	)


func begin_round(duration: float) -> bool:
	if not can_start_round():
		return false
	round_number += 1
	current_round_type = get_round_type(round_number)
	round_duration = maxf(duration, 0.0)
	round_time_remaining = round_duration
	round_elapsed = 0.0
	round_active = true
	phase = PHASE_ACTIVE
	return true


func advance_time(delta: float) -> bool:
	if not round_active:
		return false
	var safe_delta := maxf(delta, 0.0)
	round_elapsed += safe_delta
	round_time_remaining = maxf(round_time_remaining - safe_delta, 0.0)
	return round_time_remaining <= 0.0


func end_round() -> bool:
	if game_ended or not round_active:
		return false
	round_active = false
	phase = PHASE_BUILD
	return true


func enter_build_phase() -> void:
	if not game_ended:
		phase = PHASE_BUILD


func enter_draft_phase() -> void:
	if not game_ended:
		phase = PHASE_DRAFT


func finish_game() -> bool:
	if game_ended:
		return false
	game_ended = true
	round_active = false
	phase = PHASE_COMPLETE
	return true


func should_finish_round(
	spawning_active: bool,
	mobs_left_to_spawn: int,
	mobs_alive: int,
	pending_spawn_count: int
) -> bool:
	return (
		round_active
		and not spawning_active
		and mobs_left_to_spawn <= 0
		and mobs_alive <= 0
		and pending_spawn_count <= 0
	)


func get_post_round_action(
	tower_draft_rounds: Array[int],
	_reinforcement_draft_rounds: Array[int] = []
) -> StringName:
	if round_number >= max_rounds:
		return POST_ROUND_VICTORY
	if tower_draft_rounds.has(round_number):
		return POST_ROUND_TOWER_DRAFT
	return POST_ROUND_BUILD


func calculate_end_round_reward() -> int:
	return GameStats.get_round_cash_reward(round_number)


func get_displayed_round() -> int:
	if not round_active and round_number < max_rounds:
		return round_number + 1
	return round_number


func get_round_type_display_name(round_type: StringName) -> String:
	match round_type:
		ROUND_HORDE:
			return "Horde Round"
		ROUND_ELITE:
			return "Elite Round"
		ROUND_GAUNTLET:
			return "Gauntlet"
		ROUND_PAYDAY:
			return "Payday Round"
		_:
			return "Standard Round"
