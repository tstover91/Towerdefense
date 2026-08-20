extends Node

const GameStats = preload("res://stat_database.gd")
const RoundControllerScript = preload("res://round_controller.gd")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var controller = RoundControllerScript.new(rng)
	controller.configure(24)
	controller.roll_challenge_round_order()
	assert(controller.round_eight_type in [
		RoundControllerScript.ROUND_HORDE,
		RoundControllerScript.ROUND_ELITE,
	])
	assert(controller.round_sixteen_type != controller.round_eight_type)
	assert(controller.get_round_type(8) == controller.round_eight_type)
	assert(controller.get_round_type(16) == controller.round_sixteen_type)
	assert(controller.get_round_type(6) == RoundControllerScript.ROUND_STANDARD)
	assert(controller.get_round_type(17) == RoundControllerScript.ROUND_STANDARD)

	assert(controller.can_start_round())
	assert(not controller.can_start_round(true))
	assert(controller.begin_round(30.0))
	assert(controller.round_number == 1)
	assert(controller.round_active)
	assert(controller.phase == RoundControllerScript.PHASE_ACTIVE)
	assert(not controller.advance_time(12.5))
	assert(is_equal_approx(controller.round_elapsed, 12.5))
	assert(is_equal_approx(controller.round_time_remaining, 17.5))
	assert(controller.advance_time(20.0))
	assert(is_zero_approx(controller.round_time_remaining))
	assert(controller.should_finish_round(false, 0, 0, 0))
	assert(not controller.should_finish_round(false, 0, 1, 0))

	var tower_rounds: Array[int] = [3, 9, 14]
	var relic_rounds: Array[int] = [1, 5, 11, 20]
	var reinforcement_rounds: Array[int] = [7, 17]
	assert(controller.end_round())
	assert(controller.get_post_round_action(
		tower_rounds,
		relic_rounds,
		reinforcement_rounds
	) == RoundControllerScript.POST_ROUND_RELIC_DRAFT)
	controller.round_number = 7
	assert(controller.get_post_round_action(
		tower_rounds,
		relic_rounds,
		reinforcement_rounds
	) == RoundControllerScript.POST_ROUND_REINFORCEMENT_DRAFT)
	controller.enter_draft_phase()
	assert(controller.phase == RoundControllerScript.PHASE_DRAFT)
	controller.enter_build_phase()
	assert(controller.phase == RoundControllerScript.PHASE_BUILD)

	controller.round_number = 1
	var base_reward := GameStats.get_round_cash_reward(1)
	assert(controller.calculate_end_round_reward(500, false) == base_reward)
	assert(controller.calculate_end_round_reward(500, true) >= base_reward)

	controller.round_number = 23
	assert(controller.begin_round(60.0))
	assert(controller.round_number == 24)
	assert(controller.end_round())
	assert(controller.get_post_round_action(
		tower_rounds,
		relic_rounds,
		reinforcement_rounds
	) == RoundControllerScript.POST_ROUND_VICTORY)
	assert(controller.finish_game())
	assert(controller.game_ended)
	assert(controller.phase == RoundControllerScript.PHASE_COMPLETE)
	assert(not controller.finish_game())
	assert(not controller.can_start_round())

	print("Round controller smoke test passed: scheduling, phases, timing, rewards, and completion.")
	get_tree().quit(0)
