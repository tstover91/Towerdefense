extends Node

const GameStats = preload("res://stat_database.gd")
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
	var money := 100_000
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func spend_money(amount: int) -> bool:
		if amount > money:
			return false
		money -= amount
		money_changed.emit(money)
		return true

	func add_money(amount: int) -> void:
		money += amount
		money_changed.emit(money)

	func show_tower_details(_tower: Node) -> void:
		pass

	func can_purchase_tower_evolution() -> bool:
		return not game_ended and not shop_open


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var slinger_wave := await _create_tower(fake_main, &"slinger")
	var slinger_build := await _create_tower(fake_main, &"slinger")
	var void_caller := await _create_tower(fake_main, &"voidcaller")
	var orbital_cannon := await _create_tower(fake_main, &"orbitalcannon")

	if not _check(
		GameStats.get_tower_evolutions(&"slinger").size() == 2,
		"Slinger did not expose both pilot evolutions."
	):
		return
	if not _check(
		GameStats.get_tower_evolutions(&"voidcaller").size() == 2,
		"Void Caller did not expose both pilot evolutions."
	):
		return
	if not _check(
		GameStats.get_tower_evolutions(&"orbitalcannon").size() == 3,
		"Orbital Cannon did not expose all three evolutions."
	):
		return

	if not _check(
		not orbital_cannon.can_purchase_evolution(&"solar_lance", false),
		"A below-level tower could evolve."
	):
		return

	_level_to_evolution(slinger_wave)
	_level_to_evolution(slinger_build)
	_level_to_evolution(void_caller)
	fake_main.round_active = true
	var wave_xp_before: float = slinger_wave.instance_progression.xp
	var wave_money_before := fake_main.money
	var explosive_cost := int(
		GameStats.get_tower_evolution(&"slinger", &"explosive_ricochet")["cost"]
	)
	slinger_wave.select_evolution_choice(&"explosive_ricochet")
	slinger_wave.purchase_selected_evolution()
	if not _check(
		slinger_wave.instance_progression.evolution_id == &"explosive_ricochet",
		"Evolution could not be purchased during an active wave."
	):
		return
	if not _check(
		fake_main.money == wave_money_before - explosive_cost,
		"Wave evolution charged the wrong gold amount."
	):
		return
	if not _check(
		is_equal_approx(slinger_wave.instance_progression.xp, wave_xp_before),
		"Evolution did not preserve the tower's XP."
	):
		return
	if not _check(
		slinger_wave.purchased_paths == [&"a"],
		"Evolution did not activate its adapted gameplay behavior."
	):
		return
	if not _check(
		not slinger_wave.can_purchase_evolution(&"razor_disc", false),
		"One tower instance could purchase a second evolution."
	):
		return

	fake_main.round_active = false
	fake_main.shop_open = false
	slinger_build.select_evolution_choice(&"razor_disc")
	slinger_build.purchase_selected_evolution()
	if not _check(
		slinger_build.instance_progression.evolution_id == &"razor_disc",
		"Evolution could not be purchased in the pre-round build phase."
	):
		return
	if not _check(
		slinger_build.purchased_paths == [&"b"],
		"A second copy could not take a different evolution."
	):
		return

	fake_main.shop_open = true
	var shop_money_before := fake_main.money
	void_caller.select_evolution_choice(&"singularity")
	void_caller.purchase_selected_evolution()
	if not _check(
		void_caller.instance_progression.evolution_id.is_empty(),
		"Evolution was purchased while the store was open."
	):
		return
	if not _check(
		fake_main.money == shop_money_before,
		"A blocked store-phase evolution charged gold."
	):
		return
	if not await _audit_full_roster(fake_main):
		return

	print("Tower evolution smoke test passed: full playable roster data, level gates, every per-instance choice, wave/build timing, store lockout, XP/item preservation, and Level 20 capstone reloads.")
	get_tree().quit(0)


func _audit_full_roster(fake_main: Node) -> bool:
	fake_main.shop_open = false
	fake_main.round_active = true
	for family_id in GameStats.get_playable_tower_family_ids():
		var evolutions := GameStats.get_tower_evolutions(family_id)
		if not _check(not evolutions.is_empty(), "%s has no evolution choices." % family_id):
			return false
		for evolution_key in evolutions:
			var evolution_id := StringName(evolution_key)
			var evolution: Dictionary = evolutions[evolution_key]
			if not _check(
				int(evolution.get("required_level", -1)) == GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL,
				"%s/%s does not unlock at Level %d." % [family_id, evolution_id, GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL]
			):
				return false
			var legacy_path_id := StringName(evolution.get("legacy_path_id", &""))
			if not _check(
				not legacy_path_id.is_empty()
				and GameStats.get_tower(family_id).get("paths", {}).has(legacy_path_id),
				"%s/%s points to a missing gameplay path." % [family_id, evolution_id]
			):
				return false
			if not _check(
				not evolution.get("level_20", {}).is_empty(),
				"%s/%s has no Level 20 capstone definition." % [family_id, evolution_id]
			):
				return false

			var tower := await _create_tower(fake_main, family_id)
			_level_to_evolution(tower)
			var xp_before: float = tower.instance_progression.xp
			tower.instance_progression.set_equipped_item(0, &"calibrated_gears", 2)
			fake_main.money = 100_000
			tower.select_evolution_choice(evolution_id)
			tower.purchase_selected_evolution()
			if not _check(
				tower.instance_progression.evolution_id == evolution_id,
				"%s/%s could not be purchased at Level 10." % [family_id, evolution_id]
			):
				return false
			if not _check(
				is_equal_approx(tower.instance_progression.xp, xp_before),
				"%s/%s reset XP during evolution." % [family_id, evolution_id]
			):
				return false
			if not _check(
				tower.instance_progression.equipped_item_ids[0] == &"calibrated_gears"
				and tower.instance_progression.equipped_item_counts[0] == 2,
				"%s/%s did not preserve its equipped item stack." % [family_id, evolution_id]
			):
				return false
			tower.instance_progression.grant_xp(
				tower.instance_progression.get_total_xp_required_for_level(
					GameStats.TOWER_XP_MAX_LEVEL
				) - tower.instance_progression.xp
			)
			tower.load_base_tags()
			tower.load_level_stats()
			if not _check(
				tower.instance_progression.level == GameStats.TOWER_XP_MAX_LEVEL,
				"%s/%s did not reach Level 20 for its capstone reload." % [family_id, evolution_id]
			):
				return false
			tower.queue_free()
			await get_tree().process_frame
	return true


func _create_tower(fake_main: Node, tower_id: StringName) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _level_to_evolution(tower: BaseTower) -> void:
	tower.instance_progression.grant_xp(
		tower.instance_progression.get_total_xp_required_for_level(
			GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL
		)
	)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
