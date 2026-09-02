extends Node

const TOWER_SCENE = preload("res://base_tower.tscn")


class FakeMain:
	extends Node
	signal money_changed(new_amount: int)
	signal round_started(round_number: int)
	signal round_ended(round_number: int)
	var round_active := false
	var sandbox_mode := true
	var money := 1_000_000
	var owned_shop_items: Dictionary = {}
	var lightweight_refreshes := 0
	var full_refreshes := 0

	func get_run_bonus(_effect: StringName) -> float:
		return 0.0

	func refresh_tower_xp_display(_tower: Node) -> void:
		lightweight_refreshes += 1

	func show_tower_details(_tower: Node) -> void:
		full_refreshes += 1


func _ready() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var fake_main := FakeMain.new()
	add_child(fake_main)
	var tower := TOWER_SCENE.instantiate() as BaseTower
	tower.tower_id = &"invader"
	tower.main = fake_main
	add_child(tower)
	await get_tree().process_frame

	tower.selected = true
	for _event in 20:
		tower.instance_progression.grant_xp(0.01)
	assert(fake_main.lightweight_refreshes == 0)
	tower._process(0.016)
	assert(fake_main.lightweight_refreshes == 1)

	for _event in 20:
		tower.instance_progression.grant_xp(0.01)
	tower._process(0.10)
	assert(fake_main.lightweight_refreshes == 1)
	tower._process(0.10)
	assert(fake_main.lightweight_refreshes == 2)

	tower.selected = false
	var refreshes_before_hidden_xp := fake_main.lightweight_refreshes
	var level_before_hidden_xp: int = tower.instance_progression.level
	tower.instance_progression.grant_xp(500.0)
	await get_tree().process_frame
	assert(tower.instance_progression.level > level_before_hidden_xp)
	assert(fake_main.lightweight_refreshes == refreshes_before_hidden_xp)
	assert(fake_main.full_refreshes == 0)

	tower.is_placed = true
	var notification_level: int = (
		11 if tower.instance_progression.level == 10 else 10
	)
	tower.instance_progression.set_level_for_sandbox(notification_level)
	assert(tower.level_up_notification.visible)
	assert(tower.level_up_notification.text == "LEVEL %d!" % notification_level)
	assert(tower.upgrade_ready_indicator.visible)
	fake_main.money = 0
	fake_main.money_changed.emit(fake_main.money)
	assert(not tower.upgrade_ready_indicator.visible)
	fake_main.money = 1_000_000
	fake_main.money_changed.emit(fake_main.money)
	assert(tower.upgrade_ready_indicator.visible)
	await get_tree().create_timer(1.6).timeout
	assert(not tower.level_up_notification.visible)

	print("Progression UI refresh smoke test passed: selected XP is throttled, hidden cards do no UI work, level-up notices expire, and affordable evolutions are marked in-world.")
	get_tree().quit(0)
