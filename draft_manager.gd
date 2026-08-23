class_name DraftManager
extends RefCounted

const GameStats = preload("res://stat_database.gd")

const SHOP_CHOICE_COUNT := 3
const MINIMUM_APPLICABLE_RELIC_CHOICES := 2
const RELIC_DRAFT_ROUNDS: Array[int] = [1, 5, 11, 20]
const DOUBLE_COMMON_RELIC_DRAFT_ROUND := 11
const RELIC_RARITY_WEIGHTS_BY_ROUND := {
	1: {&"common": 100.0},
	5: {&"common": 70.0, &"rare": 30.0},
	11: {&"common": 40.0, &"rare": 55.0, &"legendary": 5.0},
	20: {&"rare": 60.0, &"legendary": 40.0},
}
const RELIC_MINIMUM_RARE_PLUS_BY_ROUND := {
	5: 1,
	11: 2,
	20: 3,
}
const RELIC_ROLL_MAX_ATTEMPTS := 256
const RECENT_RELIC_HISTORY_LIMIT := 6

var rng: RandomNumberGenerator
var recent_relic_offers: Array[StringName] = []


func _init(random_source: RandomNumberGenerator) -> void:
	rng = random_source


func get_relic_choice_quantities(
	round_number: int,
	offers: Array[StringName]
) -> Dictionary:
	var quantities: Dictionary = {}
	if round_number != DOUBLE_COMMON_RELIC_DRAFT_ROUND:
		return quantities
	for relic_id in offers:
		var relic := GameStats.get_relic(relic_id)
		if relic["rarity"] == &"common" and bool(relic.get("stackable", false)):
			quantities[relic_id] = 2
	return quantities


func roll_relic_offers(
	round_number: int,
	owned_items: Dictionary,
	current_tags: Array[StringName],
	path_relic_eligibility: Dictionary,
	has_dedicated_spawner: bool,
	excluded_relics: Array[StringName] = []
) -> Array[StringName]:
	var eligible_relics: Array[StringName] = []
	for item_key in GameStats.RELICS:
		var item_id := StringName(item_key)
		if excluded_relics.has(item_id):
			continue
		var item_stats: Dictionary = GameStats.get_relic(item_id)
		if not bool(item_stats.get("enabled", true)):
			continue
		var latest_draft_round := int(item_stats.get("latest_draft_round", 0))
		if latest_draft_round > 0 and round_number > latest_draft_round:
			continue
		if (
			not item_stats.get("stackable", false)
			and int(owned_items.get(item_id, 0)) > 0
		):
			continue
		if has_owned_exclusive_relic(item_stats, owned_items):
			continue
		if (
			item_id in [&"singularity_core", &"perfect_mutation"]
			and not bool(path_relic_eligibility.get(item_id, false))
		):
			continue
		if not is_relic_applicable(
			item_id,
			current_tags,
			has_dedicated_spawner
		):
			continue
		eligible_relics.append(item_id)

	var choice_count := get_relic_draft_choice_count(round_number)
	var available: Array[StringName] = []
	for item_id in eligible_relics:
		if not recent_relic_offers.has(item_id):
			available.append(item_id)
	if available.size() < choice_count:
		for item_id in eligible_relics:
			if available.has(item_id):
				continue
			available.append(item_id)
			if available.size() >= choice_count:
				break
	assert(
		available.size() >= choice_count,
		"The shop needs at least %d items." % choice_count
	)
	if round_number == RELIC_DRAFT_ROUNDS[0]:
		var opening_offers := roll_opening_relic_offers(
			available,
			current_tags,
			has_dedicated_spawner,
			round_number
		)
		remember_relic_offers(opening_offers)
		return opening_offers

	var rarity_weights: Dictionary = RELIC_RARITY_WEIGHTS_BY_ROUND.get(
		round_number,
		{}
	)
	var minimum_rare_plus := int(
		RELIC_MINIMUM_RARE_PLUS_BY_ROUND.get(round_number, 0)
	)
	minimum_rare_plus = mini(
		minimum_rare_plus,
		count_rare_plus_relics(available)
	)
	var offers: Array[StringName] = []
	for _attempt in RELIC_ROLL_MAX_ATTEMPTS:
		offers = roll_weighted_relic_set(
			available,
			rarity_weights,
			choice_count
		)
		if (
			count_rare_plus_relics(offers) >= minimum_rare_plus
			and count_applicable_relics(
				offers,
				current_tags,
				has_dedicated_spawner
			) >= MINIMUM_APPLICABLE_RELIC_CHOICES
		):
			remember_relic_offers(offers)
			return offers

	assert(
		false,
		"Unable to satisfy the relic draft guarantees for round %d." % round_number
	)
	return offers


