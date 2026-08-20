extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const GameStats = preload("res://stat_database.gd")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics: Dictionary = {}
	var bonuses: Dictionary = {}

	func get_run_bonus(effect: StringName) -> float:
		return float(bonuses.get(effect, 0.0))

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))


func _ready() -> void:
	call_deferred("run_test")


func create_tower(
	tower_id: StringName,
	fake_main: Node,
	level := 0,
	paths: Array[StringName] = []
) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.tower_level = level
	tower.purchased_paths.assign(paths)
	tower.main = fake_main
	add_child(tower)
	return tower


func run_test() -> void:
	var fake_main := FakeMain.new()
	fake_main.bonuses[&"tower_damage_flat"] = 5.0
	fake_main.bonuses[&"tower_attack_speed"] = 0.10
	fake_main.bonuses[&"tower_range"] = 0.20
	add_child(fake_main)

	var invader := create_tower(&"invader", fake_main, 3, [&"b"])
	assert(invader.stats_controller != null)
	assert(invader.stats_controller.tower == invader)
	var invader_stats := invader.get_effective_stats_for_level(3)
	assert(invader_stats == invader.stats_controller.get_effective_stats_for_level(3))
	assert(int(invader_stats["damage"]) == roundi(140.0 * 1.7 + 5.0))
	assert(is_equal_approx(
		float(invader_stats["firerate"]), 0.396 * 1.2 / 1.10
	))
	assert(is_equal_approx(float(invader_stats["range"]), 11.9 * 1.20))
	assert(invader.has_damage_tag(&"ballistic"))
	assert(invader.has_bonus_tag(&"pierce"))
	assert(invader.pierce_count == 1)
	assert(invader.damage_type == &"ballistic")
	fake_main.relics[&"deep_penetration"] = 2
	invader.load_base_tags()
	invader.load_level_stats()
	assert(invader.pierce_count == 3)
	fake_main.relics.erase(&"deep_penetration")
	invader.load_base_tags()
	invader.load_level_stats()
	assert(invader.pierce_count == 1)

	fake_main.relics[&"heavy_rounds"] = 1
	invader.load_base_tags()
	invader.load_level_stats()
	var heavy_stats := invader.get_effective_stats_for_level(3)
	assert(int(heavy_stats["damage"]) == maxi(roundi(
		float(roundi(140.0 * 1.7 + 5.0))
		* GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER
	), 1))
	assert(is_equal_approx(
		float(heavy_stats["firerate"]),
		0.396 * 1.2 / 1.10 * GameStats.HEAVY_ROUNDS_INTERVAL_MULTIPLIER
	))

	var fisherman := create_tower(&"fisherman", fake_main, 3, [&"a"])
	assert(fisherman.has_type_tag(&"biological"))
	assert(fisherman.has_damage_tag(&"melee"))
	assert(fisherman.has_damage_tag(&"electric"))
	assert(fisherman.get_primary_damage_type() == &"electric")

	var depot := create_tower(&"dronedepot", fake_main, 3, [&"a"])
	var depot_stats := depot.get_effective_stats_for_level(3)
	assert(depot.uses_standard_spawner_system())
	assert(depot_stats.has("unit_stats"))
	assert(int(depot_stats["damage"]) == int(depot_stats["unit_stats"]["damage"]))
	assert(is_equal_approx(
		float(depot_stats["range"]),
		float(depot_stats["deployment_radius"])
			* invader.get_main_multiplier(&"tower_range")
	))

	# Experimental Munitions grants a lower 1.5x baseline that other Critical
	# relics can build on. Deadeye adds its multiplier and a per-attack miss.
	fake_main.relics[&"experimental_munitions"] = 1
	invader.load_base_tags()
	invader.load_level_stats()
	assert(invader.has_bonus_tag(&"critical"))
	assert(is_equal_approx(
		invader.critical_multiplier,
		GameStats.EXPERIMENTAL_MUNITIONS_CRITICAL_MULTIPLIER
	))
	fake_main.relics[&"deadeye"] = 1
	invader.load_level_stats()
	assert(is_equal_approx(
		invader.critical_multiplier,
		GameStats.EXPERIMENTAL_MUNITIONS_CRITICAL_MULTIPLIER
			+ GameStats.DEADEYE_CRITICAL_MULTIPLIER_BONUS
	))
	assert(is_equal_approx(invader.miss_chance, GameStats.DEADEYE_MISS_CHANCE))
	invader.miss_chance = 1.0
	assert(invader.roll_attack_damage() == 0)
	var missed_context := invader.create_attack_context(
		&"hitscan", null, &"tower", null, false, true
	)
	assert(bool(missed_context.metadata.get("shot_missed", false)))

	# Lone Wolf now cares only about duplicate copies of the same Melee tower.
	fake_main.relics[&"lone_wolf"] = 1
	var reaver := create_tower(&"reaver", fake_main)
	reaver.is_placed = true
	var lone_reaver_stats := reaver.get_effective_stats_for_level(0)
	var slinger := create_tower(&"slinger", fake_main)
	slinger.is_placed = true
	var mixed_melee_stats := reaver.get_effective_stats_for_level(0)
	assert(lone_reaver_stats == mixed_melee_stats)
	var second_reaver := create_tower(&"reaver", fake_main)
	second_reaver.is_placed = true
	var duplicate_reaver_stats := reaver.get_effective_stats_for_level(0)
	assert(int(lone_reaver_stats["damage"]) > int(duplicate_reaver_stats["damage"]))
	assert(float(lone_reaver_stats["firerate"]) < float(duplicate_reaver_stats["firerate"]))
	assert(float(lone_reaver_stats["range"]) > float(duplicate_reaver_stats["range"]))
	second_reaver.is_placed = false
	var mech_bay := create_tower(&"mechbay", fake_main)
	mech_bay.is_placed = true
	var lone_mech_stats := mech_bay.get_effective_stats_for_level(0)
	var second_mech_bay := create_tower(&"mechbay", fake_main)
	second_mech_bay.is_placed = true
	var duplicate_mech_stats := mech_bay.get_effective_stats_for_level(0)
	assert(
		int(lone_mech_stats["unit_stats"]["damage"])
		> int(duplicate_mech_stats["unit_stats"]["damage"])
	)

	var sidebar := invader.get_sidebar_stats()
	assert(sidebar["display_name"] == "Invader")
	assert(sidebar["level"] == 3)
	assert(sidebar["attack_tags"] == invader.damage_tags)
	assert(sidebar["bonus_tags"] == invader.bonus_tags)

	print("Tower stats controller smoke test passed: base, paths, relics, spawned units, tags, pierce, and previews.")
	get_tree().quit(0)
