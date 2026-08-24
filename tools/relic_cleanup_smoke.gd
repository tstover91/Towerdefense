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
	var rarity_colors := {
		&"common": Color("35d6e8"),
		&"rare": Color("e94bd6"),
		&"legendary": Color("ffd447"),
	}
	for rarity in rarity_colors:
		var rarity_button := Button.new()
		director.apply_relic_icon_style(rarity_button, StringName(rarity))
		var rarity_style := rarity_button.get_theme_stylebox("normal") as StyleBoxFlat
		assert(rarity_style.bg_color.is_equal_approx(rarity_colors[rarity]))
	var relic_icon_labels: Dictionary = {}
	for relic_key in GameStats.RELICS:
		var relic_id := StringName(relic_key)
		if not bool(GameStats.get_relic(relic_id).get("enabled", true)):
			continue
		var icon_label: String = director.get_relic_icon_label(relic_id)
		assert(not icon_label.is_empty())
		assert(not relic_icon_labels.has(icon_label))
		relic_icon_labels[icon_label] = relic_id
	var status_panel := director.get_node("MainUI/HUDRoot/TopLeftPanel") as Control
	var enemy_strip := director.get_node("MainUI/HUDRoot/EnemyStrip") as Control
	var relic_strip := director.get_node("MainUI/HUDRoot/RelicStrip") as Control
	var edge_controls := director.get_node("MainUI/HUDRoot/EdgeControls") as Control
	assert(not director.has_node("MainUI/HUDRoot/TopBarBackground"))
	assert(status_panel.size.y <= 44.0)
	assert(enemy_strip.get_global_rect().position.y < relic_strip.get_global_rect().position.y)
	assert(edge_controls.get_theme_stylebox("panel") is StyleBoxEmpty)
	var status_style := status_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(status_style.bg_color.get_luminance() < 0.15)
	assert(enemy_strip.get_global_rect().end.x <= edge_controls.get_global_rect().position.x)
	assert(relic_strip.get_global_rect().end.x <= edge_controls.get_global_rect().position.x)
	assert(not director.has_node("MainUI/HUDRoot/RelicStrip/RelicLabel"))
	assert(not director.has_node(
		"MainUI/HUDRoot/RelicStrip/RelicIconList/NoRelicsLabel"
	))
	assert(director.enemy_hud_buttons.size() > 0)
	var first_enemy_id := StringName(director.enemy_hud_buttons.keys()[0])
	director.show_enemy_hud_selection(first_enemy_id)
	assert(director.enemy_info_panel.visible)
	assert(not director.enemy_info_description.text.is_empty())
	director.clear_enemy_hud_selection()
	assert(director.build_toggle_button.visible)
	assert(director.thumb_controls.z_index >= 20)
	assert(director.build_toggle_button.z_index > director.thumb_controls.z_index)
	assert(director.build_toggle_button.get_parent() == director.get_node(
		"MainUI/HUDRoot"
	))
	assert(director.build_toggle_button.is_visible_in_tree())
	var build_button_rect: Rect2 = director.build_toggle_button.get_global_rect()
	assert(build_button_rect.position.x >= 0.0)
	assert(build_button_rect.end.x <= director.get_viewport_rect().size.x)
	assert(build_button_rect.get_center().x < director.get_viewport_rect().size.x * 0.5)
	assert(
		build_button_rect.end.y
		<= director.get_viewport_rect().size.y
	)
	assert(director.build_toggle_button.size.x >= 88.0)
	assert(director.reinforcement_button.size.x >= 88.0)
	director.tower_roster.assign([&"invader"])
	director.populate_tower_list()
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
	var biological_tower = create_test_tower(
		director, &"hivemother", Vector2(420.0, 0.0)
	)
	director.refresh_relic_hud()
	assert(director.relic_hud_buttons.size() == 1)
	var network_icon := director.relic_hud_buttons[&"network_upgrade"] as Button
	assert(network_icon.text == "NU")
	assert(network_icon.custom_minimum_size.x == 30.0)
	director.show_relic_hud_selection(&"network_upgrade")
	assert(director.relic_info_panel.visible)
	assert(director.relic_info_name.text == "Network Upgrade")
	assert(director.relic_info_description.text.contains("attack speed"))
	assert(network_tower.relic_highlight_affected)
	assert(gauss_tower.relic_highlight_affected)
	assert(not biological_tower.relic_highlight_affected)
	assert(biological_tower.visual_sprite.modulate.a < 1.0)
	director.clear_relic_hud_selection()
	assert(not director.relic_info_panel.visible)
	assert(not network_tower.relic_highlight_active)
	assert(network_tower.visual_sprite.modulate.is_equal_approx(Color.WHITE))
	director.show_tower_details(network_tower)
	assert(director.tower_inspector.visible)
	assert(not director.build_sidebar_state.visible)
	assert(director.sidebar.visible)
	assert(director.build_toggle_button.visible)
	assert(director.reinforcement_button.visible)
	assert(director.reinforcement_button.icon != null)
	assert(director.build_toggle_button.icon != null)
	assert(director.reinforcement_button.text.is_empty())
	assert(director.build_toggle_button.text.is_empty())
	var reinforcement_style := (
		director.reinforcement_button.get_theme_stylebox("normal")
		as StyleBoxFlat
	)
	var build_style := (
		director.build_toggle_button.get_theme_stylebox("normal")
		as StyleBoxFlat
	)
	assert(reinforcement_style.corner_radius_top_left >= 36)
	assert(build_style.corner_radius_top_left >= 36)
	assert(build_style.border_width_left >= 4)
	assert(reinforcement_style.border_width_left >= 4)
	assert(Vector3(
		build_style.bg_color.r,
		build_style.bg_color.g,
		build_style.bg_color.b
	).distance_to(Vector3(0x35 / 255.0, 0xd6 / 255.0, 0xe8 / 255.0)) < 0.001)
	assert(Vector3(
		reinforcement_style.bg_color.r,
		reinforcement_style.bg_color.g,
		reinforcement_style.bg_color.b
	).distance_to(Vector3(0x9b / 255.0, 0xe3 / 255.0, 0x3b / 255.0)) < 0.001)
	var dock_style := director.sidebar.get_theme_stylebox("panel") as StyleBoxFlat
	assert(Vector3(
		dock_style.bg_color.r,
		dock_style.bg_color.g,
		dock_style.bg_color.b
	).distance_to(Vector3(1.0, 0xf0 / 255.0, 0xc2 / 255.0)) < 0.001)
	assert(Vector3(
		dock_style.border_color.r,
		dock_style.border_color.g,
		dock_style.border_color.b
	).distance_to(Vector3(0x20 / 255.0, 0x21 / 255.0, 0x3a / 255.0)) < 0.001)
	assert(is_equal_approx(
		director.sidebar.size.x,
		720.0
	))
	assert(director.sidebar.size.y <= 120.0)
	assert(is_equal_approx(
		director.playable_map_width,
		floorf(
			director.get_viewport().get_visible_rect().size.x
			/ GameStats.BUILD_CELL_SIZE
		) * GameStats.BUILD_CELL_SIZE
	))
	assert(director.tower_name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT)
	assert(not director.has_node(
		"MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/"
		+ "TowerInspector/InspectorHeader/BackButton"
	))
	assert(
		director.get_node(
			"MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/"
			+ "TowerInspector/InspectorScroll"
		) is VBoxContainer
	)
	assert(director.tower_tags_label.text.contains("Technology"))
	assert(director.tower_relics_label.text.contains("Network Upgrade"))
	assert(director.tower_portrait_button.icon != null)
	assert(not director.tower_inspector_details.visible)
	assert(not director.tower_tags_label.is_visible_in_tree())
	assert(not director.tower_relics_label.is_visible_in_tree())
	assert(director.tower_upgrade_button.get_parent() == director.get_node(
		"MainUI/HUDRoot/Sidebar/SidebarMargin/SidebarLayout/"
		+ "TowerInspector/InspectorHeader"
	))
	assert(director.tower_aim_button.get_parent() == director.tower_upgrade_button.get_parent())
	assert(director.tower_sell_button.get_parent() == director.tower_upgrade_button.get_parent())
	assert(director.tower_upgrade_section.visible)
	assert(director.tower_upgrade_button.text.begins_with("Upgrade"))
	assert(director.tower_upgrade_button.tooltip_text.contains("Tap twice"))
	assert(director.tower_sell_button.text.begins_with("Sell"))
	assert(director.tower_sell_button.tooltip_text.contains("Tap twice"))
	director._on_tower_portrait_pressed()
	assert(director.tower_inspector_details.visible)
	assert(director.tower_information_content.visible)
	assert(not director.tower_target_section.visible)
	assert(director.tower_tags_label.is_visible_in_tree())
	assert(director.tower_relics_label.is_visible_in_tree())
	if director.tower_aim_button.visible:
		director._on_tower_aim_pressed()
		assert(director.tower_inspector_details.visible)
		assert(not director.tower_information_content.visible)
		assert(director.tower_target_section.visible)
	director._on_build_toggle_pressed()
	assert(not director.tower_inspector.visible)
	assert(director.build_sidebar_state.visible)
	assert(director.tower_fan.visible)
	assert(not director.tower_selection_area.visible)
	assert(not director.sidebar.visible)
	assert(director.tower_fan_buttons.size() == director.tower_roster.size())
	for fan_button in director.tower_fan_buttons:
		assert(fan_button.size.x >= 78.0)
		var fan_target: Vector2 = fan_button.get_meta("fan_target_position")
		assert(fan_target.y < build_button_rect.position.y)
		var fan_style := fan_button.get_theme_stylebox("normal") as StyleBoxFlat
		assert(fan_style.corner_radius_top_left >= 39)
	assert(director.build_toggle_button.visible)
	director.set_build_drawer_open(false)
	director.show_tower_details(network_tower)
	var upgrade_style := (
		director.tower_upgrade_button.get_theme_stylebox("normal") as StyleBoxFlat
	)
	var sell_style := (
		director.tower_sell_button.get_theme_stylebox("normal") as StyleBoxFlat
	)
	assert(upgrade_style.bg_color.g > upgrade_style.bg_color.r)
	assert(sell_style.bg_color.r > sell_style.bg_color.g)
	director.money = 100000
	network_tower.selected = true
	var starting_level: int = network_tower.tower_level
	director._on_sidebar_upgrade_pressed()
	assert(network_tower.tower_level == starting_level)
	assert(network_tower.pending_action == BaseTower.MenuAction.UPGRADE)
	assert(director.tower_upgrade_button.text.begins_with("Tap Again"))
	director._on_sidebar_upgrade_pressed()
	assert(network_tower.tower_level == starting_level + 1)
	assert(network_tower.pending_action == BaseTower.MenuAction.NONE)
	assert(director.sidebar_confirmation_action == -1)
	director._on_sidebar_sell_pressed()
	assert(network_tower.pending_action == BaseTower.MenuAction.SELL)
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2.ZERO
	director._input(outside_click)
	assert(network_tower.pending_action == BaseTower.MenuAction.NONE)
	assert(director.sidebar_confirmation_action == -1)

	var sell_tower = create_test_tower(
		director, &"invader", Vector2(192.0, 0.0)
	)
	sell_tower.selected = true
	director.show_tower_details(sell_tower)
	director._on_sidebar_sell_pressed()
	assert(not sell_tower.is_queued_for_deletion())
	assert(sell_tower.pending_action == BaseTower.MenuAction.SELL)
	assert(director.tower_sell_button.text.begins_with("Tap Again"))
	director._on_sidebar_sell_pressed()
	assert(sell_tower.is_queued_for_deletion())
	assert(director.sidebar_confirmation_action == -1)

	director.show_tower_details(network_tower)
	director.clear_tower_details(network_tower)
	assert(not director.tower_inspector.visible)
	assert(director.build_sidebar_state.visible)
	assert(director.reinforcement_button.visible)
	assert(not director.tower_selection_area.visible)
	assert(not director.tower_fan.visible or director.tower_fan_tween != null)
	assert(not director.sidebar.visible)
	assert(director.build_toggle_button.visible)
	director.reinforcement_cooldown_remaining = 4.2
	director.update_reinforcement_button()
	assert(director.reinforcement_cooldown_label.visible)
	assert(director.reinforcement_cooldown_label.text == "5")
	assert(director.reinforcement_button.text.is_empty())
	director.reinforcement_cooldown_remaining = 0.0
	director.update_reinforcement_button()
	director._on_build_toggle_pressed()
	assert(director.tower_fan.visible)
	assert(not director.tower_selection_area.visible)
	assert(not director.sidebar.visible)
	assert(director.build_toggle_button.button_pressed)
	director._on_build_toggle_pressed()
	assert(not director.tower_fan.visible or director.tower_fan_tween != null)
	assert(not director.sidebar.visible)
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
