class_name DraftManager
extends RefCounted

const GameStats = preload("res://stat_database.gd")
const SHOP_CHOICE_COUNT := 3

var rng: RandomNumberGenerator


func _init(random_source: RandomNumberGenerator = null) -> void:
	rng = random_source if random_source != null else RandomNumberGenerator.new()


func roll_tower_offers(
	tower_roster: Array[StringName],
	tower_pool: Array[StringName] = []
) -> Array[StringName]:
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
		var index := rng.randi_range(0, available.size() - 1)
		offers.append(available.pop_at(index))
	return offers


func roll_random_starting_towers(count: int = 2) -> Array[StringName]:
	var available := GameStats.get_playable_tower_family_ids()
	var roster: Array[StringName] = []
	for _index in mini(count, available.size()):
		var random_index := rng.randi_range(0, available.size() - 1)
		roster.append(available.pop_at(random_index))
	return roster
