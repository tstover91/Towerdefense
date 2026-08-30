extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")
const GameStats = preload("res://stat_database.gd")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000_000
	var targeting_tower: Node

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func get_relic_count(_relic_id: StringName) -> int:
		return 0

	func show_tower_details(_tower: Node) -> void:
		pass

	func clear_tower_details(_tower: Node) -> void:
		pass

	func begin_manual_tower_targeting(tower: Node) -> void:
		targeting_tower = tower

	func spend_money(amount: int) -> bool:
		if amount > money:
			return false
		money -= amount
		return true


func _ready() -> void:
	call_deferred("run_test")


func create_tower(tower_id: StringName, fake_main: Node) -> BaseTower:
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = tower_id
	tower.main = fake_main
	add_child(tower)
	return tower


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)

	var invader := create_tower(&"invader", fake_main)
	assert(invader.menu_controller != null)
	invader.set_selected(true)
	assert(not invader.get_node("HBoxContainer").visible)
	assert(invader.get_node("HBoxContainer/targetmode").text == "Target\nFirst")
	invader._on_targetmode_pressed()
	assert(not invader.has_node("DirectionUI"))
	assert(invader.selected)
	invader.set_selected(true)
	assert(not invader.get_node("HBoxContainer/upgradetower").visible)
	invader._on_upgradetower_pressed()
	assert(invader.pending_action == BaseTower.MenuAction.NONE)

	var gauss := create_tower(&"gauss_repeater", fake_main)
	assert(not gauss.has_node("DirectionUI"))
	assert(gauss.get_node("HBoxContainer/targetmode").text == "Set Aim\nDirection")
	gauss.set_selected(true)
	gauss._on_targetmode_pressed()
	assert(fake_main.targeting_tower == gauss)
	assert(not gauss.get_node("targetui").visible)
	assert(gauss.confirm_manual_target_position(gauss.global_position + Vector2.DOWN * 100.0))
	assert(gauss.aim_direction == Vector2.DOWN)
	assert(gauss.has_directional_aim_marker)

	var fisherman := create_tower(&"fisherman", fake_main)
	assert(not fisherman.has_node("DirectionUI"))
	assert(fisherman.get_node("HBoxContainer/targetmode").text == "Set Aim\nDirection")
	assert(fisherman.uses_finite_directional_range())

	var orbital := create_tower(&"orbitalcannon", fake_main)
	orbital.set_selected(true)
	orbital._on_targetmode_pressed()
	assert(fake_main.targeting_tower == orbital)
	assert(not orbital.get_node("HBoxContainer").visible)
	assert(orbital.range_preview_visible)

	var depot := create_tower(&"dronedepot", fake_main)
	assert(not depot.get_node("HBoxContainer/targetmode").visible)
	depot.purchased_paths.assign([&"a"])
	depot.load_base_tags()
	depot.load_level_stats()
	depot.menu_controller.update_menu_buttons()
	assert(depot.get_node("HBoxContainer/targetmode").text == "Drones\nDistributed")
	depot.set_selected(true)
	depot._on_targetmode_pressed()
	assert(depot.get_node("targetui/button_first").text == "Distributed")
	assert(depot.get_node("targetui/button_last").text == "Focus: Max HP")
	assert(not depot.get_node("targetui/button_low").visible)
	depot._on_button_last_pressed()
	assert(depot.get_drone_target_mode() == BaseTower.DroneTargetMode.FOCUS_MAX_HEALTH)

	var saucer := create_tower(&"saucer", fake_main)
	assert(not saucer.get_node("HBoxContainer/targetmode").visible)

	var path_tower := create_tower(&"fisherman", fake_main)
	path_tower.tower_level = GameStats.get_tower(&"fisherman")["levels"].size() - 1
	path_tower.load_base_tags()
	path_tower.load_level_stats()
	path_tower.set_selected(true)
	path_tower.show_path_menu()
	assert(not path_tower.get_node("pathui").visible)
	assert(path_tower.get_node("pathui/PathA").visible)
	assert(path_tower.get_node("pathui/PathB").visible)

	print("Tower menu controller smoke test passed: sidebar targeting, direction selection, manual targeting, and path state.")
	get_tree().quit(0)
