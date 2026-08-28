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

	assert(state.add_tower_item(&"heavy_rounds", 2))
	assert(state.get_tower_item_count(&"heavy_rounds") == 2)
	assert(state.remove_tower_item(&"heavy_rounds"))
	assert(state.get_tower_item_count(&"heavy_rounds") == 1)
	assert(not state.remove_tower_item(&"heavy_rounds", 2))
	var locked_items: Array[StringName] = [&"heavy_rounds", &"blast_gel"]
	state.set_locked_tower_item_offers(locked_items)
	assert(state.locked_tower_item_offers == [&"heavy_rounds"])
	state.run_bonuses[&"kill_reward"] = 0.25
	assert(is_equal_approx(state.get_run_bonus(&"kill_reward"), 0.25))

	var roster: Array[StringName] = [&"invader", &"longshot"]
	state.set_tower_roster(roster)
	assert(state.collect_tower(&"slinger", 5))
	assert(not state.collect_tower(&"slinger", 5))
	assert(state.get_tower_roster_dictionary().size() == 3)
	assert(not state.get_roster_base_tags().is_empty())
	assert(state.get_sidebar_tower_id(0) == &"invader")
	assert(state.get_sidebar_tower_id(5).is_empty())
	assert(state.get_tower_build_cost(&"invader") == int(
		GameStats.get_tower(&"invader")["placement_cost"]
	))

	state.initialize(mode, true)
	assert(state.sandbox_mode)
	assert(state.money == RunStateScript.SANDBOX_MONEY)
	assert(state.spend_money(RunStateScript.SANDBOX_MONEY * 2))
	assert(state.money == RunStateScript.SANDBOX_MONEY)

	print("Run state smoke test passed: economy, health, item inventory, roster, and sandbox.")
	get_tree().quit(0)
