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
	assert(not bool(GameStats.get_relic(&"pressure_point").get("enabled", true)))
	assert(GameStats.get_relic(&"experimental_munitions")["rarity"] == &"rare")
	assert(not GameStats.get_relic(&"experimental_munitions").has("latest_draft_round"))
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
	var third_draft_offers: Array[StringName] = [
		&"overcharged_capacitor", &"conductive", &"static_discharge",
	]
	var third_draft_quantities: Dictionary = director.draft_manager.get_relic_choice_quantities(
		11,
		third_draft_offers
	)
	assert(int(third_draft_quantities.get(&"overcharged_capacitor", 1)) == 2)
	assert(int(third_draft_quantities.get(&"conductive", 1)) == 1)
	assert(int(third_draft_quantities.get(&"static_discharge", 1)) == 1)
	var second_draft_offers: Array[StringName] = [&"overcharged_capacitor"]
	assert(director.draft_manager.get_relic_choice_quantities(
		5,
		second_draft_offers
	).is_empty())
	var relic_card: ShopChoiceCard = director.between_round_shop.cards[0]
	assert_relic_card_color(
		relic_card, &"overcharged_capacitor", ShopChoiceCard.COMMON_COLOR
	)
	assert_relic_card_color(
		relic_card, &"static_discharge", ShopChoiceCard.RARE_COLOR
	)
	assert_relic_card_color(
		relic_card, &"contraband_blueprint", ShopChoiceCard.LEGENDARY_COLOR
	)
	relic_card.display_item(
		GameStats.get_tower_draft_entry(&"invader"), 0, false
	)
	assert(relic_card.category_label.get_theme_color(
		"font_color"
	).is_equal_approx(relic_card.default_category_color))
	director.shop_rng.seed = 481516
	director.recent_relic_offers.clear()
	for draft_round in [1, 5, 11, 20]:
		director.round_number = draft_round
		var relic_offers: Array[StringName] = director.roll_relic_offers()
		var expected_count := 4 if draft_round in [1, 5] else 3
		assert(relic_offers.size() == expected_count)
		var applicable_count := 0
		var doubled_common_count := 0
		var rare_plus_count := 0
		for relic_id in relic_offers:
			var rarity: StringName = GameStats.get_relic(relic_id)["rarity"]
			if rarity in [&"rare", &"legendary"]:
				rare_plus_count += 1
			if draft_round == 1:
				assert(rarity == &"common")
			if director.is_relic_applicable_to_current_loadout(
				relic_id,
				base_roster_tags
			):
				applicable_count += 1
			if (
				draft_round == 11
				and is_doubled_common_offer(
					director.draft_manager, draft_round, relic_id
				)
			):
				doubled_common_count += 1
		assert(applicable_count >= int(
			director.draft_manager.RELIC_MINIMUM_APPLICABLE_BY_ROUND[draft_round]
		))
		assert(rare_plus_count >= int(
			director.draft_manager.RELIC_MINIMUM_RARE_PLUS_BY_ROUND.get(
				draft_round, 0
			)
		))
		if draft_round == 11:
			assert(applicable_count == 3)
			assert(doubled_common_count == 1)
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
	var gauss_tower = create_test_tower(
		director, &"gauss_repeater", Vector2(96.0, 0.0)
	)
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
	assert(network_tower.receives_relic_effect(&"network_upgrade"))
	assert(gauss_tower.receives_relic_effect(&"network_upgrade"))
	assert(network_tower.get_active_relic_effect_ids().has(&"network_upgrade"))
	var network_stats: Dictionary = network_tower.get_effective_stats_for_level(0)
	assert(is_equal_approx(float(network_stats["firerate"]), 0.40 / 1.24))
	var placed_towers: Array[Node] = [
		network_tower, gauss_tower, diagonal_tower,
	]
	director.pause_menu.populate_owned_items(
		director.owned_shop_items,
		placed_towers
	)
	assert(director.pause_menu.items_grid.get_child_count() == 1)
	var displayed_enemies: Array[StringName] = [&"normal", &"runner"]
	director.pause_menu.populate_enemy_pool(displayed_enemies, 2)
	assert(director.pause_menu.enemies_grid.get_child_count() == 2)
	assert(director.pause_menu.enemy_header.text == "Enemy Pool — Round 2")

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


func assert_relic_card_color(
	card: ShopChoiceCard,
	relic_id: StringName,
	expected_color: Color
) -> void:
	card.display_item(GameStats.get_relic(relic_id), 0, true)
	var panel_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel_style != null)
	assert(panel_style.border_color.is_equal_approx(expected_color))
	assert(card.category_label.get_theme_color(
		"font_color"
	).is_equal_approx(expected_color))


func is_doubled_common_offer(
	draft_manager: DraftManager,
	draft_round: int,
	relic_id: StringName
) -> bool:
	var single_offer: Array[StringName] = [relic_id]
	return int(draft_manager.get_relic_choice_quantities(
		draft_round,
		single_offer
	).get(relic_id, 1)) == 2
