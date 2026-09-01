extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")
const ITEM_SHOP_MANAGER = preload("res://tower_items/item_shop_manager.gd")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
	var shop_open := false
	var game_ended := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var relics: Dictionary = {}
	var owned_shop_items: Dictionary = {}

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(relic_id: StringName) -> int:
		return int(relics.get(relic_id, 0))

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
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"longshot"
	tower.tower_level = 3
	tower.purchased_paths.assign([&"a"])
	tower.main = fake_main
	tower.position = Vector2(300.0, 300.0)
	add_child(tower)
	tower.confirm_placement()
	var component = tower.attack_component
	assert(component != null)
	assert(not component.kill_chain_enabled)
	assert(tower.damage == roundi(2674.0 * 2.40))
	assert(is_equal_approx(tower.loaded_attack_interval, 1.65 * 1.25))
	assert(is_equal_approx(tower.critical_multiplier, 3.0))

	tower.purchased_paths.assign([&"b"])
	tower.load_base_tags()
	tower.load_level_stats()
	assert(component.kill_chain_enabled)
	assert(not tower.has_damage_tag(&"explosive"))
	assert(is_equal_approx(component.kill_reload_remaining_multiplier, 0.50))
	assert(is_equal_approx(
		component.critical_kill_reload_remaining_multiplier, 0.10
	))

	tower.attack_on_cooldown = true
	tower.damage_timer.start(1.0)
	# Merely firing or dealing nonlethal damage never invokes the kill callback,
	# so a normal reload remains untouched.
	var unreduced_reload := tower.damage_timer.time_left
	assert(unreduced_reload > 0.95)
	component._apply_kill_chain_reload_reduction(0.50)
	assert(tower.damage_timer.time_left <= 0.50)
	assert(tower.damage_timer.time_left > 0.45)
	tower.damage_timer.start(1.0)
	component._apply_kill_chain_reload_reduction(0.10)
	assert(tower.damage_timer.time_left <= 0.10)
	assert(tower.damage_timer.time_left > 0.05)

	assert(GameStats.get_tower_evolutions(&"longshot").size() == 2)
	assert(not GameStats.get_tower_item_ids().has(&"kill_chain"))
	assert(GameStats.has_tower_item(&"kill_chain"))
	assert(not GameStats.is_tower_item_shop_enabled(&"kill_chain"))
	var shop = ITEM_SHOP_MANAGER.new(RandomNumberGenerator.new())
	shop.open_shop(10, [&"kill_chain"])
	assert(not shop.offers.has(&"kill_chain"))

	var anti_materiel := await _create_evolved_tower(
		fake_main, &"anti_materiel"
	)
	assert(is_equal_approx(anti_materiel.critical_multiplier, 3.0))
	_level_to(anti_materiel, GameStats.TOWER_XP_MAX_LEVEL)
	assert(is_equal_approx(anti_materiel.critical_multiplier, 4.0))

	var kill_chain := await _create_evolved_tower(fake_main, &"kill_chain")
	var kill_chain_component = kill_chain.attack_component
	assert(kill_chain_component.kill_chain_enabled)
	assert(is_equal_approx(
		kill_chain_component.kill_reload_remaining_multiplier, 0.50
	))
	assert(is_equal_approx(
		kill_chain_component.critical_kill_reload_remaining_multiplier, 0.10
	))
	_level_to(kill_chain, GameStats.TOWER_XP_MAX_LEVEL)
	assert(is_equal_approx(
		kill_chain_component.kill_reload_remaining_multiplier, 0.35
	))
	assert(is_zero_approx(
		kill_chain_component.critical_kill_reload_remaining_multiplier
	))

	print("Longshot smoke test passed: two evolutions, Anti-Materiel mastery, Kill Chain mastery, and retired shop item compatibility.")
	get_tree().quit(0)


func _create_evolved_tower(
	fake_main: Node,
	evolution_id: StringName
) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"longshot"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	_level_to(tower, GameStats.TOWER_EVOLUTION_DEFAULT_LEVEL)
	var xp_before: float = tower.instance_progression.xp
	tower.select_evolution_choice(evolution_id)
	tower.purchase_selected_evolution()
	assert(tower.instance_progression.evolution_id == evolution_id)
	assert(is_equal_approx(tower.instance_progression.xp, xp_before))
	return tower


func _level_to(tower: BaseTower, level: int) -> void:
	var target_xp: float = (
		tower.instance_progression.get_total_xp_required_for_level(level)
	)
	tower.instance_progression.grant_xp(
		maxf(target_xp - tower.instance_progression.xp, 0.0)
	)
