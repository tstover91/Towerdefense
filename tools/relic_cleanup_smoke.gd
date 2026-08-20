extends Node

const MAIN_SCENE = preload("res://main.tscn")
const MOB_SCENE = preload("res://mob.tscn")
const TOWER_SCENE = preload("res://base_tower.tscn")
const GameStats = preload("res://stat_database.gd")


func _init() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	assert(not GameStats.RELICS.has(&"opening_shot"))
	assert(not GameStats.RELICS.has(&"long_term_investment"))
	assert(is_equal_approx(GameStats.HOLLOW_POINT_DAMAGE_PER_STACK, 0.25))

	var director = MAIN_SCENE.instantiate()
	get_tree().root.add_child(director)
	director.tower_roster.assign([&"invader"])
	var base_roster_tags: Array[StringName] = director.get_tower_roster_tags()
	assert(base_roster_tags.has(&"biological"))
	assert(base_roster_tags.has(&"ballistic"))
	assert(not base_roster_tags.has(&"critical"))
	assert(not base_roster_tags.has(&"pierce"))
	assert(not base_roster_tags.has(&"reveal"))
	assert(director.is_relic_applicable_to_current_loadout(
		&"hollow_point", base_roster_tags
	))
	assert(not director.is_relic_applicable_to_current_loadout(
		&"lucky_shot", base_roster_tags
	))
	assert(not director.is_relic_applicable_to_current_loadout(
		&"deep_penetration", base_roster_tags
	))
	assert(director.is_relic_applicable_to_current_loadout(
		&"dividends", base_roster_tags
	))
	director.shop_rng.seed = 481516
	director.recent_relic_offers.clear()
	for draft_round in [1, 6, 11, 16, 20]:
		director.round_number = draft_round
		var relic_offers: Array[StringName] = director.roll_relic_offers()
		var expected_count := 4 if draft_round in [1, 6, 16] else 3
		assert(relic_offers.size() == expected_count)
		for relic_id in relic_offers:
			assert(director.is_relic_applicable_to_current_loadout(
				relic_id,
				base_roster_tags
			))
		if draft_round == 16:
			var quantities: Dictionary = director.get_relic_choice_quantities(
				relic_offers
			)
			assert(int(quantities.get(relic_offers.back(), 1)) == 2)
	var tower_offers: Array[StringName] = director.roll_tower_offers()
	assert(tower_offers.size() == 3)
	assert(not tower_offers.has(&"invader"))

	var test_mob = MOB_SCENE.instantiate()
	test_mob.enemy_id = &"normal"
	director.add_child(test_mob)
	var hollow_point_context := AttackContext.legacy(&"invader", &"direct")
	hollow_point_context.metadata["hollow_point"] = 1
	test_mob.max_health = 1000
	test_mob.health = 751
	assert(test_mob.apply_damage(
		100, &"ballistic", false, true, hollow_point_context
	) == 125)
	test_mob.health = 750
	assert(test_mob.apply_damage(
		100, &"ballistic", false, true, hollow_point_context
	) == 100)

	director.owned_shop_items[&"network_upgrade"] = 1
	var network_tower = create_test_tower(director, &"energycore", Vector2.ZERO)
	create_test_tower(director, &"gauss_repeater", Vector2(96.0, 0.0))
	var diagonal_tower = create_test_tower(
		director, &"saucer", Vector2(88.0, 88.0)
	)
	assert(network_tower.get_nearby_type_tower_count(
		&"technology", GameStats.BUILD_CELL_SIZE
	) == 1)
	diagonal_tower.global_position = Vector2(86.0, 86.0)
	assert(network_tower.get_nearby_type_tower_count(
		&"technology", GameStats.BUILD_CELL_SIZE
	) == 2)
	var network_stats: Dictionary = network_tower.get_effective_stats_for_level(0)
	assert(is_equal_approx(float(network_stats["firerate"]), 0.40 / 1.24))

	print("Relic cleanup smoke checks passed.")
	director.queue_free()
	get_tree().quit(0)


func create_test_tower(
	director: Node,
	tower_id: StringName,
	world_position: Vector2
) -> Node2D:
	var tower = TOWER_SCENE.instantiate()
	tower.main = director
	tower.tower_id = tower_id
	director.add_child(tower)
	tower.global_position = world_position
	tower.is_placed = true
	return tower
