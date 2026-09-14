extends Node

const ItemDropManagerScript = preload("res://tower_items/item_drop_manager.gd")
const GameStats = preload("res://stat_database.gd")

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 49127
	var drops = ItemDropManagerScript.new(rng)
	for round_number in range(1, 25):
		drops.begin_round(round_number)
		var awarded := &""
		for _kill in 6:
			var result: StringName = drops.record_kill()
			if not result.is_empty():
				assert(awarded.is_empty())
				awarded = result
		if ItemDropManagerScript.DROP_ROUNDS.has(round_number):
			assert(GameStats.has_tower_item(awarded))
		else:
			assert(awarded.is_empty())
	print("Item drop manager smoke passed: twelve guaranteed combat drops with round-scaled rarity.")
	get_tree().quit()
