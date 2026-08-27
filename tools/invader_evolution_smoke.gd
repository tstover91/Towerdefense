extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := true
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
	var base := await _create_tower(fake_main)
	_check_base_invader(base)

	var gunslinger := await _create_evolved_tower(fake_main, &"gunslinger")
	assert(gunslinger.delivery_type == GameStats.DELIVERY_HITSCAN)
	assert(gunslinger.attack_component == null)
	assert(gunslinger.has_bonus_tag(&"critical"))
	assert(is_equal_approx(gunslinger.critical_chance, 0.10))
	_level_to(gunslinger, GameStats.TOWER_XP_MAX_LEVEL)
	assert(is_equal_approx(gunslinger.critical_chance, 0.20))

	var gauss := await _create_evolved_tower(fake_main, &"gauss_gunner")
	assert(gauss.delivery_type == GameStats.DELIVERY_PROJECTILE)
	assert(gauss.attack_component is GaussRepeaterAttackComponent)
	assert(gauss.uses_directional_aim())
	assert(gauss.menu_controller.direction_ui != null)
	assert(not gauss.attack_component.overclock_enabled)
	_level_to(gauss, GameStats.TOWER_XP_MAX_LEVEL)
	assert(gauss.attack_component.overclock_enabled)

	var rail := await _create_evolved_tower(fake_main, &"railgunner")
	assert(rail.delivery_type == GameStats.DELIVERY_PROJECTILE)
	assert(rail.attack_component == null)
	assert(rail.pierce_count == 1)
	assert(not rail.infinite_pierce)
	_level_to(rail, GameStats.TOWER_XP_MAX_LEVEL)
	assert(rail.infinite_pierce)

	print("Invader evolution smoke test passed: base hitscan identity, per-evolution attack routing, and all three Level 20 capstones.")
	get_tree().quit(0)


func _create_tower(fake_main: Node) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"invader"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame
	return tower


func _create_evolved_tower(
	fake_main: Node,
	evolution_id: StringName
) -> BaseTower:
	var tower := await _create_tower(fake_main)
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


func _check_base_invader(tower: BaseTower) -> void:
	assert(tower.delivery_type == GameStats.DELIVERY_HITSCAN)
	assert(tower.attack_component == null)
	assert(not tower.uses_directional_aim())
	assert(not tower.has_bonus_tag(&"reveal"))
	var stats := tower.get_current_effective_stats()
	assert(int(stats["damage"]) == 30)
	assert(is_equal_approx(float(stats["firerate"]), 0.50))
	assert(is_equal_approx(float(stats["range"]), 9.35))
