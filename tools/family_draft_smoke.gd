extends SceneTree

const GameStats = preload("res://stat_database.gd")
const DraftManagerScript = preload("res://draft_manager.gd")


func _initialize() -> void:
	var starters := GameStats.get_starter_tower_family_ids()
	var checked_paths := 0
	for first_index in starters.size():
		for second_index in range(first_index + 1, starters.size()):
			var opening: Array[StringName] = [
				starters[first_index], starters[second_index]
			]
			var shared_hybrid := GameStats.get_hybrid_tower_unlock(
				opening[0], opening[1]
			)
			for seed_offset in 3:
				var rng := RandomNumberGenerator.new()
				rng.seed = first_index * 1000 + second_index * 100 + seed_offset
				var draft := DraftManagerScript.new(rng)
				var round_three := draft.roll_tower_offers(opening, [], 3)
				assert(round_three.size() == 3)
				assert(shared_hybrid in round_three)
				var focused_count := 0
				var new_starter_count := 0
				for offer_id in round_three:
					if offer_id in [
						GameStats.get_focused_tower_unlock(opening[0]),
						GameStats.get_focused_tower_unlock(opening[1]),
					]:
						focused_count += 1
					if GameStats.STARTER_TOWER_FAMILY_IDS.has(offer_id):
						new_starter_count += 1
				assert(focused_count == 1)
				assert(new_starter_count == 1)
				for round_three_choice in round_three:
					var roster_after_three := opening.duplicate()
					roster_after_three.append(round_three_choice)
					var round_eight := draft.roll_tower_offers(
						roster_after_three, [], 8
					)
					assert_unique_unowned(round_eight, roster_after_three)
					for round_eight_choice in round_eight:
						var roster_after_eight := roster_after_three.duplicate()
						roster_after_eight.append(round_eight_choice)
						var round_twelve := draft.roll_tower_offers(
							roster_after_eight, [], 12
						)
						assert_unique_unowned(round_twelve, roster_after_eight)
						var compatible := GameStats.get_initial_family_unlocks(
							roster_after_eight
						)
						var wildcards := GameStats.get_wildcard_hybrid_unlocks(
							roster_after_eight
						)
						for offer_id in round_twelve:
							assert(
								compatible.has(offer_id)
								or wildcards.has(offer_id)
								or GameStats.STARTER_TOWER_FAMILY_IDS.has(offer_id)
							)
						var compatible_remaining := 0
						for tower_id in compatible:
							if not roster_after_eight.has(tower_id):
								compatible_remaining += 1
						if compatible_remaining < 3 and not wildcards.is_empty():
							assert(any_offer_in(round_twelve, wildcards))
						checked_paths += 1
	print("Family draft smoke checks passed across %d draft paths." % checked_paths)
	quit()


func assert_unique_unowned(
	offers: Array[StringName],
	roster: Array[StringName],
	require_three: bool = true
) -> void:
	if require_three:
		assert(offers.size() == 3)
	var unique: Array[StringName] = []
	for offer_id in offers:
		assert(not roster.has(offer_id))
		assert(not unique.has(offer_id))
		unique.append(offer_id)


func any_offer_in(offers: Array[StringName], candidates: Array[StringName]) -> bool:
	for offer_id in offers:
		if candidates.has(offer_id):
			return true
	return false
