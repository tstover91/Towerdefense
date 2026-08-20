extends Node

const GameStats = preload("res://stat_database.gd")
const RunStateScript = preload("res://run_state.gd")


func _ready() -> void:
	var state = RunStateScript.new()
	var mode: Dictionary = GameStats.get_mode(&"easy")
	state.initialize(mode, false)
	assert(state.money == int(mode["starting_cash"]))
	assert(state.lives == int(mode["starting_lives"]))
	assert(state.max_lives == state.lives)

	var starting_money: int = state.money
	assert(state.spend_money(100))
	assert(state.money == starting_money - 100)
	assert(not state.spend_money(state.money + 1))
	state.add_money(250)
	assert(state.money == starting_money + 150)
	state.take_damage(7)
	assert(state.lives == state.max_lives - 7)
	assert(state.get_draft_health_recovery(20) == 7)
	state.restore_health(3)
	assert(state.lives == state.max_lives - 4)
	state.restore_full_health()
	assert(state.lives == state.max_lives)

	assert(state.collect_relic(&"network_upgrade", 2))
	assert(state.collect_relic(&"network_upgrade", 1))
	assert(state.get_relic_count(&"network_upgrade") == 3)
	assert(state.collect_relic(&"dividends"))
	assert(not state.collect_relic(&"dividends"))
	assert(state.get_relic_count(&"dividends") == 1)
	state.run_bonuses[&"kill_reward"] = 0.25
	assert(is_equal_approx(state.get_run_bonus(&"kill_reward"), 0.25))

	var roster: Array[StringName] = [&"invader", &"longshot"]
	state.set_tower_roster(roster)
	assert(state.collect_tower(&"slinger", 5))
	assert(not state.collect_tower(&"slinger", 5))
	assert(state.get_tower_roster_dictionary().size() == 3)
	assert(not state.get_roster_base_tags().is_empty())
	assert(state.get_sidebar_tower_id(0, 5) == &"invader")

	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	var contraband_id: StringName = state.activate_contraband_blueprint(rng)
	assert(not contraband_id.is_empty())
	assert(not state.tower_roster.has(contraband_id))
	assert(state.get_tower_build_cost(contraband_id, true, []) == 0)
	assert(state.consume_contraband(contraband_id))
	assert(state.contraband_tower_id.is_empty())

	assert(state.collect_relic(&"holiday_sale"))
	var sale_id: StringName = state.roll_holiday_sale_tower(rng)
	assert(state.tower_roster.has(sale_id))
	var base_cost := int(GameStats.get_tower(sale_id)["placement_cost"])
	assert(state.get_tower_build_cost(sale_id, false, []) < base_cost)

	state.initialize(mode, true)
	assert(state.sandbox_mode)
	assert(state.money == RunStateScript.SANDBOX_MONEY)
	assert(state.spend_money(RunStateScript.SANDBOX_MONEY * 2))
	assert(state.money == RunStateScript.SANDBOX_MONEY)

	print("Run state smoke test passed: economy, health, relics, roster, contraband, sale, and sandbox.")
	get_tree().quit(0)
