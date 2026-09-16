class_name DraftManager
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const SHOP_CHOICE_COUNT := 3

var rng: RandomNumberGenerator
var offered_tower_ids: Array[StringName] = []


func _init(random_source: RandomNumberGenerator = null) -> void:
	rng = random_source if random_source != null else RandomNumberGenerator.new()


func roll_tower_offers(
	tower_roster: Array[StringName],
	tower_pool: Array[StringName] = [],
	draft_round: int = -1
) -> Array[StringName]:
	if tower_pool.is_empty() and draft_round == 3:
		return _record_offers(_roll_round_three_offers(tower_roster))
	if tower_pool.is_empty() and draft_round == 8:
		return _record_offers(_roll_family_offers(tower_roster, true))
	if tower_pool.is_empty() and draft_round == 12:
		return _record_offers(_roll_final_family_offers(tower_roster))
	var available: Array[StringName] = []
	var source_towers: Array[StringName] = tower_pool.duplicate()
	if source_towers.is_empty():
		source_towers.assign(GameStats.get_playable_tower_family_ids())
	for tower_id in source_towers:
		var family_id := GameStats.get_canonical_tower_family_id(tower_id)
		if (
			GameStats.is_playable_tower_family(family_id)
			and not tower_roster.has(family_id)
			and not available.has(family_id)
		):
			available.append(family_id)
	assert(
		available.size() >= SHOP_CHOICE_COUNT,
		"The tower draft needs at least %d available towers." % SHOP_CHOICE_COUNT
	)
	var offers: Array[StringName] = []
	while offers.size() < SHOP_CHOICE_COUNT:
		_append_random_offer(offers, available)
	return _record_offers(offers)


func _roll_round_three_offers(
	tower_roster: Array[StringName]
) -> Array[StringName]:
	var roots := GameStats.get_tower_family_roots(tower_roster)
	var focused: Array[StringName] = []
	for root_id in roots:
		var tower_id := GameStats.get_focused_tower_unlock(root_id)
		if not tower_id.is_empty() and not tower_roster.has(tower_id):
			focused.append(tower_id)
	var hybrids: Array[StringName] = []
	for first_index in roots.size():
		for second_index in range(first_index + 1, roots.size()):
			var tower_id := GameStats.get_hybrid_tower_unlock(
				roots[first_index], roots[second_index]
			)
			if not tower_id.is_empty() and not tower_roster.has(tower_id):
				hybrids.append(tower_id)
	var extra_starters: Array[StringName] = []
	for starter_id in GameStats.get_starter_tower_family_ids():
		if not tower_roster.has(starter_id):
			extra_starters.append(starter_id)
	var offers: Array[StringName] = []
	_append_random_offer(offers, focused)
	_append_random_offer(offers, hybrids)
	_append_random_offer(offers, extra_starters)
	_fill_family_offers(offers, tower_roster, true)
	_shuffle(offers)
	assert(offers.size() == SHOP_CHOICE_COUNT)
	return offers


func _roll_family_offers(
	tower_roster: Array[StringName],
	allow_starter_fallback: bool
) -> Array[StringName]:
	var offers: Array[StringName] = []
	_fill_family_offers(offers, tower_roster, allow_starter_fallback)
	assert(
		offers.size() == SHOP_CHOICE_COUNT,
		"The family draft needs at least %d compatible towers." % SHOP_CHOICE_COUNT
	)
	return offers


func _roll_final_family_offers(
	tower_roster: Array[StringName]
) -> Array[StringName]:
	var offers: Array[StringName] = []
	_fill_compatible_offers(offers, tower_roster)
	var wildcards := GameStats.get_wildcard_hybrid_unlocks(tower_roster)
	for tower_id in offers:
		wildcards.erase(tower_id)
	while offers.size() < SHOP_CHOICE_COUNT and not wildcards.is_empty():
		_append_random_offer(offers, wildcards)
	var starters := GameStats.get_starter_tower_family_ids()
	for tower_id in tower_roster:
		starters.erase(tower_id)
	for tower_id in offers:
		starters.erase(tower_id)
	while offers.size() < SHOP_CHOICE_COUNT and not starters.is_empty():
		_append_random_offer(offers, starters)
	assert(
		offers.size() == SHOP_CHOICE_COUNT,
		"The final draft needs at least %d family choices." % SHOP_CHOICE_COUNT
	)
	return offers


func _fill_family_offers(
	offers: Array[StringName],
	tower_roster: Array[StringName],
	allow_starter_fallback: bool
) -> void:
	_fill_compatible_offers(offers, tower_roster)
	if allow_starter_fallback:
		var starters := GameStats.get_starter_tower_family_ids()
		for tower_id in tower_roster:
			starters.erase(tower_id)
		for tower_id in offers:
			starters.erase(tower_id)
		while offers.size() < SHOP_CHOICE_COUNT and not starters.is_empty():
			_append_random_offer(offers, starters)


func _fill_compatible_offers(
	offers: Array[StringName], tower_roster: Array[StringName]
) -> void:
	var compatible := GameStats.get_initial_family_unlocks(tower_roster)
	for tower_id in tower_roster:
		compatible.erase(tower_id)
	for tower_id in offers:
		compatible.erase(tower_id)
	while offers.size() < SHOP_CHOICE_COUNT and not compatible.is_empty():
		_append_random_offer(offers, compatible)


func _append_random_offer(
	offers: Array[StringName], candidates: Array[StringName]
) -> void:
	if candidates.is_empty():
		return
	var unseen_indices: Array[int] = []
	for candidate_index in candidates.size():
		if not offered_tower_ids.has(candidates[candidate_index]):
			unseen_indices.append(candidate_index)
	var index: int
	if unseen_indices.is_empty():
		index = rng.randi_range(0, candidates.size() - 1)
	else:
		index = unseen_indices[rng.randi_range(0, unseen_indices.size() - 1)]
	var tower_id: StringName = candidates.pop_at(index)
	if not offers.has(tower_id):
		offers.append(tower_id)


func _record_offers(offers: Array[StringName]) -> Array[StringName]:
	for tower_id in offers:
		if not offered_tower_ids.has(tower_id):
			offered_tower_ids.append(tower_id)
	return offers


func _shuffle(values: Array[StringName]) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = value


func roll_random_starting_towers(count: int = 2) -> Array[StringName]:
	var available := GameStats.get_starter_tower_family_ids()
	var roster: Array[StringName] = []
	for _index in mini(count, available.size()):
		var random_index := rng.randi_range(0, available.size() - 1)
		roster.append(available.pop_at(random_index))
	return roster
