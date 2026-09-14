class_name ItemDropManager
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const DROP_ROUNDS: Array[int] = [2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24]
const EARLY_WEIGHTS := {&"common": 82.0, &"uncommon": 17.0, &"rare": 1.0}
const MIDDLE_WEIGHTS := {&"common": 55.0, &"uncommon": 38.0, &"rare": 7.0}
const LATE_WEIGHTS := {&"common": 35.0, &"uncommon": 45.0, &"rare": 20.0}

var rng: RandomNumberGenerator
var current_round := 0
var kills_this_round := 0
var drop_kill_target := 0
var drop_awarded := false

func _init(random_source: RandomNumberGenerator = null) -> void:
	rng = random_source if random_source != null else RandomNumberGenerator.new()

func begin_round(round_number: int) -> void:
	current_round = round_number
	kills_this_round = 0
	drop_awarded = false
	drop_kill_target = rng.randi_range(2, 5) if DROP_ROUNDS.has(round_number) else 0

func record_kill() -> StringName:
	if drop_awarded or drop_kill_target <= 0:
		return &""
	kills_this_round += 1
	if kills_this_round < drop_kill_target:
		return &""
	drop_awarded = true
	return _roll_item()

func _roll_item() -> StringName:
	var candidates := GameStats.get_tower_item_ids()
	if candidates.is_empty():
		return &""
	var rarity_weights: Dictionary = EARLY_WEIGHTS
	if current_round >= 17:
		rarity_weights = LATE_WEIGHTS
	elif current_round >= 9:
		rarity_weights = MIDDLE_WEIGHTS
	var items_by_rarity: Dictionary = {}
	var total_weight := 0.0
	for item_id in candidates:
		var rarity := StringName(GameStats.get_tower_item(item_id).get("rarity", &"common"))
		if float(rarity_weights.get(rarity, 0.0)) <= 0.0:
			continue
		if not items_by_rarity.has(rarity):
			items_by_rarity[rarity] = []
		items_by_rarity[rarity].append(item_id)
	for rarity in items_by_rarity:
		total_weight += float(rarity_weights.get(rarity, 0.0))
	if items_by_rarity.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randf() * total_weight
	var selected_rarity: StringName = StringName(items_by_rarity.keys().back())
	for rarity in items_by_rarity:
		roll -= float(rarity_weights.get(rarity, 0.0))
		if roll <= 0.0:
			selected_rarity = StringName(rarity)
			break
	var rarity_items: Array = items_by_rarity[selected_rarity]
	return StringName(rarity_items[rng.randi_range(0, rarity_items.size() - 1)])
