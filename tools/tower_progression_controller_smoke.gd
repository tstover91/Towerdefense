extends Node

const GameStats = preload("res://stat_database.gd")
const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000

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

	func clear_tower_details(_tower: Node) -> void:
		pass


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"fisherman"
	tower.main = fake_main
	add_child(tower)
	if not _check(tower.progression_controller != null, "Progression controller was not created."):
		return

	var levels: Array = GameStats.get_tower(&"fisherman")["levels"]
	var money_before_upgrade := fake_main.money
	tower._on_upgradetower_pressed()
	if not _check(
		tower.pending_action == BaseTower.MenuAction.NONE,
		"Automatic progression still requested a paid upgrade confirmation."
	):
		return
	tower._on_upgradetower_pressed()
	if not _check(tower.tower_level == 0, "Paid upgrade changed the automatic stat rank."):
		return
	if not _check(
		fake_main.money == money_before_upgrade,
		"Disabled paid upgrade still charged gold."
	):
		return

	tower.tower_level = levels.size() - 1
	tower.load_base_tags()
	tower.load_level_stats()
	var path_a := GameStats.get_tower_path(&"fisherman", &"a")
	var path_a_cost := int(path_a.get("cost", 0))
	var money_before_path := fake_main.money
	tower.select_path_choice(&"a")
	tower.purchase_selected_path()
	if not _check(tower.purchased_paths.has(&"a"), "Selected path was not purchased."):
		return
	if not _check(
		fake_main.money == money_before_path - path_a_cost,
		"Path purchase charged the wrong amount."
	):
		return
	if not _check(
		not tower.can_purchase_path(&"b", false),
		"Second path was available after choosing an evolution path."
	):
		return

	var sell_price := tower.get_sell_price()
	var money_before_sale := fake_main.money
	var sale_state := {"sold": false}
	tower.tower_sold.connect(
		func(_sold_tower: Node2D) -> void: sale_state["sold"] = true
	)
	tower._on_selltower_pressed()
	if not _check(
		tower.pending_action == BaseTower.MenuAction.SELL,
		"First sell press did not request confirmation."
	):
		return
	tower._on_selltower_pressed()
	if not _check(sale_state["sold"], "Confirmed sale did not emit tower_sold."):
		return
	if not _check(
		fake_main.money == money_before_sale + sell_price,
		"Confirmed sale credited the wrong amount."
	):
		return

	print("Tower progression controller smoke test passed: paid upgrades disabled, legacy paths, sell values, and sale flow.")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false