func has_owned_exclusive_relic(
	item_stats: Dictionary,
	owned_items: Dictionary
) -> bool:
	for exclusive_id in item_stats.get("exclusive_with", []):
		if int(owned_items.get(StringName(exclusive_id), 0)) > 0:
			return true
	return false


func get_relic_draft_choice_count(round_number: int) -> int:
	return (
		4
		if round_number in RELIC_DRAFT_ROUNDS.slice(0, 2)
		else SHOP_CHOICE_COUNT
	)


func roll_opening_relic_offers(
	available: Array[StringName],
	current_tags: Array[StringName],
	has_dedicated_spawner: bool,
	round_number: int
) -> Array[StringName]:
	var common_relics: Array[StringName] = []
	var rare_relics: Array[StringName] = []
	var other_relics: Array[StringName] = []
	for item_id in available:
		var rarity: StringName = GameStats.get_relic(item_id)["rarity"]
		if rarity == &"common":
			common_relics.append(item_id)
		elif rarity == &"rare":
			rare_relics.append(item_id)
		else:
			other_relics.append(item_id)
	assert(
		available.size() >= 4,
		"Opening relic drafts need four eligible relics."
	)
	for _attempt in RELIC_ROLL_MAX_ATTEMPTS:
		var remaining_commons := common_relics.duplicate()
		var remaining_rares := rare_relics.duplicate()
		var remaining_other := other_relics.duplicate()
		var offers: Array[StringName] = []
		while offers.size() < 3 and not remaining_commons.is_empty():
			offers.append(remaining_commons.pop_at(
				rng.randi_range(0, remaining_commons.size() - 1)
			))
		while offers.size() < 4:
			var selected_pool: Array[StringName]
			if (
				not remaining_rares.is_empty()
				and (remaining_commons.is_empty() or rng.randf() < 0.25)
			):
				selected_pool = remaining_rares
			elif not remaining_commons.is_empty():
				selected_pool = remaining_commons
			elif not remaining_rares.is_empty():
				selected_pool = remaining_rares
			else:
				selected_pool = remaining_other
			assert(not selected_pool.is_empty(), "No opening relic remains.")
			offers.append(selected_pool.pop_at(
				rng.randi_range(0, selected_pool.size() - 1)
			))
		if count_applicable_relics(
			offers,
			current_tags,
			has_dedicated_spawner
		) >= MINIMUM_APPLICABLE_RELIC_CHOICES:
			return offers
	assert(
		false,
		"Unable to satisfy the opening relic draft guarantees for round %d."
			% round_number
	)
	return []


func remember_relic_offers(offers: Array[StringName]) -> void:
	for item_id in offers:
		if not recent_relic_offers.has(item_id):
			recent_relic_offers.append(item_id)
	while recent_relic_offers.size() > RECENT_RELIC_HISTORY_LIMIT:
		recent_relic_offers.pop_front()


