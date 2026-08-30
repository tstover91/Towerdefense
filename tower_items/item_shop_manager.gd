class_name ItemShopManager
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const OFFER_COUNT := 4
const REROLL_BASE_COST := 40
const REROLL_BASE_COST_PER_ROUND := 10
const REROLL_MINIMUM_COST_STEP := 25
const REROLL_COST_STEP_PER_ROUND := 5
const RARITY_WEIGHTS_BY_ROUND := {
	&"early": {&"common": 100.0, &"uncommon": 50.0, &"rare": 15.0, &"legendary": 1.0},
	&"middle": {&"common": 75.0, &"uncommon": 65.0, &"rare": 35.0, &"legendary": 5.0},
	&"late": {&"common": 55.0, &"uncommon": 75.0, &"rare": 65.0, &"legendary": 15.0},
}
const PREFERRED_ITEM_WEIGHT_MULTIPLIER := 3.0

var rng: RandomNumberGenerator
var offers: Array[StringName] = []
var locked_slots: Array[bool] = []
var reroll_count := 0
var current_shop_round := 1


func _init(random_source: RandomNumberGenerator = null) -> void:
	rng = random_source if random_source != null else RandomNumberGenerator.new()
	offers.resize(OFFER_COUNT)
	locked_slots.resize(OFFER_COUNT)
	for slot_index in OFFER_COUNT:
		offers[slot_index] = &""
		locked_slots[slot_index] = false


func open_shop(
	round_number: int,
	persisted_locked_offers: Array[StringName],
	preferred_item_ids: Array[StringName] = []
) -> void:
	current_shop_round = maxi(round_number, 1)
	reroll_count = 0
	for slot_index in OFFER_COUNT:
		offers[slot_index] = &""
		locked_slots[slot_index] = false
	var locked_index := 0
	for item_id in persisted_locked_offers:
		if (
			locked_index >= OFFER_COUNT
			or not GameStats.has_tower_item(item_id)
			or not GameStats.is_tower_item_shop_enabled(item_id)
			or offers.has(item_id)
		):
			continue
		offers[locked_index] = item_id
		locked_slots[locked_index] = true
		locked_index += 1
		break
	_roll_unlocked_slots(round_number, preferred_item_ids)


func get_reroll_cost() -> int:
	var base_cost := (
		REROLL_BASE_COST
		+ REROLL_BASE_COST_PER_ROUND * current_shop_round
	)
	var cost_step := maxi(
		REROLL_MINIMUM_COST_STEP,
		REROLL_COST_STEP_PER_ROUND * current_shop_round
	)
	return base_cost + cost_step * reroll_count


func has_rerollable_slots() -> bool:
	for slot_index in OFFER_COUNT:
		if not locked_slots[slot_index]:
			return true
	return false


func reroll(
	round_number: int,
	preferred_item_ids: Array[StringName] = []
) -> void:
	if not has_rerollable_slots():
		return
	current_shop_round = maxi(round_number, 1)
	reroll_count += 1
	for slot_index in OFFER_COUNT:
		if not locked_slots[slot_index]:
			offers[slot_index] = &""
	_roll_unlocked_slots(round_number, preferred_item_ids)


func mark_purchased(slot_index: int) -> bool:
	if not is_valid_offer_slot(slot_index):
		return false
	offers[slot_index] = &""
	locked_slots[slot_index] = false
	return true


func toggle_lock(slot_index: int) -> bool:
	if not is_valid_offer_slot(slot_index):
		return false
	var should_lock := not locked_slots[slot_index]
	for index in locked_slots.size():
		locked_slots[index] = false
	locked_slots[slot_index] = should_lock
	return locked_slots[slot_index]


func get_locked_offer_ids() -> Array[StringName]:
	var item_ids: Array[StringName] = []
	for slot_index in OFFER_COUNT:
		if locked_slots[slot_index] and not offers[slot_index].is_empty():
			item_ids.append(offers[slot_index])
	return item_ids


func is_valid_offer_slot(slot_index: int) -> bool:
	return (
		slot_index >= 0
		and slot_index < OFFER_COUNT
		and not offers[slot_index].is_empty()
	)


func _roll_unlocked_slots(
	round_number: int,
	preferred_item_ids: Array[StringName]
) -> void:
	for slot_index in OFFER_COUNT:
		if locked_slots[slot_index] or not offers[slot_index].is_empty():
			continue
		var candidates := GameStats.get_tower_item_ids()
		for offered_item_id in offers:
			candidates.erase(offered_item_id)
		if candidates.is_empty():
			continue
		offers[slot_index] = _choose_weighted_item(
			candidates,
			round_number,
			preferred_item_ids
		)


func _choose_weighted_item(
	candidates: Array[StringName],
	round_number: int,
	preferred_item_ids: Array[StringName]
) -> StringName:
	var rarity_weights := _get_rarity_weights(round_number)
	var weighted_entries: Array[Dictionary] = []
	var total_weight := 0.0
	for item_id in candidates:
		var item := GameStats.get_tower_item(item_id)
		var rarity := StringName(item.get("rarity", &"common"))
		var weight := float(rarity_weights.get(rarity, 1.0))
		if preferred_item_ids.has(item_id):
			weight *= PREFERRED_ITEM_WEIGHT_MULTIPLIER
		weight = maxf(weight, 0.0)
		weighted_entries.append({"id": item_id, "weight": weight})
		total_weight += weight
	if total_weight <= 0.0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	var roll := rng.randf() * total_weight
	for entry in weighted_entries:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return StringName(entry["id"])
	return StringName(weighted_entries.back()["id"])


func _get_rarity_weights(round_number: int) -> Dictionary:
	if round_number >= 13:
		return RARITY_WEIGHTS_BY_ROUND[&"late"]
	if round_number >= 6:
		return RARITY_WEIGHTS_BY_ROUND[&"middle"]
	return RARITY_WEIGHTS_BY_ROUND[&"early"]
