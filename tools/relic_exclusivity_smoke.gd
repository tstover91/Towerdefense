extends Node

const GameStats = preload("res://stat_database.gd")
const RunStateScript = preload("res://run_state.gd")

const EXCLUSIVE_PAIRS := [
	[&"focused_lens", &"wide_lens"],
	[&"heavy_rounds", &"lightweight_ammo"],
	[&"long_barrel", &"point_blank"],
	[&"high_yield", &"concentrated_charge"],
	[&"lingering_thoughts", &"quick_thinking"],
	[&"frenzy", &"duelist"],
	[&"crowd_pleaser", &"direct_hit"],
]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72024
	var draft_manager := DraftManager.new(rng)
	var mode: Dictionary = GameStats.get_mode(&"easy")

	for pair in EXCLUSIVE_PAIRS:
		var left_id := StringName(pair[0])
		var right_id := StringName(pair[1])
		var left: Dictionary = GameStats.get_relic(left_id)
		var right: Dictionary = GameStats.get_relic(right_id)

		assert(left.get("exclusive_with", []).has(right_id))
		assert(right.get("exclusive_with", []).has(left_id))
		assert(left["description"].contains(
			"Exclusive with %s." % right["display_name"]
		))
		assert(right["description"].contains(
			"Exclusive with %s." % left["display_name"]
		))
		assert(draft_manager.has_owned_exclusive_relic(
			right, {left_id: 1}
		))
		assert(draft_manager.has_owned_exclusive_relic(
			left, {right_id: 1}
		))
		assert(not draft_manager.has_owned_exclusive_relic(left, {}))

		var left_first = RunStateScript.new()
		left_first.initialize(mode, false)
		assert(left_first.collect_relic(left_id))
		assert(not left_first.collect_relic(right_id))

		var right_first = RunStateScript.new()
		right_first.initialize(mode, false)
		assert(right_first.collect_relic(right_id))
		assert(not right_first.collect_relic(left_id))

	var compatible_state = RunStateScript.new()
	compatible_state.initialize(mode, false)
	assert(compatible_state.collect_relic(&"strength_in_numbers"))
	assert(compatible_state.collect_relic(&"lone_wolf"))
	assert(GameStats.get_relic(&"strength_in_numbers").get(
		"exclusive_with", []
	).is_empty())
	assert(GameStats.get_relic(&"lone_wolf").get(
		"exclusive_with", []
	).is_empty())

	print("Relic exclusivity smoke checks passed for all seven pairs.")
	get_tree().quit(0)