func roll_weighted_relic_set(
	available: Array[StringName],
	rarity_weights: Dictionary,
	choice_count: int
) -> Array[StringName]:
	var remaining: Array[StringName] = available.duplicate()
	var offers: Array[StringName] = []
	while offers.size() < choice_count:
		var item_id := choose_weighted_relic_by_rarity(
			remaining,
			rarity_weights
		)
		assert(not item_id.is_empty(), "No eligible relic remains for this draft.")
		offers.append(item_id)
		remaining.erase(item_id)
	return offers


func choose_weighted_relic_by_rarity(
	available: Array[StringName],
	rarity_weights: Dictionary
) -> StringName:
	if rarity_weights.is_empty():
		return available[rng.randi_range(0, available.size() - 1)]
	var eligible_by_rarity: Dictionary = {}
	var total_weight := 0.0
	for rarity_key in rarity_weights:
		var rarity := StringName(rarity_key)
		var eligible: Array[StringName] = []
		for item_id in available:
			if GameStats.get_relic(item_id)["rarity"] == rarity:
				eligible.append(item_id)
		if eligible.is_empty():
			continue
		eligible_by_rarity[rarity] = eligible
		total_weight += float(rarity_weights[rarity_key])
	if eligible_by_rarity.is_empty() or total_weight <= 0.0:
		if available.is_empty():
			return &""
		return available[rng.randi_range(0, available.size() - 1)]
	var roll := rng.randf_range(0.0, total_weight)
	for rarity_key in rarity_weights:
		var rarity := StringName(rarity_key)
		if not eligible_by_rarity.has(rarity):
			continue
		roll -= float(rarity_weights[rarity_key])
		if roll <= 0.0:
			var eligible: Array[StringName] = eligible_by_rarity[rarity]
			return eligible[rng.randi_range(0, eligible.size() - 1)]
	var fallback_rarity: StringName = eligible_by_rarity.keys().back()
	var fallback: Array[StringName] = eligible_by_rarity[fallback_rarity]
	return fallback[rng.randi_range(0, fallback.size() - 1)]


func count_rare_plus_relics(offers: Array[StringName]) -> int:
	var count := 0
	for item_id in offers:
		if GameStats.get_relic(item_id)["rarity"] in [&"rare", &"legendary"]:
			count += 1
	return count


func count_applicable_relics(
	offers: Array[StringName],
	current_tags: Array[StringName],
	has_dedicated_spawner: bool
) -> int:
	var count := 0
	for item_id in offers:
		if is_relic_applicable(
			item_id,
			current_tags,
			has_dedicated_spawner
		):
			count += 1
	return count


func is_relic_applicable(
	item_id: StringName,
	current_tags: Array[StringName],
	has_dedicated_spawner: bool
) -> bool:
	if item_id == &"trade_agreement":
		return has_dedicated_spawner
	var category: StringName = GameStats.get_relic(item_id)["category"]
	return category == &"global" or current_tags.has(category)


func roll_tower_offers(
	tower_roster: Array[StringName],
	tower_pool: Array[StringName] = []
) -> Array[StringName]:
	var available: Array[StringName] = []
	var source_towers: Array[StringName] = tower_pool.duplicate()
	if source_towers.is_empty():
		for tower_key in GameStats.TOWERS:
			source_towers.append(StringName(tower_key))
	for tower_id in source_towers:
		if not tower_roster.has(tower_id):
			available.append(tower_id)
	assert(
		available.size() >= SHOP_CHOICE_COUNT,
		"The tower draft needs at least %d available towers." % SHOP_CHOICE_COUNT
	)
	var offers: Array[StringName] = []
	while offers.size() < SHOP_CHOICE_COUNT:
		var index := rng.randi_range(0, available.size() - 1)
		offers.append(available.pop_at(index))
	return offers


func roll_random_starting_towers(count: int = 2) -> Array[StringName]:
	var available: Array[StringName] = []
	for tower_key in GameStats.TOWERS:
		available.append(StringName(tower_key))
	var roster: Array[StringName] = []
	for _index in mini(count, available.size()):
		var random_index := rng.randi_range(0, available.size() - 1)
		roster.append(available.pop_at(random_index))
	return roster
