class_name SiegeTownHallCatalog
extends RefCounted

# Combat caps, army space, and Wall quantities mirror current Clash TH1-TH3.
const TIERS := {
	1: {
		"army_capacity": 20,
		"reward_a": 5,
		"reward_b": 7,
		"structure_caps": {&"command_core": 1, &"cannon": 2},
		"count_caps": {&"command_core": 1, &"cannon": 1, &"wall": 0},
		"troop_levels": {&"raider": 1, &"ranger": 1},
	},
	2: {
		"army_capacity": 30,
		"reward_a": 7,
		"reward_b": 9,
		"structure_caps": {&"command_core": 2, &"cannon": 3, &"archer_tower": 2, &"wall": 2},
		"count_caps": {&"command_core": 1, &"cannon": 2, &"archer_tower": 1, &"wall": 25},
		"troop_levels": {&"raider": 1, &"ranger": 1, &"brute": 1},
	},
	3: {
		"army_capacity": 70,
		"reward_a": 10,
		"reward_b": 14,
		"structure_caps": {&"command_core": 3, &"cannon": 4, &"archer_tower": 3, &"mortar": 1, &"wall": 3},
		"count_caps": {&"command_core": 1, &"cannon": 2, &"archer_tower": 1, &"mortar": 1, &"wall": 50},
		"troop_levels": {&"raider": 2, &"ranger": 2, &"brute": 1, &"sapper": 1},
	},
}

const FOOTPRINTS := {
	&"command_core": Vector2i(4, 4),
	&"cannon": Vector2i(3, 3),
	&"archer_tower": Vector2i(3, 3),
	&"mortar": Vector2i(3, 3),
	&"wall": Vector2i.ONE,
}


static func get_tier(town_hall: int) -> Dictionary:
	return Dictionary(TIERS.get(clampi(town_hall, 1, 3), {})).duplicate(true)


static func get_army_budget(town_hall: int, battle_index: int) -> int:
	# Show the force actually deployed. Clash army capacity remains reference
	# data, but filling it every round overwhelms this condensed TD economy.
	return get_wave_housing(build_wave(town_hall, battle_index))


static func get_reward(town_hall: int, battle_index: int) -> int:
	var tier := get_tier(town_hall)
	return int(tier.get("reward_b" if battle_index >= 1 else "reward_a", 0))


static func get_level_cap(town_hall: int, kind: StringName) -> int:
	return int(Dictionary(get_tier(town_hall).get("structure_caps", {})).get(kind, 0))


static func get_count_cap(town_hall: int, kind: StringName) -> int:
	return int(Dictionary(get_tier(town_hall).get("count_caps", {})).get(kind, 0))


static func get_unlocked_build_kinds(town_hall: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for kind in [&"cannon", &"archer_tower", &"mortar", &"wall"]:
		if get_count_cap(town_hall, kind) > 0:
			result.append(kind)
	return result


static func get_footprint(kind: StringName) -> Vector2i:
	return Vector2i(FOOTPRINTS.get(kind, Vector2i.ONE))


static func build_wave(town_hall: int, battle_index: int) -> Array[Dictionary]:
	var composition: Array[Dictionary] = []
	match town_hall:
		1:
			composition = _composition([[&"raider", 9 if battle_index == 0 else 10], [&"ranger", 6 if battle_index == 0 else 10]])
		2:
			if battle_index == 0:
				# The opening defense is a readable tutorial wave: exact level-one
				# Barbarian stats, without ranged pressure or defense-targeting Giants.
				composition = _composition([[&"raider", 10]])
			else:
				composition = _composition([[&"brute", 1], [&"raider", 5], [&"ranger", 5]])
		_:
			if battle_index == 0:
				composition = _composition([[&"brute", 1], [&"sapper", 1], [&"raider", 7], [&"ranger", 6]])
			else:
				composition = _composition([[&"brute", 1], [&"sapper", 1], [&"raider", 8], [&"ranger", 7]])
	var levels: Dictionary = get_tier(town_hall).get("troop_levels", {})
	var spawn_delay := _get_spawn_delay(town_hall, battle_index)
	for index in composition.size():
		composition[index]["level"] = int(levels.get(composition[index]["kind"], 1))
		composition[index]["row"] = 12 + index % 20
		composition[index]["next_delay"] = spawn_delay
	return composition


static func get_wave_housing(wave: Array[Dictionary]) -> int:
	var total := 0
	for entry in wave:
		match StringName(entry.get("kind", &"")):
			&"brute": total += 5
			&"sapper": total += 2
			_: total += 1
	return total


static func _composition(groups: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group in groups:
		for _index in int(group[1]):
			result.append({"kind": StringName(group[0])})
	return result


static func _get_spawn_delay(town_hall: int, battle_index: int) -> float:
	# TD pacing, not a combat-stat modifier: early armies enter in a readable
	# trickle while the larger TH3 armies deploy in denser groups.
	match town_hall:
		1: return 3.0 if battle_index == 0 else 2.6
		2: return 2.4 if battle_index == 0 else 2.0
		_: return 1.15 if battle_index == 0 else 0.82
