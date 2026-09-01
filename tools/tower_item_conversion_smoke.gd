extends Node

const GameStats = preload("res://stat_database.gd")
const ItemShopManagerScript = preload("res://tower_items/item_shop_manager.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
	var relics: Dictionary = {}
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))

	func show_tower_details(_tower: Node) -> void:
		pass


class FakeElectricTarget:
	extends Node
	var registered_hits := 0
	var registered_damage := 0

	func register_electric_hit(
		received_damage: int,
		_attack_context: AttackContext
	) -> void:
		registered_hits += 1
		registered_damage += received_damage


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var item_ids := GameStats.get_tower_item_ids()
	var price_bands := {
		&"common": Vector2i(3500, 5000),
		&"uncommon": Vector2i(5500, 7500),
		&"rare": Vector2i(8000, 10000),
		&"legendary": Vector2i(14000, 17000),
	}
	var rarity_counts := {
		&"common": 0,
		&"uncommon": 0,
		&"rare": 0,
		&"legendary": 0,
	}
	for item_id in item_ids:
		var catalog_item := GameStats.get_tower_item(item_id)
		var rarity := StringName(catalog_item.get("rarity", &""))
		assert(price_bands.has(rarity), "%s has an invalid rarity." % item_id)
		var price := int(catalog_item.get("price", 0))
		var price_band: Vector2i = price_bands[rarity]
		assert(
			price >= price_band.x and price <= price_band.y,
			"%s price %d is outside the %s band." % [item_id, price, rarity]
		)
		var max_copies := int(catalog_item.get("max_copies_per_tower", 0))
		assert(
			max_copies == 1 or max_copies == GameStats.TOWER_ITEM_STACK_LIMIT,
			"%s must be single-copy or stack to the slot cap." % item_id
		)
		rarity_counts[rarity] = int(rarity_counts[rarity]) + 1
	assert(rarity_counts[&"common"] == 18)
	assert(rarity_counts[&"uncommon"] == 18)
	assert(rarity_counts[&"rare"] == 18)
	assert(rarity_counts[&"legendary"] == 0)
	for held_id in [
		&"network_upgrade",
		&"pack_hunter",
		&"predatory_instinct",
		&"maximum_payload",
		&"dividends",
		&"holiday_sale",
		&"contraband_blueprint",
		&"singularity_core",
		&"perfect_mutation",
		&"targeting_computer",
		&"beam_optics",
		&"long_barrel",
		&"point_blank",
		&"wide_lens",
		&"lone_wolf",
		&"deadeye",
		&"lingering_thoughts",
		&"quick_thinking",
		&"heavy_payload",
		&"strength_in_numbers",
		&"experimental_munitions",
	]:
		assert(not item_ids.has(held_id), "%s leaked into the item pool." % held_id)
	for adapted_item_id in GameStats.ADAPTED_TOWER_ITEMS:
		var adapted_item := GameStats.get_tower_item(adapted_item_id)
		for obsolete_key in ["enabled", "exclusive_with", "stackable"]:
			assert(not adapted_item.has(obsolete_key))
		assert(not String(adapted_item.get("description", "")).to_lower().contains(
			"relic"
		))
		assert(int(adapted_item.get("item_effects", {}).get(
			adapted_item_id, 0
		)) == 1)

	assert(GameStats.has_tower_item(&"long_barrel"))
	assert(GameStats.get_tower_item(&"penetrator_rounds")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"interference_beam")["rarity"] == &"common")
	assert(GameStats.get_tower_item(&"giant_killer")["rarity"] == &"common")
	assert(GameStats.get_tower_item(&"death_ray")["rarity"] == &"rare")
	assert(GameStats.get_tower_item(&"youre_not_special")["rarity"] == &"rare")
	assert(GameStats.get_tower_item(&"trade_agreement")["rarity"] == &"rare")
	assert(GameStats.get_tower_item(&"ricochet_module")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"ricochet_module")["required_any_tags"] == [&"ballistic", &"beam"])
	assert(GameStats.get_tower_item(&"penetrator_rounds")["required_any_tags"] == [&"ballistic", &"beam"])
	assert(GameStats.get_tower_item(&"split_chamber")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"explosive_payload")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"live_wire")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"afterimage_round")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"pressure_point")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"follow_through")["rarity"] == &"uncommon")
	assert(not GameStats.get_tower_item(&"heavy_rounds").has("exclusive_with"))
	assert(not GameStats.get_tower_item(&"lightweight_ammo").has("exclusive_with"))
	for approved_item_id in [
		&"blast_gel",
		&"reinforced_components",
		&"calibrated_gears",
		&"rangefinder",
		&"kinetic_rebound",
		&"afterimage_round",
		&"secondary_detonator",
		&"crippling_current",
		&"aftershock",
		&"patient_hunter",
		&"replication_matrix",
		&"training_manual",
		&"mentor",
		&"fracture_rounds",
		&"sticky_charge",
		&"experimental_blueprint",
	]:
		assert(item_ids.has(approved_item_id), "%s missing from shop." % approved_item_id)
	assert(not item_ids.has(&"critical_fragmentation"))

	var shop_manager := ItemShopManagerScript.new()
	for phase in [&"early", &"middle", &"late"]:
		var weights: Dictionary = shop_manager.RARITY_WEIGHTS_BY_ROUND[phase]
		for rarity in [&"common", &"uncommon", &"rare", &"legendary"]:
			assert(weights.has(rarity))

	var fake_main := FakeMain.new()
	add_child(fake_main)

	var invader := await _create_tower(fake_main, &"invader")
	var untouched_invader := await _create_tower(fake_main, &"invader")
	var base_invader_stats := invader.get_current_effective_stats()
	assert(invader.equip_item(&"heavy_rounds"))
	assert(invader.can_equip_item(&"lightweight_ammo"))
	assert(invader.item_controller.is_item_compatible(&"lightweight_ammo"))
	assert(invader.equip_item(&"lightweight_ammo"))
	assert(invader.equip_item(&"heavy_rounds"))
	assert(invader.equip_item(&"lucky_shot"))
	assert(invader.get_equipped_item_ids().count(&"heavy_rounds") == 1)
	assert(invader.get_equipped_item_count(0) == 2)
	assert(invader.get_equipped_item_ids().count(&"lightweight_ammo") == 1)
	assert(invader.get_effect_stack_count(&"heavy_rounds") == 2)
	assert(untouched_invader.get_effect_stack_count(&"heavy_rounds") == 0)
	assert(not invader.has_bonus_tag(&"critical"))
	assert(is_equal_approx(
		invader.critical_chance, GameStats.LUCKY_SHOT_CHANCE_PER_STACK
	))
	assert(is_equal_approx(
		invader.critical_multiplier, GameStats.DEFAULT_CRITICAL_MULTIPLIER
	))
	assert(
		invader.damage
		== roundi(
			float(base_invader_stats["damage"])
			* pow(GameStats.HEAVY_ROUNDS_DAMAGE_MULTIPLIER, 2)
			* GameStats.LIGHTWEIGHT_AMMO_DAMAGE_MULTIPLIER
		)
	)

	var longshot := await _create_tower(fake_main, &"longshot")
	assert(longshot.equip_item(&"glass_cannon"))
	assert(longshot.equip_item(&"glass_cannon"))
	assert(is_equal_approx(longshot.critical_multiplier, 4.0))
	assert(is_equal_approx(longshot.noncritical_damage_multiplier, 0.64))
	assert(is_equal_approx(longshot.miss_chance, 0.0))
	assert(is_equal_approx(longshot.critical_chance, 0.10))

	var energy_core := await _create_tower(fake_main, &"energycore")
	assert(energy_core.equip_item(&"chain_lightning"))
	assert(energy_core.equip_item(&"chain_lightning"))
	assert(energy_core.get_effect_stack_count(&"chain_lightning") == 2)
	var electric_metadata := energy_core.get_attack_effect_metadata(
		energy_core.global_position,
		energy_core.range_radius_pixels,
		energy_core.type_tags,
		energy_core.damage_tags
	)
	assert(int(electric_metadata.get("chain_lightning", 0)) == 2)

	var scanner_tower := await _create_tower(fake_main, &"invader")
	assert(scanner_tower.equip_item(&"scanner_implant"))
	assert(scanner_tower.has_bonus_tag(BaseTower.BONUS_REVEAL))
	assert(scanner_tower.equip_item(&"perfect_intelligence"))

	var payload_tower := await _create_tower(fake_main, &"slinger")
	assert(payload_tower.equip_item(&"explosive_payload"))
	assert(payload_tower.has_bonus_tag(&"explosive"))
	assert(payload_tower.can_equip_item(&"blast_gel"))

	var live_wire_tower := await _create_tower(fake_main, &"invader")
	assert(live_wire_tower.equip_item(&"live_wire"))
	assert(live_wire_tower.has_bonus_tag(&"electric"))
	assert(live_wire_tower.can_equip_item(&"conductive"))
	assert(live_wire_tower.equip_item(&"overcharged_capacitor"))
	var live_wire_effects := live_wire_tower.get_attack_effect_metadata(
		live_wire_tower.global_position,
		live_wire_tower.range_radius_pixels,
		live_wire_tower.type_tags,
		live_wire_tower.damage_tags
	)
	assert(int(live_wire_effects.get("overcharged_capacitor", 0)) == 1)
	var electric_target := FakeElectricTarget.new()
	add_child(electric_target)
	var live_wire_context := AttackContext.from_tower(live_wire_tower)
	live_wire_tower.item_controller.notify_damage_dealt(
		electric_target, 100, live_wire_context, &"ballistic"
	)
	assert(electric_target.registered_hits == 1)
	assert(electric_target.registered_damage == 100)
	# Native Electric damage is registered by the enemy itself; Live Wire must
	# not add a duplicate contribution.
	live_wire_tower.item_controller.notify_damage_dealt(
		electric_target, 100, live_wire_context, &"electric"
	)
	assert(electric_target.registered_hits == 1)

	# Tag-granting prerequisites must work regardless of their physical slot
	# order after swaps. Put Conductive before the Live Wire that enables it.
	var reversed_wire_tower := await _create_tower(fake_main, &"invader")
	assert(reversed_wire_tower.equip_item(&"live_wire", 3))
	assert(reversed_wire_tower.equip_item(&"conductive", 0))
	assert(reversed_wire_tower.get_equipped_item_ids()[0] == &"conductive")
	assert(reversed_wire_tower.get_equipped_item_ids()[3] == &"live_wire")
	assert(reversed_wire_tower.item_controller.is_item_active_in_slot(0))
	assert(reversed_wire_tower.item_controller.is_item_active_in_slot(3))

	var depot := await _create_tower(fake_main, &"dronedepot")
	var base_unit_damage := int(
		depot.get_current_effective_stats()["unit_stats"]["damage"]
	)
	assert(depot.equip_item(&"trade_agreement"))
	var modified_unit_damage := int(
		depot.get_current_effective_stats()["unit_stats"]["damage"]
	)
	var modified_unit_budget := float(
		depot.get_current_effective_stats()["unit_stats"]["damage_budget"]
	)
	assert(
		modified_unit_damage
		== maxi(roundi(
			float(base_unit_damage)
			* GameStats.TRADE_AGREEMENT_UNIT_DAMAGE_MULTIPLIER
		), 1)
	)
	assert(depot.attack_component.spawn_batch_size == 2)
	assert(depot.attack_component.spawn_limit == 2)
	assert(is_equal_approx(modified_unit_budget, 800.0))

	var slinger := await _create_tower(fake_main, &"slinger")
	assert(slinger.can_equip_item(&"kinetic_rebound"))
	assert(slinger.equip_item(&"fracture_rounds"))
	assert(slinger.equip_item(&"sticky_charge"))

	var trainee := await _create_tower(fake_main, &"invader")
	var trainee_base_damage := trainee.damage
	assert(trainee.equip_item(&"training_manual"))
	assert(trainee.equip_item(&"training_manual"))
	assert(trainee.get_equipped_item_count(0) == 2)
	assert(trainee.damage == maxi(roundi(
		float(trainee_base_damage) * pow(0.88, 2)
	), 1))
	assert(is_equal_approx(
		trainee.item_controller.modify_and_share_xp(10.0), 18.0
	))

	var mentor := await _create_tower(fake_main, &"invader")
	var student := await _create_tower(fake_main, &"invader")
	mentor.position = Vector2(1000.0, 0.0)
	student.position = Vector2(1010.0, 0.0)
	mentor.is_placed = true
	student.is_placed = true
	assert(mentor.equip_item(&"mentor"))
	assert(is_equal_approx(
		mentor.item_controller.modify_and_share_xp(100.0), 60.0
	))
	assert(is_equal_approx(student.instance_progression.xp, 40.0))

	var hunter := await _create_tower(fake_main, &"longshot")
	hunter.is_placed = true
	fake_main.round_active = true
	assert(hunter.equip_item(&"patient_hunter"))
	hunter.item_controller.process_combat_time(3.0)
	hunter.notify_attack_started()
	assert(is_equal_approx(
		hunter.item_controller.get_pending_attack_damage_multiplier(), 1.60
	))

	var blueprint_stats: Dictionary = depot.item_controller.apply_spawn_variant_to_stats(
		{"damage": 100, "attack_interval": 1.0, "damage_budget": 1000.0},
		&"defective",
		true
	)
	assert(int(blueprint_stats["damage"]) == 38)
	assert(is_equal_approx(float(blueprint_stats["damage_budget"]), 375.0))
	assert(bool(blueprint_stats["replicated_unit"]))

	print("Tower item conversion smoke test passed: catalog rarity, pricing, stacking, compatibility, XP items, Patient Hunter, spawn variants, scoped effects, tags, and Spawner behavior.")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower
