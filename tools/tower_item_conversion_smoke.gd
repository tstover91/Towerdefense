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


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var item_ids := GameStats.get_tower_item_ids()
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
	]:
		assert(not item_ids.has(held_id), "%s leaked into the item pool." % held_id)
	for converted_item_id in GameStats.CONVERTED_RELIC_ITEM_CONFIG:
		var converted_item := GameStats.get_tower_item(converted_item_id)
		assert(not converted_item.has("legacy_relic_effects"))
		assert(int(converted_item.get("item_effects", {}).get(
			converted_item_id, 0
		)) == 1)

	assert(GameStats.get_tower_item(&"long_barrel")["rarity"] == &"common")
	assert(GameStats.get_tower_item(&"penetrator_rounds")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"interference_beam")["rarity"] == &"rare")
	assert(GameStats.get_tower_item(&"death_ray")["rarity"] == &"legendary")
	assert(GameStats.get_tower_item(&"ricochet_module")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"split_chamber")["rarity"] == &"uncommon")
	assert(GameStats.get_tower_item(&"explosive_payload")["rarity"] == &"rare")
	assert(not GameStats.get_tower_item(&"heavy_rounds").has("exclusive_with"))
	assert(not GameStats.get_tower_item(&"lightweight_ammo").has("exclusive_with"))

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
	assert(invader.equip_item(&"experimental_munitions"))
	assert(invader.get_equipped_item_ids().count(&"heavy_rounds") == 1)
	assert(invader.get_equipped_item_count(0) == 2)
	assert(invader.get_equipped_item_ids().count(&"lightweight_ammo") == 1)
	assert(invader.get_effect_stack_count(&"heavy_rounds") == 2)
	assert(invader.get_owned_relic_count(&"heavy_rounds") == 0)
	assert(untouched_invader.get_effect_stack_count(&"heavy_rounds") == 0)
	assert(invader.has_bonus_tag(BaseTower.BONUS_CRITICAL))
	assert(is_equal_approx(invader.critical_multiplier, 1.5))
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
	assert(longshot.equip_item(&"deadeye"))
	assert(longshot.equip_item(&"targeting_computer"))
	assert(is_equal_approx(longshot.critical_multiplier, 8.0))
	assert(is_equal_approx(longshot.noncritical_damage_multiplier, 0.49))
	assert(is_equal_approx(longshot.miss_chance, 0.20))
	assert(is_equal_approx(longshot.critical_chance, 0.22))

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

	var reaver := await _create_tower(fake_main, &"reaver")
	assert(reaver.equip_item(&"strength_in_numbers"))
	assert(reaver.equip_item(&"strength_in_numbers"))
	assert(reaver.get_effect_stack_count(&"strength_in_numbers") == 2)

	var scanner_tower := await _create_tower(fake_main, &"invader")
	assert(scanner_tower.equip_item(&"scanner_implant"))
	assert(scanner_tower.has_bonus_tag(BaseTower.BONUS_REVEAL))
	assert(scanner_tower.equip_item(&"perfect_intelligence"))

	var depot := await _create_tower(fake_main, &"dronedepot")
	var base_unit_damage := int(
		depot.get_current_effective_stats()["unit_stats"]["damage"]
	)
	assert(depot.equip_item(&"trade_agreement"))
	var modified_unit_damage := int(
		depot.get_current_effective_stats()["unit_stats"]["damage"]
	)
	assert(
		modified_unit_damage
		== maxi(roundi(
			float(base_unit_damage)
			* GameStats.TRADE_AGREEMENT_UNIT_DAMAGE_MULTIPLIER
		), 1)
	)
	assert(depot.attack_component.spawn_batch_size == 2)

	print("Tower item conversion smoke test passed: held exclusions, four rarities, compatibility, non-exclusive combinations, single-slot stacking, scoped effects, tags, and legendary Spawner behavior.")
	get_tree().quit(0)


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower
