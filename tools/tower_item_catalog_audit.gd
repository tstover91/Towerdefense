extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")

const VALID_RARITIES: Array[StringName] = [&"common", &"uncommon", &"rare"]
const VALID_DEFINITION_KEYS: Array[StringName] = [
	&"id", &"display_name", &"description", &"rarity", &"category", &"price",
	&"texture",
	&"shop_enabled", &"max_copies_per_tower", &"allowed_tower_ids",
	&"required_all_tags", &"required_any_tags", &"forbidden_tags",
	&"exclusive_with",
	&"stat_defaults", &"stat_multipliers", &"stat_additions",
	&"stat_minimums", &"stat_overrides", &"unit_stat_defaults",
	&"unit_stat_multipliers", &"unit_stat_additions", &"unit_stat_minimums",
	&"unit_stat_overrides",
	&"add_type_tags", &"add_damage_tags", &"add_bonus_tags",
	&"pierce_count_add", &"item_effects", &"trigger_effects",
]
const RECOGNIZED_TRIGGER_EFFECTS: Array[StringName] = [
	&"kill_cooldown_remaining_multiplier",
	&"critical_kill_cooldown_remaining_multiplier",
	&"primary_hit_explosion_damage_multiplier", &"primary_hit_explosion_radius",
	&"additional_projectiles", &"contributes_electric_hits",
	&"bounce_damage_multiplier", &"critical_fragment_count",
	&"afterimage_projectile_count", &"secondary_detonation",
	&"temporary_armor_reduction", &"aftershock", &"patient_hunter",
	&"replication_matrix", &"xp_gain_bonus", &"mentor",
	&"terminal_fragment_count", &"sticky_charge", &"experimental_blueprint",
]
const RECOGNIZED_ITEM_EFFECTS: Array[StringName] = [
	&"blast_gel", &"focused_lens", &"wide_lens", &"interference_beam",
	&"microwave", &"death_ray", &"hollow_point", &"heavy_rounds",
	&"lightweight_ammo", &"suppressive_fire", &"experimental_munitions",
	&"frenzy", &"duelist", &"relentless", &"giant_killer",
	&"strength_in_numbers", &"lone_wolf", &"high_yield",
	&"concentrated_charge", &"crowd_pleaser", &"direct_hit",
	&"thermite_bombs", &"charred_clothes", &"conductive",
	&"overcharged_capacitor", &"static_discharge", &"chain_lightning",
	&"lucky_shot", &"glass_cannon", &"pressure_point", &"deadeye",
	&"lingering_thoughts", &"quick_thinking", &"perfect_intelligence",
	&"follow_through", &"big_game_control", &"emergency_brake",
	&"youre_not_special", &"trade_agreement",
	&"radiation_conversion", &"probability_transmitter",
]


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass

	func can_purchase_tower_evolution() -> bool:
		return not game_ended and not shop_open

	func spend_money(amount: int) -> bool:
		if amount > money:
			return false
		money -= amount
		return true

	func add_money(amount: int) -> void:
		money += amount


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var variants: Array[BaseTower] = []
	for family_id in GameStats.get_playable_tower_family_ids():
		variants.append(await _create_tower(fake_main, family_id))
		for evolution_key in GameStats.get_tower_evolutions(family_id):
			variants.append(await _create_tower(
				fake_main, family_id, StringName(evolution_key)
			))

	var enabled_ids := GameStats.get_tower_item_ids()
	var compatible_variants: Dictionary = {}
	for item_id in enabled_ids:
		var item := GameStats.get_tower_item(item_id)
		if not _check_catalog_definition(item_id, item):
			return
		var matches: Array[BaseTower] = []
		for tower in variants:
			if _is_item_reachable(tower, item_id, enabled_ids):
				matches.append(tower)
		if not _check(
			not matches.is_empty(),
			"Enabled item %s is incompatible with every playable tower/evolution." % item_id
		):
			return
		compatible_variants[item_id] = matches

	for item_id in enabled_ids:
		var source: BaseTower = compatible_variants[item_id][0]
		var test_tower := await _create_tower(
			fake_main,
			source.tower_id,
			source.instance_progression.evolution_id
		)
		var item := GameStats.get_tower_item(item_id)
		if not test_tower.item_controller.is_item_compatible(item_id):
			_equip_tag_prerequisites(test_tower, item_id, enabled_ids)
		var maximum := int(item.get(
			"max_copies_per_tower", GameStats.TOWER_ITEM_STACK_LIMIT
		))
		for copy_index in maximum:
			if not _check(
				test_tower.equip_item(item_id),
				"%s failed to equip copy %d on a compatible tower." % [
					item_id, copy_index + 1
				]
			):
				return
		if not _check(
			test_tower.get_equipped_item_ids().count(item_id) == 1
			and test_tower.item_controller.get_total_equipped_item_count(item_id) == maximum,
			"%s copies did not combine into one tower slot." % item_id
		):
			return
		if not _check(
			not test_tower.equip_item(item_id),
			"%s exceeded its configured per-tower copy limit." % item_id
		):
			return
		test_tower.queue_free()
		await get_tree().process_frame

	for tower in variants:
		tower.queue_free()
	await get_tree().process_frame
	print("Tower item catalog audit passed: %d enabled items have valid data, at least one compatible playable variant, functional equip limits, and single-slot stacking." % enabled_ids.size())
	get_tree().quit(0)


func _is_item_reachable(
	tower: BaseTower,
	item_id: StringName,
	enabled_ids: Array[StringName]
) -> bool:
	var tags: Array[StringName] = tower.item_controller.get_compatibility_tags()
	var changed := true
	while changed:
		changed = false
		for candidate_id in enabled_ids:
			var candidate := GameStats.get_tower_item(candidate_id)
			if not _definition_matches_tags(candidate, tower.tower_id, tags):
				continue
			for normalized in _get_granted_tags(candidate_id, candidate):
				if not tags.has(normalized):
					tags.append(normalized)
					changed = true
	return _definition_matches_tags(
		GameStats.get_tower_item(item_id), tower.tower_id, tags
	)


func _equip_tag_prerequisites(
	tower: BaseTower,
	target_item_id: StringName,
	enabled_ids: Array[StringName]
) -> void:
	for _pass in GameStats.TOWER_ITEM_SLOT_COUNT:
		if tower.item_controller.is_item_compatible(target_item_id):
			return
		var target := GameStats.get_tower_item(target_item_id)
		var current_tags: Array[StringName] = (
			tower.item_controller.get_compatibility_tags()
		)
		var wanted_tags: Array[StringName] = []
		for tag in target.get("required_all_tags", []):
			if not current_tags.has(StringName(tag)):
				wanted_tags.append(StringName(tag))
		if wanted_tags.is_empty():
			for tag in target.get("required_any_tags", []):
				wanted_tags.append(StringName(tag))
		var equipped_one := false
		for candidate_id in enabled_ids:
			if candidate_id == target_item_id:
				continue
			var candidate := GameStats.get_tower_item(candidate_id)
			var granted_tags := _get_granted_tags(candidate_id, candidate)
			var grants_tags: bool = not granted_tags.is_empty()
			var grants_wanted := false
			for tag in granted_tags:
				if wanted_tags.has(tag):
					grants_wanted = true
			if (
				grants_tags and grants_wanted
				and tower.item_controller.is_item_compatible(candidate_id)
				and tower.equip_item(candidate_id)
			):
				equipped_one = true
				break
		if not equipped_one:
			return


func _definition_matches_tags(
	item: Dictionary,
	tower_id: StringName,
	tags: Array[StringName]
) -> bool:
	var allowed: Array = item.get("allowed_tower_ids", [])
	if not allowed.is_empty() and not allowed.has(tower_id):
		return false
	for tag in item.get("required_all_tags", []):
		if not tags.has(StringName(tag)):
			return false
	var required_any: Array = item.get("required_any_tags", [])
	if not required_any.is_empty():
		var any_match := false
		for tag in required_any:
			if tags.has(StringName(tag)):
				any_match = true
				break
		if not any_match:
			return false
	for tag in item.get("forbidden_tags", []):
		if tags.has(StringName(tag)):
			return false
	return true


func _get_granted_tags(
	item_id: StringName,
	item: Dictionary
) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag_key in ["add_type_tags", "add_damage_tags", "add_bonus_tags"]:
		for tag in item.get(tag_key, []):
			var normalized := StringName(tag)
			if not result.has(normalized):
				result.append(normalized)
	return result


func _check_catalog_definition(item_id: StringName, item: Dictionary) -> bool:
	for key in item:
		if not _check(
			VALID_DEFINITION_KEYS.has(StringName(key)),
			"%s uses unsupported definition key %s." % [item_id, key]
		):
			return false
	if not _check(
		not String(item.get("display_name", "")).strip_edges().is_empty(),
		"%s has no display name." % item_id
	):
		return false
	if not _check(
		not String(item.get("description", "")).strip_edges().is_empty(),
		"%s has no player-facing description." % item_id
	):
		return false
	if not _check(
		VALID_RARITIES.has(StringName(item.get("rarity", &""))),
		"%s has an unsupported rarity." % item_id
	):
		return false
	if not _check(int(item.get("price", 0)) > 0, "%s has no valid price." % item_id):
		return false
	for effect_key in item.get("trigger_effects", {}):
		if not _check(
			RECOGNIZED_TRIGGER_EFFECTS.has(StringName(effect_key)),
			"%s declares unhandled trigger effect %s." % [item_id, effect_key]
		):
			return false
	for effect_key in item.get("item_effects", {}):
		if not _check(
			RECOGNIZED_ITEM_EFFECTS.has(StringName(effect_key)),
			"%s declares unhandled combat effect %s." % [item_id, effect_key]
		):
			return false
	var maximum := int(item.get(
		"max_copies_per_tower", GameStats.TOWER_ITEM_STACK_LIMIT
	))
	return _check(
		maximum == 1 or maximum == GameStats.TOWER_ITEM_STACK_LIMIT,
		"%s must be single-copy or stack to the configured stack limit." % item_id
	)


func _create_tower(
	fake_main: Node,
	family_id: StringName,
	evolution_id: StringName = &""
) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = family_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	if not evolution_id.is_empty():
		var evolution := GameStats.get_tower_evolution(family_id, evolution_id)
		tower.instance_progression.choose_evolution(
			evolution_id, int(evolution.get("cost", 0))
		)
		tower.purchased_paths.assign([
			StringName(evolution.get("legacy_path_id", &""))
		])
		tower.configure_attack_component()
		tower.load_base_tags()
		tower.load_level_stats()
	return tower


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
